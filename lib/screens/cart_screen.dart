import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:caferio/providers/app_provider.dart';
import 'package:caferio/utils/theme.dart';

class CartScreen extends StatelessWidget {
  final VoidCallback? onBrowse;
  const CartScreen({super.key, this.onBrowse});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final cartItems = provider.cart;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('My Cart'),
        elevation: 0,
      ),
      body: cartItems.isEmpty
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
                    child: const Icon(Icons.shopping_bag_outlined, size: 80, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 24),
                  Text('Your cart is empty', style: Theme.of(context).textTheme.displayMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'Looks like you haven\'t added\nanything to your cart yet', 
                    textAlign: TextAlign.center, 
                    style: TextStyle(color: AppTheme.textLight, height: 1.5, fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      if (onBrowse != null) {
                        onBrowse!();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                      foregroundColor: AppTheme.primaryColor,
                      elevation: 0,
                    ),
                    child: const Text('Start Browsing', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: item.menuItem.imageUrl.startsWith('assets/')
                                    ? Image.asset(
                                        item.menuItem.imageUrl,
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          width: 90,
                                          height: 90,
                                          color: Colors.grey[100],
                                          child: const Icon(Icons.fastfood, color: Colors.grey),
                                        ),
                                      )
                                    : Image.network(
                                        item.menuItem.imageUrl,
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          width: 90,
                                          height: 90,
                                          color: Colors.grey[100],
                                          child: const Icon(Icons.fastfood, color: Colors.grey),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.menuItem.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${item.menuItem.price.toStringAsFixed(0)}',
                                      style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 16),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () => provider.removeFromCart(item.menuItem),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.grey.shade300),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.remove, size: 16, color: AppTheme.textDark),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text('${item.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 12),
                                        InkWell(
                                          onTap: () => provider.addToCart(item.menuItem),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.add, size: 16, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      )
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal', style: TextStyle(color: AppTheme.textLight, fontSize: 16)),
                            Text('₹${provider.cartTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Taxes & Fees', style: TextStyle(color: AppTheme.textLight, fontSize: 16)),
                            Text('₹50', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Divider(),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(
                              '₹${(provider.cartTotal + 50.0).toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        InkWell(
                          onTap: () {
                            provider.placeOrder();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Order placed successfully! Track it in the Track tab.'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.green.shade800,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.primaryColor, Color(0xFFC01018)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Checkout',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
    );
  }
}
