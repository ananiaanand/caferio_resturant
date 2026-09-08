import 'package:flutter/foundation.dart';
import 'cart_item.dart';

/// Order statuses for kitchen lifecycle.
enum KitchenOrderStatus { received, preparing, ready, served }

extension KitchenOrderStatusExt on KitchenOrderStatus {
  String get label {
    switch (this) {
      case KitchenOrderStatus.received:
        return 'RECEIVED';
      case KitchenOrderStatus.preparing:
        return 'PREPARING';
      case KitchenOrderStatus.ready:
        return 'READY';
      case KitchenOrderStatus.served:
        return 'SERVED';
    }
  }

  String get storedValue {
    switch (this) {
      case KitchenOrderStatus.received:
        return 'received';
      case KitchenOrderStatus.preparing:
        return 'preparing';
      case KitchenOrderStatus.ready:
        return 'ready';
      case KitchenOrderStatus.served:
        return 'served';
    }
  }

  static KitchenOrderStatus fromString(String s) {
    switch (s) {
      case 'preparing':
        return KitchenOrderStatus.preparing;
      case 'ready':
        return KitchenOrderStatus.ready;
      case 'served':
        return KitchenOrderStatus.served;
      default:
        return KitchenOrderStatus.received;
    }
  }
}

class KitchenOrder {
  final String id;
  final List<CartItem> items;
  final double total;
  final String tableNumber;
  final String customerUserId;
  KitchenOrderStatus status;
  final DateTime placedAt;
  bool isNew;

  KitchenOrder({
    required this.id,
    required this.items,
    required this.total,
    required this.tableNumber,
    required this.customerUserId,
    this.status = KitchenOrderStatus.received,
    required this.placedAt,
    this.isNew = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'items': items.map((i) => i.toJson()).toList(),
        'total': total,
        'tableNumber': tableNumber,
        'customerUserId': customerUserId,
        'status': status.storedValue,
        'placedAt': placedAt.toIso8601String(),
        'isNew': isNew,
      };

  factory KitchenOrder.fromJson(Map<String, dynamic> json) {
    return KitchenOrder(
      id: json['id'] as String,
      items: (json['items'] as List<dynamic>)
          .map((i) => CartItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toDouble(),
      tableNumber: json['tableNumber'] as String? ?? 'Table 1',
      customerUserId: json['customerUserId'] as String? ?? 'guest',
      status: KitchenOrderStatusExt.fromString(json['status'] as String? ?? 'received'),
      placedAt: DateTime.parse(json['placedAt'] as String),
      isNew: json['isNew'] as bool? ?? false,
    );
  }
}
