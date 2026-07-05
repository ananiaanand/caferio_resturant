import 'package:flutter/material.dart';
import '../theme/colors.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 12,
          ),
        ],
      ),
      padding: const EdgeInsets.only(bottom: 16, top: 8, left: 8, right: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.restaurant_menu, 'Menu', context),
          _buildNavItem(1, Icons.receipt_long, 'Orders', context),
          _buildNavItem(2, Icons.favorite_border, 'Favorites', context),
          _buildNavItem(3, Icons.person_outline, 'Profile', context),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, BuildContext context) {
    final isSelected = currentIndex == index;
    
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isSelected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
