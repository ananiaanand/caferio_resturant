import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/cart_provider.dart';
import 'package:intl/intl.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<CartProvider>().orders;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.hardEdge,
              child: Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuDGZ6xe-N3BjSTerxs8se9MoHm9HAhEE5SFd6fnJeehxojv-NORMpKRmXTYGeuBwIPWCCMauHe19c0Og5E9tgO3YPzg0YsFs92RIbdR7NHu4g2vB5qgKeeIrRtc7hHZ3wLwXF8fmScVxGPMOxEOBKbgp0yerMikjlMVMltNkncxBMRxmgiggGufT_nIgMPZkf3Fwj2caFaWgAsewnC7o9-CCbNPbHnr7lJkZ4FszOWAQotpNB4yB59KtGdptYI1w-KPM5pwJTa_v5YO',
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Your Orders',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
      body: orders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: AppColors.outlineVariant),
                  const SizedBox(height: 16),
                  Text(
                    'No orders yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100), // Bottom padding for nav bar
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.5)),
                  ),
                  color: AppColors.surfaceContainerLowest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order #${order.id.substring(order.id.length - 5)}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              '₹${order.total.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dateFormat.format(order.date),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: AppColors.outlineVariant),
                        const SizedBox(height: 16),
                        ...order.items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.quantity}x',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.secondary,
                                      ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${(item.product.price * item.quantity).toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
