import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/profile_provider.dart';
import '../providers/cart_provider.dart';
import 'package:intl/intl.dart';
import 'cart_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  void _showEditProfileDialog(BuildContext context) {
    final profileProvider = context.read<ProfileProvider>();
    final nameController = TextEditingController(text: profileProvider.name);
    final imageController = TextEditingController(text: profileProvider.imageUrl);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: imageController,
                  decoration: const InputDecoration(labelText: 'Image URL'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                profileProvider.updateProfile(
                  name: nameController.text,
                  imageUrl: imageController.text,
                );
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final cartProvider = context.watch<CartProvider>();
    
    // Filter orders from the last 30 days
    final now = DateTime.now();
    final recentOrders = cartProvider.orders.where((order) {
      return now.difference(order.date).inDays <= 30;
    }).toList();

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
                profileProvider.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.person),
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
            icon: const Icon(Icons.shopping_bag, color: AppColors.primary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Section
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                      )
                    ],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Image.network(
                    profileProvider.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 40),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profileProvider.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.onSurface,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        profileProvider.email,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Gold Member',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.onSecondaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 40),
            
            // Recent Orders
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Ordered Dishes',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (recentOrders.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
                ),
                child: const Text(
                  'No recent orders in the last 30 days.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.onSurfaceVariant),
                ),
              )
            else
              ...recentOrders.map((order) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.receipt_long, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order #${order.id.substring(order.id.length - 4)}',
                                    style: Theme.of(context).textTheme.labelLarge,
                                  ),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(order.date),
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${order.total.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: AppColors.primary,
                                    ),
                              ),
                              Text(
                                'Delivered',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppColors.secondary,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: order.items.map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildOrderItemImage(item.product.imageUrl),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),

            const SizedBox(height: 40),

            // Account Settings
            Text(
              'Account Settings',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildSettingsTile(Icons.person_outline, 'Edit Profile', onTap: () => _showEditProfileDialog(context)),
            const SizedBox(height: 8),
            _buildSettingsTile(Icons.notifications_active_outlined, 'Notifications'),
            const SizedBox(height: 8),
            _buildSettingsTile(Icons.payments_outlined, 'Payment Methods'),
            
            const SizedBox(height: 24),
            const Divider(color: AppColors.outlineVariant),
            const SizedBox(height: 16),
            
            GestureDetector(
              onTap: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(
                      'Log Out',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.delete_forever, color: AppColors.error),
                  const SizedBox(width: 12),
                  Text(
                    'Delete Account',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.error,
                        ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            const Center(
              child: Text(
                'Caferio App v2.4.0',
                style: TextStyle(color: AppColors.tertiaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemImage(String url) {
    bool isAsset = url.startsWith('asset:');
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
      ),
      clipBehavior: Clip.hardEdge,
      child: isAsset
          ? Image.asset('assets/images/${url.replaceAll('asset:', '')}.png', fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.image))
          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.image)),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 12),
                Text(title),
              ],
            ),
            const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
