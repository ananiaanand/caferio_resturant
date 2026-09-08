import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A singleton service that records every user activity as a structured
/// JSON event log, persisted in SharedPreferences under [_logKey].
///
/// Each event row has at minimum:
///   { "event": "<name>", "timestamp": "<iso8601>", ...extra fields... }
class UserActivityService {
  static final UserActivityService _instance = UserActivityService._internal();
  factory UserActivityService() => _instance;
  UserActivityService._internal();

  static const String _logKey = 'user_activity_log';

  // ─── Logging ───────────────────────────────────────────────────────────────

  Future<void> log(Map<String, dynamic> event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_logKey) ?? [];
      final row = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        ...event,
      };
      existing.add(jsonEncode(row));
      await prefs.setStringList(_logKey, existing);
    } catch (e) {
      debugPrint('[UserActivityService] Failed to log event: $e');
    }
  }

  // ─── Convenience helpers ───────────────────────────────────────────────────

  Future<void> logLogin({
    required String userId,
    required String role,
  }) =>
      log({'event': 'login', 'userId': userId, 'role': role});

  Future<void> logAddToCart({
    required String userId,
    required String productId,
    required String productName,
    required double price,
  }) =>
      log({
        'event': 'add_to_cart',
        'userId': userId,
        'productId': productId,
        'productName': productName,
        'price': price,
      });

  Future<void> logRemoveFromCart({
    required String userId,
    required String productId,
    required String productName,
  }) =>
      log({
        'event': 'remove_from_cart',
        'userId': userId,
        'productId': productId,
        'productName': productName,
      });

  Future<void> logOrderPlaced({
    required String userId,
    required String orderId,
    required double total,
    required int itemCount,
    required List<Map<String, dynamic>> items,
  }) =>
      log({
        'event': 'order_placed',
        'userId': userId,
        'orderId': orderId,
        'total': total,
        'itemCount': itemCount,
        'items': items,
      });

  Future<void> logFavoriteToggled({
    required String userId,
    required String productId,
    required String productName,
    required bool isFavorite,
  }) =>
      log({
        'event': 'favorite_toggled',
        'userId': userId,
        'productId': productId,
        'productName': productName,
        'isFavorite': isFavorite,
      });

  // ─── Export / Inspect ──────────────────────────────────────────────────────

  /// Returns all logged events as a list of decoded JSON maps.
  Future<List<Map<String, dynamic>>> getAllEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_logKey) ?? [];
    return raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  /// Returns the full log as a formatted JSON string (for export/debugging).
  Future<String> exportAsJson() async {
    final events = await getAllEvents();
    return const JsonEncoder.withIndent('  ').convert(events);
  }

  /// Clears the full activity log.
  Future<void> clearLog() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logKey);
  }
}
