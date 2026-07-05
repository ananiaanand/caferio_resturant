import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/cart_provider.dart';

class KitchenOrdersScreen extends StatelessWidget {
  const KitchenOrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final liveOrders = cartProvider.orders; // In a real app, filter by status

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
                        '${liveOrders.length} Active',
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
              child: liveOrders.isEmpty
                  ? Center(
                      child: Text(
                        'No live orders at the moment.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: liveOrders.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final order = liveOrders[index];
                        final isEven = index % 2 == 0;
                        return _buildOrderCard(context, order, isEven);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, PlacedOrder order, bool isInProgress) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: isInProgress
                    ? AppColors.surfaceContainerLowest
                    : AppColors.primary.withOpacity(0.5),
                width: 4,
              ),
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
                        'Table ${order.id.hashCode % 20 + 1}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isInProgress
                          ? AppColors.secondaryContainer
                          : AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isInProgress ? 'IN PROGRESS' : 'PENDING',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isInProgress
                                ? AppColors.onSecondaryContainer
                                : AppColors.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.surfaceContainerLow),
              const SizedBox(height: 12),
              Column(
                children: order.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item.quantity}x ${item.product.name}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Icon(
                          isInProgress
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isInProgress
                              ? AppColors.primary
                              : AppColors.outlineVariant,
                          size: 20,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 4),
              const Divider(color: AppColors.surfaceContainerLow),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 18,
                        color: isInProgress
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${order.date.hour.toString().padLeft(2, '0')}:${order.date.minute.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isInProgress
                                  ? AppColors.primary
                                  : AppColors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isInProgress
                          ? AppColors.primary
                          : AppColors.secondaryContainer,
                      foregroundColor: isInProgress
                          ? AppColors.onPrimary
                          : AppColors.onSecondaryContainer,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      isInProgress ? 'Ready' : 'Start',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // NEW badge — shown until kitchen staff opens the Orders tab
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
}

