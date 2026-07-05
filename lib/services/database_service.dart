import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A singleton service that persists order data using SharedPreferences.
/// Data is keyed by user email, so each user has their own order history.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ─── Orders ────────────────────────────────────────────────────────────────

  /// Returns the SharedPreferences key for a given user's orders.
  String _ordersKey(String userEmail) => 'orders_$userEmail';

  /// Saves a new order to the database under the user's key.
  Future<void> saveOrder({
    required String userEmail,
    required Map<String, dynamic> orderJson,
  }) async {
    final prefs = _prefs!;
    final key = _ordersKey(userEmail);
    final existing = prefs.getStringList(key) ?? [];
    existing.insert(0, jsonEncode(orderJson));
    await prefs.setStringList(key, existing);
  }

  /// Loads all orders for a given user from the database.
  Future<List<Map<String, dynamic>>> loadOrders(String userEmail) async {
    final prefs = _prefs!;
    final key = _ordersKey(userEmail);
    final raw = prefs.getStringList(key) ?? [];
    return raw
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList();
  }

  /// Persists the full list of orders (used when updating isNew flags).
  Future<void> saveAllOrders({
    required String userEmail,
    required List<Map<String, dynamic>> orders,
  }) async {
    final prefs = _prefs!;
    final key = _ordersKey(userEmail);
    await prefs.setStringList(
      key,
      orders.map((o) => jsonEncode(o)).toList(),
    );
  }

  /// Clears all data (for testing / logout).
  Future<void> clearUserData(String userEmail) async {
    await _prefs?.remove(_ordersKey(userEmail));
  }
}
