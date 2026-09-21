class InventoryItem {
  final String id;
  final String name;
  final String category;
  bool isOutOfStock;
  
  // Stock-out prediction fields
  int? daysLeft;
  DateTime? expectedRunOutDate;
  String? stockStatus; // 'CRITICAL', 'WARNING', 'OK'

  // Refill and exact stock tracking
  double currentStock;
  DateTime? lastRefilledDate;

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    this.isOutOfStock = false,
    this.daysLeft,
    this.expectedRunOutDate,
    this.stockStatus,
    this.currentStock = 5000.0,
    this.lastRefilledDate,
  });
}
