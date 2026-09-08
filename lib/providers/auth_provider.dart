import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

export '../services/auth_service.dart' show AuthException, AuthResult;

/// Exposes authentication state to the widget tree.
class AuthProvider with ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  final AuthService _auth = AuthService();

  // ─── Session restore ──────────────────────────────────────────────────────

  /// Called on startup. Returns the persisted user if a session exists.
  Future<UserModel?> restoreSession() async {
    _isLoading = true;
    notifyListeners();
    try {
      final user = await _auth.getCurrentSession();
      _currentUser = user;
      return user;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Login ────────────────────────────────────────────────────────────────

  /// Returns the [UserModel] on success, throws [AuthException] on failure.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final user = await _auth.login(email: email, password: password);
      _currentUser = user;
      return user;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Registration ─────────────────────────────────────────────────────────

  /// Registers a new customer. Returns [UserModel] on success.
  Future<UserModel> register({
    required String email,
    required String name,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final user = await _auth.register(
        email: email,
        name: name,
        password: password,
        role: UserRole.customer,
      );
      _currentUser = user;
      return user;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Logout ───────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _auth.clearSession();
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
