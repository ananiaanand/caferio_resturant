import 'menu_item.dart';

enum OrderStatus {
  received('Order Received'),
  preparing('Start preparing'),
  halfDone('Half done'),
  completed('Preparation completed'),
  served('Served');

  final String label;
  const OrderStatus(this.label);
}

class Order {
  final String id;
  final List<CartItem> items;
  final double totalAmount;
  final DateTime createdAt;
  OrderStatus status;

  Order({
    required this.id,
    required this.items,
    required this.totalAmount,
    required this.createdAt,
    this.status = OrderStatus.received,
  });
}
