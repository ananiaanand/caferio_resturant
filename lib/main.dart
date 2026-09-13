import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'utils/theme.dart';
import 'screens/auth_gate.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://etgnpwntblbobdlkvflz.supabase.co', // TODO: REPLACE WITH YOUR SUPABASE URL
    anonKey: 'sb_publishable_Dqq56CpA3ZZDRcvcsFo_SQ_s_0Mm3vP', // Provided anon key
  );

  runApp(const CaferioApp());
}

class CaferioApp extends StatelessWidget {
  const CaferioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: MaterialApp(
        title: 'Caferio',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const AuthGate(),
      ),
    );
  }
}
