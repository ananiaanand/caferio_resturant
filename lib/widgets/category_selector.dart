import 'package:flutter/material.dart';
import '../theme/colors.dart';

class CategorySelector extends StatelessWidget {
  final List<String> categories;
  final int selectedIndex;
  final Function(int) onSelected;

  const CategorySelector({
    Key? key,
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: List.generate(categories.length, (index) {
          final isSelected = index == selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Text(
                  categories[index],
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
