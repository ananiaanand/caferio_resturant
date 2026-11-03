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
    defaultValue: 'https://etgnpwntblbobdlkvflz.supabase.co',
  );

  const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV0Z25wd250Ymxib2JkbGt2Zmx6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkzMjAwMTUsImV4cCI6MjEwNDg5NjAxNX0.0gf5Ao_dRoP8lmDCQTw94tEP8diqlDrlGLCj_dUtpfc',
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
