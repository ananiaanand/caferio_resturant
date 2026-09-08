import '../models/ingredient_model.dart';
import '../models/depletion_event_model.dart';

/// Risk tier for an ingredient based on predicted exhaustion time.
enum IngredientRisk {
  critical, // < 4 hours
  warning,  // 4–12 hours
  ok,       // > 12 hours
}

/// Confidence level of a prediction based on how much historical data exists.
enum PredictionConfidence {
  high,   // >= 7 days of data
  medium, // 3–6 days
  low,    // < 3 days
}

/// Output from the prediction engine for one ingredient.
class IngredientPrediction {
  final String ingredientId;
  final String ingredientName;
  final String unit;
  final double currentStock;

  /// Predicted hours until exhaustion (double.infinity = won't run out today).
  final double hoursUntilExhaustion;

  /// Predicted stock remaining at end of day (in base unit).
  final double predictedEndOfDayStock;

  /// Consumption rate used (base unit per hour).
  final double consumptionRatePerHour;

  final IngredientRisk riskLevel;
  final PredictionConfidence confidence;

  /// Recommended restock quantity to cover next 48 hours.
  final double suggestedRestockAmount;

  const IngredientPrediction({
    required this.ingredientId,
    required this.ingredientName,
    required this.unit,
    required this.currentStock,
    required this.hoursUntilExhaustion,
    required this.predictedEndOfDayStock,
    required this.consumptionRatePerHour,
    required this.riskLevel,
    required this.confidence,
    required this.suggestedRestockAmount,
  });

  /// Formatted exhaustion time for display.
  String get exhaustionLabel {
    if (hoursUntilExhaustion.isInfinite) return 'Safe today';
    if (hoursUntilExhaustion < 1) {
      final mins = (hoursUntilExhaustion * 60).round();
      return '~${mins}m left';
    }
    if (hoursUntilExhaustion < 24) {
      return '~${hoursUntilExhaustion.toStringAsFixed(1)}h left';
    }
    final days = (hoursUntilExhaustion / 24).floor();
    return '~${days}d left';
  }

  String get riskLabel {
    switch (riskLevel) {
      case IngredientRisk.critical: return 'Critical';
      case IngredientRisk.warning:  return 'Warning';
      case IngredientRisk.ok:       return 'Stable';
    }
  }
}

/// ─── Ingredient Prediction Service ────────────────────────────────────────
///
/// Algorithm:
///   1. Group [DepletionEvent]s by ingredient and by day.
///   2. Compute a 7-day **Exponentially Weighted Moving Average** (EWMA)
///      of daily consumption (alpha = 0.4, recent days weighted more).
///   3. Convert to hourly rate using a 12-hour active kitchen window.
///   4. Factor in today's order-pace multiplier (orders placed so far
///      vs. historical average for this time of day).
///   5. Predict `hoursUntilExhaustion = currentStock / hourlyRate`.
///   6. Output [IngredientPrediction] for every ingredient.
class IngredientPredictionService {
  /// EWMA smoothing factor — higher = more weight on recent data.
  static const double _alpha = 0.4;

  /// Hours the kitchen is active per day (used for rate normalisation).
  static const double _activeHoursPerDay = 12.0;

