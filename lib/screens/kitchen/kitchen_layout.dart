import 'package:flutter/material.dart';
import 'package:caferio/utils/theme.dart';
import 'pending_orders_screen.dart';
import 'completed_orders_screen.dart';
import 'shortage_screen.dart';
import 'kitchen_profile_screen.dart';

class KitchenLayout extends StatefulWidget {
  const KitchenLayout({super.key});

  @override
  State<KitchenLayout> createState() => _KitchenLayoutState();
}

class _KitchenLayoutState extends State<KitchenLayout> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    PendingOrdersScreen(),
    ShortageScreen(),
    CompletedOrdersScreen(),
    KitchenProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Row(
        children: [
          // Left Sidebar (Navigation Rail)
          NavigationRail(
            backgroundColor: Colors.white,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            extended: true,
            minExtendedWidth: 220,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                children: [
                  const Icon(Icons.restaurant, color: AppTheme.primaryColor, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Caferio Kitchen',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            selectedLabelTextStyle: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            unselectedLabelTextStyle: const TextStyle(
              color: AppTheme.textLight,
              fontSize: 15,
            ),
            selectedIconTheme: const IconThemeData(color: AppTheme.primaryColor, size: 28),
            unselectedIconTheme: const IconThemeData(color: AppTheme.textLight, size: 24),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.pending_actions_outlined),
                selectedIcon: Icon(Icons.pending_actions),
                label: Text('Pending Orders'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory),
                label: Text('Shortage'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.check_circle_outline),
                selectedIcon: Icon(Icons.check_circle),
                label: Text('Completed'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: Text('Profile'),
              ),
            ],
          ),
          
          const VerticalDivider(thickness: 1, width: 1, color: Color(0xFFEEEEEE)),
          
          // Main Content Area
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
    );
  }
}
