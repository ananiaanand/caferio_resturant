import 'dart:math';
import '../models/product.dart';
import '../data/product_data.dart';
import '../providers/cart_provider.dart';
import '../providers/favorites_provider.dart';

/// A single recommendation with its score breakdown for debugging / UI display.
class ProductRecommendation {
  final Product product;
  final double score;
  final List<String> reasons; // Human-readable reason chips

  const ProductRecommendation({
    required this.product,
    required this.score,
    required this.reasons,
  });
}

// ─── Co-purchase knowledge base ────────────────────────────────────────────
// Manually curated pairs that make culinary sense for Caferio's menu.
// Format: productId → list of productIds frequently ordered together.
const Map<String, List<String>> _coPurchaseMap = {
  // Curries pair well with breads and rice
  '1': ['41', '42', '43'],  // Nadan Beef Roast → Garlic Naan, Bread, Plain Rice
  '2': ['41', '42', '43'],  // Nadan Chicken Curry → same
  '3': ['41', '42', '43'],  // Butter Chicken → same
  '6': ['41', '43'],        // Mutton Kurma → Garlic Naan, Plain Rice
  '9': ['42', '43'],        // Nadan Beef Curry → Bread, Plain Rice
  '11': ['42', '43'],       // Beef Stew → Bread, Plain Rice
  '12': ['42', '43'],       // Mutton Stew → Bread, Plain Rice
  // Sides pair with mains
  '4': ['14', '20', '21'],  // Chicken 65 → noodles, fried rice
  '25': ['20', '14'],       // Chilly Beef → fried rice, noodles
  '28': ['19', '22'],       // Chilly Chicken → szechwan fried rice, veg fried rice
  '34': ['15', '22'],       // Chilly Gobi → veg noodles, veg fried rice
  '37': ['15', '22', '19'], // Gobi Manchurian → veg items
  // Breads pair with curries
  '41': ['1', '2', '3', '9'],   // Garlic Naan → curries
  '42': ['11', '12', '9', '2'], // Bread → stews, curries
  '43': ['1', '6', '2'],        // Plain Rice → curries
  '44': ['2', '3'],             // Aloo Paratha → chicken curries
};

// ─── Time-of-day product boosts ─────────────────────────────────────────────
// IDs that are most appropriate at each meal window.
const List<String> _breakfastBoosts  = ['41', '42', '44', '43'];      // breads, paratha, rice
const List<String> _lunchBoosts      = ['1', '2', '3', '20', '21', '43', '41']; // curries + rice + breads
const List<String> _eveningBoosts    = ['4', '34', '37', '33', '28']; // snacks/starters
const List<String> _dinnerBoosts     = ['1', '5', '6', '7', '25', '24', '14', '18', '23']; // specials

// ─── Global popularity fallback (hardcoded bestsellers) ─────────────────────
const List<String> _globalPopular = ['1', '4', '2', '28', '25', '37', '20', '14', '41', '3'];

/// Signal weights (must sum to 1.0).
const double _wFavorite    = 0.35;
const double _wRecency     = 0.25;
const double _wFrequency   = 0.20;
const double _wCoPurchase  = 0.10;
const double _wTimeOfDay   = 0.05;
const double _wCategory    = 0.05;

/// Recency decay half-life in days — orders older than this contribute < 50%.
const double _decayHalfLife = 7.0;

/// Max items from the same category in the final list.
const int _maxPerCategory = 2;

