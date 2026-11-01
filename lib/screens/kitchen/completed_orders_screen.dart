import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:caferio/providers/app_provider.dart';
import 'package:caferio/models/order.dart';
import 'package:caferio/models/menu_item.dart';
import 'package:caferio/utils/theme.dart';
import 'package:intl/intl.dart';

class CompletedOrdersScreen extends StatelessWidget {
  const CompletedOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final completedOrders = provider.allOrders
        .where((o) => o.status == OrderStatus.served)
        .toList();

    // Sort newest served first
    completedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final isPhone = MediaQuery.of(context).size.width < 650;

    return RefreshIndicator(
      onRefresh: () async => await provider.refreshOrders(),
      color: AppTheme.primaryColor,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isPhone ? 12.0 : 24.0,
          vertical: isPhone ? 12.0 : 20.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Completed Orders',
                        style: TextStyle(
                          fontSize: isPhone ? 22 : 30,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'History of all served orders',
                        style: TextStyle(
                          fontSize: isPhone ? 13 : 15,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.done_all, size: 16, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        '${completedOrders.length} Served',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: completedOrders.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: isPhone ? 60 : 80, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              'No completed orders yet',
                              style: TextStyle(
                                fontSize: isPhone ? 16 : 18,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : isPhone
                      ? ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: completedOrders.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _CompletedOrderCard(
                              order: completedOrders[index],
                              isPhone: true,
                            );
                          },
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 420,
                            mainAxisExtent: 280,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                          ),
                          itemCount: completedOrders.length,
                          itemBuilder: (context, index) {
                            return _CompletedOrderCard(
                              order: completedOrders[index],
                              isPhone: false,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedOrderCard extends StatelessWidget {
  final Order order;
  final bool isPhone;

  const _CompletedOrderCard({
    required this.order,
    required this.isPhone,
  });

  @override
  Widget build(BuildContext context) {
    final shortId = order.id.length > 4
        ? order.id.substring(order.id.length - 4)
        : order.id;

    final customerDisplay = (order.customerId != null && order.customerId!.isNotEmpty)
        ? order.customerId!.replaceFirst('usr_', '@')
        : null;

    Widget cardBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: isPhone ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Order #$shortId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ),
                  if (customerDisplay != null) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          customerDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 14, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    'SERVED',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              DateFormat('MMM dd, yyyy • hh:mm a').format(order.createdAt),
              style: const TextStyle(color: AppTheme.textLight, fontSize: 12),
            ),
            const Spacer(),
            Text(
              '₹${order.totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                color: AppTheme.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const Divider(height: 20),
        if (isPhone) ...[
          ...order.items.map((item) => _buildItemRow(item)),
        ] else ...[
          Expanded(
            child: ListView.builder(
              itemCount: order.items.length,
              itemBuilder: (context, index) => _buildItemRow(order.items[index]),
            ),
          ),
        ],
      ],
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: cardBody,
      ),
    );
  }

  Widget _buildItemRow(CartItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${item.quantity}x',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: AppTheme.textLight,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.menuItem.name,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
