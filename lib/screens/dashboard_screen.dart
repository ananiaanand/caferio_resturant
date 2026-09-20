import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:caferio/providers/app_provider.dart';
import 'package:caferio/utils/theme.dart';
import 'package:caferio/models/menu_item.dart';
import 'package:caferio/screens/recommendations_section.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});


  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

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
            
            // Search Bar Placeholder
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
                onChanged: (value) => context.read<AppProvider>().setSearchQuery(value),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: 'Search for food...',
                  prefixIcon: Icon(Icons.search),
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

            // Personalized Recommendations
            if (provider.selectedCategory == 'All') ...[
              const RecommendationsSection(),
              const SizedBox(height: 32),
            ],

            // Dynamic Category Items Header & Sections
            if (provider.selectedCategory == 'All') ...[
              Text('You Might Like', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 22)),
              const SizedBox(height: 16),
              SizedBox(
                height: 250,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: provider.specialItems.length,
                  itemBuilder: (context, index) => Container(
                    width: 170, 
                    margin: const EdgeInsets.only(right: 16), 
                    child: _buildMenuItemCard(context, provider.specialItems[index], provider)
                  ),
                ),
              ),
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
                    child: _buildMenuItemCard(context, provider.topPicks[index], provider)
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('All Dishes', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 22)),
                  Text('${provider.currentCategoryItems.length} items', style: const TextStyle(color: AppTheme.textLight)),
                ],
              ),
              const SizedBox(height: 16),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    provider.selectedCategory,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 22),
                  ),
                  Text('${provider.currentCategoryItems.length} items', style: const TextStyle(color: AppTheme.textLight)),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // Items Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75, // Adjust this to prevent overflow
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: provider.currentCategoryItems.length,
              itemBuilder: (context, index) {
                return _buildMenuItemCard(context, provider.currentCategoryItems[index], provider);
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
