import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/ingredient_provider.dart';
import '../models/ingredient_model.dart';
import '../services/ingredient_prediction_service.dart';

class KitchenStockScreen extends StatelessWidget {
  const KitchenStockScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IngredientProvider>();
    final ingredients = provider.ingredients;
    final predictions = provider.predictions;

    // Group ingredients by category
    final Map<String, List<IngredientModel>> grouped = {};
    for (final ing in ingredients) {
      grouped.putIfAbsent(ing.category, () => []).add(ing);
    }

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
                    onPressed: () => provider.autoRestockCritical(),
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

            if (ingredients.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              ...grouped.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: _buildCategorySection(context, entry.key, entry.value, predictions),
                );
              }).toList(),
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

  Widget _buildCategorySection(BuildContext context, String title, List<IngredientModel> items, List<IngredientPrediction> predictions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              '${items.length} Items',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.outline),
            ),
          ],
        ),
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
              
              final prediction = predictions.where((p) => p.ingredientId == item.id).firstOrNull;
              
              final displayValue = item.currentStock / item.displayDivisor;
              final stockText = '${displayValue.toStringAsFixed(1)} ${item.displayUnit}';
              
              Color color = AppColors.secondaryContainer;
              String timeText = '';
              
              if (prediction != null) {
                timeText = prediction.exhaustionLabel;
                if (prediction.riskLevel == IngredientRisk.critical) {
                  color = AppColors.error;
                } else if (prediction.riskLevel == IngredientRisk.warning) {
                  color = AppColors.secondary;
                }
              }

              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('Stock: $stockText', style: TextStyle(color: color == AppColors.error ? AppColors.error : AppColors.outline, fontSize: 12)),
                                if (timeText.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(timeText, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 96,
                        child: LinearProgressIndicator(
                          value: item.stockFraction,
                          backgroundColor: AppColors.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
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
