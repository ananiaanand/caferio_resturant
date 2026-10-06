import 'package:flutter/material.dart';
import 'package:caferio/utils/theme.dart';
import 'package:provider/provider.dart';
import 'package:caferio/providers/app_provider.dart';
import 'dashboard_screen.dart';
import 'cart_screen.dart';
import 'track_order_screen.dart';
import 'profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  void _navigateTo(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  late final List<Widget> _screens = [
    const DashboardScreen(),
    CartScreen(
      onBrowse: () => _navigateTo(0),
      onOrderPlaced: () => _navigateTo(2),
    ),
    const TrackOrderScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Consumer<AppProvider>(
        builder: (context, provider, child) {
          final cartItemCount = provider.cart.fold<int>(
            0,
            (sum, item) => sum + item.quantity,
          );

          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _navigateTo,
            selectedItemColor: AppTheme.primaryColor,
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: cartItemCount > 0,
                  label: Text(cartItemCount.toString()),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                activeIcon: Badge(
                  isLabelVisible: cartItemCount > 0,
                  label: Text(cartItemCount.toString()),
                  child: const Icon(Icons.shopping_cart),
                ),
                label: 'Cart',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.delivery_dining_outlined),
                activeIcon: Icon(Icons.delivery_dining),
                label: 'Track',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          );
        },
      ),
    );
  }
}
