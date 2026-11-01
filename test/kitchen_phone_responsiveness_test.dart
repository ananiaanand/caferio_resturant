import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:caferio/providers/app_provider.dart';
import 'package:caferio/models/order.dart';
import 'package:caferio/screens/kitchen/kitchen_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://rpuzznremhzsrwgzpggk.supabase.co',
        // ignore: deprecated_member_use
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJwdXp6bnJlbWh6c3J3Z3pwZ2drIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY5MjA1ODYsImV4cCI6MjA3MjQ5NjU4Nn0.sSi9oYbhkyn3uXnd8twbUa-wH99ySvSkCPCS45J_Be8',
      );
    } catch (_) {}
  });

  Widget buildKitchenApp(AppProvider provider, {Size size = const Size(390, 844)}) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: KitchenLayout(),
        ),
      ),
    );
  }

  testWidgets('Kitchen Dashboard on phone shows bottom navigation bar and responsive pending orders', (tester) async {
    await tester.runAsync(() async {
      final provider = AppProvider();

      final testItem = provider.menuItems.first;
      provider.addToCart(testItem);
      await provider.placeOrder();

      expect(provider.allOrders.isNotEmpty, true);
      final order = provider.allOrders.first;
      final shortId = order.id.length > 4 ? order.id.substring(order.id.length - 4) : order.id;

      // Set phone viewport (390 x 844, typical iPhone / Android)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildKitchenApp(provider, size: const Size(390, 844)));
      await tester.pump();

      // Verify phone bottom navigation bar is present
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Shortage'), findsWidgets);
      expect(find.text('Completed'), findsWidgets);

      // Verify Pending Orders screen elements
      expect(find.text('Pending Orders'), findsOneWidget); // AppBar title
      expect(find.text('Active Tickets'), findsOneWidget); // Body responsive title
      expect(find.text('1 Active'), findsOneWidget);
      expect(find.text('All (1)'), findsOneWidget);
      expect(find.text('Received (1)'), findsOneWidget);

      // Verify Order Card displays short ID, dish name, and next action
      expect(find.text('Order #$shortId'), findsOneWidget);
      expect(find.text(testItem.name), findsOneWidget);
      expect(find.text('Start Preparing'), findsOneWidget);

      // Tap next action
      await tester.tap(find.text('Start Preparing'));
      await tester.pump();

      // Status advances to Preparing
      expect(provider.allOrders.first.status, OrderStatus.preparing);
      expect(find.text('Mark Half Done'), findsOneWidget);
    });
  });
}
