import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../services/database_service.dart';
import '../services/user_activity_service.dart';

export '../models/cart_item.dart';

// ─── PlacedOrder ──────────────────────────────────────────────────────────────

class PlacedOrder {
  final String id;
  final List<CartItem> items;
  final double total;
  final DateTime date;
  /// True until the kitchen staff opens the Orders tab.
  bool isNew;

  PlacedOrder({
    required this.id,
    required this.items,
    required this.total,
    required this.date,
    this.isNew = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'items': items.map((i) => i.toJson()).toList(),
        'total': total,
        'date': date.toIso8601String(),
        'isNew': isNew,
      };

  factory PlacedOrder.fromJson(Map<String, dynamic> json) => PlacedOrder(
        id: json['id'] as String,
        items: (json['items'] as List<dynamic>)
            .map((i) => CartItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        isNew: json['isNew'] as bool? ?? false,
      );
}

// ─── CartProvider ─────────────────────────────────────────────────────────────

/// Callback type used to push a new order to the KitchenProvider without
/// creating a circular dependency between providers.
typedef OnOrderPlacedCallback = Future<void> Function({
  required String id,
  required List<CartItem> items,
  required double total,
  required String customerUserId,
  String tableNumber,
});

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};
  final List<PlacedOrder> _orders = [];

  // The currently logged-in user's email; set this after login.
  String _currentUserEmail = 'user@gmail.com';
  String _currentUserId = 'guest';

  final DatabaseService _db = DatabaseService();
  final UserActivityService _activity = UserActivityService();

  /// Optional callback injected by main.dart to forward orders to KitchenProvider.
  OnOrderPlacedCallback? onOrderPlaced;

  Map<String, CartItem> get items => _items;
  List<PlacedOrder> get orders => _orders;

  int get itemCount =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      _items.values.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity));

  double get taxAndFees => subtotal * 0.065;

  double get total => subtotal + taxAndFees;

  /// Number of orders the kitchen has not yet seen.
  int get newOrderCount => _orders.where((o) => o.isNew).length;

  /// Call this after login to load the user's persisted orders.
  Future<void> loadOrdersForUser(String email, {String userId = 'guest'}) async {
    _currentUserEmail = email;
    _currentUserId = userId;
    final raw = await _db.loadOrdersCompat(email);
    _orders.clear();
    _orders.addAll(raw.map((j) => PlacedOrder.fromJson(j)));
    notifyListeners();
  }

  void addItem(Product product) {
    if (_items.containsKey(product.id)) {
      _items[product.id]!.quantity += 1;
    } else {
      _items[product.id] = CartItem(product: product);
      // Log add-to-cart event for the dataset
      _activity.logAddToCart(
        userId: _currentUserEmail,
        productId: product.id,
        productName: product.name,
        price: product.price,
      );
    }
    notifyListeners();
  }

  void decrementItem(String productId) {
    if (!_items.containsKey(productId)) return;
    if (_items[productId]!.quantity > 1) {
      _items[productId]!.quantity -= 1;
    } else {
      _items.remove(productId);
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    final item = _items[productId];
    if (item != null) {
      // Log remove-from-cart event for the dataset
      _activity.logRemoveFromCart(
        userId: _currentUserEmail,
        productId: item.product.id,
        productName: item.product.name,
      );
    }
    _items.remove(productId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  /// Places the order, persists it to the database, pushes it to the kitchen,
  /// and logs the activity event.
  Future<void> placeOrder() async {
    if (_items.isEmpty) return;

    final orderId = DateTime.now().millisecondsSinceEpoch.toString();
    final orderItems = _items.values
        .map((item) => CartItem(product: item.product, quantity: item.quantity))
        .toList();
    final orderTotal = total;

    final newOrder = PlacedOrder(
      id: orderId,
      items: orderItems,
      total: orderTotal,
      date: DateTime.now(),
      isNew: true,
    );

    _orders.insert(0, newOrder);
    _items.clear();

    // 1. Persist customer order history
    await _db.saveOrderCompat(
      userEmail: _currentUserEmail,
      orderJson: {
        ...newOrder.toJson(),
        'userId': _currentUserId,
      },
    );

    // 2. Push to KitchenProvider (real-time kitchen update)
    if (onOrderPlaced != null) {
      await onOrderPlaced!(
        id: orderId,
        items: orderItems,
        total: orderTotal,
        customerUserId: _currentUserEmail,
        tableNumber: 'Table 1',
      );
    }

    // 3. Log order_placed event for the activity dataset
    await _activity.logOrderPlaced(
      userId: _currentUserEmail,
      orderId: orderId,
      total: orderTotal,
      itemCount: orderItems.fold(0, (s, i) => s + i.quantity),
      items: orderItems
          .map((i) => {
                'productId': i.product.id,
                'productName': i.product.name,
                'quantity': i.quantity,
                'price': i.product.price,
              })
          .toList(),
    );

    notifyListeners();
  }

  /// Called when the kitchen opens the Orders tab — clears notification badges.
  Future<void> markOrdersAsSeen() async {
    bool changed = false;
    for (final order in _orders) {
      if (order.isNew) {
        order.isNew = false;
        changed = true;
      }
    }
    if (changed) {
      // Persist the updated isNew flags
      await _db.saveAllOrders(
        userEmail: _currentUserEmail,
        orders: _orders.map((o) => o.toJson()).toList(),
      );
      notifyListeners();
    }
  }
}
