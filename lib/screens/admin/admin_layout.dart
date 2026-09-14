import 'package:flutter/material.dart';
import 'package:caferio/utils/theme.dart';
import 'package:caferio/screens/admin/sales_screen.dart';
import 'package:caferio/screens/admin/edits_screen.dart';
import 'package:caferio/screens/kitchen/shortage_screen.dart';
import 'package:caferio/screens/admin/admin_profile_screen.dart';

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    SalesScreen(),
    EditsScreen(),
    ShortageScreen(),
    AdminProfileScreen(),
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
                    'Caferio Admin',
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
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: Text('Sales'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.edit_note_outlined),
                selectedIcon: Icon(Icons.edit_note),
                label: Text('Edits'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory),
                label: Text('Shortage'),
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
