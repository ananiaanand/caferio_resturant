/// Records a single consumption event for an ingredient,
/// used to build the historical depletion rate.
class DepletionEvent {
  final String id;

  /// Matches [IngredientModel.id].
  final String ingredientId;

  /// When the depletion happened (order placed time).
  final DateTime timestamp;

  /// Amount consumed in the ingredient's base unit.
  final double amountConsumed;

  /// The order that caused this depletion.
  final String orderId;

  const DepletionEvent({
    required this.id,
    required this.ingredientId,
    required this.timestamp,
    required this.amountConsumed,
    required this.orderId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ingredientId': ingredientId,
        'timestamp': timestamp.toIso8601String(),
        'amountConsumed': amountConsumed,
        'orderId': orderId,
      };

  factory DepletionEvent.fromJson(Map<String, dynamic> json) => DepletionEvent(
        id: json['id'] as String,
        ingredientId: json['ingredientId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        amountConsumed: (json['amountConsumed'] as num).toDouble(),
        orderId: json['orderId'] as String,
      );
}

/// ─── Seed Data: 7-day historical depletion history ────────────────────────
/// Simulates a realistic busy café with meals being served throughout the day.
List<DepletionEvent> generateSeedDepletionEvents() {
  final now = DateTime.now();
  final events = <DepletionEvent>[];

  // Daily order patterns: (hour, number of orders that hour)
  final hourlyPattern = [
    (11, 8), (12, 20), (13, 25), (14, 18), (15, 10),
    (17, 12), (18, 22), (19, 30), (20, 28), (21, 15), (22, 8),
  ];

  // Ingredient consumption per "average order" (grams per order slot)
  final avgConsumptionPerOrder = {
    'beef': 120.0,
    'chicken_boneless': 90.0,
    'chicken_bone_in': 140.0,
    'mutton': 80.0,
    'onion_red': 60.0,
    'ginger': 8.0,
    'garlic': 8.0,
    'coconut_oil': 18.0,
    'veg_oil': 22.0,
    'basmati_rice': 160.0,
    'all_purpose_flour': 100.0,
    'eggs': 1.5,
    'yogurt': 28.0,
    'paneer': 60.0,
    'fresh_cream': 18.0,
    'butter': 12.0,
    'ghee': 14.0,
    'turmeric': 1.5,
    'kashmiri_chili': 4.0,
    'coriander_powder': 4.0,
    'garam_masala': 2.5,
    'dark_soy': 8.0,
    'cornflour': 12.0,
    'fresh_coriander': 6.0,
    'cashew': 8.0,
    'curry_leaves': 2.0,
    'green_chili': 3.0,
    'spring_onion': 10.0,
    'capsicum': 20.0,
    'carrot': 18.0,
    'cauliflower': 80.0,
    'salt': 2.0,
    'sesame_oil': 3.0,
  };

  var eventId = 0;

  for (var daysAgo = 6; daysAgo >= 0; daysAgo--) {
    for (final (hour, orderCount) in hourlyPattern) {
      for (var o = 0; o < orderCount; o++) {
        final minute = (o * 60 / orderCount).round();
        final eventTime = DateTime(
          now.year, now.month, now.day - daysAgo, hour, minute,
        );
        final orderId = 'seed_order_${daysAgo}_${hour}_$o';

        avgConsumptionPerOrder.forEach((ingredientId, baseAmount) {
          // Add ±20% random variation
          final variation = 0.8 + (eventId % 5) * 0.08;
          events.add(DepletionEvent(
            id: 'dep_${eventId++}',
            ingredientId: ingredientId,
            timestamp: eventTime,
            amountConsumed: baseAmount * variation,
            orderId: orderId,
          ));
        });
      }
    }
  }

  return events;
}
