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
  final DateTime? servedAt;
  OrderStatus status;

  Order({
    required this.id,
    required this.items,
    required this.totalAmount,
    required this.createdAt,
    this.servedAt,
    this.status = OrderStatus.received,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      items: (json['items'] as List).map((item) => CartItem.fromJson(item)).toList(),
      totalAmount: json['total_amount'].toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      servedAt: json['served_at'] != null ? DateTime.parse(json['served_at']) : null,
      status: OrderStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => OrderStatus.received,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'items': items.map((e) => e.toJson()).toList(),
      'total_amount': totalAmount,
      'created_at': createdAt.toIso8601String(),
      if (servedAt != null) 'served_at': servedAt!.toIso8601String(),
      'status': status.name,
    };
  }
}
