import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:caferio/providers/app_provider.dart';
import 'package:caferio/utils/theme.dart';
import 'package:caferio/models/customer_behaviour.dart';
import 'package:caferio/Authentication/auth_service.dart';
import 'package:caferio/Authentication/profile_security_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final favourites = provider.favouriteItems;

    final isGuest = !AuthService.instance.isAuthenticated || AuthService.instance.isGuest;
    final username = AuthService.instance.currentUsername;
    final displayName = !isGuest && username != null && username.isNotEmpty
        ? '@$username'
        : 'Guest User';
    final subtitle = !isGuest
        ? 'Verified Caferio Account'
        : 'Browsing as Guest';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.only(top: 60, bottom: 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, Color(0xFFC01018)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 4),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)],
                      ),
                      child: const CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Favourites Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.centerLeft,
              child: Text(
                'My Favourites',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 20),
              ),
            ),
            const SizedBox(height: 12),
            favourites.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.favorite_border, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('No favourites yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: favourites.length,
                    itemBuilder: (context, index) {
                      final item = favourites[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: item.imageUrl.startsWith('assets/')
                                ? Image.asset(
                                    item.imageUrl,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    item.imageUrl,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text('₹${item.price.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                          trailing: IconButton(
                            icon: const Icon(Icons.favorite, color: AppTheme.primaryColor),
                            onPressed: () => provider.toggleFavourite(item.id),
                          ),
                        ),
                      );
                    },
                  ),
                  
            const SizedBox(height: 24),

            // --- Taste Profile & Insights ---
            Builder(
              builder: (context) {
                final behaviour = Provider.of<AppProvider>(context).customerBehaviour;
                if (behaviour == null || !behaviour.hasHistory) {
                  return const SizedBox.shrink();
                }
                return _buildTasteProfileCard(context, behaviour);
              },
            ),

            // Security & Authentication Section
            const SizedBox(height: 24),
            const ProfileSecurityCard(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTasteProfileCard(BuildContext context, CustomerBehaviour behaviour) {
    final topCat = behaviour.topCategory;
    final totalOrders = behaviour.totalOrders;
    final aov = behaviour.avgOrderValue;

    final dayLabel = behaviour.preferredDay != null
        ? ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][behaviour.preferredDay!]
        : null;
    final hourLabel = behaviour.preferredHour != null
        ? '${behaviour.preferredHour! % 12 == 0 ? 12 : behaviour.preferredHour! % 12}${behaviour.preferredHour! < 12 ? 'am' : 'pm'}'
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.08),
              const Color(0xFFC01018).withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.15), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.psychology_outlined,
                      color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Your Taste Profile',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: AppTheme.textDark),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Stats Row
            Row(
              children: [
                _buildStatTile('🛒', 'Orders', '$totalOrders'),
                const SizedBox(width: 12),
                _buildStatTile('💰', 'Avg Spend',
                    '₹${aov.toStringAsFixed(0)}'),
                const SizedBox(width: 12),
                _buildStatTile('❤️', 'Favourite', topCat),
              ],
            ),
            if (dayLabel != null && hourLabel != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      color: AppTheme.textLight, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Usually orders on $dayLabel around $hourLabel',
                    style:
                        const TextStyle(color: AppTheme.textLight, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String emoji, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.textDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
            ),
          ],
        ),
      ),
    );
  }
}
