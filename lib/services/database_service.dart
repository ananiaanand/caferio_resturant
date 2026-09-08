import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/user_model.dart';

/// Singleton SQLite database service.
///
/// Tables:
///   - `users`          — registered user accounts
///   - `orders`         — all customer orders (keyed by user_id)
///   - `login_history`  — per-login audit trail
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  // ─── Schema version — increment when adding columns/tables ───────────────
  static const int _schemaVersion = 1;

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, 'caferio.db');

    _db = await openDatabase(
      fullPath,
      version: _schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    debugPrint('[DB] Opened at $fullPath');
  }

  Database get _database {
    assert(_db != null, 'DatabaseService.init() must be called before use');
    return _db!;
  }

  // ─── Schema creation ──────────────────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id             TEXT PRIMARY KEY,
        email          TEXT UNIQUE NOT NULL,
        name           TEXT NOT NULL,
        password_hash  TEXT NOT NULL,
        salt           TEXT NOT NULL,
        role           TEXT NOT NULL DEFAULT 'customer',
        created_at     TEXT NOT NULL,
        last_login_at  TEXT NOT NULL,
        login_count    INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id            TEXT PRIMARY KEY,
        user_id       TEXT NOT NULL,
        user_email    TEXT NOT NULL,
        items_json    TEXT NOT NULL,
        total         REAL NOT NULL,
        table_number  TEXT NOT NULL DEFAULT 'Table 1',
        status        TEXT NOT NULL DEFAULT 'received',
        placed_at     TEXT NOT NULL,
        is_new        INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE login_history (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id       TEXT NOT NULL,
        user_email    TEXT NOT NULL,
        logged_in_at  TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // ── Seed the two built-in staff accounts ─────────────────────────────
    await _seedStaffAccounts(db);
    debugPrint('[DB] Schema created and staff accounts seeded');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here, e.g.:
    // if (oldVersion < 2) { await db.execute('ALTER TABLE users ADD COLUMN ...'); }
    debugPrint('[DB] Upgraded from v$oldVersion to v$newVersion');
  }

  /// Seeds the hardcoded staff logins so they work on first run.
  Future<void> _seedStaffAccounts(Database db) async {
    // Import auth helpers inline to avoid circular import
    // (salt + hash are duplicated here only for seeding)
    final managerSalt = _generateSalt('manager_seed_salt');
    final kitchenSalt = _generateSalt('kitchen_seed_salt');

    final now = DateTime.now().toIso8601String();

    await db.insert('users', {
      'id':            'system_manager',
      'email':         'manager@gmail.com',
      'name':          'Manager',
      'password_hash': _hashPassword('manager', managerSalt),
      'salt':          managerSalt,
      'role':          'manager',
      'created_at':    now,
      'last_login_at': now,
      'login_count':   0,
    });

    await db.insert('users', {
      'id':            'system_kitchen',
      'email':         'kitchen@gmail.com',
      'name':          'Kitchen Staff',
      'password_hash': _hashPassword('kitchen', kitchenSalt),
      'salt':          kitchenSalt,
      'role':          'kitchen_staff',
      'created_at':    now,
      'last_login_at': now,
      'login_count':   0,
    });
  }

  // ─── Minimal hash helpers (used only for seeding; full logic in AuthService) ─

  static String _generateSalt(String seed) {
    // Deterministic salt for seeded accounts (auth_service uses random bytes)
    final bytes = utf8.encode(seed);
    var hash = 0;
    for (final b in bytes) { hash = (hash * 31 + b) & 0xFFFFFFFF; }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  static String _hashPassword(String password, String salt) {
    final combined = utf8.encode('$salt:$password');
    var hash = 0;
    for (final b in combined) { hash = (hash * 1337 + b) & 0xFFFFFFFFFF; }
    return hash.toRadixString(16).padLeft(12, '0');
  }

  // ─── Users ────────────────────────────────────────────────────────────────

  /// Returns a user by email, or null if not found.
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final rows = await _database.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Returns a user by ID, or null.
  Future<Map<String, dynamic>?> getUserById(String id) async {
    final rows = await _database.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Inserts a new user row. Throws if email already exists.
  Future<void> insertUser({
    required String id,
    required String email,
    required String name,
    required String passwordHash,
    required String salt,
    required String role,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _database.insert(
      'users',
      {
        'id':            id,
        'email':         email.toLowerCase(),
        'name':          name,
        'password_hash': passwordHash,
        'salt':          salt,
        'role':          role,
        'created_at':    now,
        'last_login_at': now,
        'login_count':   0,
      },
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  /// Updates the last_login_at and increments login_count for a user.
  Future<void> recordLogin(String userId) async {
    final now = DateTime.now().toIso8601String();
    await _database.rawUpdate(
      'UPDATE users SET last_login_at = ?, login_count = login_count + 1 WHERE id = ?',
      [now, userId],
    );
    await _database.insert('login_history', {
      'user_id':      userId,
      'user_email':   (await getUserById(userId))?['email'] ?? '',
      'logged_in_at': now,
    });
  }

  /// Returns all registered users (for manager dashboard).
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    return _database.query('users', orderBy: 'created_at DESC');
  }

  // ─── Orders ───────────────────────────────────────────────────────────────

  /// Inserts a new order row.
  Future<void> saveOrder({
    required String id,
    required String userId,
    required String userEmail,
    required List<Map<String, dynamic>> items,
    required double total,
    String tableNumber = 'Table 1',
    String status = 'received',
  }) async {
    final now = DateTime.now().toIso8601String();
    await _database.insert(
      'orders',
      {
        'id':           id,
        'user_id':      userId,
        'user_email':   userEmail.toLowerCase(),
        'items_json':   jsonEncode(items),
        'total':        total,
        'table_number': tableNumber,
        'status':       status,
        'placed_at':    now,
        'is_new':       1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Loads orders for a specific user, newest first.
  Future<List<Map<String, dynamic>>> loadOrdersForUser(String userEmail) async {
    final rows = await _database.query(
      'orders',
      where: 'user_email = ?',
      whereArgs: [userEmail.toLowerCase()],
      orderBy: 'placed_at DESC',
    );
    return _decodeOrders(rows);
  }

  /// Loads ALL orders across all users (kitchen / manager view), newest first.
  Future<List<Map<String, dynamic>>> loadAllOrders() async {
    final rows = await _database.query('orders', orderBy: 'placed_at DESC');
    return _decodeOrders(rows);
  }

  /// Updates the status of an order.
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _database.update(
      'orders',
      {'status': status},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  /// Marks all orders as seen by the kitchen (is_new = 0).
  Future<void> markOrdersAsSeen(String userEmail) async {
    await _database.update(
      'orders',
      {'is_new': 0},
      where: 'user_email = ?',
      whereArgs: [userEmail.toLowerCase()],
    );
  }

  // ─── Login History ────────────────────────────────────────────────────────

  /// Returns login history for a user, newest first.
  Future<List<Map<String, dynamic>>> getLoginHistory(String userId) async {
    return _database.query(
      'login_history',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'logged_in_at DESC',
    );
  }

  // ─── Utilities ────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _decodeOrders(List<Map<String, dynamic>> rows) {
    return rows.map((row) {
      final m = Map<String, dynamic>.from(row);
      m['items'] = jsonDecode(m['items_json'] as String) as List<dynamic>;
      return m;
    }).toList();
  }

  /// Drops and recreates the database (for testing / dev reset).
  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    await deleteDatabase(p.join(dbPath, 'caferio.db'));
    _db = null;
    await init();
  }

  // ─── Legacy SharedPreferences shim (keeps CartProvider compatible) ────────

  /// Kept for backward compat — delegates to SQLite [saveOrder].
  Future<void> saveOrderCompat({
    required String userEmail,
    required Map<String, dynamic> orderJson,
  }) async {
    await saveOrder(
      id: orderJson['id'] as String,
      userId: orderJson['userId'] as String? ?? userEmail,
      userEmail: userEmail,
      items: (orderJson['items'] as List<dynamic>).cast<Map<String, dynamic>>(),
      total: (orderJson['total'] as num).toDouble(),
      tableNumber: orderJson['tableNumber'] as String? ?? 'Table 1',
      status: orderJson['status'] as String? ?? 'received',
    );
  }

  Future<List<Map<String, dynamic>>> loadOrdersCompat(String userEmail) =>
      loadOrdersForUser(userEmail);

  Future<void> saveAllOrdersCompat({
    required String userEmail,
    required List<Map<String, dynamic>> orders,
  }) async {
    // no-op: SQLite handles individual saves; full-list overwrite not needed
  }
}
