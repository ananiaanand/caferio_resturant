import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/cart_provider.dart';
import 'kitchen_orders_screen.dart';
import 'kitchen_stock_screen.dart';
import 'kitchen_analytics_screen.dart';
import 'profile_screen.dart';

class KitchenMainScreen extends StatefulWidget {
  const KitchenMainScreen({Key? key}) : super(key: key);

  @override
  State<KitchenMainScreen> createState() => _KitchenMainScreenState();
}

class _KitchenMainScreenState extends State<KitchenMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const KitchenOrdersScreen(),
    const KitchenStockScreen(),
    const KitchenAnalyticsScreen(),
    const ProfileScreen(),
  ];

  void _onDestinationSelected(int index) {
    // When kitchen staff taps Orders tab, mark all orders as seen
    if (index == 0) {
      context.read<CartProvider>().markOrdersAsSeen();
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final newOrderCount = context.watch<CartProvider>().newOrderCount;

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onDestinationSelected,
            backgroundColor: AppColors.surface,
            elevation: 0,
            indicatorColor: AppColors.secondaryContainer,
            destinations: [
              NavigationDestination(
                icon: _buildOrdersIcon(newOrderCount, selected: false),
                selectedIcon: _buildOrdersIcon(newOrderCount, selected: true),
                label: 'Orders',
              ),
              const NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined, color: AppColors.onSurfaceVariant),
                selectedIcon: Icon(Icons.inventory_2, color: AppColors.onSecondaryContainer),
                label: 'Stock',
              ),
              const NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined, color: AppColors.onSurfaceVariant),
                selectedIcon: Icon(Icons.bar_chart, color: AppColors.onSecondaryContainer),
                label: 'Analytics',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline, color: AppColors.onSurfaceVariant),
                selectedIcon: Icon(Icons.person, color: AppColors.onSecondaryContainer),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersIcon(int badgeCount, {required bool selected}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          selected ? Icons.receipt_long : Icons.receipt_long_outlined,
          color: selected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
        ),
        if (badgeCount > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                badgeCount > 9 ? '9+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
