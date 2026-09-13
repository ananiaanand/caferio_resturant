import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:caferio/providers/app_provider.dart';
import 'package:caferio/models/order.dart';
import 'package:caferio/utils/theme.dart';

class TrackOrderScreen extends StatelessWidget {
  const TrackOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final activeOrders = provider.orders;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Track Order'),
        elevation: 0,
      ),
      body: activeOrders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delivery_dining, size: 80, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 24),
                  Text('No active orders', style: Theme.of(context).textTheme.displayMedium),
                  const SizedBox(height: 8),
                  const Text('When you place an order, you can\ntrack its status here.',
                      textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textLight, height: 1.5)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: activeOrders.length,
              itemBuilder: (context, index) {
                final order = activeOrders[index];
                return _buildOrderTracker(context, order);
              },
            ),
    );
  }

  Widget _buildOrderTracker(BuildContext context, Order order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #${order.id.substring(order.id.length - 6)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textDark)),
                    const SizedBox(height: 4),
                    Text('${order.items.length} items • Est. 15 mins', style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w500)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('₹${order.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 18)),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Divider(),
            ),
            ...OrderStatus.values.map((status) {
              final isCompleted = order.status.index >= status.index;
              final isCurrent = order.status == status;
              
              IconData stepIcon;
              switch (status) {
                case OrderStatus.received: stepIcon = Icons.receipt_long; break;
                case OrderStatus.preparing: stepIcon = Icons.soup_kitchen; break;
                case OrderStatus.halfDone: stepIcon = Icons.timelapse; break;
                case OrderStatus.completed: stepIcon = Icons.done_all; break;
                case OrderStatus.served: stepIcon = Icons.room_service; break;
              }

              return Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted ? Colors.green : Colors.grey.shade100,
                          border: isCurrent ? Border.all(color: Colors.green.withValues(alpha: 0.3), width: 6) : null,
                          boxShadow: isCurrent ? [BoxShadow(color: Colors.green.withValues(alpha: 0.4), blurRadius: 10)] : [],
                        ),
                        child: Icon(stepIcon, size: 18, color: isCompleted ? Colors.white : Colors.grey.shade400),
                      ),
                      if (status != OrderStatus.values.last)
                        Container(
                          width: 3,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                isCompleted ? Colors.green : Colors.grey.shade200,
                                order.status.index > status.index ? Colors.green : Colors.grey.shade200,
                              ]
                            )
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: status != OrderStatus.values.last ? 40 : 0),
                      child: Text(
                        status.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          color: isCompleted ? AppTheme.textDark : AppTheme.textLight,
                        ),
                      ),
                    ),
                  )
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
