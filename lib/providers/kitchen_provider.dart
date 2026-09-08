import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/kitchen_order.dart';
import '../models/cart_item.dart';
import 'ingredient_provider.dart';

/// Provider that manages the kitchen's view of all orders.
/// Orders are persisted to SharedPreferences so they survive app restarts.
class KitchenProvider with ChangeNotifier {
  static const String _storageKey = 'kitchen_orders';

  final List<KitchenOrder> _orders = [];

  List<KitchenOrder> get orders => List.unmodifiable(_orders);

  /// Orders the kitchen has not yet acknowledged.
  int get newOrderCount => _orders.where((o) => o.isNew).length;

  /// Active orders (not yet served/cancelled).
  List<KitchenOrder> get activeOrders =>
      _orders.where((o) => o.status != KitchenOrderStatus.served).toList();

  // ─── Load / Persist ────────────────────────────────────────────────────────

  /// Call once at startup to restore persisted kitchen orders.
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_storageKey) ?? [];
      _orders
        ..clear()
        ..addAll(
            raw.map((e) => KitchenOrder.fromJson(jsonDecode(e) as Map<String, dynamic>)));
      notifyListeners();
    } catch (e) {
      debugPrint('[KitchenProvider] loadFromStorage error: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _storageKey,
        _orders.map((o) => jsonEncode(o.toJson())).toList(),
      );
    } catch (e) {
      debugPrint('[KitchenProvider] _persist error: $e');
    }
  }

  // ─── Mutations ─────────────────────────────────────────────────────────────

  /// Called from CartProvider.placeOrder() to push a new order to the kitchen.
  Future<void> addOrder({
    required String id,
    required List<CartItem> items,
    required double total,
    required String customerUserId,
    String tableNumber = 'Table 1',
    required IngredientProvider ingredientProvider,
  }) async {
    final order = KitchenOrder(
      id: id,
      items: items,
      total: total,
      tableNumber: tableNumber,
      customerUserId: customerUserId,
      status: KitchenOrderStatus.received,
      placedAt: DateTime.now(),
      isNew: true,
    );
    _orders.insert(0, order);
    await _persist();

    // Consume stock and run predictions
    await ingredientProvider.consumeForOrder(items, id);

    notifyListeners();
  }

  /// Advances an order through the status lifecycle.
  Future<void> updateStatus(String orderId, KitchenOrderStatus newStatus) async {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    _orders[idx].status = newStatus;
    await _persist();
    notifyListeners();
  }

  /// Marks all new orders as seen (clears notification badge).
  Future<void> markAllSeen() async {
    bool changed = false;
    for (final order in _orders) {
      if (order.isNew) {
        order.isNew = false;
        changed = true;
      }
    }
    if (changed) {
      await _persist();
      notifyListeners();
    }
  }
}
