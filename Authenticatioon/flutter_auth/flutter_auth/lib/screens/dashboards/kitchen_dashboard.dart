import 'package:flutter/material.dart';

import '../../models/app_role.dart';
import 'dashboard_scaffold.dart';

class KitchenDashboard extends StatelessWidget {
  const KitchenDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardScaffold(
      title: 'Kitchen Dashboard',
      role: AppRole.kitchen,
      child: Center(
        child: Text('Kitchen tools go here (incoming orders, prep queue...).'),
      ),
    );
  }
}
