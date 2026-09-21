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

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shortage & Inventory',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 8),
          Text(
            'Mark dishes as Out of Stock to prevent new orders',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          
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
              child: provider.groupedInventoryItems.length == 0 
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
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            subtitle: item.stockStatus != null && item.expectedRunOutDate != null
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                          'Runs out in ${item.daysLeft} days (Expected: ${item.expectedRunOutDate!.day}/${item.expectedRunOutDate!.month}/${item.expectedRunOutDate!.year})\nStock: ${item.currentStock.toStringAsFixed(0)} ${item.lastRefilledDate != null ? '| Refilled: ${item.lastRefilledDate!.day}/${item.lastRefilledDate!.month}' : ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.add_shopping_cart, color: Colors.blue),
                                  tooltip: 'Refill',
                                  onPressed: () => _showRefillDialog(context, item, provider),
                                ),
                                Text(
                                  item.isOutOfStock ? 'OUT OF STOCK' : 'AVAILABLE',
                                  style: TextStyle(
                                    color: item.isOutOfStock ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Switch(
                                  value: !item.isOutOfStock, // Switch is ON when Available, OFF when Out of Stock
                                  onChanged: (val) {
                                    provider.toggleInventoryStock(item.id);
                                  },
                                  activeColor: Colors.green,
                                  inactiveThumbColor: Colors.red,
                                  inactiveTrackColor: Colors.red.withValues(alpha: 0.3),
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
