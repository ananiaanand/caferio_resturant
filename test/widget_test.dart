import 'package:flutter_test/flutter_test.dart';
import 'package:caferio/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const CaferioApp());
    expect(find.text('Caferio'), findsWidgets);
  });
}
