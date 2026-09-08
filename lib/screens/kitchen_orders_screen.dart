import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/kitchen_provider.dart';
import '../models/kitchen_order.dart';

class KitchenOrdersScreen extends StatelessWidget {
  const KitchenOrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final kitchenProvider = context.watch<KitchenProvider>();
    final activeOrders = kitchenProvider.activeOrders;

    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.secondaryContainer,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.hardEdge,
              child: Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuDRfO5nvs5Eh7mcuFCINW0grdKfg1Pk-V9ptdTtRi_t0Zb49AKTQgVdX2C7GTi96kD5dnmsT5GfwU4L-oGXKooVbqHKF3DYtuVKdAh7PcBM9Pvkcsy8sJsnwMP3cEqP0NFWpuDpuws6F0_agjHcnkfnNTLYbYxVFGzdiWi7Z4kTRgtqdvfHeSEX9jIuKZxBYTGGy-CidruPdasR6ufi9yc96b9epG10b4ZTKKSOVhybr5bbgLI3OYULcn-Y2VOED5ju72g',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.person),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Caferio',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Live Orders',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${activeOrders.length} Active',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: activeOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restaurant, size: 64, color: AppColors.outlineVariant),
                          const SizedBox(height: 16),
                          Text(
                            'No live orders at the moment.',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: activeOrders.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final order = activeOrders[index];
                        return _buildOrderCard(context, order, kitchenProvider);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(
      BuildContext context, KitchenOrder order, KitchenProvider kitchenProvider) {
    final statusColor = _statusColor(order.status);
    final statusBgColor = _statusBgColor(order.status);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: statusColor, width: 4),
              top: const BorderSide(color: AppColors.surfaceContainer),
              right: const BorderSide(color: AppColors.surfaceContainer),
              bottom: const BorderSide(color: AppColors.surfaceContainer),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${order.id.substring(order.id.length - 4)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                      ),
                      Text(
                        order.tableNumber,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${order.placedAt.hour.toString().padLeft(2, '0')}:${order.placedAt.minute.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      order.status.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.surfaceContainerLow),
              const SizedBox(height: 12),
              // Items list
              ...order.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item.quantity}x  ${item.product.name}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        '₹${(item.product.price * item.quantity).toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 4),
              const Divider(color: AppColors.surfaceContainerLow),
              const SizedBox(height: 12),
              // Footer: total + action button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: ₹${order.total.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                  ),
                  _buildActionButton(context, order, kitchenProvider),
                ],
              ),
            ],
          ),
        ),
        // NEW badge
        if (order.isNew)
          Positioned(
            top: -10,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton(
      BuildContext context, KitchenOrder order, KitchenProvider kitchenProvider) {
    String label;
    Color bg;
    Color fg;
    KitchenOrderStatus? nextStatus;

    switch (order.status) {
      case KitchenOrderStatus.received:
        label = 'Start';
        bg = AppColors.secondaryContainer;
        fg = AppColors.onSecondaryContainer;
        nextStatus = KitchenOrderStatus.preparing;
        break;
      case KitchenOrderStatus.preparing:
        label = 'Ready';
        bg = AppColors.primary;
        fg = AppColors.onPrimary;
        nextStatus = KitchenOrderStatus.ready;
        break;
      case KitchenOrderStatus.ready:
        label = 'Served';
        bg = Colors.green.shade600;
        fg = Colors.white;
        nextStatus = KitchenOrderStatus.served;
        break;
      case KitchenOrderStatus.served:
        label = '✓ Done';
        bg = AppColors.surfaceContainer;
        fg = AppColors.onSurfaceVariant;
        nextStatus = null;
        break;
    }

    return ElevatedButton(
      onPressed: nextStatus == null
          ? null
          : () => kitchenProvider.updateStatus(order.id, nextStatus!),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Color _statusColor(KitchenOrderStatus status) {
    switch (status) {
      case KitchenOrderStatus.received:
        return Colors.orange;
      case KitchenOrderStatus.preparing:
        return AppColors.primary;
      case KitchenOrderStatus.ready:
        return Colors.green.shade600;
      case KitchenOrderStatus.served:
        return AppColors.outlineVariant;
    }
  }

  Color _statusBgColor(KitchenOrderStatus status) {
    switch (status) {
      case KitchenOrderStatus.received:
        return Colors.orange.withOpacity(0.12);
      case KitchenOrderStatus.preparing:
        return AppColors.primary.withOpacity(0.1);
      case KitchenOrderStatus.ready:
        return Colors.green.withOpacity(0.12);
      case KitchenOrderStatus.served:
        return AppColors.surfaceContainer;
    }
  }
}
