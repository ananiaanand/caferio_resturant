import 'package:flutter/foundation.dart';
import '../services/user_activity_service.dart';
import '../data/product_data.dart';

class FavoritesProvider with ChangeNotifier {
  final Set<String> _favoriteIds = {};
  String _currentUserId = 'user@gmail.com';

  final UserActivityService _activity = UserActivityService();

  Set<String> get favoriteIds => _favoriteIds;

  void setUserId(String userId) {
    _currentUserId = userId;
  }

  bool isFavorite(String productId) {
    return _favoriteIds.contains(productId);
  }

  void toggleFavorite(String productId) {
    final isNowFavorite = !_favoriteIds.contains(productId);
    if (_favoriteIds.contains(productId)) {
      _favoriteIds.remove(productId);
    } else {
      _favoriteIds.add(productId);
    }

    // Log favorite toggle event for the activity dataset
    try {
      final product = allProducts.firstWhere((p) => p.id == productId);
      _activity.logFavoriteToggled(
        userId: _currentUserId,
        productId: productId,
        productName: product.name,
        isFavorite: isNowFavorite,
      );
    } catch (_) {
      // Product not found in local data — log without name
      _activity.logFavoriteToggled(
        userId: _currentUserId,
        productId: productId,
        productName: 'unknown',
        isFavorite: isNowFavorite,
      );
    }

    notifyListeners();
  }
}
