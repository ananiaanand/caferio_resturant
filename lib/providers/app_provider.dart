import 'package:flutter/foundation.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import 'dart:async';
import 'dart:math';

class AppProvider with ChangeNotifier {
  // Categories
  final List<String> categories = [
    'All',
    'Starters',
    'Curry',
    'Biriyani',
    'Chinese Cuisine',
    'Burgers',
    'Shawarma',
    'Mandhi Options',
    'Desserts',
    'Beverages',
  ];

  // Mock Menu Items
  final List<MenuItem> _menuItems = [
    // --- Starters ---
    MenuItem(
      id: '1',
      name: 'Paneer Tikka',
      description: 'Grilled cottage cheese with spices',
      price: 220.0,
      category: 'Starters',
      imageUrl: 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '2',
      name: 'Chicken 65',
      description: 'Spicy, deep-fried chicken starter',
      price: 250.0,
      category: 'Starters',
      imageUrl: 'https://images.unsplash.com/photo-1610057099443-fde8c4d50f91?auto=format&fit=crop&q=80&w=400',
    ),

    // --- Curry ---
    MenuItem(
      id: '3',
      name: 'Chicken Curry',
      description: 'Creamy and rich tomato-based curry',
      price: 320.0,
      category: 'Curry',
      imageUrl: 'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '4',
      name: 'Pepper Chicken',
      description: 'Spicy South Indian style pepper chicken',
      price: 340.0,
      category: 'Curry',
      imageUrl: 'assets/images/pepper_chicken.png',
    ),
    MenuItem(
      id: '5',
      name: 'Thalasserry Chicken',
      description: 'Authentic Kerala style chicken curry',
      price: 350.0,
      category: 'Curry',
      imageUrl: 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '6',
      name: 'Prawns Curry',
      description: 'Coastal style spicy prawns curry',
      price: 420.0,
      category: 'Curry',
      imageUrl: 'assets/images/prawns_curry.png',
    ),
    MenuItem(
      id: '7',
      name: 'Kera Fish Curry',
      description: 'Traditional Kerala fish curry with coconut',
      price: 380.0,
      category: 'Curry',
      imageUrl: 'assets/images/kera_fish_curry.png',
    ),
    MenuItem(
      id: '8',
      name: 'Mutton Chaps',
      description: 'Slow cooked mutton chops in thick gravy',
      price: 450.0,
      category: 'Curry',
      imageUrl: 'assets/images/mutton_chaps.png',
    ),
    MenuItem(
      id: '9',
      name: 'Chilly Chicken',
      description: 'Spicy Indo-Chinese chicken gravy',
      price: 280.0,
      category: 'Curry',
      imageUrl: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '10',
      name: 'Gobi Manchurian',
      description: 'Crispy cauliflower tossed in Manchurian sauce',
      price: 220.0,
      category: 'Curry',
      imageUrl: 'assets/images/gobi_manchurian.png',
    ),

    // --- Biriyani ---
    MenuItem(
      id: '11',
      name: 'Chicken Biriyani',
      description: 'Aromatic basmati rice with tender chicken',
      price: 280.0,
      category: 'Biriyani',
      imageUrl: 'assets/images/chicken_biriyani.png',
    ),
    MenuItem(
      id: '12',
      name: 'Egg Biriyani',
      description: 'Spiced biriyani rice with boiled eggs',
      price: 220.0,
      category: 'Biriyani',
      imageUrl: 'assets/images/egg_biriyani.png',
    ),
    MenuItem(
      id: '13',
      name: 'Mutton Biriyani',
      description: 'Slow-cooked aromatic basmati rice with mutton',
      price: 380.0,
      category: 'Biriyani',
      imageUrl: 'assets/images/mutton_biriyani.png',
    ),
    MenuItem(
      id: '14',
      name: 'Beef Biriyani',
      description: 'Spicy beef masala layered with biriyani rice',
      price: 350.0,
      category: 'Biriyani',
      imageUrl: 'assets/images/beef_biriyani.png',
    ),
    MenuItem(
      id: '15',
      name: 'Ravuther Biriyani',
      description: 'Authentic Tamil Nadu style ravuther biriyani',
      price: 300.0,
      category: 'Biriyani',
      imageUrl: 'assets/images/ravuther_biriyani.png',
    ),
    MenuItem(
      id: '16',
      name: 'Veg Biriyani',
      description: 'Mixed vegetables cooked with fragrant rice',
      price: 200.0,
      category: 'Biriyani',
      imageUrl: 'assets/images/veg_biriyani.png',
    ),
    MenuItem(
      id: '17',
      name: 'Caferio Special Biriyani',
      description: 'Chef\'s special mixed meat biriyani',
      price: 450.0,
      category: 'Biriyani',
      imageUrl: 'assets/images/caferio_special_biriyani.png',
    ),

    // --- Chinese Cuisine ---
    MenuItem(
      id: '18',
      name: 'Fried Rice',
      description: 'Classic wok-tossed fried rice',
      price: 180.0,
      category: 'Chinese Cuisine',
      imageUrl: 'assets/images/fried_rice.png',
    ),
    MenuItem(
      id: '19',
      name: 'Sushi',
      description: 'Traditional Japanese sushi rolls',
      price: 450.0,
      category: 'Chinese Cuisine',
      imageUrl: 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '20',
      name: 'Gobi Manchurian',
      description: 'Crispy cauliflower tossed in Manchurian sauce',
      price: 220.0,
      category: 'Chinese Cuisine',
      imageUrl: 'assets/images/gobi_manchurian.png',
    ),
    MenuItem(
      id: '21',
      name: 'Dragon Chicken',
      description: 'Spicy and tangy Chinese style chicken',
      price: 290.0,
      category: 'Chinese Cuisine',
      imageUrl: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '22',
      name: 'Veg noodles',
      description: 'Stir-fried noodles with fresh vegetables',
      price: 180.0,
      category: 'Chinese Cuisine',
      imageUrl: 'https://images.unsplash.com/photo-1552611052-33e04de081de?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '23',
      name: 'Chicken noodles',
      description: 'Wok-tossed noodles with chicken strips',
      price: 220.0,
      category: 'Chinese Cuisine',
      imageUrl: 'https://images.unsplash.com/photo-1612929633738-8fe44f7ec841?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '24',
      name: 'Chicken Fried rice',
      description: 'Fried rice with egg and chicken pieces',
      price: 220.0,
      category: 'Chinese Cuisine',
      imageUrl: 'assets/images/ckn_fried_rice.png',
    ),
    MenuItem(
      id: '25',
      name: 'Egg fried rice',
      description: 'Classic fried rice with scrambled eggs',
      price: 190.0,
      category: 'Chinese Cuisine',
      imageUrl: 'assets/images/egg_fried_rice.png',
    ),
    MenuItem(
      id: '26',
      name: 'Mixed Fried Rice',
      description: 'Fried rice with chicken, prawns, and egg',
      price: 280.0,
      category: 'Chinese Cuisine',
      imageUrl: 'assets/images/mixed_fried_rice.png',
    ),

    // --- Burgers ---
    MenuItem(
      id: '27',
      name: 'Jumbo Burger',
      description: 'Extra large chicken burger with fries',
      price: 250.0,
      category: 'Burgers',
      imageUrl: 'assets/images/jumbo_burger.png',
    ),
    MenuItem(
      id: '28',
      name: 'Extra Cheese Burger',
      description: 'Double beef patty with dripping cheese',
      price: 280.0,
      category: 'Burgers',
      imageUrl: 'assets/images/extra_cheese_burger.png',
    ),
    MenuItem(
      id: '29',
      name: 'Burger Giant',
      description: 'Our signature giant triple-patty burger',
      price: 350.0,
      category: 'Burgers',
      imageUrl: 'assets/images/burger_giant.png',
    ),
    MenuItem(
      id: '30',
      name: 'Smoky Beef Burger',
      description: 'BBQ smoked beef patty with bacon',
      price: 320.0,
      category: 'Burgers',
      imageUrl: 'assets/images/smoky_beef_burger.png',
    ),
    MenuItem(
      id: '31',
      name: 'Smashed Burger',
      description: 'Crispy smashed beef patty with signature sauce',
      price: 240.0,
      category: 'Burgers',
      imageUrl: 'assets/images/smashed_burger.png',
    ),

    // --- Shawarma ---
    MenuItem(
      id: '32',
      name: 'Loaded Shawarma',
      description: 'Extra meat, cheese, and fries loaded inside',
      price: 220.0,
      category: 'Shawarma',
      imageUrl: 'https://loremflickr.com/400/400/shawarma?lock=1',
    ),
    MenuItem(
      id: '33',
      name: 'Chkn Shawarma',
      description: 'Classic grilled chicken shawarma wrap',
      price: 150.0,
      category: 'Shawarma',
      imageUrl: 'assets/images/chicken_shawarma.png',
    ),
    MenuItem(
      id: '34',
      name: 'Beef Shawarma',
      description: 'Juicy sliced beef with tahini sauce',
      price: 180.0,
      category: 'Shawarma',
      imageUrl: 'assets/images/beef_shawarma.png',
    ),
    MenuItem(
      id: '35',
      name: 'Italian Shawarma',
      description: 'Shawarma with olives, jalapenos, and mozzarella',
      price: 200.0,
      category: 'Shawarma',
      imageUrl: 'assets/images/italian_shawarma.png',
    ),
    MenuItem(
      id: '36',
      name: 'Mexican Shawarma',
      description: 'Spicy shawarma with salsa and nachos',
      price: 210.0,
      category: 'Shawarma',
      imageUrl: 'assets/images/mexican_shawarma.png',
    ),
    MenuItem(
      id: '37',
      name: 'Classic Shawarma',
      description: 'Simple Lebanese style chicken shawarma',
      price: 140.0,
      category: 'Shawarma',
      imageUrl: 'assets/images/classic_shawarma.png',
    ),
    MenuItem(
      id: '38',
      name: 'Full Meat Shawarma',
      description: 'Only meat and sauce, no veggies',
      price: 240.0,
      category: 'Shawarma',
      imageUrl: 'assets/images/full_meat_shawarma.png',
    ),

    // --- Others ---
    MenuItem(
      id: '39',
      name: 'Chicken Mandhi',
      description: 'Traditional Yemeni rice dish cooked underground',
      price: 320.0,
      category: 'Mandhi Options',
      imageUrl: 'https://images.unsplash.com/photo-1541529086526-db283c563270?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '40',
      name: 'Gulab Jamun',
      description: 'Deep fried milk dumplings in sugar syrup',
      price: 80.0,
      category: 'Desserts',
      imageUrl: 'https://images.unsplash.com/photo-1596803244618-8dbee441d70b?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '41',
      name: 'Mango Lassi',
      description: 'Refreshing yogurt-based mango drink',
      price: 90.0,
      category: 'Beverages',
      imageUrl: 'https://images.unsplash.com/photo-1546888281-7c9c04961d6e?auto=format&fit=crop&q=80&w=400',
    ),
  ];

