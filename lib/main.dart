import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/kitchen_main_screen.dart';
import 'screens/manager_main_screen.dart';
import 'providers/cart_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/kitchen_provider.dart';
import 'providers/ingredient_provider.dart';
import 'providers/auth_provider.dart';
import 'models/user_model.dart';
import 'services/database_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => KitchenProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => IngredientProvider()),
      ],
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
      home: const _AppInitializer(),
    );
  }
}

/// Stateful widget that initialises services, restores session, and wires
/// providers before routing the user to the correct screen.
class _AppInitializer extends StatefulWidget {
  const _AppInitializer();

  @override
  State<_AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<_AppInitializer> {
  late final Future<Widget> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _init();
  }

  Future<Widget> _init() async {
    // 1. Initialise the SQLite database (creates schema if first run)
    await DatabaseService().init();

    if (!mounted) return const LoginScreen();

    // 2. Load persisted kitchen orders
    await context.read<KitchenProvider>().loadFromStorage();

    if (!mounted) return const LoginScreen();

    // 3. Load ingredient state and run initial predictions
    await context.read<IngredientProvider>().loadFromStorage();

    if (!mounted) return const LoginScreen();

    // 4. Wire CartProvider → KitchenProvider (with IngredientProvider)
    final cart       = context.read<CartProvider>();
    final kitchen    = context.read<KitchenProvider>();
    final ingredients = context.read<IngredientProvider>();

    cart.onOrderPlaced = ({
      required String id,
      required List<CartItem> items,
      required double total,
      required String customerUserId,
      String tableNumber = 'Table 1',
    }) {
      return kitchen.addOrder(
        id: id,
        items: items,
        total: total,
        customerUserId: customerUserId,
        tableNumber: tableNumber,
        ingredientProvider: ingredients,
      );
    };

    // 5. Attempt session restore — auto-login if valid session exists
    final authProvider = context.read<AuthProvider>();
    final restoredUser = await authProvider.restoreSession();

    if (!mounted) return const LoginScreen();

    if (restoredUser != null) {
      // Sync profile
      context.read<ProfileProvider>().setUser(restoredUser);

      // Load orders if customer
      if (restoredUser.isCustomer) {
        await cart.loadOrdersForUser(restoredUser.email, userId: restoredUser.id);
      }

      return _screenForRole(restoredUser);
    }

    return const LoginScreen();
  }

  Widget _screenForRole(UserModel user) {
    switch (user.role) {
      case UserRole.manager:      return const ManagerMainScreen();
      case UserRole.kitchenStaff: return const KitchenMainScreen();
      case UserRole.customer:     return const MainScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Startup error — please restart')),
          );
        }
        return snapshot.data!;
      },
    );
  }
}
