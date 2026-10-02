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

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, label: 'Sales'),
    _NavItem(icon: Icons.edit_note_outlined, selectedIcon: Icons.edit_note, label: 'Edits'),
    _NavItem(icon: Icons.inventory_2_outlined, selectedIcon: Icons.inventory, label: 'Shortage'),
    _NavItem(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
  ];

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
    // Close drawer on mobile after selection
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Widget _buildSidebarContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        Center(
          child: Column(
            children: [
              const Icon(Icons.restaurant, color: AppTheme.primaryColor, size: 48),
              const SizedBox(height: 8),
              Text(
                'Caferio Admin',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Divider(height: 1),
        const SizedBox(height: 16),
        ...List.generate(_navItems.length, (index) {
          final item = _navItems[index];
          final isSelected = _selectedIndex == index;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: InkWell(
              onTap: () => _onDestinationSelected(index),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      color: isSelected ? AppTheme.primaryColor : AppTheme.textLight,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? AppTheme.primaryColor : AppTheme.textLight,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;

    if (isWide) {
      // Desktop / Tablet: Persistent sidebar
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Row(
          children: [
            SizedBox(
              width: 220,
              child: Container(
                color: Colors.white,
                child: _buildSidebarContent(),
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1, color: Color(0xFFEEEEEE)),
            Expanded(child: _screens[_selectedIndex]),
          ],
        ),
      );
    } else {
      // Mobile: Hamburger + Drawer
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: AppTheme.textDark),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Text(
            _navItems[_selectedIndex].label,
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: false,
        ),
        drawer: Drawer(
          backgroundColor: Colors.white,
          child: SafeArea(child: _buildSidebarContent()),
        ),
        body: _screens[_selectedIndex],
      );
    }
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItem({required this.icon, required this.selectedIcon, required this.label});
}
