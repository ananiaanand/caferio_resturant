import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:caferio/providers/app_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://rpuzznremhzsrwgzpggk.supabase.co',
      // ignore: deprecated_member_use
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJwdXp6bnJlbWh6c3J3Z3pwZ2drIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY5MjA1ODYsImV4cCI6MjA3MjQ5NjU4Nn0.sSi9oYbhkyn3uXnd8twbUa-wH99ySvSkCPCS45J_Be8',
    );
  });

  group('Food Search Tests', () {
    late AppProvider provider;

    setUp(() {
      provider = AppProvider();
    });

    test('Initial state has empty search query and category All', () {
      expect(provider.searchQuery, '');
      expect(provider.selectedCategory, 'All');
      expect(provider.currentCategoryItems.isNotEmpty, true);
    });

    test('Searching by dish name (e.g. Burger)', () {
      provider.setSearchQuery('Burger');
      final items = provider.currentCategoryItems;
      expect(items.isNotEmpty, true);
      for (final item in items) {
        final matches = item.name.toLowerCase().contains('burger') ||
            item.description.toLowerCase().contains('burger') ||
            item.category.toLowerCase().contains('burger') ||
            item.ingredients.any((ing) => ing.toLowerCase().contains('burger'));
        expect(matches, true);
      }
    });

    test('Search is case-insensitive and trims whitespace', () {
      provider.setSearchQuery('  bUrGeR   ');
      final items = provider.currentCategoryItems;
      expect(items.isNotEmpty, true);
    });

    test('Searching by category or ingredient (e.g. paneer)', () {
      provider.setSearchQuery('paneer');
      final items = provider.currentCategoryItems;
      expect(items.isNotEmpty, true);
      expect(items.any((i) => i.name.toLowerCase().contains('paneer')), true);
    });

    test('Auto-resets category to All when user initiates search while in another category', () {
      provider.selectCategory('Beverages');
      expect(provider.selectedCategory, 'Beverages');

      // Now user starts typing 'burger' in search bar
      provider.setSearchQuery('burger');
      expect(provider.selectedCategory, 'All');
      expect(provider.currentCategoryItems.isNotEmpty, true);
    });

    test('Clearing search restores all items', () {
      final totalCountBefore = provider.currentCategoryItems.length;
      provider.setSearchQuery('biryani');
      expect(provider.currentCategoryItems.length < totalCountBefore, true);

      provider.clearSearch();
      expect(provider.searchQuery, '');
      expect(provider.currentCategoryItems.length, totalCountBefore);
    });

    test('Unmatched query returns empty list', () {
      provider.setSearchQuery('nonexistentfooditem12345xyz');
      expect(provider.currentCategoryItems.isEmpty, true);
    });
  });
}
