import 'package:flutter/foundation.dart';

class FavoritesProvider with ChangeNotifier {
  final Set<String> _favoriteIds = {};

  Set<String> get favoriteIds => _favoriteIds;

  bool isFavorite(String productId) {
    return _favoriteIds.contains(productId);
  }

  void toggleFavorite(String productId) {
    if (_favoriteIds.contains(productId)) {
      _favoriteIds.remove(productId);
    } else {
      _favoriteIds.add(productId);
    }
    notifyListeners();
  }
}
