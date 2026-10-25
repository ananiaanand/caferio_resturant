import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:caferio/providers/app_provider.dart';
import 'package:caferio/utils/theme.dart';
import 'package:caferio/models/menu_item.dart';
import 'package:caferio/screens/recommendations_section.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<AppProvider>().searchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    // Keep controller in sync if search query changed externally
    if (_searchController.text != provider.searchQuery) {
      _searchController.value = TextEditingValue(
        text: provider.searchQuery,
        selection: TextSelection.collapsed(offset: provider.searchQuery.length),
      );
    }

    final isSearching = provider.searchQuery.trim().isNotEmpty;
    final categoryItems = provider.currentCategoryItems;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        toolbarHeight: 70,
        title: Row(
          children: [
            const Icon(Icons.restaurant, color: AppTheme.primaryColor, size: 32),
            const SizedBox(width: 8),
            Text(
              'Caferio',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontSize: 28,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: AppTheme.surfaceColor,
              child: IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppTheme.textDark),
                onPressed: () {},
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What would you like\nto eat today?',
              style: GoogleFonts.sourGummy(
                textStyle: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28, height: 1.2),
              ),
            ),
            const SizedBox(height: 24),
            
            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  provider.setSearchQuery(value);
                  setState(() {});
                },
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: 'Search food, drinks, ingredients...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            provider.clearSearch();
                            setState(() {});
                          },
                        )
                      : null,
                  fillColor: Colors.transparent,
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Categories
            SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: provider.categories.length,
                itemBuilder: (context, index) {
                  final category = provider.categories[index];
                  final isSelected = category == provider.selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryColor,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textDark,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      onSelected: (selected) {
                        if (selected) {
                          provider.selectCategory(category);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),

            // Personalized Recommendations & Top Picks (only when not searching)
            if (!isSearching && provider.selectedCategory == 'All') ...[
              const RecommendationsSection(),
              const SizedBox(height: 32),
              Text('Top Picks', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 22)),
              const SizedBox(height: 16),
              SizedBox(
                height: 250,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: provider.topPicks.length,
                  itemBuilder: (context, index) => Container(
                    width: 170, 
                    margin: const EdgeInsets.only(right: 16), 
                    child: _buildMenuItemCard(context, provider.topPicks[index], provider),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isSearching
                        ? 'Results for "${provider.searchQuery.trim()}"'
                        : (provider.selectedCategory == 'All' ? 'All Dishes' : provider.selectedCategory),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 22),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${categoryItems.length} items',
                  style: TextStyle(
                    color: isSearching ? AppTheme.primaryColor : AppTheme.textLight,
                    fontWeight: isSearching ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Empty State or Items Grid
            if (categoryItems.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      isSearching ? Icons.search_off_rounded : Icons.restaurant_menu,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isSearching ? 'No dishes found' : 'No items available',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSearching
                          ? 'We couldn\'t find any food matching "${provider.searchQuery.trim()}". Try searching with another dish or ingredient.'
                          : 'There are currently no items in this category.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                    if (isSearching) ...[
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          _searchController.clear();
                          provider.clearSearch();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear, size: 18),
                        label: const Text('Clear Search'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: MediaQuery.of(context).size.width < 600
                    ? const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      )
                    : const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                itemCount: categoryItems.length,
                itemBuilder: (context, index) {
                  return _buildMenuItemCard(context, categoryItems[index], provider);
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemCard(BuildContext context, MenuItem item, AppProvider provider) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Opacity(
                    opacity: item.isOutOfStock ? 0.5 : 1.0,
                    child: item.imageUrl.startsWith('assets/')
                        ? Image.asset(
                            item.imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey[100],
                              child: const Center(child: Icon(Icons.fastfood, color: Colors.grey)),
                            ),
                          )
                        : Image.network(
                            item.imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey[100],
                              child: const Center(child: Icon(Icons.fastfood, color: Colors.grey)),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: () => provider.toggleFavourite(item.id),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                        ],
                      ),
                      child: Icon(
                        item.isFavourite ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.category,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                        fontSize: 15,
                      ),
                    ),
                    if (item.isOutOfStock)
                      const Text('Out of Stock', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))
                    else
                      Builder(
                        builder: (context) {
                          final quantity = provider.getCartItemQuantity(item.id);
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
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Icon(Icons.remove, color: AppTheme.primaryColor, size: 16),
                                    ),
                                  ),
                                  Text(
                                    quantity.toString(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                  ),
                                  InkWell(
                                    onTap: () => provider.addToCart(item),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Icon(Icons.add, color: AppTheme.primaryColor, size: 16),
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
                              child: const Icon(Icons.add, color: Colors.white, size: 16),
                            ),
                          );
                        }
                      )
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
