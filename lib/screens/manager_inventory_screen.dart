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
    {'name': 'Fresh Basil', 'qty': '1.2kg', 'expiry': '3 days', 'status': 'low', 'category': 'Vegetables',
      'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuAt6L-ewKa7X2u9i6j0M4Gkeho7Atx29RnPbYZMefho7lKEoGh4v32MI_ACq7KPSbUxNlcEu34J_xXlZYOVRgbSBXSP0OF4wBGk8IfAfXbvhWSP6sTXTW_60lwZ9DuEe1-Km-vNJ-qVGpacWliHn9V90idomrlXPuX8eeK-BABHtIzPUlinkxCx4Uxfba_fuOx1dsYzdUiinmzzX7Qmf89PT30SnnEX9VV66jdZ0Ta3AGwVFk5em3LWYQ'},
    {'name': 'Roma Tomatoes', 'qty': '24.5kg', 'expiry': '8 days', 'status': 'good', 'category': 'Vegetables',
      'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuBMU9H9ZXPTOgcMBsmH7EbdpoyQdOE38FxP-Q1BAKwfdNoA5wkYFOil8gUYVff1vKzO9voDhFvJvNuSmumCgWoRCY7QkLUkByvAsnTuN8KR4llLGdCu7Dq_w2dAtaN_givqrmidI_TckgOMkUnzBcg7_GbaTxOyNcEKrYTwbU6RvUDLbc_X0bvSkSQ23zaqfCQx7_wWFkghP5E5EcSkHDOn-Yb4jvR-xJdvRsi8-km7zvdJa30SWg-tpg'},
    {'name': 'Whole Milk', 'qty': '5L', 'expiry': '2 days', 'status': 'low', 'category': 'Dairy',
      'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuAPxDPZxrmfPYuDSJ7At8vGwQ3-FEymvO6Z_C2VGBR8ch2i53B9TXRZPM29nsDlb1-yJKWzf_rbdcfrXEZvdV4ctbJpTFa8lWrmllux7QSBb7NO5rHvkyejDFT1CTWrpgxfvE1psA8ewD8rR-PlW6R5Cxq6P2CIYuIbhUjvnYYfX-ggq8GGZYknfMOMtCIg-6B6RN-mWUfKiRYl6Gnzfo2mlS9ihxvLcEHf38dxOl6KSpmSQcRTdNXOVQ'},
    {'name': 'Smoked Paprika', 'qty': '2.8kg', 'expiry': '120 days', 'status': 'good', 'category': 'Spices',
      'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuDihaqI1utKZF7WfC2172Zm_4Hk9AJ9nm_Op8YYy7BHDvXy-XnoInWiecdivzE_7vYpGn590Cj_HI8DDcTPHIgCZzYtm18c3A3YOpaDOdsbKmWd5Q3J--RTmk1fS5GQty8TnatevsLPCQQEZczo_nk7F2C_7lKIgwqNQmj5VzT_cy3bA1fnWk425HwNZ2AvWqSrt2zXXM2KA9Mn7P9YrSuc7heaYkOGKM87pYf0IzlN8rf7d9fjzeiQ4A'},
    {'name': 'Beef Tenderloin', 'qty': '18.0kg', 'expiry': '4 days', 'status': 'good', 'category': 'Meat',
      'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuDdH5mKT9pgA-RRbXTAzHjsJsXZ03MBuoxXfqYWfA8gZrtxXEQ21XpfO0NMw5-04WH40lkHkMvAoGBq06TqJjkQR8GxB1qVakC-MsTQ-EqruFPIexqr02Qe86StOLg_PM9QV70JJHN3ANYObcvUPxzO5pJtQRjzoOYbQgkMogiWbKtvDQocw-4fSDmcsckZhbQs19h1qdUdLfw6qCSgUOO7Is3spkCMpMUpx9Nxm2kpWNDwglw'},
    {'name': 'Shallots', 'qty': '1.2kg', 'expiry': '5 days', 'status': 'low', 'category': 'Vegetables',
      'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuBJiPYKNH7BE7ZgpWQUtDyS91KTpXMSYMXNtb7KgIVIsPS_JBjgGJVABRzvS4xErOG2VntTQkViBdhaFcuQwgbAYM6KH8xAxcX8immF8mn9mdsaiGvYRV2pHEtBTfZOsPhF_bJixbw9gi92zjrp6ueeUdYM5aOPibM7cXRG8qwUD8h0VCvUPLVAhBCwj4-FqyvpUPlENA-dkZhWjgAm9rhedAtYahhPHwmmU7plqEA-hkLer_TO8AVX5A'},
    {'name': 'Coconut Oil', 'qty': '5L', 'expiry': '180 days', 'status': 'low', 'category': 'Oils',
      'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuCXH26fRifRDKEap2s9Qa7NMVXUlT1fq4hair0m_tuFbayek2htQNty8EARG-uGd0wA8PXq4aCAdNYWzld_cdkhhQkPHfsNQRJGcN5mrwmFiTlrkN9wRgilU2ahLWKLAosKjsblUVleINEn65dl1K4jft3-KwKlp5FvEa2bSAqabWZn7eoc7oT-s-ANKZHUntoEnXiWOfp3-lEdeseTm8ffv65eV7GnTVT1kybY6f19ETi7YTCf5u2RVA'},
    {'name': 'Basmati Rice', 'qty': '22kg', 'expiry': '365 days', 'status': 'good', 'category': 'Grains',
      'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuDRCgacgSyKS-jwG7gEfq-lX__B7GNkIJJvnpJT08YxTALE_x9AiYQ05m86k9u0njHcLAVozAS0kNFTIiHh8ueUf5hiqWMnbOwtR95ag2FpDrgIEK0Zd5ERaIrMCqNOIEAmwKzCssMeA_QId5siQ_UteuJRZhlHVAErZAvv7eBj6UohmapjmXktMBYyKD4UjiQ5V29CfIK_ZOBa7F1dvo7c3fEjP6aSfMF1q0q2lqlmP3w2LTGPNQFxYA'},
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
                      childAspectRatio: 0.78,
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
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isLow ? AppColors.errorContainer : AppColors.outlineVariant),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              item['image'] as String,
              height: 110,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 110,
                color: AppColors.surfaceContainer,
                child: const Icon(Icons.image, size: 40, color: AppColors.onSurfaceVariant),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isLow ? AppColors.errorContainer : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isLow ? 'Low Stock' : 'Healthy',
                    style: TextStyle(
                      color: isLow ? AppColors.error : Colors.green.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(item['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(item['qty'] as String,
                    style: TextStyle(
                        color: isLow ? AppColors.primary : AppColors.onSurfaceVariant,
                        fontWeight: isLow ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 12, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Text('Exp: ${item['expiry']}',
                        style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: isLow ? AppColors.primary : AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              isLow ? 'Refill' : 'Details',
                              style: TextStyle(
                                color: isLow ? Colors.white : AppColors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
