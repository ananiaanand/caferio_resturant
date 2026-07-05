import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'providers/cart_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/profile_provider.dart';
import 'services/database_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ],
      child: const CaferioApp(),
    ),
  );
}

class CaferioApp extends StatelessWidget {
  const CaferioApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caferio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Use a FutureBuilder to init the DB before showing the login screen
      home: FutureBuilder<void>(
        future: DatabaseService().init(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            // Blank scaffold while DB initialises (very fast on web)
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
