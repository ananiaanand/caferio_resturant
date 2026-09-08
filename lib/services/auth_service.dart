import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'database_service.dart';

/// Possible outcomes from an auth operation.
enum AuthResult {
  success,
  invalidCredentials,
  emailAlreadyExists,
  weakPassword,
  invalidEmail,
  databaseError,
}

class AuthException implements Exception {
  final AuthResult result;
  final String message;
  const AuthException(this.result, this.message);
  @override
  String toString() => 'AuthException($result): $message';
}

/// Singleton authentication service.
///
/// Security model:
///   - Each user has a unique cryptographically-random 32-byte salt.
///   - Password is hashed using PBKDF2-HMAC-SHA256 with 10 000 iterations.
///   - Only the final hash (hex) and salt (hex) are stored — never the plaintext.
///   - Active session is stored in SharedPreferences as a JSON blob of [UserModel]
///     (no sensitive data — password is never included).
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _sessionKey = 'auth_session';
  static const int _pbkdfIterations = 10000;
  static const int _saltBytes = 32;

  final DatabaseService _db = DatabaseService();

  // ─── Password hashing ─────────────────────────────────────────────────────

  /// Generates a cryptographically random hex salt.
  String _generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(_saltBytes, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// PBKDF2-HMAC-SHA256 (simplified single-round HMAC-SHA256 × N iterations).
  /// Produces a 64-char hex string.
  String _hashPassword(String password, String salt) {
    final saltedKey = utf8.encode('$salt:$password');
    var hash = Hmac(sha256, saltedKey).convert(utf8.encode('caferio_v1'));

    // Iterate to slow down brute-force attacks
    for (var i = 1; i < _pbkdfIterations; i++) {
      hash = Hmac(sha256, saltedKey).convert(hash.bytes);
    }
    return hash.toString(); // 64-char hex
  }

  bool _verifyPassword(String password, String salt, String storedHash) {
    return _hashPassword(password, salt) == storedHash;
  }

  // ─── Email validation ─────────────────────────────────────────────────────

  static final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

  bool _isValidEmail(String email) => _emailRegex.hasMatch(email.trim());

  bool _isStrongPassword(String password) => password.length >= 6;

  // ─── Registration ─────────────────────────────────────────────────────────

  /// Registers a new customer account.
  ///
  /// Throws [AuthException] on validation or DB errors.
  Future<UserModel> register({
    required String email,
    required String name,
    required String password,
    UserRole role = UserRole.customer,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    final trimmedName = name.trim();

    if (!_isValidEmail(trimmedEmail)) {
      throw const AuthException(AuthResult.invalidEmail, 'Please enter a valid email address.');
    }
    if (!_isStrongPassword(password)) {
      throw const AuthException(AuthResult.weakPassword, 'Password must be at least 6 characters.');
    }
    if (trimmedName.isEmpty) {
      throw const AuthException(AuthResult.invalidCredentials, 'Name cannot be empty.');
    }

    // Check for duplicate email
    final existing = await _db.getUserByEmail(trimmedEmail);
    if (existing != null) {
      throw const AuthException(AuthResult.emailAlreadyExists, 'An account with this email already exists.');
    }

    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);
    final id = _generateUserId();
    final now = DateTime.now();

    try {
      await _db.insertUser(
        id: id,
        email: trimmedEmail,
        name: trimmedName,
        passwordHash: hash,
        salt: salt,
        role: role.stored,
      );
    } catch (e) {
      debugPrint('[AuthService] register error: $e');
      throw const AuthException(AuthResult.databaseError, 'Registration failed. Please try again.');
    }

    final user = UserModel(
      id: id,
      email: trimmedEmail,
      name: trimmedName,
      role: role,
      createdAt: now,
      lastLoginAt: now,
      loginCount: 0,
    );

    await saveSession(user);
    debugPrint('[AuthService] New user registered: $trimmedEmail (${role.stored})');
    return user;
  }

  // ─── Login ────────────────────────────────────────────────────────────────

  /// Verifies credentials and returns the [UserModel] on success.
  ///
  /// Throws [AuthException] if credentials are wrong or DB fails.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    final row = await _db.getUserByEmail(trimmedEmail);
    if (row == null) {
      throw const AuthException(AuthResult.invalidCredentials, 'Invalid email or password.');
    }

    final salt = row['salt'] as String;
    final storedHash = row['password_hash'] as String;

    // Handle legacy-seeded accounts that used the simple hash from DatabaseService._hashPassword
    final isLegacySeed = row['id'] == 'system_manager' || row['id'] == 'system_kitchen';
    bool valid;
    if (isLegacySeed) {
      valid = _verifyLegacyHash(password, salt, storedHash);
    } else {
      valid = _verifyPassword(password, salt, storedHash);
    }

    if (!valid) {
      throw const AuthException(AuthResult.invalidCredentials, 'Invalid email or password.');
    }

    await _db.recordLogin(row['id'] as String);

    // Re-fetch to get updated login_count / last_login_at
    final updated = await _db.getUserById(row['id'] as String);
    final user = UserModel.fromRow(updated!);

    await saveSession(user);
    debugPrint('[AuthService] Login: ${user.email} (${user.role.stored})');
    return user;
  }

  /// Verifies passwords for the legacy seeded staff accounts.
  bool _verifyLegacyHash(String password, String salt, String storedHash) {
    final combined = utf8.encode('$salt:$password');
    var hash = 0;
    for (final b in combined) { hash = (hash * 1337 + b) & 0xFFFFFFFFFF; }
    return hash.toRadixString(16).padLeft(12, '0') == storedHash;
  }

  // ─── Session ──────────────────────────────────────────────────────────────

  /// Saves the logged-in user to SharedPreferences for session restore.
  Future<void> saveSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, user.toJsonString());
  }

  /// Returns the currently persisted session, or null if none.
  Future<UserModel?> getCurrentSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw == null) return null;
      return UserModel.fromJsonString(raw);
    } catch (e) {
      debugPrint('[AuthService] Session restore error: $e');
      return null;
    }
  }

  /// Clears the active session (logout).
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    debugPrint('[AuthService] Session cleared');
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _generateUserId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    // Format as UUID v4
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(13, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  // ─── Admin helpers ────────────────────────────────────────────────────────

  /// Returns all registered user accounts (manager view).
  Future<List<UserModel>> getAllUsers() async {
    final rows = await _db.getAllUsers();
    return rows.map(UserModel.fromRow).toList();
  }
}
