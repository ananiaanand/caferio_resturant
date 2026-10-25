import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'Authentication/auth_gate.dart';
import 'Authentication/auth_service.dart';
import 'providers/app_provider.dart';
import 'utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Environment variables passed via --dart-define
  // Example: flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rpuzznremhzsrwgzpggk.supabase.co',
  );

  const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJwdXp6bnJlbWh6c3J3Z3pwZ2drIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY5MjA1ODYsImV4cCI6MjA3MjQ5NjU4Nn0.sSi9oYbhkyn3uXnd8twbUa-wH99ySvSkCPCS45J_Be8',
  );

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization notice: $e');
  }

  await AuthService.instance.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const CaferioApp(),
    ),
  );
}

class CaferioApp extends StatelessWidget {
  const CaferioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caferio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}
