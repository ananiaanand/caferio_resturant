class MenuItem {
  final String id;
  final String name;
  final String description;
  double price;
  final String category;
  final String imageUrl;
  final bool isSpecial;
  final bool isTopPick;
  bool isFavourite;
  bool isOutOfStock;
  final List<String> ingredients;

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
    this.ingredients = const [],
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      description: json['description']?.toString() ?? '',
      price: (json['price'] is num) ? (json['price'] as num).toDouble() : 0.0,
      category: json['category']?.toString() ?? 'General',
      imageUrl: json['imageUrl']?.toString() ?? '',
      isSpecial: json['isSpecial'] as bool? ?? false,
      isTopPick: json['isTopPick'] as bool? ?? false,
      isFavourite: json['isFavourite'] as bool? ?? false,
      isOutOfStock: json['isOutOfStock'] as bool? ?? false,
      ingredients: (json['ingredients'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
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
      'ingredients': ingredients,
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

  /// Parses a CartItem from JSON.
  /// Handles two formats:
  /// 1. Flat (Supabase JSONB): `{ "id": "1", "name": "Burger", "quantity": 2, ... }`
  /// 2. Nested (legacy): `{ "menuItem": { "id": "1", ... }, "quantity": 2 }`
  factory CartItem.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('menuItem') && json['menuItem'] is Map) {
      // Legacy nested format
      return CartItem(
        menuItem: MenuItem.fromJson(json['menuItem'] as Map<String, dynamic>),
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      );
    }
    // Flat JSONB format stored directly in Supabase orders.items
    return CartItem(
      menuItem: MenuItem.fromJson(json),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'menuItem': menuItem.toJson(),
      'quantity': quantity,
    };
  }
}
