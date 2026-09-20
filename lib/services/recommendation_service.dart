import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_item.dart';
import '../models/recommendation.dart';
import '../models/customer_behaviour.dart';

/// Abstract Recommendation Engine interface.
/// Allows plug-and-play swapping between Rule-Based and future ML models (e.g., Random Forest / Edge Functions).
abstract class RecommendationEngine {
  Future<List<RecommendationItem>> getRecommendations({
    String? customerId,
    List<String> cartItemIds = const [],
    required List<MenuItem> allMenuItems,
    int limit = 6,
  });

  Future<CustomerBehaviour> getCustomerBehaviour(String customerId);

  Future<void> recordOrderPurchases({
    required String orderId,
    String? customerId,
    required List<CartItem> items,
    required double totalAmount,
  });
}

/// Supabase-backed Recommendation Service with Rule-Based scoring and local fallback engine.
class SupabaseRecommendationService implements RecommendationEngine {
  final SupabaseClient _supabase;

  // In-memory cache for fast UI rendering
  List<RecommendationItem>? _cachedRecommendations;
  String? _lastCachedCustomerId;
  CustomerBehaviour? _cachedBehaviour;

  SupabaseRecommendationService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  @override
  Future<List<RecommendationItem>> getRecommendations({
    String? customerId,
    List<String> cartItemIds = const [],
    required List<MenuItem> allMenuItems,
    int limit = 6,
  }) async {
    // 1. If we have a cached result for this customer and no active cart filters, return cached
    if (cartItemIds.isEmpty &&
        _cachedRecommendations != null &&
        _lastCachedCustomerId == customerId &&
        _cachedRecommendations!.isNotEmpty) {
      return _cachedRecommendations!;
    }

    List<RecommendationItem> results = [];

    try {
      if (customerId != null && customerId.isNotEmpty) {
        // Try calling Supabase RPC
        final response = await _supabase.rpc(
          'get_personalized_recommendations',
          params: {
            'p_customer_id': customerId,
            'p_cart_item_ids': cartItemIds,
            'p_limit': limit,
          },
        );

        if (response != null && response is List && response.isNotEmpty) {
          final menuMap = {for (var item in allMenuItems) item.id: item};
          for (final row in response) {
            final itemId = row['item_id']?.toString() ?? '';
            final menuItem = menuMap[itemId];
            if (menuItem != null && !menuItem.isOutOfStock) {
              results.add(RecommendationItem.fromRpcJson(row, menuItem));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Supabase recommendation RPC error (using intelligent local fallback): $e');
    }

    // 2. Fallback / Cold Start rule-based computation if Supabase RPC returned insufficient results
    if (results.length < limit) {
      final fallbackResults = _generateLocalRecommendations(
        customerId: customerId,
        cartItemIds: cartItemIds,
        allMenuItems: allMenuItems,
        existingIds: results.map((r) => r.menuItem.id).toSet(),
        needed: limit - results.length,
      );
      results.addAll(fallbackResults);
    }

    // Cache if general recommendations (no specific cart filter)
    if (cartItemIds.isEmpty) {
      _cachedRecommendations = results;
      _lastCachedCustomerId = customerId;
    }

    return results;
  }

  @override
  Future<CustomerBehaviour> getCustomerBehaviour(String customerId) async {
    if (_cachedBehaviour != null && _cachedBehaviour!.customerId == customerId) {
      return _cachedBehaviour!;
    }

    try {
      final response = await _supabase.rpc(
        'get_customer_behaviour_insights',
        params: {'p_customer_id': customerId},
      );

      if (response != null && response is Map<String, dynamic>) {
        final behaviour = CustomerBehaviour.fromJson(response);
        _cachedBehaviour = behaviour;
        return behaviour;
      }
    } catch (e) {
      debugPrint('Supabase customer behaviour RPC error: $e');
    }

    return CustomerBehaviour(hasHistory: false, customerId: customerId);
  }

  @override
  Future<void> recordOrderPurchases({
    required String orderId,
    String? customerId,
    required List<CartItem> items,
    required double totalAmount,
  }) async {
    // Invalidate local caches to trigger refresh on next request
    _cachedRecommendations = null;
    _cachedBehaviour = null;

    final itemsPayload = items.map((cartItem) {
      return {
        'item_id': cartItem.menuItem.id,
        'item_name': cartItem.menuItem.name,
        'category': cartItem.menuItem.category,
        'quantity': cartItem.quantity,
        'price': cartItem.menuItem.price,
      };
    }).toList();

    try {
      await _supabase.rpc(
        'record_order_purchases',
        params: {
          'p_order_id': orderId.isNotEmpty ? orderId : null,
          'p_customer_id': customerId,
          'p_items': itemsPayload,
          'p_order_total': totalAmount,
        },
      );
    } catch (e) {
      debugPrint('Error calling record_order_purchases RPC (trying direct insert fallback): $e');
      // Direct insert fallback
      try {
        for (final cartItem in items) {
          await _supabase.from('customer_purchases').insert({
            'customer_id': customerId,
            if (orderId.isNotEmpty) 'order_id': orderId,
            'item_id': cartItem.menuItem.id,
            'item_name': cartItem.menuItem.name,
            'category': cartItem.menuItem.category,
            'quantity': cartItem.quantity,
            'price': cartItem.menuItem.price,
            'order_date': DateTime.now().toIso8601String(),
          });
        }
      } catch (insertError) {
        debugPrint('Direct insert fallback failed: $insertError');
      }
    }
  }

  /// High-quality local rule-based fallback when offline or cold start.
  List<RecommendationItem> _generateLocalRecommendations({
    String? customerId,
    List<String> cartItemIds = const [],
    required List<MenuItem> allMenuItems,
    required Set<String> existingIds,
    required int needed,
  }) {
    final List<RecommendationItem> fallbackList = [];
    final availableItems = allMenuItems.where((item) =>
        !item.isOutOfStock &&
        !cartItemIds.contains(item.id) &&
        !existingIds.contains(item.id)
    ).toList();

    if (availableItems.isEmpty) return fallbackList;

    // A. Cart Cross-Sell Pairing (e.g. Beverages or Starters when Curry/Biriyani/Burger is in cart)
    if (cartItemIds.isNotEmpty) {
      final complimentaryItems = availableItems.where((item) =>
          item.category == 'Beverages' || item.category == 'Desserts' || item.category == 'Starters'
      ).toList();

      for (var item in complimentaryItems) {
        if (fallbackList.length >= needed) break;
        fallbackList.add(
          RecommendationItem(
            menuItem: item,
            score: 4.5,
            reasonTag: '🥤 Perfect Pairing',
          ),
        );
        existingIds.add(item.id);
      }
    }

    // B. Specials & Top Picks
    final topItems = availableItems.where((item) =>
        !existingIds.contains(item.id) && (item.isSpecial || item.isTopPick)
    ).toList();

    for (var item in topItems) {
      if (fallbackList.length >= needed) break;
      fallbackList.add(
        RecommendationItem(
          menuItem: item,
          score: 4.0,
          reasonTag: item.isSpecial ? "✨ Chef's Special" : '🏆 Top Pick',
        ),
      );
      existingIds.add(item.id);
    }

    // C. Popular Fillers
    final remaining = availableItems.where((item) => !existingIds.contains(item.id)).toList()
      ..shuffle(Random(42));

    for (var item in remaining) {
      if (fallbackList.length >= needed) break;
      fallbackList.add(
        RecommendationItem(
          menuItem: item,
          score: 3.5,
          reasonTag: '🔥 Trending Now',
        ),
      );
      existingIds.add(item.id);
    }

    return fallbackList;
  }
}
