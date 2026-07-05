import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../widgets/category_selector.dart';
import '../widgets/product_card.dart';
import '../models/product.dart';
import '../data/product_data.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';

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

  @override
  Widget build(BuildContext context) {
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
                            builder: (_) => ProductDetailScreen(product: filteredProducts[index]),
                          ),
                        );
                      },
                      onAdd: () {
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
