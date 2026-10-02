import 'package:flutter/material.dart';
import 'package:caferio/utils/theme.dart';
import 'package:caferio/services/auth_service.dart';

class KitchenProfileScreen extends StatelessWidget {
  const KitchenProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chef Profile',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your kitchen account',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 48),
          
          Center(
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
                Text(
                  AuthService().currentUser?.email ?? 'chef@caferio.com',
                  style: const TextStyle(fontSize: 16, color: AppTheme.textLight),
                ),
                const SizedBox(height: 48),
                
                SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: () => AuthService().signOut(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
