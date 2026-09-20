import 'package:flutter/foundation.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/inventory_item.dart';
import '../models/recommendation.dart';
import '../models/customer_behaviour.dart';
import '../services/recommendation_service.dart';
import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class AppProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  // --- Recommendation System ---
  final SupabaseRecommendationService _recommendationService =
      SupabaseRecommendationService();

  List<RecommendationItem> _recommendedItems = [];
  List<RecommendationItem> _cartRecommendations = [];
  CustomerBehaviour? _customerBehaviour;
  bool _isLoadingRecommendations = false;

  List<RecommendationItem> get recommendedItems => _recommendedItems;
  List<RecommendationItem> get cartRecommendations => _cartRecommendations;
  CustomerBehaviour? get customerBehaviour => _customerBehaviour;
  bool get isLoadingRecommendations => _isLoadingRecommendations;

  AppProvider() {
    _initSupabase();
  }

  bool _isSubscribed = false;

  void _initSupabase() async {
    _fetchOrders();
    _loadRecommendations();

    if (!_isSubscribed) {
      _isSubscribed = true;
      // Listen to real-time order changes
      _supabase.channel('public:orders').onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        callback: (payload) {
          _fetchOrders();
        },
      ).subscribe();
    }
  }

  /// Load personalized recommendations for the current user.
  Future<void> _loadRecommendations() async {
    _isLoadingRecommendations = true;
    notifyListeners();

    try {
      final customerId = _supabase.auth.currentUser?.id;
      _recommendedItems = await _recommendationService.getRecommendations(
        customerId: customerId,
        cartItemIds: [],
        allMenuItems: _menuItems,
      );

      if (customerId != null) {
        _customerBehaviour =
            await _recommendationService.getCustomerBehaviour(customerId);
      }
    } catch (e) {
      debugPrint('Error loading recommendations: \$e');
    } finally {
      _isLoadingRecommendations = false;
      notifyListeners();
    }
  }

  /// Refresh cart-based cross-sell recommendations when cart changes.
  Future<void> _refreshCartRecommendations() async {
    if (_cart.isEmpty) {
      _cartRecommendations = [];
      notifyListeners();
      return;
    }
    try {
      final customerId = _supabase.auth.currentUser?.id;
      final cartIds = _cart.map((c) => c.menuItem.id).toList();
      _cartRecommendations = await _recommendationService.getRecommendations(
        customerId: customerId,
        cartItemIds: cartIds,
        allMenuItems: _menuItems,
        limit: 5,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing cart recommendations: \$e');
    }
  }

  Future<void> _fetchOrders() async {
    try {
      // Fetch orders joined with their order_items rows
      final data = await _supabase
          .from('orders')
          .select('*, order_items(id, menu_item_id, quantity)')
          .order('id', ascending: false); // fallback sort if created_at missing

      _orders.clear();
      for (final row in data) {
        try {
          // Build CartItems by matching menu_item_id to our local menu catalogue
          final rawItems = row['order_items'] as List? ?? [];
          final cartItems = <CartItem>[];
          for (final oi in rawItems) {
            final menuItemId = oi['menu_item_id']?.toString() ?? '';
            final qty = (oi['quantity'] as num?)?.toInt() ?? 1;
            // Look up the menu item in our local catalogue first
            final menuItem = _menuItems.firstWhere(
              (m) => m.id == menuItemId,
              orElse: () => MenuItem(
                id: menuItemId,
                name: 'Item #$menuItemId',
                description: '',
                price: 0,
                category: 'General',
                imageUrl: '',
              ),
            );
            cartItems.add(CartItem(menuItem: menuItem, quantity: qty));
          }

          final statusStr = row['status']?.toString() ?? 'received';
          final status = OrderStatus.values.firstWhere(
            (e) => e.name == statusStr,
            orElse: () => OrderStatus.received,
          );

          _orders.add(Order(
            id: row['id']?.toString() ?? '',
            customerId: row['customer_id']?.toString(),
            items: cartItems,
            totalAmount: (row['total_amount'] is num)
                ? (row['total_amount'] as num).toDouble()
                : 0.0,
            createdAt: row['created_at'] != null
                ? DateTime.tryParse(row['created_at'].toString()) ??
                    DateTime.now()
                : DateTime.now(),
            servedAt: row['served_at'] != null
                ? DateTime.tryParse(row['served_at'].toString())
                : null,
            status: status,
          ));
        } catch (e) {
          debugPrint('Error parsing order: $e | row: $row');
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching orders: $e');
    }
  }

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

  void toggleItemStock(String id) {
    final index = _menuItems.indexWhere((item) => item.id == id);
    if (index >= 0) {
      _menuItems[index].isOutOfStock = !_menuItems[index].isOutOfStock;
      notifyListeners();
    }
  }

  void updateItemPrice(String id, double newPrice) {
    final index = _menuItems.indexWhere((item) => item.id == id);
    if (index >= 0) {
      _menuItems[index].price = newPrice;
      notifyListeners();
    }
  }

  void addMenuItem(MenuItem item) {
    _menuItems.insert(0, item);
    _shuffledAllItems = null; // reset shuffled items so it updates
    notifyListeners();
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
    _refreshCartRecommendations();
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
      _refreshCartRecommendations();
    }
  }

  /// Places an order.
  /// Strategy: try Supabase first; if it fails for any reason
  /// (DB paused, missing column, RLS, no network), fall back to
  /// a local in-memory order so the cart→track flow always works.
  Future<bool> placeOrder() async {
    if (_cart.isEmpty) return false;

    final customerId = _supabase.auth.currentUser?.id;
    final cartSnapshot = List<CartItem>.from(_cart);
    final total = cartTotal;
    final now = DateTime.now();

    String orderId = '';

    try {
      // --- Try Supabase ---
      final orderPayload = <String, dynamic>{
        'status': 'received',
        'total_amount': total,
        if (customerId != null) 'customer_id': customerId,
      };

      final response = await _supabase
          .from('orders')
          .insert(orderPayload)
          .select('id')
          .maybeSingle()
          .timeout(const Duration(seconds: 8));

      orderId = response?['id']?.toString() ?? '';

      if (orderId.isNotEmpty) {
        // Insert order_items rows (best-effort — ignore failure)
        try {
          final orderItemsPayload = cartSnapshot.map((c) => {
            'order_id': orderId,
            'menu_item_id': c.menuItem.id,
            'quantity': c.quantity,
          }).toList();
          await _supabase.from('order_items').insert(orderItemsPayload)
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint('order_items insert failed (non-fatal): $e');
        }
      }
    } catch (e) {
      debugPrint('Supabase order insert failed (using local fallback): $e');
    }

    // If Supabase didn't give us an id, generate a local one
    if (orderId.isEmpty) {
      orderId = 'local_${now.millisecondsSinceEpoch}';
    }

    // Always add the order to local state immediately
    _orders.insert(0, Order(
      id: orderId,
      customerId: customerId,
      items: cartSnapshot,
      totalAmount: total,
      createdAt: now,
      status: OrderStatus.received,
    ));

    // Record purchases for recommendation engine (fire-and-forget)
    _recommendationService
        .recordOrderPurchases(
          orderId: orderId,
          customerId: customerId,
          items: cartSnapshot,
          totalAmount: total,
        )
        .then((_) => _loadRecommendations())
        .catchError((e) => debugPrint('Recommendation recording error: $e'));

    _cart.clear();
    _cartRecommendations = [];
    notifyListeners();
    return true;
  }


  Future<void> advanceOrderStatus(String orderId) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      final order = _orders[index];
      final currentStatusIndex = order.status.index;
      if (currentStatusIndex < OrderStatus.values.length - 1) {
        final newStatus = OrderStatus.values[currentStatusIndex + 1];

        // Update local state immediately (optimistic update)
        _orders[index] = Order(
          id: order.id,
          customerId: order.customerId,
          items: order.items,
          totalAmount: order.totalAmount,
          createdAt: order.createdAt,
          servedAt: newStatus == OrderStatus.served ? DateTime.now() : order.servedAt,
          status: newStatus,
        );
        notifyListeners();

        // Sync to Supabase (best-effort — local ID orders won't sync)
        if (!orderId.startsWith('local_')) {
          try {
            final updateData = <String, dynamic>{'status': newStatus.name};
            await _supabase.from('orders').update(updateData).eq('id', orderId)
                .timeout(const Duration(seconds: 5));
          } catch (e) {
            debugPrint('Error syncing order status to Supabase: $e');
          }
        }
      }
    }
  }

  // --- Inventory Items for Kitchen Shortage ---
  final List<InventoryItem> _inventoryItems = [
    // 1. Vegetables
    InventoryItem(id: 'inv1', name: 'Onion', category: 'Vegetables'),
    InventoryItem(id: 'inv2', name: 'Tomato', category: 'Vegetables'),
    InventoryItem(id: 'inv3', name: 'Potato', category: 'Vegetables'),
    InventoryItem(id: 'inv4', name: 'Carrot', category: 'Vegetables'),
    InventoryItem(id: 'inv5', name: 'Cabbage', category: 'Vegetables'),
    InventoryItem(id: 'inv6', name: 'Cauliflower', category: 'Vegetables'),
    InventoryItem(id: 'inv7', name: 'Beans', category: 'Vegetables'),
    InventoryItem(id: 'inv8', name: 'Capsicum', category: 'Vegetables'),
    InventoryItem(id: 'inv9', name: 'Green peas', category: 'Vegetables'),
    InventoryItem(id: 'inv10', name: 'Spinach', category: 'Vegetables'),
    InventoryItem(id: 'inv11', name: 'Brinjal/Eggplant', category: 'Vegetables'),
    InventoryItem(id: 'inv12', name: 'Okra/Lady’s finger', category: 'Vegetables'),
    InventoryItem(id: 'inv13', name: 'Cucumber', category: 'Vegetables'),
    InventoryItem(id: 'inv14', name: 'Beetroot', category: 'Vegetables'),
    InventoryItem(id: 'inv15', name: 'Ginger', category: 'Vegetables'),
    InventoryItem(id: 'inv16', name: 'Garlic', category: 'Vegetables'),
    InventoryItem(id: 'inv17', name: 'Green chilli', category: 'Vegetables'),
    InventoryItem(id: 'inv18', name: 'Coriander leaves', category: 'Vegetables'),
    InventoryItem(id: 'inv19', name: 'Curry leaves', category: 'Vegetables'),
    InventoryItem(id: 'inv20', name: 'Mint leaves', category: 'Vegetables'),
    InventoryItem(id: 'inv21', name: 'Lemon', category: 'Vegetables'),
    
    // 2. Fruits
    InventoryItem(id: 'inv22', name: 'Apple', category: 'Fruits'),
    InventoryItem(id: 'inv23', name: 'Banana', category: 'Fruits'),
    InventoryItem(id: 'inv24', name: 'Orange', category: 'Fruits'),
    InventoryItem(id: 'inv25', name: 'Pineapple', category: 'Fruits'),
    InventoryItem(id: 'inv26', name: 'Papaya', category: 'Fruits'),
    InventoryItem(id: 'inv27', name: 'Mango', category: 'Fruits'),
    InventoryItem(id: 'inv28', name: 'Watermelon', category: 'Fruits'),
    InventoryItem(id: 'inv29', name: 'Grapes', category: 'Fruits'),
    InventoryItem(id: 'inv30', name: 'Pomegranate', category: 'Fruits'),
    InventoryItem(id: 'inv31', name: 'Coconut', category: 'Fruits'),

    // 3. Grains & Cereals
    InventoryItem(id: 'inv32', name: 'Rice', category: 'Grains & Cereals'),
    InventoryItem(id: 'inv33', name: 'Wheat', category: 'Grains & Cereals'),
    InventoryItem(id: 'inv34', name: 'Maida', category: 'Grains & Cereals'),
    InventoryItem(id: 'inv35', name: 'Atta', category: 'Grains & Cereals'),
    InventoryItem(id: 'inv36', name: 'Rava/Semolina', category: 'Grains & Cereals'),
    InventoryItem(id: 'inv37', name: 'Corn flour', category: 'Grains & Cereals'),
    InventoryItem(id: 'inv38', name: 'Rice flour', category: 'Grains & Cereals'),
    InventoryItem(id: 'inv39', name: 'Oats', category: 'Grains & Cereals'),
    InventoryItem(id: 'inv40', name: 'Poha', category: 'Grains & Cereals'),
    InventoryItem(id: 'inv41', name: 'Vermicelli', category: 'Grains & Cereals'),

    // 4. Pulses & Legumes
    InventoryItem(id: 'inv42', name: 'Toor dal', category: 'Pulses & Legumes'),
    InventoryItem(id: 'inv43', name: 'Moong dal', category: 'Pulses & Legumes'),
    InventoryItem(id: 'inv44', name: 'Masoor dal', category: 'Pulses & Legumes'),
    InventoryItem(id: 'inv45', name: 'Chana dal', category: 'Pulses & Legumes'),
    InventoryItem(id: 'inv46', name: 'Urad dal', category: 'Pulses & Legumes'),
    InventoryItem(id: 'inv47', name: 'Chickpeas', category: 'Pulses & Legumes'),
    InventoryItem(id: 'inv48', name: 'Rajma', category: 'Pulses & Legumes'),
    InventoryItem(id: 'inv49', name: 'Green gram', category: 'Pulses & Legumes'),
    InventoryItem(id: 'inv50', name: 'Black gram', category: 'Pulses & Legumes'),

    // 5. Spices & Seasonings
    InventoryItem(id: 'inv51', name: 'Salt', category: 'Spices & Seasonings'),
    InventoryItem(id: 'inv52', name: 'Sugar', category: 'Spices & Seasonings'),
    InventoryItem(id: 'inv53', name: 'Black pepper', category: 'Spices & Seasonings'),
    InventoryItem(id: 'inv54', name: 'Turmeric', category: 'Spices & Seasonings'),
    InventoryItem(id: 'inv55', name: 'Red chilli powder', category: 'Spices & Seasonings'),
    InventoryItem(id: 'inv56', name: 'Coriander powder', category: 'Spices & Seasonings'),
    InventoryItem(id: 'inv57', name: 'Cumin', category: 'Spices & Seasonings'),
    InventoryItem(id: 'inv58', name: 'Mustard seeds', category: 'Spices & Seasonings'),
    InventoryItem(id: 'inv59', name: 'Fennel', category: 'Spices & Seasonings'),
    InventoryItem(id: 'inv60', name: 'Cardamom', category: 'Spices & Seasonings'),
    InventoryItem(id: 'inv61', name: 'Cloves', category: 'Spices & Seasonings'),
    InventoryItem(id: 'inv62', name: 'Cinnamon', category: 'Spices & Seasonings'),
    InventoryItem(id: 'inv63', name: 'Bay leaf', category: 'Spices & Seasonings'),
    InventoryItem(id: 'inv64', name: 'Star anise', category: 'Spices & Seasonings'),
    InventoryItem(id: 'inv65', name: 'Fenugreek', category: 'Spices & Seasonings'),
    InventoryItem(id: 'inv66', name: 'Garam masala', category: 'Spices & Seasonings'),
    InventoryItem(id: 'inv67', name: 'Curry powder', category: 'Spices & Seasonings'),
    InventoryItem(id: 'inv68', name: 'Asafoetida (hing)', category: 'Spices & Seasonings'),

    // 6. Dairy Products
    InventoryItem(id: 'inv69', name: 'Milk', category: 'Dairy Products'),
    InventoryItem(id: 'inv70', name: 'Curd/Yogurt', category: 'Dairy Products'),
    InventoryItem(id: 'inv71', name: 'Butter', category: 'Dairy Products'),
    InventoryItem(id: 'inv72', name: 'Ghee', category: 'Dairy Products'),
    InventoryItem(id: 'inv73', name: 'Cheese', category: 'Dairy Products'),
    InventoryItem(id: 'inv74', name: 'Paneer', category: 'Dairy Products'),
    InventoryItem(id: 'inv75', name: 'Cream', category: 'Dairy Products'),
    InventoryItem(id: 'inv76', name: 'Condensed milk', category: 'Dairy Products'),

    // 7. Meat, Fish & Eggs
    InventoryItem(id: 'inv77', name: 'Chicken', category: 'Meat, Fish & Eggs'),
    InventoryItem(id: 'inv78', name: 'Mutton', category: 'Meat, Fish & Eggs'),
    InventoryItem(id: 'inv79', name: 'Beef', category: 'Meat, Fish & Eggs'),
    InventoryItem(id: 'inv80', name: 'Fish', category: 'Meat, Fish & Eggs'),
    InventoryItem(id: 'inv81', name: 'Prawns/Shrimp', category: 'Meat, Fish & Eggs'),
    InventoryItem(id: 'inv82', name: 'Other seafood', category: 'Meat, Fish & Eggs'),
    InventoryItem(id: 'inv83', name: 'Eggs', category: 'Meat, Fish & Eggs'),

    // 8. Oils & Sauces
    InventoryItem(id: 'inv84', name: 'Cooking oil', category: 'Oils & Sauces'),
    InventoryItem(id: 'inv85', name: 'Coconut oil', category: 'Oils & Sauces'),
    InventoryItem(id: 'inv86', name: 'Olive oil', category: 'Oils & Sauces'),
    InventoryItem(id: 'inv87', name: 'Sesame oil', category: 'Oils & Sauces'),
    InventoryItem(id: 'inv88', name: 'Soy sauce', category: 'Oils & Sauces'),
    InventoryItem(id: 'inv89', name: 'Tomato ketchup', category: 'Oils & Sauces'),
    InventoryItem(id: 'inv90', name: 'Chilli sauce', category: 'Oils & Sauces'),
    InventoryItem(id: 'inv91', name: 'Vinegar', category: 'Oils & Sauces'),
    InventoryItem(id: 'inv92', name: 'Mayonnaise', category: 'Oils & Sauces'),
    InventoryItem(id: 'inv93', name: 'Mustard sauce', category: 'Oils & Sauces'),

    // 9. Bakery & Baking Materials
    InventoryItem(id: 'inv94', name: 'Bread', category: 'Bakery & Baking Materials'),
    InventoryItem(id: 'inv95', name: 'Buns', category: 'Bakery & Baking Materials'),
    InventoryItem(id: 'inv96', name: 'Yeast', category: 'Bakery & Baking Materials'),
    InventoryItem(id: 'inv97', name: 'Baking powder', category: 'Bakery & Baking Materials'),
    InventoryItem(id: 'inv98', name: 'Baking soda', category: 'Bakery & Baking Materials'),
    InventoryItem(id: 'inv99', name: 'Cocoa powder', category: 'Bakery & Baking Materials'),
    InventoryItem(id: 'inv100', name: 'Chocolate', category: 'Bakery & Baking Materials'),
    InventoryItem(id: 'inv101', name: 'Vanilla essence', category: 'Bakery & Baking Materials'),
    InventoryItem(id: 'inv102', name: 'Custard powder', category: 'Bakery & Baking Materials'),
    InventoryItem(id: 'inv103', name: 'Corn starch', category: 'Bakery & Baking Materials'),
    InventoryItem(id: 'inv104', name: 'Icing sugar', category: 'Bakery & Baking Materials'),

    // 10. Canned & Packaged Items
    InventoryItem(id: 'inv105', name: 'Canned tomatoes', category: 'Canned & Packaged Items'),
    InventoryItem(id: 'inv106', name: 'Canned fruits', category: 'Canned & Packaged Items'),
    InventoryItem(id: 'inv107', name: 'Pickles', category: 'Canned & Packaged Items'),
    InventoryItem(id: 'inv108', name: 'Jam', category: 'Canned & Packaged Items'),
    InventoryItem(id: 'inv109', name: 'Peanut butter', category: 'Canned & Packaged Items'),
    InventoryItem(id: 'inv110', name: 'Coconut milk', category: 'Canned & Packaged Items'),
    InventoryItem(id: 'inv111', name: 'Tomato paste', category: 'Canned & Packaged Items'),
    InventoryItem(id: 'inv112', name: 'Pasta', category: 'Canned & Packaged Items'),
    InventoryItem(id: 'inv113', name: 'Noodles', category: 'Canned & Packaged Items'),

    // 11. Beverages
    InventoryItem(id: 'inv114', name: 'Tea', category: 'Beverages'),
    InventoryItem(id: 'inv115', name: 'Coffee', category: 'Beverages'),
    InventoryItem(id: 'inv116', name: 'Milk powder', category: 'Beverages'),
    InventoryItem(id: 'inv117', name: 'Drinking water', category: 'Beverages'),
    InventoryItem(id: 'inv118', name: 'Fruit juices', category: 'Beverages'),
    InventoryItem(id: 'inv119', name: 'Soft drinks', category: 'Beverages'),
    InventoryItem(id: 'inv120', name: 'Syrups', category: 'Beverages'),

    // 12. Frozen Items
    InventoryItem(id: 'inv121', name: 'Frozen vegetables', category: 'Frozen Items'),
    InventoryItem(id: 'inv122', name: 'Frozen peas', category: 'Frozen Items'),
    InventoryItem(id: 'inv123', name: 'Frozen fries', category: 'Frozen Items'),
    InventoryItem(id: 'inv124', name: 'Frozen chicken', category: 'Frozen Items'),
    InventoryItem(id: 'inv125', name: 'Frozen seafood', category: 'Frozen Items'),
    InventoryItem(id: 'inv126', name: 'Ice cream', category: 'Frozen Items'),

    // 13. Other Common Ingredients
    InventoryItem(id: 'inv127', name: 'Cashews', category: 'Other Common Ingredients'),
    InventoryItem(id: 'inv128', name: 'Almonds', category: 'Other Common Ingredients'),
    InventoryItem(id: 'inv129', name: 'Raisins', category: 'Other Common Ingredients'),
    InventoryItem(id: 'inv130', name: 'Peanuts', category: 'Other Common Ingredients'),
    InventoryItem(id: 'inv131', name: 'Sesame seeds', category: 'Other Common Ingredients'),
    InventoryItem(id: 'inv132', name: 'Coconut', category: 'Other Common Ingredients'),
    InventoryItem(id: 'inv133', name: 'Breadcrumbs', category: 'Other Common Ingredients'),
    InventoryItem(id: 'inv134', name: 'Papad', category: 'Other Common Ingredients'),
    InventoryItem(id: 'inv135', name: 'Food colouring', category: 'Other Common Ingredients'),
    InventoryItem(id: 'inv136', name: 'Food flavouring', category: 'Other Common Ingredients'),

    // 14. Kitchen Consumables & Cleaning Materials
    InventoryItem(id: 'inv137', name: 'Aluminium foil', category: 'Kitchen Consumables & Cleaning Materials'),
    InventoryItem(id: 'inv138', name: 'Cling film', category: 'Kitchen Consumables & Cleaning Materials'),
    InventoryItem(id: 'inv139', name: 'Baking paper', category: 'Kitchen Consumables & Cleaning Materials'),
    InventoryItem(id: 'inv140', name: 'Disposable gloves', category: 'Kitchen Consumables & Cleaning Materials'),
    InventoryItem(id: 'inv141', name: 'Paper towels', category: 'Kitchen Consumables & Cleaning Materials'),
    InventoryItem(id: 'inv142', name: 'Garbage bags', category: 'Kitchen Consumables & Cleaning Materials'),
    InventoryItem(id: 'inv143', name: 'Dishwashing liquid', category: 'Kitchen Consumables & Cleaning Materials'),
    InventoryItem(id: 'inv144', name: 'Sanitizer', category: 'Kitchen Consumables & Cleaning Materials'),
    InventoryItem(id: 'inv145', name: 'Cleaning brushes', category: 'Kitchen Consumables & Cleaning Materials'),
    InventoryItem(id: 'inv146', name: 'Sponges', category: 'Kitchen Consumables & Cleaning Materials'),
  ];
  
  String _inventorySearchQuery = '';
  String get inventorySearchQuery => _inventorySearchQuery;

  void setInventorySearchQuery(String query) {
    _inventorySearchQuery = query;
    notifyListeners();
  }
  
  List<InventoryItem> get inventoryItems {
    if (_inventorySearchQuery == '') return _inventoryItems;
    final query = _inventorySearchQuery.toLowerCase();
    return _inventoryItems.where((item) => item.name.toLowerCase().contains(query)).toList();
  }

  Map<String, List<InventoryItem>> get groupedInventoryItems {
    final Map<String, List<InventoryItem>> grouped = {};
    for (var item in inventoryItems) {
      if (!grouped.containsKey(item.category)) {
        grouped[item.category] = [];
      }
      grouped[item.category]!.add(item);
    }
    return grouped;
  }
  
  void toggleInventoryStock(String id) {
    final index = _inventoryItems.indexWhere((item) => item.id == id);
    if (index >= 0) {
      _inventoryItems[index].isOutOfStock = !_inventoryItems[index].isOutOfStock;
      notifyListeners();
    }
  }
}
