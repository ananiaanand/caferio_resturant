import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:caferio/providers/app_provider.dart';
import 'package:caferio/utils/theme.dart';
import 'package:caferio/models/menu_item.dart';
import 'package:caferio/models/recommendation.dart';

/// Shows "Frequently Bought Together" cross-sell items in the cart screen.
class CartRecommendationsWidget extends StatelessWidget {
  const CartRecommendationsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final items = provider.cartRecommendations;

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE65100).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_fire_department_rounded,
                      color: Color(0xFFE65100), size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Frequently Bought Together',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.textDark),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 116,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16, right: 8, bottom: 16),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  _buildCartRecCard(context, items[index], provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartRecCard(
      BuildContext context, RecommendationItem rec, AppProvider provider) {
    final item = rec.menuItem;

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.20), width: 1.2),
        borderRadius: BorderRadius.circular(14),
        color: AppTheme.primaryColor.withValues(alpha: 0.03),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 52,
                child: item.imageUrl.startsWith('assets/')
                    ? Image.asset(item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _placeholder())
                    : Image.network(item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _placeholder()),
              ),
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.textDark),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${item.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  _buildAddButton(item, provider),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(MenuItem item, AppProvider provider) {
    final qty = provider.getCartItemQuantity(item.id);
    if (item.isOutOfStock) {
      return const Text('Out of Stock',
          style: TextStyle(
              color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold));
    }
    if (qty > 0) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.primaryColor),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => provider.removeFromCart(item),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Icon(Icons.remove, color: AppTheme.primaryColor, size: 12),
              ),
            ),
            Text('$qty',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    fontSize: 12)),
            InkWell(
              onTap: () => provider.addToCart(item),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Icon(Icons.add, color: AppTheme.primaryColor, size: 12),
              ),
            ),
          ],
        ),
      );
    }
    return InkWell(
      onTap: () => provider.addToCart(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: Colors.white, size: 12),
            SizedBox(width: 4),
            Text('Add',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey[100],
      child: const Center(
          child: Icon(Icons.fastfood, color: Colors.grey, size: 22)),
    );
  }
}
