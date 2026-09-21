import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_role.dart';
import 'dashboard_scaffold.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<List<Map<String, dynamic>>> _users = _load();

  // RLS lets only role=admin read every row in `profiles`.
  Future<List<Map<String, dynamic>>> _load() => Supabase.instance.client
      .from('profiles')
      .select('email, full_name, role, created_at')
      .order('created_at');

  Future<void> _refresh() async {
    setState(() => _users = _load());
    await _users;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Admin Dashboard',
      role: AppRole.admin,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _users,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load users: ${snap.error}'));
          }
          final users = snap.data ?? [];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: users.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Users (${users.length})',
                        style: Theme.of(context).textTheme.titleMedium),
                  );
                }
                final u = users[i - 1];
                return ListTile(
                  title: Text(u['email'] ?? ''),
                  subtitle: Text(u['full_name'] ?? '-'),
                  trailing: Chip(label: Text(u['role'] ?? 'user')),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
