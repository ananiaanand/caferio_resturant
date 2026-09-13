class InventoryItem {
  final String id;
  final String name;
  final String category;
  bool isOutOfStock;

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    this.isOutOfStock = false,
  });
}
