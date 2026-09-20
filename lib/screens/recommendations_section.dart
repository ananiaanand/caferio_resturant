import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:caferio/providers/app_provider.dart';
import 'package:caferio/utils/theme.dart';
import 'package:caferio/models/recommendation.dart';
import 'package:caferio/models/menu_item.dart';

/// A polished "Recommended for You" horizontal carousel widget.
/// Renders personalized recommendation cards with score badges, reason tags, and quick-add buttons.
class RecommendationsSection extends StatelessWidget {
  const RecommendationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    if (provider.isLoadingRecommendations) {
      return _buildShimmerSection(context);
    }

    final items = provider.recommendedItems;
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: AppTheme.primaryColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Recommended for You',
                    style:
                        Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 20),
                  ),
                ],
              ),
              Text(
                '${items.length} picks',
                style: const TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 248,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) => Container(
              width: 168,
              margin: const EdgeInsets.only(right: 16),
              child: _buildRecommendationCard(context, items[index], provider),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(
      BuildContext context, RecommendationItem rec, AppProvider provider) {
    final item = rec.menuItem;
    final quantity = provider.getCartItemQuantity(item.id);

    return Stack(
      children: [
        Card(
          elevation: 6,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          shadowColor: AppTheme.primaryColor.withValues(alpha: 0.10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 118,
                  width: double.infinity,
                  child: Opacity(
                    opacity: item.isOutOfStock ? 0.45 : 1.0,
                    child: item.imageUrl.startsWith('assets/')
                        ? Image.asset(item.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _placeholderIcon())
                        : Image.network(item.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _placeholderIcon()),
                  ),
                ),
              ),
              // Reason Tag Badge
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _tagColor(rec.reasonTag).withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    rec.reasonTag,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _tagColor(rec.reasonTag),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.category,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${item.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        if (item.isOutOfStock)
                          const Text('Out of Stock',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10))
                        else
                          _buildAddButton(context, item, quantity, provider),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Favourite heart
        Positioned(
          top: 8,
          right: 8,
          child: InkWell(
            onTap: () => provider.toggleFavourite(item.id),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10), blurRadius: 4),
                ],
              ),
              child: Icon(
                item.isFavourite ? Icons.favorite : Icons.favorite_border,
                size: 16,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton(
      BuildContext context, MenuItem item, int quantity, AppProvider provider) {
    if (quantity > 0) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => provider.removeFromCart(item),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Icon(Icons.remove, color: AppTheme.primaryColor, size: 14),
              ),
            ),
            Text('$quantity',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    fontSize: 13)),
            InkWell(
              onTap: () => provider.addToCart(item),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Icon(Icons.add, color: AppTheme.primaryColor, size: 14),
              ),
            ),
          ],
        ),
      );
    }
    return InkWell(
      onTap: () => provider.addToCart(item),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 14),
      ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      color: Colors.grey[100],
      child: const Center(child: Icon(Icons.fastfood, color: Colors.grey)),
    );
  }

  Color _tagColor(String tag) {
    if (tag.contains('Paired') || tag.contains('Pairing')) return const Color(0xFFE65100);
    if (tag.contains('Favorite') || tag.contains('Favourite')) return AppTheme.primaryColor;
    if (tag.contains('Again')) return const Color(0xFF1565C0);
    if (tag.contains('Special')) return const Color(0xFF6A1B9A);
    if (tag.contains('Popular') || tag.contains('Trending')) return const Color(0xFF2E7D32);
    return const Color(0xFF00695C);
  }
}

/// Shimmer placeholder cards while loading recommendations
Widget _buildShimmerSection(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(width: 10),
          Container(
            width: 180,
            height: 20,
            decoration: BoxDecoration(
                color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
          ),
        ],
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 248,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 4,
          itemBuilder: (context, index) => Container(
            width: 168,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    ],
  );
}
