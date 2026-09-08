import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ingredient_model.dart';
import '../models/recipe_ingredient_model.dart';
import '../models/depletion_event_model.dart';
import '../models/cart_item.dart';
import '../services/ingredient_prediction_service.dart';

class IngredientProvider with ChangeNotifier {
  static const String _storageKeyIngredients = 'stock_ingredients';
  static const String _storageKeyDepletion = 'stock_depletion_events';

  List<IngredientModel> _ingredients = [];
  List<DepletionEvent> _depletionEvents = [];
  List<IngredientPrediction> _predictions = [];

  final IngredientPredictionService _predictionService =
      IngredientPredictionService();

  List<IngredientModel> get ingredients => List.unmodifiable(_ingredients);
  List<DepletionEvent> get depletionEvents => List.unmodifiable(_depletionEvents);
  List<IngredientPrediction> get predictions => List.unmodifiable(_predictions);

  // ─── Initialization ────────────────────────────────────────────────────────

  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load ingredients
      final rawIngredients = prefs.getStringList(_storageKeyIngredients);
      if (rawIngredients != null && rawIngredients.isNotEmpty) {
        _ingredients = rawIngredients
            .map((e) => IngredientModel.fromJson(jsonDecode(e)))
            .toList();
      } else {
        _ingredients = _generateSeedIngredients();
        await _persistIngredients();
      }

      // Load depletion events
      final rawDepletion = prefs.getStringList(_storageKeyDepletion);
      if (rawDepletion != null && rawDepletion.isNotEmpty) {
        _depletionEvents = rawDepletion
            .map((e) => DepletionEvent.fromJson(jsonDecode(e)))
            .toList();
      } else {
        _depletionEvents = generateSeedDepletionEvents();
        await _persistDepletionEvents();
      }

