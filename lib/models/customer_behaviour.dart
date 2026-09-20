/// Represents analyzed customer buying behaviour and preferences.
/// Designed for analytics dashboards and ML feature vector extraction.
class CustomerBehaviour {
  final bool hasHistory;
  final String? customerId;
  final int totalOrders;
  final double totalSpend;
  final double avgOrderValue;
  final Map<String, int> favoriteCategories;
  final Map<String, int> frequentItems;
  final List<String> recentItems;
  final int? preferredHour;
  final int? preferredDay;
  final DateTime? lastOrderDate;

  CustomerBehaviour({
    required this.hasHistory,
    this.customerId,
    this.totalOrders = 0,
    this.totalSpend = 0.0,
    this.avgOrderValue = 0.0,
    this.favoriteCategories = const {},
    this.frequentItems = const {},
    this.recentItems = const [],
    this.preferredHour,
    this.preferredDay,
    this.lastOrderDate,
  });

  /// The customer's primary favorite category, or 'Explore Menu' if no orders yet.
  String get topCategory {
    if (favoriteCategories.isEmpty) return 'Explore Menu';
    var sorted = favoriteCategories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  /// The customer's most frequently ordered item ID.
  String? get topItemId {
    if (frequentItems.isEmpty) return null;
    var sorted = frequentItems.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  factory CustomerBehaviour.fromJson(Map<String, dynamic> json) {
    final hasHistory = json['has_history'] as bool? ?? false;
    if (!hasHistory) {
      return CustomerBehaviour(hasHistory: false);
    }

    Map<String, int> parseCountMap(dynamic raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), (v is num) ? v.toInt() : 0));
      }
      return {};
    }

    List<String> parseList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    return CustomerBehaviour(
      hasHistory: true,
      customerId: json['customer_id']?.toString(),
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      totalSpend: (json['total_spend'] as num?)?.toDouble() ?? 0.0,
      avgOrderValue: (json['avg_order_value'] as num?)?.toDouble() ?? 0.0,
      favoriteCategories: parseCountMap(json['favorite_categories']),
      frequentItems: parseCountMap(json['frequent_items']),
      recentItems: parseList(json['recent_items']),
      preferredHour: (json['preferred_hour'] as num?)?.toInt(),
      preferredDay: (json['preferred_day'] as num?)?.toInt(),
      lastOrderDate: json['last_order_date'] != null
          ? DateTime.tryParse(json['last_order_date'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'has_history': hasHistory,
      'customer_id': customerId,
      'total_orders': totalOrders,
      'total_spend': totalSpend,
      'avg_order_value': avgOrderValue,
      'favorite_categories': favoriteCategories,
      'frequent_items': frequentItems,
      'recent_items': recentItems,
      'preferred_hour': preferredHour,
      'preferred_day': preferredDay,
      'last_order_date': lastOrderDate?.toIso8601String(),
    };
  }

  /// Extracts a normalized numerical feature vector for Machine Learning models (e.g. Random Forest).
  ///
  /// Features:
  /// [0] Normalized Total Orders (min-max log scaled)
  /// [1] Normalized Average Order Value (scaled by ₹1000 benchmark)
  /// [2] Recency in days (scaled)
  /// [3] Hour of day preference (normalized 0.0 - 1.0)
  /// [4] Day of week preference (normalized 0.0 - 1.0)
  /// [5] Diversity score (unique items / total items)
  List<double> toFeatureVector() {
    final daysSinceLastOrder = lastOrderDate != null
        ? DateTime.now().difference(lastOrderDate!).inDays.toDouble()
        : 90.0;

    final normOrders = (totalOrders > 0) ? (totalOrders / 50.0).clamp(0.0, 1.0) : 0.0;
    final normAov = (avgOrderValue / 1000.0).clamp(0.0, 1.0);
    final normRecency = (1.0 - (daysSinceLastOrder / 90.0)).clamp(0.0, 1.0);
    final normHour = preferredHour != null ? (preferredHour! / 24.0) : 0.5;
    final normDay = preferredDay != null ? (preferredDay! / 7.0) : 0.5;
    final diversity = totalOrders > 0 ? (frequentItems.length / (totalOrders * 2.0)).clamp(0.0, 1.0) : 0.0;

    return [normOrders, normAov, normRecency, normHour, normDay, diversity];
  }
}
