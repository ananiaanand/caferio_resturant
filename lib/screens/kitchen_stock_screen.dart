import 'package:flutter/material.dart';
import '../theme/colors.dart';

class KitchenStockScreen extends StatelessWidget {
  const KitchenStockScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.secondaryContainer,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.hardEdge,
              child: Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuBKc1FTvboO3rTuaHr9RZZES8pJLT-BW9qAyaUo6dBY8uNmc-G_z3NMNFpyI4Z6XcEN4bOA7mbmoPVBuX4geG3BCkH9cCC1Xg_ZuFznVHdX2teLy7SH3knPnW7KFIMmlbzk0vW0lNFF4BBtaqAgfAirvTTZelSJJ-wi6ekmimiXB2XuYV0m8EeWwndXdqMnPAxThxbuVJjNw6cn7Tix1EBthdVOFdiKZvJRLmMKsFJ4TRfr5sxkAPwRoQ',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.person),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Caferio',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search & Quick Actions
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search ingredients...',
                  prefixIcon: Icon(Icons.search, color: AppColors.outline),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.refresh),
                    label: const Text('Auto-Restock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryContainer,
                      foregroundColor: AppColors.onSecondaryContainer,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Restock All', maxLines: 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Category Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip('All Items', true),
                  _buildChip('Fresh Produce', false),
                  _buildChip('Proteins', false),
                  _buildChip('Pantry', false),
                  _buildChip('Spices', false),
                ],
              ),
            ),
            const SizedBox(height: 32),

            _buildSimpleSection(context, 'Fresh Produce & Aromatics', [
              'Onions (Red/Big)', 'Shallots', 'Ginger', 'Garlic', 'Green Chilies', 
              'Curry Leaves (Fresh)', 'Spring Onions', 'Capsicum (Bell Peppers)', 
              'Carrots', 'Cabbage', 'French Beans', 'Fresh Coriander Leaves', 'Lemon/Lime'
            ]),
            const SizedBox(height: 32),
            _buildSimpleSection(context, 'Spices & Seasoning', [
              'Mustard Seeds', 'Fennel Seeds', 'Cumin Seeds', 'Green Cardamom', 
              'Black Cardamom', 'Cloves', 'Cinnamon Sticks', 'Star Anise', 'Bay Leaves', 
              'Whole Black Peppercorns', 'Turmeric Powder', 'Kashmiri Red Chili Powder', 
              'Coriander Powder', 'Garam Masala', 'White Pepper Powder', 'Black Pepper Powder',
              'Kasuri Methi', 'Salt'
            ]),
            const SizedBox(height: 32),
            _buildSimpleSection(context, 'Pantry, Sauces & Oils', [
              'Coconut Oil', 'Neutral Vegetable Oil', 'Sesame Oil', 'Ghee', 'Butter (Unsalted)',
              'Dark Soy Sauce', 'Tomato Ketchup', 'Green Chili Sauce', 'Red Chili Sauce',
              'Szechuan Sauce', 'White Vinegar', 'Cornflour', 'All-Purpose Flour', 'Sugar/Honey'
            ]),
            const SizedBox(height: 32),
            _buildSimpleSection(context, 'Dairy & Refrigerated', [
              'Yogurt (Curd)', 'Fresh Cream', 'Paneer'
            ]),
            const SizedBox(height: 32),
            _buildSimpleSection(context, 'Proteins & Vegetables', [
              'Chicken (Boneless & Bone-in)', 'Beef', 'Mutton', 'Eggs',
              'Cauliflower (Gobi)', 'Mushrooms', 'Baby Corn', 'Potatoes'
            ]),
            const SizedBox(height: 32),
            _buildSimpleSection(context, 'Grains & Noodles', [
              'Basmati Rice', 'Noodles'
            ]),
            const SizedBox(height: 32),
            _buildSimpleSection(context, 'Essential "Secret" Ingredients', [
              'Cashew Nuts', 'Fresh Coconut', 'Tamarind'
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.outline),
        ),
      ],
    );
  }



  Widget _buildPantryItem(BuildContext context, String name, String levelText, double levelValue, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Stock level: $levelText', style: TextStyle(color: color == AppColors.error ? AppColors.error : AppColors.outline, fontSize: 12)),
          ],
        ),
        SizedBox(
          width: 96,
          child: LinearProgressIndicator(
            value: levelValue,
            backgroundColor: AppColors.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(4),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleSection(BuildContext context, String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, title, '${items.length} Items'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == items.length - 1;
              
              // Create deterministic pseudo-random stock levels
              double stockLevel = (item.length * 7 % 100) / 100.0;
              if (stockLevel < 0.1) stockLevel = 0.1; // Ensure it's not 0
              
              final stockText = '${(stockLevel * 100).toInt()}%';
              final color = stockLevel < 0.25 ? AppColors.error : AppColors.secondaryContainer;

              return Column(
                children: [
                  _buildPantryItem(context, item, stockText, stockLevel, color),
                  if (!isLast) const Divider(color: AppColors.surfaceContainerHighest, height: 24),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
