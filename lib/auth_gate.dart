import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/app_role.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_layout.dart';
import 'screens/kitchen/kitchen_layout.dart';
import 'screens/main_layout.dart';
import 'services/auth_service.dart';

/// Listens to Supabase auth state changes.
///
/// No session → [LoginScreen].
/// Session → role is read from the JWT `app_metadata.role` (server-side only,
/// unforgeable), then routes to the matching dashboard layout.
///
/// Sign-out in any child widget only needs to call [AuthService.signOut].
/// Supabase emits a null-session event and this gate swaps back to [LoginScreen]
/// automatically — no manual Navigator.push needed.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return StreamBuilder<AuthState>(
      stream: auth.authChanges,
      builder: (context, snapshot) {
        // While waiting for the first event, show a loading screen.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final session = snapshot.data?.session ?? auth.session;

        if (session == null) {
          return const LoginScreen();
        }

        // Role is read from the JWT claim — cannot be forged by the client.
        switch (AppRole.fromUser(session.user)) {
          case AppRole.admin:
            return const AdminLayout();
          case AppRole.kitchen:
            return const KitchenLayout();
          case AppRole.user:
            return const MainLayout();
        }
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
