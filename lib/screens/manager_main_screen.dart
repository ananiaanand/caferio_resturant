import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'manager_dashboard_screen.dart';
import 'manager_inventory_screen.dart';
import 'manager_sales_screen.dart';
import 'manager_profile_screen.dart';

class ManagerMainScreen extends StatefulWidget {
  const ManagerMainScreen({Key? key}) : super(key: key);

  @override
  State<ManagerMainScreen> createState() => _ManagerMainScreenState();
}

class _ManagerMainScreenState extends State<ManagerMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ManagerDashboardScreen(),
    const ManagerInventoryScreen(),
    const ManagerSalesScreen(),
    const ManagerProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
            onDestinationSelected: (index) => setState(() => _currentIndex = index),
            backgroundColor: AppColors.surface,
            elevation: 0,
            indicatorColor: AppColors.primaryContainer.withOpacity(0.2),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined, color: AppColors.onSurfaceVariant),
                selectedIcon: Icon(Icons.dashboard, color: AppColors.primary),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined, color: AppColors.onSurfaceVariant),
                selectedIcon: Icon(Icons.inventory_2, color: AppColors.primary),
                label: 'Inventory',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined, color: AppColors.onSurfaceVariant),
                selectedIcon: Icon(Icons.bar_chart, color: AppColors.primary),
                label: 'Sales',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, color: AppColors.onSurfaceVariant),
                selectedIcon: Icon(Icons.person, color: AppColors.primary),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