  /// Predict exhaustion for all [ingredients] using [events] as history.
  ///
  /// [todayOrderCount] – orders placed so far today.
  /// [historicalDailyAvgOrders] – baseline daily order count.
  List<IngredientPrediction> predict({
    required List<IngredientModel> ingredients,
    required List<DepletionEvent> events,
    required int todayOrderCount,
    required double historicalDailyAvgOrders,
  }) {
    final now = DateTime.now();

    // ── 1. Group events by ingredient and by day ──────────────────────────
    final Map<String, Map<int, double>> dailyConsumption = {};
    // dailyConsumption[ingredientId][daysAgo] = total consumed that day

    for (final e in events) {
      final daysAgo = now.difference(e.timestamp).inDays;
      if (daysAgo > 6) continue; // Only last 7 days
      dailyConsumption
          .putIfAbsent(e.ingredientId, () => {})
          .update(daysAgo, (v) => v + e.amountConsumed,
              ifAbsent: () => e.amountConsumed);
    }

    // ── 2. Compute EWMA daily consumption per ingredient ─────────────────
    final Map<String, double> ewmaDaily = {};
    final Map<String, int> dataDays = {};

    dailyConsumption.forEach((ingredientId, byDay) {
      // Sort from oldest (day 6) to most recent (day 0)
      final sortedDays = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
      double ewma = byDay[sortedDays.first] ?? 0;
      for (var i = 1; i < sortedDays.length; i++) {
        final dayConsumption = byDay[sortedDays[i]] ?? ewma;
        ewma = _alpha * dayConsumption + (1 - _alpha) * ewma;
      }
      ewmaDaily[ingredientId] = ewma;
      dataDays[ingredientId] = byDay.length;
    });

    // ── 3. Order-pace multiplier ──────────────────────────────────────────
    final double orderMultiplier;
    if (historicalDailyAvgOrders > 0 && todayOrderCount > 0) {
      // Annualise today's partial count to a full-day pace
      final hoursElapsed = now.hour + now.minute / 60.0;
      final activeHoursElapsed = (hoursElapsed - 11.0).clamp(0.0, _activeHoursPerDay);
      if (activeHoursElapsed > 0) {
        final projectedTotal =
            todayOrderCount * (_activeHoursPerDay / activeHoursElapsed);
        orderMultiplier =
            (projectedTotal / historicalDailyAvgOrders).clamp(0.5, 2.5);
      } else {
        orderMultiplier = 1.0;
      }
    } else {
      orderMultiplier = 1.0;
    }

    // ── 4. Build predictions ──────────────────────────────────────────────
    return ingredients.map((ingredient) {
      final dailyRate = ewmaDaily[ingredient.id] ?? 0.0;
      final daysOfData = dataDays[ingredient.id] ?? 0;

      // Hourly consumption rate (adjusted for today's pace)
      final hourlyRate = (dailyRate / _activeHoursPerDay) * orderMultiplier;

      // Predicted hours until exhaustion
      final double hoursUntilExhaustion;
      if (hourlyRate <= 0) {
        hoursUntilExhaustion = double.infinity;
      } else {
        hoursUntilExhaustion = ingredient.currentStock / hourlyRate;
      }

      // Predicted end-of-day stock
      final hoursRemaining = (_activeHoursPerDay -
              ((now.hour - 11.0).clamp(0.0, _activeHoursPerDay)))
          .clamp(0.0, _activeHoursPerDay);
      final predictedEndOfDayStock =
          (ingredient.currentStock - hourlyRate * hoursRemaining)
              .clamp(0.0, double.infinity);

      // Risk level
      final IngredientRisk risk;
      if (hoursUntilExhaustion < 4) {
        risk = IngredientRisk.critical;
      } else if (hoursUntilExhaustion < 12) {
        risk = IngredientRisk.warning;
      } else {
        risk = IngredientRisk.ok;
      }

      // Confidence
      final PredictionConfidence confidence;
      if (daysOfData >= 7) {
        confidence = PredictionConfidence.high;
      } else if (daysOfData >= 3) {
        confidence = PredictionConfidence.medium;
      } else {
        confidence = PredictionConfidence.low;
      }

      // Suggested restock: cover 48 hours of predicted consumption
      final suggestedRestock = (hourlyRate * 48 - ingredient.currentStock)
          .clamp(0.0, double.infinity);

      return IngredientPrediction(
        ingredientId: ingredient.id,
        ingredientName: ingredient.name,
        unit: ingredient.displayUnit,
        currentStock: ingredient.currentStock,
        hoursUntilExhaustion: hoursUntilExhaustion,
        predictedEndOfDayStock: predictedEndOfDayStock,
        consumptionRatePerHour: hourlyRate,
        riskLevel: risk,
        confidence: confidence,
        suggestedRestockAmount: suggestedRestock,
      );
    }).toList()
      ..sort(_sortByRisk);
  }

  static int _sortByRisk(IngredientPrediction a, IngredientPrediction b) {
    // Critical first, then Warning, then OK
    final riskOrder = {
      IngredientRisk.critical: 0,
      IngredientRisk.warning: 1,
      IngredientRisk.ok: 2,
    };
    final riskCmp = riskOrder[a.riskLevel]!.compareTo(riskOrder[b.riskLevel]!);
    if (riskCmp != 0) return riskCmp;
    // Within same risk: soonest exhaustion first
    if (a.hoursUntilExhaustion.isInfinite && b.hoursUntilExhaustion.isInfinite) return 0;
    if (a.hoursUntilExhaustion.isInfinite) return 1;
    if (b.hoursUntilExhaustion.isInfinite) return -1;
    return a.hoursUntilExhaustion.compareTo(b.hoursUntilExhaustion);
  }
}
