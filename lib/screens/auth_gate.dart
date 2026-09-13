import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:caferio/screens/login_screen.dart';
import 'package:caferio/screens/main_layout.dart';
import 'package:caferio/screens/kitchen/kitchen_layout.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          // Fetch user role
          return FutureBuilder(
            future: Supabase.instance.client
                .from('profiles')
                .select('role')
                .eq('id', session.user.id)
                .single(),
            builder: (context, AsyncSnapshot<Map<String, dynamic>> roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              
              if (roleSnapshot.hasError) {
                 // Fallback to customer if profile fetch fails
                 debugPrint('Error fetching role: ${roleSnapshot.error}');
                 return const MainLayout();
              }

              final role = roleSnapshot.data?['role'] as String?;
              if (role == 'kitchen') {
                return const KitchenLayout();
              } else {
                return const MainLayout();
              }
            },
          );
        }

        // User is not authenticated
        return const LoginScreen();
      },
    );
  }
}
