import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';
import '../data/product_data.dart';
import '../widgets/product_card.dart';
import '../theme/colors.dart';
import 'product_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final favoriteIds = context.watch<FavoritesProvider>().favoriteIds;
    final favoriteProducts = allProducts.where((p) => favoriteIds.contains(p.id)).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Favorites',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
      body: favoriteProducts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: AppColors.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No favorites yet',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your favorite dishes will appear here',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.outline,
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: favoriteProducts.length,
              itemBuilder: (context, index) {
                final product = favoriteProducts[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ProductCard(
                    product: product,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(product: product),
                        ),
                      );
                    },
                    onAdd: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${product.name} added to cart'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