  String _selectedCategory = 'All';
  String _searchQuery = '';
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<MenuItem> get menuItems => _menuItems;
  List<MenuItem>? _shuffledAllItems;
  List<MenuItem> get currentCategoryItems {
    List<MenuItem> items;
    if (_selectedCategory == 'All') {
      if (_shuffledAllItems == null) {
        _shuffledAllItems = List<MenuItem>.from(_menuItems)..shuffle(Random(42));
      }
      items = _shuffledAllItems!;
    } else {
      items = _menuItems.where((item) => item.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      items = items.where((item) => item.name.toLowerCase().contains(query)).toList();
    }

    return items;
  }
  List<MenuItem> get specialItems {
    final list = _menuItems.where((item) => item.isSpecial).toList();
    if (list.isEmpty) {
      final randomList = List<MenuItem>.from(_menuItems)..shuffle(Random(1));
      return randomList.take(5).toList();
    }
    return list;
  }
  
  List<MenuItem> get topPicks {
    final list = _menuItems.where((item) => item.isTopPick).toList();
    if (list.isEmpty) {
      final randomList = List<MenuItem>.from(_menuItems)..shuffle(Random(2));
      return randomList.take(5).toList();
    }
    return list;
  }
  List<MenuItem> get favouriteItems => _menuItems.where((item) => item.isFavourite).toList();

  // Cart
  final List<CartItem> _cart = [];
  List<CartItem> get cart => _cart;
  double get cartTotal => _cart.fold(0, (total, item) => total + (item.menuItem.price * item.quantity));

  // Orders
  final List<Order> _orders = [];
  List<Order> get orders => _orders;

  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void toggleFavourite(String id) {
    final index = _menuItems.indexWhere((item) => item.id == id);
    if (index >= 0) {
      _menuItems[index].isFavourite = !_menuItems[index].isFavourite;
      notifyListeners();
    }
  }

  int getCartItemQuantity(String itemId) {
    final index = _cart.indexWhere((c) => c.menuItem.id == itemId);
    if (index >= 0) return _cart[index].quantity;
    return 0;
  }

  void addToCart(MenuItem item) {
    final index = _cart.indexWhere((cartItem) => cartItem.menuItem.id == item.id);
    if (index >= 0) {
      _cart[index].quantity++;
    } else {
      _cart.add(CartItem(menuItem: item));
    }
    notifyListeners();
  }

  void removeFromCart(MenuItem item) {
    final index = _cart.indexWhere((cartItem) => cartItem.menuItem.id == item.id);
    if (index >= 0) {
      if (_cart[index].quantity > 1) {
        _cart[index].quantity--;
      } else {
        _cart.removeAt(index);
      }
      notifyListeners();
    }
  }

  void placeOrder() {
    if (_cart.isEmpty) return;

    final newOrder = Order(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      items: List.from(_cart),
      totalAmount: cartTotal,
      createdAt: DateTime.now(),
    );
    
    _orders.insert(0, newOrder);
    _cart.clear();
    notifyListeners();

    _simulateOrderProgress(newOrder);
  }

  void _simulateOrderProgress(Order order) {
    const statuses = OrderStatus.values;
    int currentStatusIndex = 0;

    Timer.periodic(const Duration(seconds: 15), (timer) {
      currentStatusIndex++;
      if (currentStatusIndex < statuses.length) {
        order.status = statuses[currentStatusIndex];
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }
}
