import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../widgets/category_selector.dart';
import '../widgets/product_card.dart';
import '../models/product.dart';
import '../data/product_data.dart';
import 'package:provider/provider.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';
import '../services/recommendation_service.dart';
import '../providers/cart_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/auth_provider.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _selectedCategoryIndex = 0;

  final List<String> _categories = [
    'All',
    'Main Course',
    'Curries & Fries',
    'Veg Chinese',
    'Non-Veg Sides',
  ];

  final List<Product> _products = allProducts;

  List<ProductRecommendation> _recommendations = [];
  bool _isLoadingRecommendations = true;

  final RecommendationService _recommendationService = RecommendationService();

  // Track previously watched state to detect changes that need a recommendation refresh
  int _lastOrderCount = -1;
  int _lastCartCount = -1;
  int _lastFavCount = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRecommendations();
    });
  }

  /// Recomputes recommendations synchronously (no async needed — pure Dart).
  void _fetchRecommendations() {
    final cart = context.read<CartProvider>();
    final fav  = context.read<FavoritesProvider>();
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? 'guest';

    final recs = _recommendationService.getRecommendations(
      userId: userId,
      cartProvider: cart,
      favoritesProvider: fav,
    );

    if (mounted) {
      setState(() {
        _recommendations = recs;
        _isLoadingRecommendations = false;
        _lastOrderCount = cart.orders.length;
        _lastCartCount  = cart.itemCount;
        _lastFavCount   = fav.favoriteIds.length;
      });
    }
  }

  /// Called on every build — refreshes recommendations when underlying data changes.
  void _maybeRefreshRecommendations(CartProvider cart, FavoritesProvider fav) {
    if (!_isLoadingRecommendations &&
        (cart.orders.length != _lastOrderCount ||
         cart.itemCount    != _lastCartCount   ||
         fav.favoriteIds.length != _lastFavCount)) {
      _fetchRecommendations();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final fav  = context.watch<FavoritesProvider>();

    // Refresh reactively when data changes
    _maybeRefreshRecommendations(cart, fav);

    final currentCategory = _categories[_selectedCategoryIndex];
    final filteredProducts = currentCategory == 'All'
        ? _products
        : _products.where((p) => p.category == currentCategory).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.network(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuDGZ6xe-N3BjSTerxs8se9MoHm9HAhEE5SFd6fnJeehxojv-NORMpKRmXTYGeuBwIPWCCMauHe19c0Og5E9tgO3YPzg0YsFs92RIbdR7NHu4g2vB5qgKeeIrRtc7hHZ3wLwXF8fmScVxGPMOxEOBKbgp0yerMikjlMVMltNkncxBMRxmgiggGufT_nIgMPZkf3Fwj2caFaWgAsewnC7o9-CCbNPbHnr7lJkZ4FszOWAQotpNB4yB59KtGdptYI1w-KPM5pwJTa_v5YO',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Caferio',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.primary),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: CategorySelector(
              categories: _categories,
              selectedIndex: _selectedCategoryIndex,
              onSelected: (index) {
                setState(() {
                  _selectedCategoryIndex = index;
                });
              },
            ),
          ),

          // ── Recommended For You ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text(
                          'Recommended for You',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                        ),
                        const SizedBox(width: 8),
                        if (!_isLoadingRecommendations)
                          GestureDetector(
                            onTap: _fetchRecommendations,
                            child: const Icon(Icons.refresh, size: 18, color: AppColors.primary),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: _isLoadingRecommendations
                        ? const Center(child: CircularProgressIndicator())
                        : _recommendations.isEmpty
                            ? const Center(
                                child: Text('No recommendations yet',
                                    style: TextStyle(color: AppColors.onSurfaceVariant)),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: _recommendations.length,
                                itemBuilder: (context, index) {
                                  final rec = _recommendations[index];
                                  return Container(
                                    width: 300,
                                    margin: const EdgeInsets.only(right: 16),
                                    child: _RecommendationCard(
                                      recommendation: rec,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ProductDetailScreen(product: rec.product),
                                          ),
                                        );
                                      },
                                      onAdd: () {
                                        context.read<CartProvider>().addItem(rec.product);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('${rec.product.name} added to cart'),
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, indent: 20, endIndent: 20, color: AppColors.outlineVariant),
                ],
              ),
            ),
          ),

          // ── Category header ─────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _categories[_selectedCategoryIndex],
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.onSurface,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Signature coastal flavors and spiced delights',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),

          // ── Full product list ────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ProductCard(
                      product: filteredProducts[index],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductDetailScreen(product: filteredProducts[index]),
                          ),
                        );
                      },
                      onAdd: () {
                        context.read<CartProvider>().addItem(filteredProducts[index]);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${filteredProducts[index].name} added to cart'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  );
                },
                childCount: filteredProducts.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recommendation Card with reason chips ──────────────────────────────────

class _RecommendationCard extends StatelessWidget {
  final ProductRecommendation recommendation;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const _RecommendationCard({
    required this.recommendation,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final product = recommendation.product;
    final reasons = recommendation.reasons;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: product.imageUrl.startsWith('http')
                    ? Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.surfaceContainerLow,
                          child: const Icon(Icons.restaurant, color: AppColors.outline),
                        ),
                      )
                    : Container(
                        color: AppColors.surfaceContainerLow,
                        child: const Icon(Icons.restaurant, color: AppColors.outline, size: 36),
                      ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name + add button row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: onAdd,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${product.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Reason chip — show the top reason only
                  if (reasons.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        reasons.first,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
