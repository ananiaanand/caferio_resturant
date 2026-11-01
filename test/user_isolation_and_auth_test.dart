import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:caferio/Authentication/auth_service.dart';
import 'package:caferio/providers/app_provider.dart';

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

  group('User Isolation, Authentication & Deletion Tests', () {
    late AppProvider provider;

    setUp(() async {
      await AuthService.instance.signOut();
      provider = AppProvider();
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('User A signs up, adds items, favourites dishes, and places order', () async {
      // 1. Sign up as user_a
      final res = await AuthService.instance.signUp(
        username: 'user_a',
        password: 'password_a_123',
      );
      expect(res.user != null, true);
      expect(AuthService.instance.currentUsername, 'user_a');

      // Allow provider auth change listener to process
      await Future.delayed(const Duration(milliseconds: 100));
      expect(provider.activeUserKey, 'user_a');
      expect(provider.cart.isEmpty, true);
      expect(provider.orders.isEmpty, true);

      // 2. Add an item to cart
      final firstItem = provider.menuItems.first;
      provider.addToCart(firstItem);
      expect(provider.cart.length, 1);
      expect(provider.cart.first.menuItem.id, firstItem.id);

      // 3. Favourite a dish
      provider.toggleFavourite(firstItem.id);
      expect(provider.favouriteItems.any((i) => i.id == firstItem.id), true);

      // 4. Place an order
      final orderPlaced = await provider.placeOrder();
      expect(orderPlaced, true);
      expect(provider.cart.isEmpty, true);
      expect(provider.orders.length, 1);
      expect(provider.orders.first.items.first.menuItem.id, firstItem.id);

      // 5. User A signs out
      await AuthService.instance.signOut();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(AuthService.instance.currentUsername, null);
      expect(provider.activeUserKey, 'guest');
    });

    test('User B signs up and CANNOT see User A\'s cart, favourites, or orders', () async {
      // 1. Sign up as user_b
      final resB = await AuthService.instance.signUp(
        username: 'user_b',
        password: 'password_b_456',
      );
      expect(resB.user != null, true);
      expect(AuthService.instance.currentUsername, 'user_b');

      await Future.delayed(const Duration(milliseconds: 100));
      expect(provider.activeUserKey, 'user_b');

      // 2. Verify User B has an EMPTY cart
      expect(provider.cart.isEmpty, true);

      // 3. Verify User B has ZERO favourites (User A's favourite is not visible)
      expect(provider.favouriteItems.isEmpty, true);

      // 4. Verify User B has ZERO orders in orders (User A's order is not visible)
      expect(provider.orders.isEmpty, true);

      // 5. User B adds a DIFFERENT item and favourites it
      final secondItem = provider.menuItems[1];
      provider.addToCart(secondItem);
      provider.toggleFavourite(secondItem.id);

      expect(provider.cart.length, 1);
      expect(provider.cart.first.menuItem.id, secondItem.id);
      expect(provider.favouriteItems.length, 1);
      expect(provider.favouriteItems.first.id, secondItem.id);

      // 6. User B places their own order
      final orderB = await provider.placeOrder();
      expect(orderB, true);
      expect(provider.orders.length, 1);
      expect(provider.orders.first.items.first.menuItem.id, secondItem.id);

      // User B signs out
      await AuthService.instance.signOut();
    });

    test('User A logs back in with the same username & password, sees ONLY User A data', () async {
      // 1. User A logs in
      final resA = await AuthService.instance.signIn(
        username: 'user_a',
        password: 'password_a_123',
      );
      expect(resA.user != null, true);
      expect(AuthService.instance.currentUsername, 'user_a');

      await Future.delayed(const Duration(milliseconds: 100));

      // 2. User A's favourites are restored
      final firstItem = provider.menuItems.first;
      expect(provider.favouriteItems.any((i) => i.id == firstItem.id), true);

      // 3. User B's favourite (secondItem) is NOT in User A's favourites
      final secondItem = provider.menuItems[1];
      expect(provider.favouriteItems.any((i) => i.id == secondItem.id), false);

      // 4. User A's order is visible, but User B's order is NOT visible
      expect(provider.orders.length, 1);
      expect(provider.orders.first.items.first.menuItem.id, firstItem.id);
    });

    test('Wrong password gives "Invalid username or password"', () async {
      expect(
        () => AuthService.instance.signIn(
          username: 'user_a',
          password: 'WRONG_PASSWORD',
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Invalid username or password',
        )),
      );
    });

    test('Deleting User A account deletes credentials, data, and prevents re-login', () async {
      // 1. Log in as user_a
      await AuthService.instance.signIn(
        username: 'user_a',
        password: 'password_a_123',
      );

      // 2. Delete account
      await AuthService.instance.deleteAccount();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(AuthService.instance.isAuthenticated, false);

      // 3. Attempting to log back in with deleted credentials FAILS
      expect(
        () => AuthService.instance.signIn(
          username: 'user_a',
          password: 'password_a_123',
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Invalid username or password',
        )),
      );

      // 4. User B can still log in fine (completely isolated and unaffected)
      final resB = await AuthService.instance.signIn(
        username: 'user_b',
        password: 'password_b_456',
      );
      expect(resB.user != null, true);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(provider.orders.length, 1);
      expect(provider.orders.first.items.first.menuItem.id, provider.menuItems[1].id);

      await AuthService.instance.signOut();
    });

    test('A newly created account with the old username starts 100% fresh', () async {
      // Sign up again as user_a
      final freshA = await AuthService.instance.signUp(
        username: 'user_a',
        password: 'brand_new_password',
      );
      expect(freshA.user != null, true);
      await Future.delayed(const Duration(milliseconds: 100));

      // Everything starts completely fresh: empty cart, 0 favourites, 0 orders
      expect(provider.cart.isEmpty, true);
      expect(provider.favouriteItems.isEmpty, true);
      expect(provider.orders.isEmpty, true);
    });
  });
}

