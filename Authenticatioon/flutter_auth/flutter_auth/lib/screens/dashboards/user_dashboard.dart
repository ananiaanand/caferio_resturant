import 'package:flutter/material.dart';

import '../../models/app_role.dart';
import 'dashboard_scaffold.dart';

class UserDashboard extends StatelessWidget {
  const UserDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardScaffold(
      title: 'My Dashboard',
      role: AppRole.user,
      child: Center(
        child: Text('Customer features go here (menu, orders, profile...).'),
      ),
    );
  }
}
