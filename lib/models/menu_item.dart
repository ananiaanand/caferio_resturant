class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String imageUrl;
  final bool isSpecial;
  final bool isTopPick;
  bool isFavourite;
  bool isOutOfStock;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrl,
    this.isSpecial = false,
    this.isTopPick = false,
    this.isFavourite = false,
    this.isOutOfStock = false,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: json['price'].toDouble(),
      category: json['category'],
      imageUrl: json['imageUrl'],
      isSpecial: json['isSpecial'] ?? false,
      isTopPick: json['isTopPick'] ?? false,
      isFavourite: json['isFavourite'] ?? false,
      isOutOfStock: json['isOutOfStock'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'imageUrl': imageUrl,
      'isSpecial': isSpecial,
      'isTopPick': isTopPick,
      'isFavourite': isFavourite,
      'isOutOfStock': isOutOfStock,
    };
  }
}

class CartItem {
  final MenuItem menuItem;
  int quantity;

  CartItem({
    required this.menuItem,
    this.quantity = 1,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      menuItem: MenuItem.fromJson(json['menuItem']),
      quantity: json['quantity'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'menuItem': menuItem.toJson(),
      'quantity': quantity,
    };
  }
}
