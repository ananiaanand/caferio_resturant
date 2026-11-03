import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:caferio/providers/app_provider.dart';
import 'package:caferio/utils/theme.dart';

class ShortageScreen extends StatelessWidget {
  const ShortageScreen({super.key});

  void _showRefillDialog(BuildContext context, dynamic item, AppProvider provider) {
    final tc = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Refill ${item.name}'),
        content: TextField(
          controller: tc,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount to refill (e.g., kg or L)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(tc.text);
              if (amount != null && amount > 0) {
                provider.refillItem(item.id, amount);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Refill'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isPhone = MediaQuery.of(context).size.width < 650;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 14.0 : 24.0,
        vertical: isPhone ? 12.0 : 20.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shortage & Inventory',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: isPhone ? 22 : 32),
          ),
          const SizedBox(height: 4),
          Text(
            'Mark dishes as Out of Stock to prevent new orders',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: isPhone ? 13 : 14),
          ),
          SizedBox(height: isPhone ? 16 : 32),
          
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: TextField(
              onChanged: (value) => context.read<AppProvider>().setInventorySearchQuery(value),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Search inventory...',
                prefixIcon: Icon(Icons.search),
                fillColor: Colors.transparent,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: provider.groupedInventoryItems.isEmpty 
              ? const Center(child: Text("No items found", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                itemCount: provider.groupedInventoryItems.length,
                itemBuilder: (context, index) {
                  final category = provider.groupedInventoryItems.keys.elementAt(index);
                  final items = provider.groupedInventoryItems[category]!;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        color: Colors.grey[50],
                        width: double.infinity,
                        child: Text(
                          category,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor),
                        ),
                      ),
                      ...items.map((item) => Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Left: name + status info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                      if (item.stockStatus != null && item.expectedRunOutDate != null) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: item.stockStatus == 'CRITICAL'
                                                    ? Colors.red.withValues(alpha: 0.1)
                                                    : item.stockStatus == 'WARNING'
                                                        ? Colors.orange.withValues(alpha: 0.1)
                                                        : Colors.green.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: item.stockStatus == 'CRITICAL'
                                                      ? Colors.red
                                                      : item.stockStatus == 'WARNING'
                                                          ? Colors.orange
                                                          : Colors.green,
                                                ),
                                              ),
                                              child: Text(
                                                item.stockStatus!,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: item.stockStatus == 'CRITICAL'
                                                      ? Colors.red
                                                      : item.stockStatus == 'WARNING'
                                                          ? Colors.orange
                                                          : Colors.green,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Runs out in ${item.daysLeft} days · ${item.expectedRunOutDate!.day}/${item.expectedRunOutDate!.month}/${item.expectedRunOutDate!.year}',
                                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Stock: ${item.currentStock.toStringAsFixed(0)}${item.lastRefilledDate != null ? '  ·  Refilled: ${item.lastRefilledDate!.day}/${item.lastRefilledDate!.month}' : ''}',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Right: toggle + refill
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          item.isOutOfStock ? 'OUT OF\nSTOCK' : 'AVAILABLE',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: item.isOutOfStock ? Colors.red : Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Switch(
                                          value: !item.isOutOfStock,
                                          onChanged: (val) => provider.toggleInventoryStock(item.id),
                                          activeThumbColor: Colors.green,
                                          inactiveThumbColor: Colors.red,
                                          inactiveTrackColor: Colors.red.withValues(alpha: 0.3),
                                        ),
                                      ],
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _showRefillDialog(context, item, provider),
                                      icon: const Icon(Icons.add_shopping_cart, size: 14),
                                      label: const Text('Refill', style: TextStyle(fontSize: 12)),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.blue,
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        minimumSize: Size.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      )),
                    ],
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}
