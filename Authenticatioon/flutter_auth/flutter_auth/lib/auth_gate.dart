import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/app_role.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboards/admin_dashboard.dart';
import 'screens/dashboards/kitchen_dashboard.dart';
import 'screens/dashboards/user_dashboard.dart';
import 'services/auth_service.dart';

/// Listens to auth state. No session -> login. Session -> dashboard by role.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return StreamBuilder<AuthState>(
      stream: auth.authChanges,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? auth.session;
        if (session == null) return const LoginScreen();

        switch (AppRole.fromUser(session.user)) {
          case AppRole.admin:
            return const AdminDashboard();
          case AppRole.kitchen:
            return const KitchenDashboard();
          case AppRole.user:
            return const UserDashboard();
        }
      },
    );
  }
}
