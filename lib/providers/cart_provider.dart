import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/database_service.dart';

// ─── CartItem ─────────────────────────────────────────────────────────────────

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'quantity': quantity,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        product: Product.fromJson(json['product'] as Map<String, dynamic>),
        quantity: json['quantity'] as int,
      );
}

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

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};
  final List<PlacedOrder> _orders = [];

  // The currently logged-in user's email; set this after login.
  String _currentUserEmail = 'user@gmail.com';

  final DatabaseService _db = DatabaseService();

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
  Future<void> loadOrdersForUser(String email) async {
    _currentUserEmail = email;
    final raw = await _db.loadOrders(email);
    _orders.clear();
    _orders.addAll(raw.map((j) => PlacedOrder.fromJson(j)));
    notifyListeners();
  }

  void addItem(Product product) {
    if (_items.containsKey(product.id)) {
      _items[product.id]!.quantity += 1;
    } else {
      _items[product.id] = CartItem(product: product);
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
    _items.remove(productId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  /// Places the order, persists it to the database, and notifies listeners.
  Future<void> placeOrder() async {
    if (_items.isEmpty) return;

    final newOrder = PlacedOrder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      items: _items.values
          .map((item) => CartItem(product: item.product, quantity: item.quantity))
          .toList(),
      total: total,
      date: DateTime.now(),
      isNew: true,
    );

    _orders.insert(0, newOrder);
    _items.clear();

    // Persist to database
    await _db.saveOrder(
      userEmail: _currentUserEmail,
      orderJson: newOrder.toJson(),
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
