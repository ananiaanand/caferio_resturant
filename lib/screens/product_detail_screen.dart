import 'package:flutter/material.dart';
import '../models/product.dart';
import '../theme/colors.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({Key? key, required this.product}) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  void _increment() {
    setState(() => _quantity++);
  }

  void _decrement() {
    if (_quantity > 1) {
      setState(() => _quantity--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                expandedHeight: 350,
                pinned: true,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.onSurfaceVariant),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8.0),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        context.watch<FavoritesProvider>().isFavorite(widget.product.id) ? Icons.favorite : Icons.favorite_border,
                        color: AppColors.primary,
                      ),
                      onPressed: () {
                        context.read<FavoritesProvider>().toggleFavorite(widget.product.id);
                      },
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(8.0),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.share, color: AppColors.onSurfaceVariant),
                      onPressed: () {},
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        widget.product.imageUrl,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 100,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                AppColors.surface,
                                AppColors.surface.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.product.name,
                                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                              color: AppColors.onSurface,
                                              fontWeight: FontWeight.bold,
                                              height: 1.2,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.secondaryFixed,
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.star, size: 16, color: AppColors.secondary),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '4.9 (120+)',
                                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                                        color: AppColors.secondary,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Traditional Kerala style',
                                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                                  color: AppColors.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${widget.product.price.toInt()}',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.outlineVariant,
                                  style: BorderStyle.solid, // Flutter doesn't have dashed border built-in easily for container
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule, color: AppColors.primary, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Expected time: 15-20 mins',
                                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                              color: AppColors.onSurface,
                                            ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'FRESHLY PREPARED',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: AppColors.secondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.onSurface,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'A signature delicacy from the heart of Kerala. This Nadan (Traditional) Beef Roast features tender chunks of beef slow-cooked to perfection in a thick, spicy gravy made with pearl onions, aromatic spices, and hand-pressed coconut oil. Topped with crispy fried coconut shards and fresh curry leaves for that authentic rustic flavor.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.onSurfaceVariant,
                              height: 1.6,
                            ),
                      ),

                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDietaryInfo(Icons.local_fire_department, 'Calories', '420 kcal', AppColors.secondary),
                          _buildDietaryInfo(Icons.restaurant, 'Spice Level', 'High', AppColors.primary),
                          _buildDietaryInfo(Icons.egg_alt, 'Proteins', '32g', AppColors.secondary),
                          _buildDietaryInfo(Icons.eco, 'Standard', 'Halal', AppColors.primary),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                      Text(
                        'Add-ons',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.onSurface,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _buildAddon(
                        'Kerala Porotta (2 pcs)',
                        60,
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuDrQTyOATUC_Cf-hLjlc_1eQNAgcJAa--dm6xOvSEaZeD4Il1DpQ9KNNFEo9evODBKmPD6jZKWkm5wggCfI23puvvdRsfLY86gBCaCN29BLTi2ahBZcWWxUyhw0h4QPjJ2IaNTQLNKbxhoCvLS1I94f43Elqa1lm58xmkIuf7vM7a3EOShIUTe5dixFc3Whd2AzPVeHFLktuw3_oPChjjq_9c9PoWvE3yinOj8BNCjSSVjNp3yaEADcnb2JKa78CiAHJryH6IiTnLwp',
                      ),
                      const SizedBox(height: 8),
                      _buildAddon(
                        'Steamed Rice',
                        45,
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuCUO0K67EiuOlK3uUlSJai0OTMCIYJmnwRYEYb1zAs2RVTNQtI4P8EqbLlhmNUGsKHbIelNPo5-JhcAeKWJWUhlopDPLaIoCJIBootAeo_wRMrZmuehwcSPQWYfs1Hdx_jZPqArIEcE__hgyDtPK50mDRLdC4afSx6GmuNX_MEdN11mJIVEKJ7ywg7YFiIN0u_Ypb-xXZI4gwUsnaBYC0NGVV0nRNKYRyDp7YBL-sMIV7Gv6UIRtU0BIbscqnXDTxytSZYqP0VosFIl',
                      ),

                      const SizedBox(height: 120), // Bottom padding for action bar
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, color: AppColors.onSurface),
                          onPressed: _decrement,
                        ),
                        SizedBox(
                          width: 32,
                          child: Center(
                            child: Text(
                              '$_quantity',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: AppColors.onSurface,
                                  ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: AppColors.onSurface),
                          onPressed: _increment,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Added $_quantity ${widget.product.name} to cart')),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shopping_cart),
                            const SizedBox(width: 8),
                            Text(
                              'Add to Cart',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: AppColors.onPrimary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryInfo(IconData icon, String label, String value, Color iconColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.onSurface,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddon(String name, int price, String imageUrl) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 24),
              Text(
                name,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.onSurface,
                    ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                '+₹$price',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.add_circle, color: AppColors.secondary),
            ],
          ),
        ],
      ),
    );
  }
}
