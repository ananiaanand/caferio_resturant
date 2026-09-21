import 'package:flutter/material.dart';

import '../../models/app_role.dart';
import '../../services/auth_service.dart';

/// Shared shell: app bar, sign-out, who-am-I header.
class DashboardScaffold extends StatelessWidget {
  const DashboardScaffold({
    super.key,
    required this.title,
    required this.role,
    required this.child,
  });

  final String title;
  final AppRole role;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: auth.signOut,
          ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(auth.currentUser?.email ?? ''),
            subtitle: Text('Role: ${role.name}'),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
