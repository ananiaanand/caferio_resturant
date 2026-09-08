import 'package:flutter/material.dart';
import '../theme/colors.dart';

class ManagerInventoryScreen extends StatefulWidget {
  const ManagerInventoryScreen({Key? key}) : super(key: key);

  @override
  State<ManagerInventoryScreen> createState() => _ManagerInventoryScreenState();
}

class _ManagerInventoryScreenState extends State<ManagerInventoryScreen> {
  int _selectedCategory = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _categories = ['All Items', 'Vegetables', 'Spices', 'Meat', 'Dairy', 'Grains', 'Oils'];

  final List<Map<String, dynamic>> _allItems = [
    {'name': 'Fresh Basil', 'qty': '0kg', 'expiry': '0 days', 'status': 'low', 'category': 'Vegetables'},
    {'name': 'Roma Tomatoes', 'qty': '0kg', 'expiry': '0 days', 'status': 'good', 'category': 'Vegetables'},
    {'name': 'Whole Milk', 'qty': '0L', 'expiry': '0 days', 'status': 'low', 'category': 'Dairy'},
    {'name': 'Smoked Paprika', 'qty': '0kg', 'expiry': '0 days', 'status': 'good', 'category': 'Spices'},
    {'name': 'Beef Tenderloin', 'qty': '0kg', 'expiry': '0 days', 'status': 'good', 'category': 'Meat'},
    {'name': 'Shallots', 'qty': '0kg', 'expiry': '0 days', 'status': 'low', 'category': 'Vegetables'},
    {'name': 'Coconut Oil', 'qty': '0L', 'expiry': '0 days', 'status': 'low', 'category': 'Oils'},
    {'name': 'Basmati Rice', 'qty': '0kg', 'expiry': '0 days', 'status': 'good', 'category': 'Grains'},
  ];

  List<Map<String, dynamic>> get _filtered {
    final cat = _categories[_selectedCategory];
    return _allItems.where((item) {
      final matchCat = cat == 'All Items' || item['category'] == cat;
      final matchSearch = _searchQuery.isEmpty ||
          (item['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final lowCount = filtered.where((i) => i['status'] == 'low').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Inventory',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined, color: AppColors.onSurfaceVariant), onPressed: () {}),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddItemDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search ingredients, spices...',
                prefixIcon: const Icon(Icons.search, color: AppColors.onSurfaceVariant),
                filled: true,
                fillColor: AppColors.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          // Predictive insight strip
          if (lowCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEBB0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFEBB0B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.analytics_outlined, color: Color(0xFF7b5800), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$lowCount items are running low — restock soon!',
                        style: const TextStyle(color: Color(0xFF7b5800), fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Category chips
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final selected = _selectedCategory == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? AppColors.primary : AppColors.outlineVariant),
                    ),
                    child: Text(
                      _categories[i],
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _buildStatChip('${filtered.length} Total', Icons.inventory_2_outlined, AppColors.primary),
                const SizedBox(width: 8),
                _buildStatChip('$lowCount Low Stock', Icons.warning_amber, AppColors.error),
                const SizedBox(width: 8),
                _buildStatChip('${filtered.length - lowCount} Healthy', Icons.check_circle_outline, Colors.green),
              ],
            ),
          ),
          // Inventory grid
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No items found', style: TextStyle(color: AppColors.onSurfaceVariant)))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.0,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _buildInventoryCard(context, filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(BuildContext context, Map<String, dynamic> item) {
    final isLow = item['status'] == 'low';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isLow ? AppColors.errorContainer : AppColors.outlineVariant),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Icon(Icons.inventory_2_outlined, size: 16, color: isLow ? AppColors.error : AppColors.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 8),
          Text(item['qty'] as String, style: TextStyle(color: isLow ? AppColors.error : AppColors.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text('Exp: ${item['expiry']}', style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11)),
        ],
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(
            left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Add Inventory Item', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            _buildDialogField('Item Name'),
            const SizedBox(height: 12),
            _buildDialogField('Quantity (e.g. 10kg)'),
            const SizedBox(height: 12),
            _buildDialogField('Expiry (days)'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(String hint) {
    return TextField(
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