      _runPredictions();
    } catch (e) {
      debugPrint('[IngredientProvider] load error: $e');
    }
  }

  Future<void> _persistIngredients() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _storageKeyIngredients,
        _ingredients.map((i) => jsonEncode(i.toJson())).toList(),
      );
    } catch (e) {
      debugPrint('[IngredientProvider] persist error: $e');
    }
  }

  Future<void> _persistDepletionEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _storageKeyDepletion,
        _depletionEvents.map((e) => jsonEncode(e.toJson())).toList(),
      );
    } catch (e) {
      debugPrint('[IngredientProvider] persist error: $e');
    }
  }

  // ─── Core Logic ────────────────────────────────────────────────────────────

  void _runPredictions() {
    // Determine today's order count by looking at events today
    final now = DateTime.now();
    final todayEvents = _depletionEvents.where((e) =>
        e.timestamp.year == now.year &&
        e.timestamp.month == now.month &&
        e.timestamp.day == now.day);
    // Rough estimate of unique orders today
    final uniqueOrderIds = todayEvents.map((e) => e.orderId).toSet();
    
    _predictions = _predictionService.predict(
      ingredients: _ingredients,
      events: _depletionEvents,
      todayOrderCount: uniqueOrderIds.length,
      historicalDailyAvgOrders: 150.0, // Historical baseline
    );
    notifyListeners();
  }

  /// Triggered by KitchenProvider when a new order arrives.
  Future<void> consumeForOrder(List<CartItem> items, String orderId) async {
    bool hasChanges = false;
    final now = DateTime.now();

    for (final item in items) {
      final dishName = item.product.name;
      // Look up BOM
      final bom = kRecipeBOM.where((b) => b.dishName == dishName).firstOrNull;
      if (bom == null) continue;

      // Consume each ingredient in BOM * quantity
      for (final entry in bom.ingredients) {
        final consumedAmount = entry.amountPerServing * item.quantity;
        
        final idx = _ingredients.indexWhere((i) => i.id == entry.ingredientId);
        if (idx != -1) {
          // Update current stock
          _ingredients[idx].currentStock -= consumedAmount;
          if (_ingredients[idx].currentStock < 0) {
            _ingredients[idx].currentStock = 0;
          }

          // Record depletion event
          _depletionEvents.add(DepletionEvent(
            id: 'dep_${DateTime.now().millisecondsSinceEpoch}_${entry.ingredientId}',
            ingredientId: entry.ingredientId,
            timestamp: now,
            amountConsumed: consumedAmount,
            orderId: orderId,
          ));
          hasChanges = true;
        }
      }
    }

    if (hasChanges) {
      // Clean up old depletion events (> 7 days) to save space
      _depletionEvents.removeWhere(
          (e) => now.difference(e.timestamp).inDays > 7);

      await _persistIngredients();
      await _persistDepletionEvents();
      _runPredictions();
    }
  }

  /// Restock an ingredient.
  Future<void> restock(String ingredientId, double amount) async {
    final idx = _ingredients.indexWhere((i) => i.id == ingredientId);
    if (idx != -1) {
      _ingredients[idx] = _ingredients[idx].copyWith(
        currentStock: _ingredients[idx].currentStock + amount,
      );
      await _persistIngredients();
      _runPredictions();
    }
  }

  /// Restocks all ingredients that are below threshold.
  Future<void> autoRestockCritical() async {
    bool changed = false;
    for (int i = 0; i < _ingredients.length; i++) {
      if (_ingredients[i].isBelowThreshold) {
        _ingredients[i] = _ingredients[i].copyWith(
          currentStock: _ingredients[i].restockQuantity, // refill to max capacity
        );
        changed = true;
      }
    }
    if (changed) {
      await _persistIngredients();
      _runPredictions();
    }
  }

  // ─── Seed Data ─────────────────────────────────────────────────────────────

  List<IngredientModel> _generateSeedIngredients() {
    final now = DateTime.now();
    return [
      IngredientModel(
        id: 'beef',
        name: 'Beef',
        category: 'Proteins',
        currentStock: 4500, // 4.5kg
        unit: 'g',
        restockQuantity: 20000,
        restockDate: now.subtract(const Duration(days: 1)),
        minimumThreshold: 5000,
        displayDivisor: 1000,
        displayUnit: 'kg',
      ),
      IngredientModel(
        id: 'chicken_boneless',
        name: 'Chicken (Boneless)',
        category: 'Proteins',
        currentStock: 8000,
        unit: 'g',
        restockQuantity: 30000,
        restockDate: now.subtract(const Duration(days: 1)),
        minimumThreshold: 8000,
        displayDivisor: 1000,
        displayUnit: 'kg',
      ),
      IngredientModel(
        id: 'chicken_bone_in',
        name: 'Chicken (Bone-in)',
        category: 'Proteins',
        currentStock: 12000,
        unit: 'g',
        restockQuantity: 40000,
        restockDate: now.subtract(const Duration(days: 1)),
        minimumThreshold: 10000,
        displayDivisor: 1000,
        displayUnit: 'kg',
      ),
      IngredientModel(
        id: 'mutton',
        name: 'Mutton',
        category: 'Proteins',
        currentStock: 3000,
        unit: 'g',
        restockQuantity: 15000,
        restockDate: now.subtract(const Duration(days: 2)),
        minimumThreshold: 4000,
        displayDivisor: 1000,
        displayUnit: 'kg',
      ),
      IngredientModel(
        id: 'onion_red',
        name: 'Onion (Red)',
        category: 'Fresh Produce',
        currentStock: 6500,
        unit: 'g',
        restockQuantity: 50000,
        restockDate: now.subtract(const Duration(days: 2)),
        minimumThreshold: 10000,
        displayDivisor: 1000,
        displayUnit: 'kg',
      ),
      IngredientModel(
        id: 'coconut_oil',
        name: 'Coconut Oil',
        category: 'Pantry',
        currentStock: 1200,
        unit: 'ml',
        restockQuantity: 10000,
        restockDate: now.subtract(const Duration(days: 3)),
        minimumThreshold: 2000,
        displayDivisor: 1000,
        displayUnit: 'L',
      ),
      IngredientModel(
        id: 'veg_oil',
        name: 'Vegetable Oil',
        category: 'Pantry',
        currentStock: 8000,
        unit: 'ml',
        restockQuantity: 20000,
        restockDate: now.subtract(const Duration(days: 2)),
        minimumThreshold: 5000,
        displayDivisor: 1000,
        displayUnit: 'L',
      ),
      IngredientModel(
        id: 'basmati_rice',
        name: 'Basmati Rice',
        category: 'Grains',
        currentStock: 15000,
        unit: 'g',
        restockQuantity: 50000,
        restockDate: now.subtract(const Duration(days: 5)),
        minimumThreshold: 10000,
        displayDivisor: 1000,
        displayUnit: 'kg',
      ),
      IngredientModel(
        id: 'all_purpose_flour',
        name: 'All-Purpose Flour',
        category: 'Pantry',
        currentStock: 4000, // Very low!
        unit: 'g',
        restockQuantity: 25000,
        restockDate: now.subtract(const Duration(days: 4)),
        minimumThreshold: 8000,
        displayDivisor: 1000,
        displayUnit: 'kg',
      ),
      IngredientModel(
        id: 'ginger',
        name: 'Ginger',
        category: 'Fresh Produce',
        currentStock: 800,
        unit: 'g',
        restockQuantity: 3000,
        restockDate: now.subtract(const Duration(days: 1)),
        minimumThreshold: 500,
        displayDivisor: 1000,
        displayUnit: 'kg',
      ),
      IngredientModel(
        id: 'garlic',
        name: 'Garlic',
        category: 'Fresh Produce',
        currentStock: 900,
        unit: 'g',
        restockQuantity: 3000,
        restockDate: now.subtract(const Duration(days: 1)),
        minimumThreshold: 500,
        displayDivisor: 1000,
        displayUnit: 'kg',
      ),
      IngredientModel(
        id: 'eggs',
        name: 'Eggs',
        category: 'Dairy & Refrigerated',
        currentStock: 60,
        unit: 'pcs',
        restockQuantity: 300,
        restockDate: now.subtract(const Duration(days: 2)),
        minimumThreshold: 50,
      ),
      IngredientModel(
        id: 'paneer',
        name: 'Paneer',
        category: 'Dairy & Refrigerated',
        currentStock: 1200,
        unit: 'g',
        restockQuantity: 5000,
        restockDate: now.subtract(const Duration(days: 1)),
        minimumThreshold: 1000,
        displayDivisor: 1000,
        displayUnit: 'kg',
      ),
      IngredientModel(
        id: 'yogurt',
        name: 'Yogurt',
        category: 'Dairy & Refrigerated',
        currentStock: 2500,
        unit: 'g',
        restockQuantity: 10000,
        restockDate: now.subtract(const Duration(days: 1)),
        minimumThreshold: 2000,
        displayDivisor: 1000,
        displayUnit: 'kg',
      ),
      IngredientModel(
        id: 'green_chili',
        name: 'Green Chilies',
        category: 'Fresh Produce',
        currentStock: 400,
        unit: 'g',
        restockQuantity: 1500,
        restockDate: now.subtract(const Duration(days: 2)),
        minimumThreshold: 300,
        displayDivisor: 1000,
        displayUnit: 'kg',
      ),
      IngredientModel(
        id: 'curry_leaves',
        name: 'Curry Leaves',
        category: 'Fresh Produce',
        currentStock: 150,
        unit: 'g',
        restockQuantity: 500,
        restockDate: now.subtract(const Duration(days: 2)),
        minimumThreshold: 100,
        displayDivisor: 1000,
        displayUnit: 'kg',
      ),
    ];
  }
}
