import 'menu_item.dart';

/// Represents a recommended food item with scoring and contextual explanation.
class RecommendationItem {
  final MenuItem menuItem;
  final double score;
  final String reasonTag;

  RecommendationItem({
    required this.menuItem,
    required this.score,
    required this.reasonTag,
  });

  factory RecommendationItem.fromRpcJson(Map<String, dynamic> json, MenuItem resolvedItem) {
    return RecommendationItem(
      menuItem: resolvedItem,
      score: (json['score'] is num) ? (json['score'] as num).toDouble() : 0.0,
      reasonTag: json['reason_tag'] as String? ?? 'Recommended for You',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'menuItem': menuItem.toJson(),
      'score': score,
      'reasonTag': reasonTag,
    };
  }
}
