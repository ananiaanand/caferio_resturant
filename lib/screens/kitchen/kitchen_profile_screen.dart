import 'package:flutter/material.dart';
import 'package:caferio/utils/theme.dart';
import 'package:caferio/Authentication/auth_service.dart';

class KitchenProfileScreen extends StatelessWidget {
  const KitchenProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.of(context).size.width < 650;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 14.0 : 24.0,
        vertical: isPhone ? 12.0 : 20.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chef Profile',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: isPhone ? 22 : 32),
          ),
          const SizedBox(height: 4),
          Text(
            'Kitchen account',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: isPhone ? 13 : 14),
          ),
          SizedBox(height: isPhone ? 24 : 48),
          
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 60,
                    backgroundColor: AppTheme.primaryColor,
                    child: Icon(Icons.person, size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Head Chef',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'chef@caferio.com',
                    style: TextStyle(fontSize: 16, color: AppTheme.textLight),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => AuthService.instance.signOut(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
