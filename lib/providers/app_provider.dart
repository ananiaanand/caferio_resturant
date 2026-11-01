import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/inventory_item.dart';
import '../models/recommendation.dart';
import '../models/customer_behaviour.dart';
import '../services/recommendation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Authentication/auth_service.dart';
import '../services/rag_service.dart';

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

  static AppProvider? instance;
  StreamSubscription<AuthState>? _authSubscription;
  String _currentUserKey = 'guest';

  String get activeUserKey {
    final uname = AuthService.instance.currentUsername?.trim().toLowerCase();
    if (uname != null && uname.isNotEmpty) return uname;
    final uid = AuthService.instance.currentUser?.id;
    if (uid != null && uid.isNotEmpty) return uid;
    return 'guest';
  }

  AppProvider() {
    instance = this;
    _currentUserKey = activeUserKey;
    _initSupabase();
    fetchMLStockoutPredictions();
    _listenToAuthChanges();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _listenToAuthChanges() {
    _authSubscription?.cancel();
    _authSubscription =
        AuthService.instance.onAuthStateChange.listen((_) {
      _onAuthChanged();
    });
  }

  Future<void> _onAuthChanged() async {
    final newKey = activeUserKey;
    _currentUserKey = newKey;

    // 1. Wipe in-memory state cleanly
    _cart.clear();
    _orders.clear();
    _cartRecommendations = [];
    _customerBehaviour = null;
    for (var item in _menuItems) {
      item.isFavourite = false;
    }
    RagService.instance.clearCustomerHistoryInMemory();
    _recommendationService.clearCache();

    // 2. Load strictly user-scoped data if an account is authenticated
    if (newKey != 'guest') {
      await _loadCart();
      await _loadFavourites();
      await _loadOrders();
      await _loadRecommendations();
    }
    notifyListeners();
  }

  /// Cleanly purge all in-memory and temporary guest data on user sign out.
  Future<void> onUserSignedOut() async {
    _currentUserKey = 'guest';
    _cart.clear();
    _orders.clear();
    _cartRecommendations = [];
    _customerBehaviour = null;
    for (var item in _menuItems) {
      item.isFavourite = false;
    }
    RagService.instance.clearCustomerHistoryInMemory();
    _recommendationService.clearCache();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('caferio_cart_guest');
      await prefs.remove('caferio_favs_guest');
      await prefs.remove('caferio_orders_guest');
      await prefs.remove('caferio_chat_history_customer_guest');
    } catch (_) {}

    notifyListeners();
  }

  Future<void> fetchMLStockoutPredictions() async {
    try {
      final itemsPayload = _inventoryItems
          .map(
            (i) => {
              "ingredient": i.name,
              "current_stock": i.currentStock,
              "lead_time_days": 1,
            },
          )
          .toList();

      final res = await http.post(
        Uri.parse('http://127.0.0.1:8000/predict/stockout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'items': itemsPayload, 'horizon_days': 21}),
      );

      if (res.statusCode == 200) {
        final results = jsonDecode(res.body)['results'] as List;
        for (var resItem in results) {
          final ingredientName = resItem['ingredient'];

          final itemIndex = _inventoryItems.indexWhere(
            (i) => i.name == ingredientName,
          );
          if (itemIndex != -1) {
            final item = _inventoryItems[itemIndex];
            item.stockStatus = resItem['status'];
            item.daysLeft = resItem['days_left'];
            if (resItem['runout_expected'] != null) {
              item.expectedRunOutDate = DateTime.tryParse(
                resItem['runout_expected'],
              );
            }
          }
        }
        notifyListeners();
        return;
      } else {
        debugPrint('ML API error: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Failed to connect to ML backend (is it running?): $e');
    }

    // Fallback: Generate mock data for UI demo purposes if API is unreachable
    debugPrint('Using mock ML data for UI demonstration');
    final rnd = Random();
    for (var item in _inventoryItems) {
      // 10% critical, 20% warning, 70% OK
      final r = rnd.nextDouble();
      if (r < 0.1) {
        item.stockStatus = 'CRITICAL';
        item.daysLeft = rnd.nextInt(2); // 0 to 1
      } else if (r < 0.3) {
        item.stockStatus = 'WARNING';
        item.daysLeft = rnd.nextInt(3) + 2; // 2 to 4
      } else {
        item.stockStatus = 'OK';
        item.daysLeft = rnd.nextInt(15) + 5; // 5 to 19
      }
      item.expectedRunOutDate = DateTime.now().add(
        Duration(days: item.daysLeft ?? 0),
      );
    }
    notifyListeners();
  }

  Future<void> refillItem(String id, double amount) async {
    final index = _inventoryItems.indexWhere((item) => item.id == id);
    if (index >= 0) {
      final item = _inventoryItems[index];
      item.currentStock += amount;
      item.lastRefilledDate = DateTime.now();

      // Update ML prediction now that stock changed
      await fetchMLStockoutPredictions();

      // Send refill log to Python backend
      try {
        await http.post(
          Uri.parse('http://127.0.0.1:8000/refill'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'ingredient': item.name,
            'amount': amount,
            'date': item.lastRefilledDate!.toIso8601String(),
          }),
        );
      } catch (e) {
        debugPrint('Failed to log refill to ML backend: $e');
      }
    }
  }

  bool _isSubscribed = false;

  void _initSupabase() async {
    _fetchOrders();
    _loadRecommendations();
    _loadCart();
    _loadOrders();
    _loadFavourites();

    if (!_isSubscribed) {
      _isSubscribed = true;
      // Listen to real-time order changes
      _supabase
          .channel('public:orders')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) {
              _fetchOrders();
            },
          )
          .subscribe();
    }
  }

  Future<void> _saveCart() async {
    try {
      _currentUserKey = activeUserKey;
      final prefs = await SharedPreferences.getInstance();
      final key = 'caferio_cart_$_currentUserKey';
      final cartJson = jsonEncode(_cart.map((c) => c.toJson()).toList());
      await prefs.setString(key, cartJson);
    } catch (e) {
      debugPrint('Error saving cart for $_currentUserKey: $e');
    }
  }

  Future<void> _loadCart() async {
    try {
      _currentUserKey = activeUserKey;
      final prefs = await SharedPreferences.getInstance();
      final key = 'caferio_cart_$_currentUserKey';
      final cartString = prefs.getString(key);
      _cart.clear();
      if (cartString != null && cartString.isNotEmpty) {
        final decoded = jsonDecode(cartString) as List;
        for (final item in decoded) {
          final cartItem = CartItem.fromJson(item as Map<String, dynamic>);
          // Verify the item still exists in the menu catalogue
          final menuIndex = _menuItems.indexWhere(
            (m) => m.id == cartItem.menuItem.id,
          );
          if (menuIndex >= 0) {
            _cart.add(
              CartItem(
                menuItem: _menuItems[menuIndex],
                quantity: cartItem.quantity,
              ),
            );
          }
        }
      }
      notifyListeners();
      _refreshCartRecommendations();
    } catch (e) {
      debugPrint('Error loading cart for $_currentUserKey: $e');
    }
  }

  Future<void> _saveOrders() async {
    try {
      _currentUserKey = activeUserKey;
      final prefs = await SharedPreferences.getInstance();
      // 1. Maintain global restaurant orders (for kitchen/admin)
      final allOrdersString = prefs.getString('caferio_all_orders');
      final List<Order> combinedAll = [];
      if (allOrdersString != null && allOrdersString.isNotEmpty) {
        try {
          final decoded = jsonDecode(allOrdersString) as List;
          combinedAll.addAll(
            decoded.map((item) => Order.fromJson(item as Map<String, dynamic>)),
          );
        } catch (_) {}
      }
      for (final o in _orders) {
        final existingIdx = combinedAll.indexWhere((existing) => existing.id == o.id);
        if (existingIdx >= 0) {
          combinedAll[existingIdx] = o;
        } else {
          combinedAll.insert(0, o);
        }
      }
      await prefs.setString(
        'caferio_all_orders',
        jsonEncode(combinedAll.map((o) => o.toJson()).toList()),
      );

      // 2. Save user-scoped orders (strictly separated per customer account)
      if (_currentUserKey != 'guest') {
        final myOrders = _orders.where((o) => _isOrderForCurrentUser(o)).toList();
        final userOrdersJson = jsonEncode(myOrders.map((o) => o.toJson()).toList());
        await prefs.setString('caferio_orders_$_currentUserKey', userOrdersJson);
      }
    } catch (e) {
      debugPrint('Error saving local orders: $e');
    }
  }

  Future<void> _loadOrders() async {
    try {
      _currentUserKey = activeUserKey;
      final prefs = await SharedPreferences.getInstance();

      final role = AuthService.instance.currentRole;
      final isStaff = role == 'admin' || role == 'chef' || role == 'kitchen';

      final List<Order> loaded = [];

      if (isStaff) {
        // Staff loads all restaurant orders for kitchen/admin dashboard
        final allOrdersString = prefs.getString('caferio_all_orders');
        if (allOrdersString != null && allOrdersString.isNotEmpty) {
          try {
            final decoded = jsonDecode(allOrdersString) as List;
            for (final item in decoded) {
              final o = Order.fromJson(item as Map<String, dynamic>);
              if (!loaded.any((existing) => existing.id == o.id)) {
                loaded.add(o);
              }
            }
          } catch (_) {}
        }
      } else {
        // Customer or Guest ONLY loads their own personal orders:
        // 1. Load from user-scoped key
        final userOrdersString = prefs.getString('caferio_orders_$_currentUserKey');
        if (userOrdersString != null && userOrdersString.isNotEmpty) {
          try {
            final decoded = jsonDecode(userOrdersString) as List;
            for (final item in decoded) {
              final o = Order.fromJson(item as Map<String, dynamic>);
              if (_isOrderForCurrentUser(o) && !loaded.any((existing) => existing.id == o.id)) {
                loaded.add(o);
              }
            }
          } catch (_) {}
        }

        // 2. Also recover from master restaurant store (caferio_all_orders) filtered strictly for this user
        final allOrdersString = prefs.getString('caferio_all_orders');
        if (allOrdersString != null && allOrdersString.isNotEmpty) {
          try {
            final decoded = jsonDecode(allOrdersString) as List;
            for (final item in decoded) {
              final o = Order.fromJson(item as Map<String, dynamic>);
              if (_isOrderForCurrentUser(o) && !loaded.any((existing) => existing.id == o.id)) {
                loaded.add(o);
              }
            }
          } catch (_) {}
        }

        // 3. If userId differs from username, also check caferio_orders_<userId>
        final uid = AuthService.instance.currentUser?.id;
        if (uid != null && uid != _currentUserKey) {
          final uidOrdersString = prefs.getString('caferio_orders_$uid');
          if (uidOrdersString != null && uidOrdersString.isNotEmpty) {
            try {
              final decoded = jsonDecode(uidOrdersString) as List;
              for (final item in decoded) {
                final o = Order.fromJson(item as Map<String, dynamic>);
                if (_isOrderForCurrentUser(o) && !loaded.any((existing) => existing.id == o.id)) {
                  loaded.add(o);
                }
              }
            } catch (_) {}
          }
        }

        // Resync user-scoped storage so it has all loaded orders
        if (_currentUserKey != 'guest' && loaded.isNotEmpty) {
          await prefs.setString(
            'caferio_orders_$_currentUserKey',
            jsonEncode(loaded.map((o) => o.toJson()).toList()),
          );
        }
      }

      _orders.clear();
      _orders.addAll(loaded);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading local orders: $e');
    }
  }

  /// Public order refresh used by Track Order screen pull-to-refresh or navigation.
  Future<void> refreshOrders() async {
    await _loadOrders();
    try {
      await _fetchOrders();
    } catch (_) {}
  }

  /// Load personalized recommendations and user taste profile.
  Future<void> _loadRecommendations() async {
    _isLoadingRecommendations = true;
    notifyListeners();

    try {
      final uid = AuthService.instance.currentUser?.id;
      final uname = AuthService.instance.currentUsername?.trim().toLowerCase();
      final customerId = uid ?? (uname != null ? 'usr_$uname' : null);

      _recommendedItems = await _recommendationService.getRecommendations(
        customerId: customerId,
        cartItemIds: _cart.map((c) => c.menuItem.id).toList(),
        allMenuItems: _menuItems,
      );

      if (customerId != null) {
        _customerBehaviour =
            await _recommendationService.getCustomerBehaviour(customerId);
      } else {
        _customerBehaviour = null;
      }
    } catch (e) {
      debugPrint('Error loading recommendations: $e');
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
      final cartIds = _cart.map((c) => c.menuItem.id).toList();
      final uid = AuthService.instance.currentUser?.id;
      final uname = AuthService.instance.currentUsername?.trim().toLowerCase();
      final customerId = uid ?? (uname != null ? 'usr_$uname' : null);

      _cartRecommendations = await _recommendationService.getRecommendations(
        customerId: customerId,
        cartItemIds: cartIds,
        allMenuItems: _menuItems,
        limit: 5,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing cart recommendations: $e');
    }
  }

  Future<void> _fetchOrders() async {
    try {
      // Fetch orders joined with their order_items rows
      final data = await _supabase
          .from('orders')
          .select('*, order_items(id, menu_item_id, quantity)')
          .order('id', ascending: false); // fallback sort if created_at missing

      final fetchedOrders = <Order>[];
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
                ingredients: [],
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

          fetchedOrders.add(
            Order(
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
            ),
          );
        } catch (e) {
          debugPrint('Error parsing order: $e | row: $row');
        }
      }

      // 1. Preserve local offline orders and merge with remote fetched orders
      final prefs = await SharedPreferences.getInstance();
      final allOrdersString = prefs.getString('caferio_all_orders');
      final combined = List<Order>.from(fetchedOrders);
      if (allOrdersString != null && allOrdersString.isNotEmpty) {
        try {
          final decoded = jsonDecode(allOrdersString) as List;
          for (final item in decoded) {
            final local = Order.fromJson(item as Map<String, dynamic>);
            if (local.id.startsWith('local_') && !combined.any((o) => o.id == local.id)) {
              combined.add(local);
            }
          }
        } catch (_) {}
      }

      await prefs.setString(
        'caferio_all_orders',
        jsonEncode(combined.map((o) => o.toJson()).toList()),
      );

      // 2. Isolate customer orders from staff orders
      final role = AuthService.instance.currentRole;
      final isStaff = role == 'admin' || role == 'chef' || role == 'kitchen';

      _orders.clear();
      if (isStaff) {
        _orders.addAll(combined);
      } else {
        _orders.addAll(combined.where((o) => _isOrderForCurrentUser(o)));
        if (_currentUserKey != 'guest') {
          await prefs.setString(
            'caferio_orders_$_currentUserKey',
            jsonEncode(_orders.map((o) => o.toJson()).toList()),
          );
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint(
        'Error fetching orders from Supabase (falling back to local cache): $e',
      );
      // On failure, _loadOrders() handles local restoration in _initSupabase.
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
      ingredients: ['Paneer', 'Curd/Yogurt', 'Cooking oil'],
      description: 'Grilled cottage cheese with spices',
      price: 220.0,
      category: 'Starters',
      imageUrl:
          'https://images.unsplash.com/photo-1565557623262-b51c2513a641?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '2',
      name: 'Chicken 65',
      ingredients: ['Chicken', 'Cooking oil', 'Red chilli powder'],
      description: 'Spicy, deep-fried chicken starter',
      price: 250.0,
      category: 'Starters',
      imageUrl:
          'https://images.unsplash.com/photo-1610057099443-fde8c4d50f91?auto=format&fit=crop&q=80&w=400',
    ),

    // --- Curry ---
    MenuItem(
      id: '3',
      name: 'Chicken Curry',
      ingredients: ['Chicken', 'Tomato', 'Onion', 'Cooking oil'],
      description: 'Creamy and rich tomato-based curry',
      price: 320.0,
      category: 'Curry',
      imageUrl:
          'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '4',
      name: 'Pepper Chicken',
      ingredients: ['Chicken', 'Cooking oil'],
      description: 'Spicy South Indian style pepper chicken',
      price: 340.0,
      category: 'Curry',
      imageUrl: 'assets/images/pepper_chicken.png',
    ),
    MenuItem(
      id: '5',
      name: 'Thalasserry Chicken',
      ingredients: ['Chicken', 'Cooking oil'],
      description: 'Authentic Kerala style chicken curry',
      price: 350.0,
      category: 'Curry',
      imageUrl:
          'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '6',
      name: 'Prawns Curry',
      ingredients: [],
      description: 'Coastal style spicy prawns curry',
      price: 420.0,
      category: 'Curry',
      imageUrl: 'assets/images/prawns_curry.png',
    ),
    MenuItem(
      id: '7',
      name: 'Kera Fish Curry',
      ingredients: [],
      description: 'Traditional Kerala fish curry with coconut',
      price: 380.0,
      category: 'Curry',
      imageUrl: 'assets/images/kera_fish_curry.png',
    ),
    MenuItem(
      id: '8',
      name: 'Mutton Chaps',
      ingredients: ['Mutton', 'Cooking oil'],
      description: 'Slow cooked mutton chops in thick gravy',
      price: 450.0,
      category: 'Curry',
      imageUrl: 'assets/images/mutton_chaps.png',
    ),
    MenuItem(
      id: '9',
      name: 'Chilly Chicken',
      ingredients: ['Chicken', 'Cooking oil'],
      description: 'Spicy Indo-Chinese chicken gravy',
      price: 280.0,
      category: 'Curry',
      imageUrl:
          'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '10',
      name: 'Gobi Manchurian',
      ingredients: [],
      description: 'Crispy cauliflower tossed in Manchurian sauce',
      price: 220.0,
      category: 'Curry',
      imageUrl: 'assets/images/gobi_manchurian.png',
    ),

    // --- Biriyani ---
    MenuItem(
      id: '11',
      name: 'Chicken Biriyani',
      ingredients: ['Chicken', 'Rice', 'Onion', 'Cooking oil', 'Ghee'],
      description: 'Aromatic basmati rice with tender chicken',
      price: 280.0,
      category: 'Biriyani',
      imageUrl: 'assets/images/chicken_biriyani.png',
    ),
    MenuItem(
      id: '12',
      name: 'Egg Biriyani',
      ingredients: ['Rice', 'Onion', 'Ghee'],
      description: 'Spiced biriyani rice with boiled eggs',
      price: 220.0,
      category: 'Biriyani',
      imageUrl: 'assets/images/egg_biriyani.png',
    ),
    MenuItem(
      id: '13',
      name: 'Mutton Biriyani',
      ingredients: ['Mutton', 'Cooking oil'],
      description: 'Slow-cooked aromatic basmati rice with mutton',
      price: 380.0,
      category: 'Biriyani',
      imageUrl: 'assets/images/mutton_biriyani.png',
    ),
    MenuItem(
      id: '14',
      name: 'Beef Biriyani',
      ingredients: ['Beef'],
      description: 'Spicy beef masala layered with biriyani rice',
      price: 350.0,
      category: 'Biriyani',
      imageUrl: 'assets/images/beef_biriyani.png',
    ),
    MenuItem(
      id: '15',
      name: 'Ravuther Biriyani',
      ingredients: ['Rice', 'Onion', 'Ghee'],
      description: 'Authentic Tamil Nadu style ravuther biriyani',
      price: 300.0,
      category: 'Biriyani',
      imageUrl: 'assets/images/ravuther_biriyani.png',
    ),
    MenuItem(
      id: '16',
      name: 'Veg Biriyani',
      ingredients: ['Rice', 'Onion', 'Ghee'],
      description: 'Mixed vegetables cooked with fragrant rice',
      price: 200.0,
      category: 'Biriyani',
      imageUrl: 'assets/images/veg_biriyani.png',
    ),
    MenuItem(
      id: '17',
      name: 'Caferio Special Biriyani',
      ingredients: ['Rice', 'Onion', 'Ghee'],
      description: 'Chef\'s special mixed meat biriyani',
      price: 450.0,
      category: 'Biriyani',
      imageUrl: 'assets/images/caferio_special_biriyani.png',
    ),

    // --- Chinese Cuisine ---
    MenuItem(
      id: '18',
      name: 'Fried Rice',
      ingredients: ['Rice', 'Egg', 'Cooking oil'],
      description: 'Classic wok-tossed fried rice',
      price: 180.0,
      category: 'Chinese Cuisine',
      imageUrl: 'assets/images/fried_rice.png',
    ),
    MenuItem(
      id: '19',
      name: 'Sushi',
      ingredients: [],
      description: 'Traditional Japanese sushi rolls',
      price: 450.0,
      category: 'Chinese Cuisine',
      imageUrl:
          'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '20',
      name: 'Gobi Manchurian',
      ingredients: [],
      description: 'Crispy cauliflower tossed in Manchurian sauce',
      price: 220.0,
      category: 'Chinese Cuisine',
      imageUrl: 'assets/images/gobi_manchurian.png',
    ),
    MenuItem(
      id: '21',
      name: 'Dragon Chicken',
      ingredients: ['Chicken', 'Cooking oil'],
      description: 'Spicy and tangy Chinese style chicken',
      price: 290.0,
      category: 'Chinese Cuisine',
      imageUrl:
          'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '22',
      name: 'Veg noodles',
      ingredients: ['Noodles', 'Cabbage', 'Carrot', 'Capsicum', 'Cooking oil'],
      description: 'Stir-fried noodles with fresh vegetables',
      price: 180.0,
      category: 'Chinese Cuisine',
      imageUrl:
          'https://images.unsplash.com/photo-1552611052-33e04de081de?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '23',
      name: 'Chicken noodles',
      ingredients: ['Chicken', 'Cooking oil'],
      description: 'Wok-tossed noodles with chicken strips',
      price: 220.0,
      category: 'Chinese Cuisine',
      imageUrl:
          'https://images.unsplash.com/photo-1612929633738-8fe44f7ec841?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '24',
      name: 'Chicken Fried rice',
      ingredients: ['Chicken', 'Cooking oil'],
      description: 'Fried rice with egg and chicken pieces',
      price: 220.0,
      category: 'Chinese Cuisine',
      imageUrl: 'assets/images/ckn_fried_rice.png',
    ),
    MenuItem(
      id: '25',
      name: 'Egg fried rice',
      ingredients: ['Rice', 'Egg', 'Cooking oil'],
      description: 'Classic fried rice with scrambled eggs',
      price: 190.0,
      category: 'Chinese Cuisine',
      imageUrl: 'assets/images/egg_fried_rice.png',
    ),
    MenuItem(
      id: '26',
      name: 'Mixed Fried Rice',
      ingredients: ['Rice', 'Egg', 'Cooking oil'],
      description: 'Fried rice with chicken, prawns, and egg',
      price: 280.0,
      category: 'Chinese Cuisine',
      imageUrl: 'assets/images/mixed_fried_rice.png',
    ),

    // --- Burgers ---
    MenuItem(
      id: '27',
      name: 'Jumbo Burger',
      ingredients: ['Chicken', 'Buns', 'Mayonnaise'],
      description: 'Extra large chicken burger with fries',
      price: 250.0,
      category: 'Burgers',
      imageUrl: 'assets/images/jumbo_burger.png',
    ),
    MenuItem(
      id: '28',
      name: 'Extra Cheese Burger',
      ingredients: ['Beef', 'Cheese', 'Buns'],
      description: 'Double beef patty with dripping cheese',
      price: 280.0,
      category: 'Burgers',
      imageUrl: 'assets/images/extra_cheese_burger.png',
    ),
    MenuItem(
      id: '29',
      name: 'Burger Giant',
      ingredients: [],
      description: 'Our signature giant triple-patty burger',
      price: 350.0,
      category: 'Burgers',
      imageUrl: 'assets/images/burger_giant.png',
    ),
    MenuItem(
      id: '30',
      name: 'Smoky Beef Burger',
      ingredients: ['Beef'],
      description: 'BBQ smoked beef patty with bacon',
      price: 320.0,
      category: 'Burgers',
      imageUrl: 'assets/images/smoky_beef_burger.png',
    ),
    MenuItem(
      id: '31',
      name: 'Smashed Burger',
      ingredients: [],
      description: 'Crispy smashed beef patty with signature sauce',
      price: 240.0,
      category: 'Burgers',
      imageUrl: 'assets/images/smashed_burger.png',
    ),

    // --- Shawarma ---
    MenuItem(
      id: '32',
      name: 'Loaded Shawarma',
      ingredients: ['Chicken', 'Mayonnaise'],
      description: 'Extra meat, cheese, and fries loaded inside',
      price: 220.0,
      category: 'Shawarma',
      imageUrl: 'https://loremflickr.com/400/400/shawarma?lock=1',
    ),
    MenuItem(
      id: '33',
      name: 'Chkn Shawarma',
      ingredients: ['Chicken', 'Mayonnaise'],
      description: 'Classic grilled chicken shawarma wrap',
      price: 150.0,
      category: 'Shawarma',
      imageUrl: 'assets/images/chicken_shawarma.png',
    ),
    MenuItem(
      id: '34',
      name: 'Beef Shawarma',
      ingredients: ['Beef'],
      description: 'Juicy sliced beef with tahini sauce',
      price: 180.0,
      category: 'Shawarma',
      imageUrl: 'assets/images/beef_shawarma.png',
    ),
    MenuItem(
      id: '35',
      name: 'Italian Shawarma',
      ingredients: ['Chicken', 'Mayonnaise'],
      description: 'Shawarma with olives, jalapenos, and mozzarella',
      price: 200.0,
      category: 'Shawarma',
      imageUrl: 'assets/images/italian_shawarma.png',
    ),
    MenuItem(
      id: '36',
      name: 'Mexican Shawarma',
      ingredients: ['Chicken', 'Mayonnaise'],
      description: 'Spicy shawarma with salsa and nachos',
      price: 210.0,
      category: 'Shawarma',
      imageUrl: 'assets/images/mexican_shawarma.png',
    ),
    MenuItem(
      id: '37',
      name: 'Classic Shawarma',
      ingredients: ['Chicken', 'Mayonnaise'],
      description: 'Simple Lebanese style chicken shawarma',
      price: 140.0,
      category: 'Shawarma',
      imageUrl: 'assets/images/classic_shawarma.png',
    ),
    MenuItem(
      id: '38',
      name: 'Full Meat Shawarma',
      ingredients: ['Chicken', 'Mayonnaise'],
      description: 'Only meat and sauce, no veggies',
      price: 240.0,
      category: 'Shawarma',
      imageUrl: 'assets/images/full_meat_shawarma.png',
    ),

    // --- Others ---
    MenuItem(
      id: '39',
      name: 'Chicken Mandhi',
      ingredients: ['Chicken', 'Cooking oil'],
      description: 'Traditional Yemeni rice dish cooked underground',
      price: 320.0,
      category: 'Mandhi Options',
      imageUrl:
          'https://images.unsplash.com/photo-1541529086526-db283c563270?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '40',
      name: 'Gulab Jamun',
      ingredients: [],
      description: 'Deep fried milk dumplings in sugar syrup',
      price: 80.0,
      category: 'Desserts',
      imageUrl:
          'https://images.unsplash.com/photo-1596803244618-8dbee441d70b?auto=format&fit=crop&q=80&w=400',
    ),
    MenuItem(
      id: '41',
      name: 'Mango Lassi',
      ingredients: ['Mango', 'Curd/Yogurt', 'Sugar'],
      description: 'Refreshing yogurt-based mango drink',
      price: 90.0,
      category: 'Beverages',
      imageUrl:
          'https://images.unsplash.com/photo-1546888281-7c9c04961d6e?auto=format&fit=crop&q=80&w=400',
    ),
  ];

  String _selectedCategory = 'All';
  String _searchQuery = '';
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    if (_searchQuery.isEmpty && query.trim().isNotEmpty && _selectedCategory != 'All') {
      _selectedCategory = 'All';
    }
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  List<MenuItem> get menuItems => _menuItems;
  List<MenuItem>? _shuffledAllItems;
  List<MenuItem> get currentCategoryItems {
    List<MenuItem> items;
    if (_selectedCategory == 'All') {
      _shuffledAllItems ??= List<MenuItem>.from(_menuItems)
        ..shuffle(Random(42));
      items = _shuffledAllItems!;
    } else {
      items = _menuItems
          .where((item) => item.category == _selectedCategory)
          .toList();
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      items = items.where((item) {
        final matchName = item.name.toLowerCase().contains(query);
        final matchDesc = item.description.toLowerCase().contains(query);
        final matchCategory = item.category.toLowerCase().contains(query);
        final matchIngredients = item.ingredients.any(
          (ing) => ing.toLowerCase().contains(query),
        );
        return matchName || matchDesc || matchCategory || matchIngredients;
      }).toList();
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

  List<MenuItem> get favouriteItems =>
      _menuItems.where((item) => item.isFavourite).toList();

  // Cart
  final List<CartItem> _cart = [];
  List<CartItem> get cart => _cart;
  double get cartTotal => _cart.fold(
    0,
    (total, item) => total + (item.menuItem.price * item.quantity),
  );

  // Orders
  final List<Order> _orders = [];

  /// All restaurant orders (used by Kitchen and Admin management).
  List<Order> get allOrders => _orders;

  /// User-scoped orders.
  /// Track Order and customer widgets ALWAYS only see orders placed by this current user!
  /// Staff dashboards (Kitchen & Admin) use [allOrders].
  List<Order> get orders {
    try {
      return _orders.where((o) => _isOrderForCurrentUser(o)).toList();
    } catch (_) {
      return <Order>[];
    }
  }

  bool _isOrderForCurrentUser(Order order) {
    try {
      final uid = AuthService.instance.currentUser?.id.trim().toLowerCase();
      final uname = AuthService.instance.currentUsername?.trim().toLowerCase();
      final userEmail = AuthService.instance.currentUser?.email?.trim().toLowerCase();
      final cid = order.customerId?.trim().toLowerCase();

      // If order has no customerId, it cannot belong to any account
      if (cid == null || cid.isEmpty) return false;

      // If user is not authenticated: only matches if order was explicitly placed by guest
      if (uname == null && uid == null) {
        return (AuthService.instance.isGuest || true) && cid == 'guest';
      }

      // Authenticated users NEVER match anonymous guest orders
      if (cid == 'guest') return false;

      // Strict exact match with user ID (UUID or usr_<username>)
      if (uid != null && uid.isNotEmpty && cid == uid) return true;

      // Strict exact match with username
      if (uname != null && uname.isNotEmpty) {
        if (cid == uname) return true;
        if (cid == 'usr_$uname') return true;

        // Legacy or timestamped local sessions: usr_<uname>_<timestamp>
        final timestampPattern = RegExp('^usr_${RegExp.escape(uname)}_\\d{8,}\$');
        if (timestampPattern.hasMatch(cid)) return true;
      }

      // Match user's email if associated
      if (userEmail != null && userEmail.isNotEmpty && cid == userEmail) {
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void toggleFavourite(String id) {
    final index = _menuItems.indexWhere((item) => item.id == id);
    if (index >= 0) {
      _menuItems[index].isFavourite = !_menuItems[index].isFavourite;
      _saveFavourites();
      notifyListeners();
    }
  }

  Future<void> _saveFavourites() async {
    try {
      _currentUserKey = activeUserKey;
      final favIds = _menuItems.where((i) => i.isFavourite).map((i) => i.id).toList();
      final prefs = await SharedPreferences.getInstance();
      final key = 'caferio_favs_$_currentUserKey';
      await prefs.setString(key, jsonEncode(favIds));
    } catch (e) {
      debugPrint('Error saving favourites for $_currentUserKey: $e');
    }
  }

  Future<void> _loadFavourites() async {
    try {
      _currentUserKey = activeUserKey;
      for (var item in _menuItems) {
        item.isFavourite = false;
      }
      final prefs = await SharedPreferences.getInstance();
      final key = 'caferio_favs_$_currentUserKey';
      final favString = prefs.getString(key);
      if (favString != null && favString.isNotEmpty) {
        final favIds = List<String>.from(jsonDecode(favString));
        if (favIds.isNotEmpty) {
          for (var item in _menuItems) {
            item.isFavourite = favIds.contains(item.id);
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading favourites for $_currentUserKey: $e');
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
    final index = _cart.indexWhere(
      (cartItem) => cartItem.menuItem.id == item.id,
    );
    if (index >= 0) {
      _cart[index].quantity++;
    } else {
      _cart.add(CartItem(menuItem: item));
    }
    notifyListeners();
    _refreshCartRecommendations();
    _saveCart();
  }

  void removeFromCart(MenuItem item) {
    final index = _cart.indexWhere(
      (cartItem) => cartItem.menuItem.id == item.id,
    );
    if (index >= 0) {
      if (_cart[index].quantity > 1) {
        _cart[index].quantity--;
      } else {
        _cart.removeAt(index);
      }
      notifyListeners();
      _refreshCartRecommendations();
      _saveCart();
    }
  }

  /// Places an order.
  /// Associates the order with the logged-in customer's ID / username.
  /// Strategy: try Supabase first; if it fails for any reason
  /// (DB paused, missing column, RLS, no network), fall back to
  /// a local in-memory order so the cart→track flow always works.
  Future<bool> placeOrder() async {
    if (_cart.isEmpty) return false;

    final uname = AuthService.instance.currentUsername?.trim().toLowerCase();
    final uid = AuthService.instance.currentUser?.id;
    final customerId = (uname != null && uname.isNotEmpty)
        ? 'usr_$uname'
        : (uid ?? 'guest');
    final cartSnapshot = List<CartItem>.from(_cart);
    final total = cartTotal;
    final now = DateTime.now();

    String orderId = '';

    try {
      // --- Try Supabase ---
      final orderPayload = <String, dynamic>{
        'status': 'received',
        'total_amount': total,
        'customer_id': customerId,
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
          final orderItemsPayload = cartSnapshot
              .map(
                (c) => {
                  'order_id': orderId,
                  'menu_item_id': c.menuItem.id,
                  'quantity': c.quantity,
                },
              )
              .toList();
          await _supabase
              .from('order_items')
              .insert(orderItemsPayload)
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

    // Always add the order to all orders immediately
    _orders.insert(
      0,
      Order(
        id: orderId,
        customerId: customerId,
        items: cartSnapshot,
        totalAmount: total,
        createdAt: now,
        status: OrderStatus.received,
      ),
    );

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
    await _saveCart();
    await _saveOrders();
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
          servedAt: newStatus == OrderStatus.served
              ? DateTime.now()
              : order.servedAt,
          status: newStatus,
        );
        await _saveOrders();
        notifyListeners();

        // Sync to Supabase (best-effort — local ID orders won't sync)
        if (!orderId.startsWith('local_')) {
          try {
            final updateData = <String, dynamic>{'status': newStatus.name};
            await _supabase
                .from('orders')
                .update(updateData)
                .eq('id', orderId)
                .timeout(const Duration(seconds: 5));
          } catch (e) {
            debugPrint('Error syncing order status to Supabase: $e');
          }
        }
      }
    }
  }

  /// Delete all data associated with a specific user (cart, orders, favourites, recommendations).
  Future<void> deleteUserDataFor(String username, String? userId) async {
    final clean = username.trim().toLowerCase();
    _currentUserKey = 'guest';
    _cart.clear();
    _cartRecommendations = [];
    _customerBehaviour = null;
    _recommendedItems = [];

    // Remove all orders belonging strictly to this user
    _orders.removeWhere((o) {
      final cid = o.customerId?.trim().toLowerCase();
      if (cid == null) return false;
      if (cid == clean || cid == 'usr_$clean') return true;
      if (userId != null && cid == userId.toLowerCase()) return true;
      return false;
    });

    // Reset favourites on all menu items
    for (var item in _menuItems) {
      item.isFavourite = false;
    }

    // Wipe in-memory caches and chat history
    RagService.instance.clearCustomerHistoryInMemory();
    _recommendationService.clearCache();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('caferio_cart_$clean');
      await prefs.remove('caferio_favs_$clean');
      await prefs.remove('caferio_orders_$clean');
      await prefs.remove('caferio_chat_history_customer_$clean');
      await prefs.remove('user_meta_$clean');
      await prefs.remove('user_fullname_$clean');
      if (userId != null) {
        await prefs.remove('caferio_cart_$userId');
        await prefs.remove('caferio_favs_$userId');
        await prefs.remove('caferio_orders_$userId');
      }
      final allOrdersJson = jsonEncode(_orders.map((o) => o.toJson()).toList());
      await prefs.setString('caferio_all_orders', allOrdersJson);
    } catch (_) {}

    notifyListeners();
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
    InventoryItem(
      id: 'inv11',
      name: 'Brinjal/Eggplant',
      category: 'Vegetables',
    ),
    InventoryItem(
      id: 'inv12',
      name: 'Okra/Lady’s finger',
      category: 'Vegetables',
    ),
    InventoryItem(id: 'inv13', name: 'Cucumber', category: 'Vegetables'),
    InventoryItem(id: 'inv14', name: 'Beetroot', category: 'Vegetables'),
    InventoryItem(id: 'inv15', name: 'Ginger', category: 'Vegetables'),
    InventoryItem(id: 'inv16', name: 'Garlic', category: 'Vegetables'),
    InventoryItem(id: 'inv17', name: 'Green chilli', category: 'Vegetables'),
    InventoryItem(
      id: 'inv18',
      name: 'Coriander leaves',
      category: 'Vegetables',
    ),
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
    InventoryItem(
      id: 'inv36',
      name: 'Rava/Semolina',
      category: 'Grains & Cereals',
    ),
    InventoryItem(
      id: 'inv37',
      name: 'Corn flour',
      category: 'Grains & Cereals',
    ),
    InventoryItem(
      id: 'inv38',
      name: 'Rice flour',
      category: 'Grains & Cereals',
    ),
    InventoryItem(id: 'inv39', name: 'Oats', category: 'Grains & Cereals'),
    InventoryItem(id: 'inv40', name: 'Poha', category: 'Grains & Cereals'),
    InventoryItem(
      id: 'inv41',
      name: 'Vermicelli',
      category: 'Grains & Cereals',
    ),

    // 4. Pulses & Legumes
    InventoryItem(id: 'inv42', name: 'Toor dal', category: 'Pulses & Legumes'),
    InventoryItem(id: 'inv43', name: 'Moong dal', category: 'Pulses & Legumes'),
    InventoryItem(
      id: 'inv44',
      name: 'Masoor dal',
      category: 'Pulses & Legumes',
    ),
    InventoryItem(id: 'inv45', name: 'Chana dal', category: 'Pulses & Legumes'),
    InventoryItem(id: 'inv46', name: 'Urad dal', category: 'Pulses & Legumes'),
    InventoryItem(id: 'inv47', name: 'Chickpeas', category: 'Pulses & Legumes'),
    InventoryItem(id: 'inv48', name: 'Rajma', category: 'Pulses & Legumes'),
    InventoryItem(
      id: 'inv49',
      name: 'Green gram',
      category: 'Pulses & Legumes',
    ),
    InventoryItem(
      id: 'inv50',
      name: 'Black gram',
      category: 'Pulses & Legumes',
    ),

    // 5. Spices & Seasonings
    InventoryItem(id: 'inv51', name: 'Salt', category: 'Spices & Seasonings'),
    InventoryItem(id: 'inv52', name: 'Sugar', category: 'Spices & Seasonings'),
    InventoryItem(
      id: 'inv53',
      name: 'Black pepper',
      category: 'Spices & Seasonings',
    ),
    InventoryItem(
      id: 'inv54',
      name: 'Turmeric',
      category: 'Spices & Seasonings',
    ),
    InventoryItem(
      id: 'inv55',
      name: 'Red chilli powder',
      category: 'Spices & Seasonings',
    ),
    InventoryItem(
      id: 'inv56',
      name: 'Coriander powder',
      category: 'Spices & Seasonings',
    ),
    InventoryItem(id: 'inv57', name: 'Cumin', category: 'Spices & Seasonings'),
    InventoryItem(
      id: 'inv58',
      name: 'Mustard seeds',
      category: 'Spices & Seasonings',
    ),
    InventoryItem(id: 'inv59', name: 'Fennel', category: 'Spices & Seasonings'),
    InventoryItem(
      id: 'inv60',
      name: 'Cardamom',
      category: 'Spices & Seasonings',
    ),
    InventoryItem(id: 'inv61', name: 'Cloves', category: 'Spices & Seasonings'),
    InventoryItem(
      id: 'inv62',
      name: 'Cinnamon',
      category: 'Spices & Seasonings',
    ),
    InventoryItem(
      id: 'inv63',
      name: 'Bay leaf',
      category: 'Spices & Seasonings',
    ),
    InventoryItem(
      id: 'inv64',
      name: 'Star anise',
      category: 'Spices & Seasonings',
    ),
    InventoryItem(
      id: 'inv65',
      name: 'Fenugreek',
      category: 'Spices & Seasonings',
    ),
    InventoryItem(
      id: 'inv66',
      name: 'Garam masala',
      category: 'Spices & Seasonings',
    ),
    InventoryItem(
      id: 'inv67',
      name: 'Curry powder',
      category: 'Spices & Seasonings',
    ),
    InventoryItem(
      id: 'inv68',
      name: 'Asafoetida (hing)',
      category: 'Spices & Seasonings',
    ),

    // 6. Dairy Products
    InventoryItem(id: 'inv69', name: 'Milk', category: 'Dairy Products'),
    InventoryItem(id: 'inv70', name: 'Curd/Yogurt', category: 'Dairy Products'),
    InventoryItem(id: 'inv71', name: 'Butter', category: 'Dairy Products'),
    InventoryItem(id: 'inv72', name: 'Ghee', category: 'Dairy Products'),
    InventoryItem(id: 'inv73', name: 'Cheese', category: 'Dairy Products'),
    InventoryItem(id: 'inv74', name: 'Paneer', category: 'Dairy Products'),
    InventoryItem(id: 'inv75', name: 'Cream', category: 'Dairy Products'),
    InventoryItem(
      id: 'inv76',
      name: 'Condensed milk',
      category: 'Dairy Products',
    ),

    // 7. Meat, Fish & Eggs
    InventoryItem(id: 'inv77', name: 'Chicken', category: 'Meat, Fish & Eggs'),
    InventoryItem(id: 'inv78', name: 'Mutton', category: 'Meat, Fish & Eggs'),
    InventoryItem(id: 'inv79', name: 'Beef', category: 'Meat, Fish & Eggs'),
    InventoryItem(id: 'inv80', name: 'Fish', category: 'Meat, Fish & Eggs'),
    InventoryItem(
      id: 'inv81',
      name: 'Prawns/Shrimp',
      category: 'Meat, Fish & Eggs',
    ),
    InventoryItem(
      id: 'inv82',
      name: 'Other seafood',
      category: 'Meat, Fish & Eggs',
    ),
    InventoryItem(id: 'inv83', name: 'Eggs', category: 'Meat, Fish & Eggs'),

    // 8. Oils & Sauces
    InventoryItem(id: 'inv84', name: 'Cooking oil', category: 'Oils & Sauces'),
    InventoryItem(id: 'inv85', name: 'Coconut oil', category: 'Oils & Sauces'),
    InventoryItem(id: 'inv86', name: 'Olive oil', category: 'Oils & Sauces'),
    InventoryItem(id: 'inv87', name: 'Sesame oil', category: 'Oils & Sauces'),
    InventoryItem(id: 'inv88', name: 'Soy sauce', category: 'Oils & Sauces'),
    InventoryItem(
      id: 'inv89',
      name: 'Tomato ketchup',
      category: 'Oils & Sauces',
    ),
    InventoryItem(id: 'inv90', name: 'Chilli sauce', category: 'Oils & Sauces'),
    InventoryItem(id: 'inv91', name: 'Vinegar', category: 'Oils & Sauces'),
    InventoryItem(id: 'inv92', name: 'Mayonnaise', category: 'Oils & Sauces'),
    InventoryItem(
      id: 'inv93',
      name: 'Mustard sauce',
      category: 'Oils & Sauces',
    ),

    // 9. Bakery & Baking Materials
    InventoryItem(
      id: 'inv94',
      name: 'Bread',
      category: 'Bakery & Baking Materials',
    ),
    InventoryItem(
      id: 'inv95',
      name: 'Buns',
      category: 'Bakery & Baking Materials',
    ),
    InventoryItem(
      id: 'inv96',
      name: 'Yeast',
      category: 'Bakery & Baking Materials',
    ),
    InventoryItem(
      id: 'inv97',
      name: 'Baking powder',
      category: 'Bakery & Baking Materials',
    ),
    InventoryItem(
      id: 'inv98',
      name: 'Baking soda',
      category: 'Bakery & Baking Materials',
    ),
    InventoryItem(
      id: 'inv99',
      name: 'Cocoa powder',
      category: 'Bakery & Baking Materials',
    ),
    InventoryItem(
      id: 'inv100',
      name: 'Chocolate',
      category: 'Bakery & Baking Materials',
    ),
    InventoryItem(
      id: 'inv101',
      name: 'Vanilla essence',
      category: 'Bakery & Baking Materials',
    ),
    InventoryItem(
      id: 'inv102',
      name: 'Custard powder',
      category: 'Bakery & Baking Materials',
    ),
    InventoryItem(
      id: 'inv103',
      name: 'Corn starch',
      category: 'Bakery & Baking Materials',
    ),
    InventoryItem(
      id: 'inv104',
      name: 'Icing sugar',
      category: 'Bakery & Baking Materials',
    ),

    // 10. Canned & Packaged Items
    InventoryItem(
      id: 'inv105',
      name: 'Canned tomatoes',
      category: 'Canned & Packaged Items',
    ),
    InventoryItem(
      id: 'inv106',
      name: 'Canned fruits',
      category: 'Canned & Packaged Items',
    ),
    InventoryItem(
      id: 'inv107',
      name: 'Pickles',
      category: 'Canned & Packaged Items',
    ),
    InventoryItem(
      id: 'inv108',
      name: 'Jam',
      category: 'Canned & Packaged Items',
    ),
    InventoryItem(
      id: 'inv109',
      name: 'Peanut butter',
      category: 'Canned & Packaged Items',
    ),
    InventoryItem(
      id: 'inv110',
      name: 'Coconut milk',
      category: 'Canned & Packaged Items',
    ),
    InventoryItem(
      id: 'inv111',
      name: 'Tomato paste',
      category: 'Canned & Packaged Items',
    ),
    InventoryItem(
      id: 'inv112',
      name: 'Pasta',
      category: 'Canned & Packaged Items',
    ),
    InventoryItem(
      id: 'inv113',
      name: 'Noodles',
      category: 'Canned & Packaged Items',
    ),

    // 11. Beverages
    InventoryItem(id: 'inv114', name: 'Tea', category: 'Beverages'),
    InventoryItem(id: 'inv115', name: 'Coffee', category: 'Beverages'),
    InventoryItem(id: 'inv116', name: 'Milk powder', category: 'Beverages'),
    InventoryItem(id: 'inv117', name: 'Drinking water', category: 'Beverages'),
    InventoryItem(id: 'inv118', name: 'Fruit juices', category: 'Beverages'),
    InventoryItem(id: 'inv119', name: 'Soft drinks', category: 'Beverages'),
    InventoryItem(id: 'inv120', name: 'Syrups', category: 'Beverages'),

    // 12. Frozen Items
    InventoryItem(
      id: 'inv121',
      name: 'Frozen vegetables',
      category: 'Frozen Items',
    ),
    InventoryItem(id: 'inv122', name: 'Frozen peas', category: 'Frozen Items'),
    InventoryItem(id: 'inv123', name: 'Frozen fries', category: 'Frozen Items'),
    InventoryItem(
      id: 'inv124',
      name: 'Frozen chicken',
      category: 'Frozen Items',
    ),
    InventoryItem(
      id: 'inv125',
      name: 'Frozen seafood',
      category: 'Frozen Items',
    ),
    InventoryItem(id: 'inv126', name: 'Ice cream', category: 'Frozen Items'),

    // 13. Other Common Ingredients
    InventoryItem(
      id: 'inv127',
      name: 'Cashews',
      category: 'Other Common Ingredients',
    ),
    InventoryItem(
      id: 'inv128',
      name: 'Almonds',
      category: 'Other Common Ingredients',
    ),
    InventoryItem(
      id: 'inv129',
      name: 'Raisins',
      category: 'Other Common Ingredients',
    ),
    InventoryItem(
      id: 'inv130',
      name: 'Peanuts',
      category: 'Other Common Ingredients',
    ),
    InventoryItem(
      id: 'inv131',
      name: 'Sesame seeds',
      category: 'Other Common Ingredients',
    ),
    InventoryItem(
      id: 'inv132',
      name: 'Coconut',
      category: 'Other Common Ingredients',
    ),
    InventoryItem(
      id: 'inv133',
      name: 'Breadcrumbs',
      category: 'Other Common Ingredients',
    ),
    InventoryItem(
      id: 'inv134',
      name: 'Papad',
      category: 'Other Common Ingredients',
    ),
    InventoryItem(
      id: 'inv135',
      name: 'Food colouring',
      category: 'Other Common Ingredients',
    ),
    InventoryItem(
      id: 'inv136',
      name: 'Food flavouring',
      category: 'Other Common Ingredients',
    ),

    // 14. Kitchen Consumables & Cleaning Materials
    InventoryItem(
      id: 'inv137',
      name: 'Aluminium foil',
      category: 'Kitchen Consumables & Cleaning Materials',
    ),
    InventoryItem(
      id: 'inv138',
      name: 'Cling film',
      category: 'Kitchen Consumables & Cleaning Materials',
    ),
    InventoryItem(
      id: 'inv139',
      name: 'Baking paper',
      category: 'Kitchen Consumables & Cleaning Materials',
    ),
    InventoryItem(
      id: 'inv140',
      name: 'Disposable gloves',
      category: 'Kitchen Consumables & Cleaning Materials',
    ),
    InventoryItem(
      id: 'inv141',
      name: 'Paper towels',
      category: 'Kitchen Consumables & Cleaning Materials',
    ),
    InventoryItem(
      id: 'inv142',
      name: 'Garbage bags',
      category: 'Kitchen Consumables & Cleaning Materials',
    ),
    InventoryItem(
      id: 'inv143',
      name: 'Dishwashing liquid',
      category: 'Kitchen Consumables & Cleaning Materials',
    ),
    InventoryItem(
      id: 'inv144',
      name: 'Sanitizer',
      category: 'Kitchen Consumables & Cleaning Materials',
    ),
    InventoryItem(
      id: 'inv145',
      name: 'Cleaning brushes',
      category: 'Kitchen Consumables & Cleaning Materials',
    ),
    InventoryItem(
      id: 'inv146',
      name: 'Sponges',
      category: 'Kitchen Consumables & Cleaning Materials',
    ),
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
    return _inventoryItems
        .where((item) => item.name.toLowerCase().contains(query))
        .toList();
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
      _inventoryItems[index].isOutOfStock =
          !_inventoryItems[index].isOutOfStock;
      notifyListeners();
    }
  }
}