class RecommendationService {
  /// Returns up to [limit] recommendations for [userId].
  ///
  /// Falls back gracefully: no order history → global popularity list.
  List<ProductRecommendation> getRecommendations({
    required String userId,
    required CartProvider cartProvider,
    required FavoritesProvider favoritesProvider,
    int limit = 5,
  }) {
    final cartProductIds   = cartProvider.items.keys.toSet();
    final favoriteIds      = favoritesProvider.favoriteIds;
    final orders           = cartProvider.orders;
    final now              = DateTime.now();

    // ── Pre-process order history ──────────────────────────────────────────
    // orderFrequency[productId] = number of times ordered
    final Map<String, int> orderFrequency = {};
    // recencyWeight[productId] = sum of exp-decayed weights
    final Map<String, double> recencyWeight = {};
    // orderedAlongside[productId] = set of other productIds in same orders
    final Map<String, Set<String>> orderedAlongside = {};

    for (final order in orders) {
      final idsInOrder = order.items.map((i) => i.product.id).toSet();
      final daysSince = now.difference(order.date).inHours / 24.0;
      final decay = exp(-daysSince * ln2 / _decayHalfLife);

      for (final item in order.items) {
        final pid = item.product.id;
        orderFrequency[pid] = (orderFrequency[pid] ?? 0) + item.quantity;
        recencyWeight[pid]  = (recencyWeight[pid]  ?? 0) + decay * item.quantity;

        // Co-purchase: record what else appeared in this order
        for (final otherId in idsInOrder) {
          if (otherId != pid) {
            orderedAlongside.putIfAbsent(pid, () => {}).add(otherId);
          }
        }
      }
    }

    // Normalise frequency and recency to [0, 1]
    final maxFreq   = orderFrequency.values.fold(0, max<int>).toDouble();
    final maxRecency = recencyWeight.values.fold(0.0, max<double>);

    // ── Category affinity from full order history ──────────────────────────
    final Map<String, double> categoryAffinity = {};
    for (final order in orders) {
      for (final item in order.items) {
        categoryAffinity[item.product.category] =
            (categoryAffinity[item.product.category] ?? 0) + 1;
      }
    }
    final maxCatAffinity = categoryAffinity.values.fold(0.0, max<double>);

    // ── Time-of-day signal ─────────────────────────────────────────────────
    final hour = now.hour;
    List<String> timeBoosts;
    String timePeriod;
    if (hour >= 6 && hour < 11) {
      timeBoosts = _breakfastBoosts;
      timePeriod = '🌅 Good for breakfast';
    } else if (hour >= 11 && hour < 15) {
      timeBoosts = _lunchBoosts;
      timePeriod = '☀️ Popular at lunch';
    } else if (hour >= 15 && hour < 18) {
      timeBoosts = _eveningBoosts;
      timePeriod = '🌆 Evening favourite';
    } else {
      timeBoosts = _dinnerBoosts;
      timePeriod = '🌙 Popular at dinner';
    }

    // ── Score every product ────────────────────────────────────────────────
    final List<ProductRecommendation> scored = [];

    for (final product in allProducts) {
      // Never recommend items already in the cart
      if (cartProductIds.contains(product.id)) continue;

      final reasons = <String>[];
      double totalScore = 0;

      // 1. Favorite bonus
      if (favoriteIds.contains(product.id)) {
        totalScore += _wFavorite * 1.0;
        reasons.add('❤️ Your Favourite');
      }

      // 2. Recency score (exponential decay)
      if (maxRecency > 0 && recencyWeight.containsKey(product.id)) {
        final recScore = recencyWeight[product.id]! / maxRecency;
        totalScore += _wRecency * recScore;
        reasons.add('🔁 Ordered recently');
      }

      // 3. Frequency score
      if (maxFreq > 0 && orderFrequency.containsKey(product.id)) {
        final freqScore = orderFrequency[product.id]! / maxFreq;
        totalScore += _wFrequency * freqScore;
        if (!reasons.contains('🔁 Ordered recently')) {
          final count = orderFrequency[product.id]!;
          reasons.add('🔁 Ordered $count×');
        }
      }

      // 4. Co-purchase score (from both order history and static map)
      double coPurchaseScore = 0;
      final cartIds = cartProductIds;

      // Static co-purchase map
      for (final cartId in cartIds) {
        if (_coPurchaseMap[cartId]?.contains(product.id) == true) {
          coPurchaseScore += 0.5;
        }
        if (_coPurchaseMap[product.id]?.contains(cartId) == true) {
          coPurchaseScore += 0.5;
        }
      }
      // Historical co-purchase
      for (final cartId in cartIds) {
        if (orderedAlongside[cartId]?.contains(product.id) == true) {
          coPurchaseScore += 1.0;
        }
      }

      if (coPurchaseScore > 0) {
        totalScore += _wCoPurchase * (coPurchaseScore / 2.0).clamp(0.0, 1.0);
        reasons.add('🛒 Goes well together');
      }

      // 5. Time-of-day boost
      if (timeBoosts.contains(product.id)) {
        totalScore += _wTimeOfDay * 1.0;
        reasons.add(timePeriod);
      }

      // 6. Category affinity
      if (maxCatAffinity > 0) {
        final affinity = (categoryAffinity[product.category] ?? 0) / maxCatAffinity;
        totalScore += _wCategory * affinity;
      }

      // 7. Global popularity fallback boost (softly, for new users)
      final popularityRank = _globalPopular.indexOf(product.id);
      if (popularityRank >= 0) {
        final popularityBoost = (1.0 - popularityRank / _globalPopular.length) * 0.05;
        totalScore += popularityBoost;
        if (orders.isEmpty && !reasons.contains('🔥 Popular dish')) {
          reasons.add('🔥 Popular dish');
        }
      }

      // Default reason if none collected
      if (reasons.isEmpty) reasons.add('✨ You might like this');

      scored.add(ProductRecommendation(
        product: product,
        score: totalScore,
        reasons: reasons,
      ));
    }

    // ── Sort by score descending ───────────────────────────────────────────
    scored.sort((a, b) => b.score.compareTo(a.score));

    // ── Diversity injection — max [_maxPerCategory] per category ──────────
    final List<ProductRecommendation> diverse = [];
    final Map<String, int> categoryCount = {};

    for (final rec in scored) {
      final cat = rec.product.category;
      final count = categoryCount[cat] ?? 0;
      if (count < _maxPerCategory) {
        diverse.add(rec);
        categoryCount[cat] = count + 1;
        if (diverse.length >= limit) break;
      }
    }

    // If diversity filter left gaps (small catalogue), fill from remainder
    if (diverse.length < limit) {
      for (final rec in scored) {
        if (!diverse.any((r) => r.product.id == rec.product.id)) {
          diverse.add(rec);
          if (diverse.length >= limit) break;
        }
      }
    }

    return diverse;
  }

  // ─── Legacy API compat (called from old code paths) ─────────────────────

  Future<List<Product>> getRecommendationsLegacy(
    String userId,
    CartProvider cartProvider,
    FavoritesProvider favoritesProvider,
  ) async {
    final recs = getRecommendations(
      userId: userId,
      cartProvider: cartProvider,
      favoritesProvider: favoritesProvider,
    );
    return recs.map((r) => r.product).toList();
  }
}

// Helper — needed because dart:math doesn't export ln2 as a named const.
const double ln2 = 0.6931471805599453;
