import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/cart_provider.dart';
import '../models/product.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final cartItems = cart.items.values.toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurfaceVariant),
          onPressed: () => Navigator.pop(context),
        ),
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
              'Caferio',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary),
            onPressed: () {},
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Delivery Time Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6), // Light yellow tint
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.secondaryContainer.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.timer, color: AppColors.onSecondaryContainer),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expected delivery time from\nkitchen',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.secondary,
                            ),
                      ),
                      Text(
                        '18 - 25 Minutes',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.onSecondaryFixed,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Your Order',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '${cart.itemCount} Items',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Items
            if (cartItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Center(
                  child: Text(
                    'Your cart is empty',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                ),
              )
            else
              ...cartItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildCartItem(
                    item.product,
                    item.quantity,
                    cart,
                  ),
                );
              }).toList(),

            const SizedBox(height: 16),
            
            // Summary Box
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Subtotal', '₹${cart.subtotal.toStringAsFixed(2)}'),
                  const SizedBox(height: 12),
                  _buildSummaryRow('Tax & Fees', '₹${cart.taxAndFees.toStringAsFixed(2)}'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Delivery Fee',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                      ),
                      Text(
                        'Free',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.outlineVariant),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        '₹${cart.total.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            
            // Place Order Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.onPrimaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: cart.itemCount > 0
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Order placed successfully!')),
                        );
                        cart.placeOrder();
                        Navigator.pop(context);
                      }
                    : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Place Order',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, color: Colors.white),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String url) {
    if (url.startsWith('asset:')) {
      final name = url.replaceFirst('asset:', '');
      return Image.asset(
        'assets/images/$name.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
    );
  }

  Widget _buildCartItem(Product product, int quantity, CartProvider cart) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 80,
              height: 80,
              child: _buildImage(product.imageUrl),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => cart.removeItem(product.id),
                      child: const Icon(Icons.delete_outline, color: AppColors.primary, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  product.description,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${product.price.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 16),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: () => cart.decrementItem(product.id),
                          ),
                          SizedBox(
                            width: 24,
                            child: Center(
                              child: Text(
                                '$quantity',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              color: AppColors.secondaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add, size: 16, color: AppColors.onSecondaryContainer),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => cart.addItem(product),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
