/// Represents a single ingredient in the kitchen stock.
class IngredientModel {
  final String id;
  final String name;
  final String category;

  /// Current quantity in the pantry (in [unit]).
  double currentStock;

  /// Unit of measurement: 'g', 'kg', 'L', 'ml', 'pcs'.
  final String unit;

  /// Quantity added during the last restock event.
  final double restockQuantity;

  /// Date/time of the last restock.
  final DateTime restockDate;

  /// Stock level below which alerts / auto-restock are triggered.
  final double minimumThreshold;

  /// Display multiplier for readable labels (e.g. stock in grams, display in kg).
  final double displayDivisor;
  final String displayUnit;

  IngredientModel({
    required this.id,
    required this.name,
    required this.category,
    required this.currentStock,
    required this.unit,
    required this.restockQuantity,
    required this.restockDate,
    required this.minimumThreshold,
    this.displayDivisor = 1,
    String? displayUnit,
  }) : displayUnit = displayUnit ?? unit;

  /// Fraction of stock remaining relative to last restock quantity (0.0 – 1.0).
  double get stockFraction =>
      (currentStock / restockQuantity).clamp(0.0, 1.0);

  /// Whether this ingredient is below the alert threshold.
  bool get isBelowThreshold => currentStock <= minimumThreshold;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'currentStock': currentStock,
        'unit': unit,
        'restockQuantity': restockQuantity,
        'restockDate': restockDate.toIso8601String(),
        'minimumThreshold': minimumThreshold,
        'displayDivisor': displayDivisor,
        'displayUnit': displayUnit,
      };

  factory IngredientModel.fromJson(Map<String, dynamic> json) =>
      IngredientModel(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        currentStock: (json['currentStock'] as num).toDouble(),
        unit: json['unit'] as String,
        restockQuantity: (json['restockQuantity'] as num).toDouble(),
        restockDate: DateTime.parse(json['restockDate'] as String),
        minimumThreshold: (json['minimumThreshold'] as num).toDouble(),
        displayDivisor: (json['displayDivisor'] as num?)?.toDouble() ?? 1,
        displayUnit: json['displayUnit'] as String?,
      );

  IngredientModel copyWith({double? currentStock}) => IngredientModel(
        id: id,
        name: name,
        category: category,
        currentStock: currentStock ?? this.currentStock,
        unit: unit,
        restockQuantity: restockQuantity,
        restockDate: restockDate,
        minimumThreshold: minimumThreshold,
        displayDivisor: displayDivisor,
        displayUnit: displayUnit,
      );
}
