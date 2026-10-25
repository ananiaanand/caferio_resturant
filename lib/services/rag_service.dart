// lib/services/rag_service.dart
//
// RAG chat service — supports persistent chat memory across sessions,
// Supabase Edge Function (`rag-chat`), direct Gemini generation with multi-model
// automatic fallback, and role-based context scoping.
//
// Security & Role boundaries:
//   • customer: Menu items only (name, description, price, availability, dietary tags) + current cart.
//               Cannot access other orders, revenue, customer data, or kitchen notes.
//   • chef:     Kitchen context (pending/preparing orders, tickets, prep items, shortage).
//               Cannot access restaurant revenue, financial metrics, or user credentials.
//   • admin:    Full restaurant context (sales, orders, stock shortage, menu analytics).
//
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents a single chat turn (user or model).
class ChatMessage {
  final bool isUser;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.isUser,
    required this.text,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Serialise to the format expected by the history parameter.
  Map<String, String> toHistory() =>
      {'role': isUser ? 'user' : 'model', 'text': text};

  Map<String, dynamic> toJson() => {
        'isUser': isUser,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        isUser: json['isUser'] == true,
        text: json['text']?.toString() ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'].toString())
            : null,
      );
}

/// The role with which the current session is chatting.
enum ChatRole { customer, chef, admin }

class RagService {
  RagService._();
  static final instance = RagService._();

  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Primary model with automatic fallbacks in case of 503 (high demand) or 429 (rate limits)
  static const List<String> _fallbackModels = [
    'gemini-3.6-flash',
    'gemini-3.1-flash-lite-preview',
    'gemini-3-flash-preview',
  ];

  final _client = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Persistent Chat Memory (Per Role)
  // ---------------------------------------------------------------------------
  final Map<ChatRole, List<ChatMessage>> _roleHistories = {
    ChatRole.customer: [],
    ChatRole.chef: [],
    ChatRole.admin: [],
  };
  bool _loadedFromPrefs = false;

  /// Loads stored messages from local device storage so chat history persists
  /// when closing and re-opening the sheet.
  Future<void> initStorage() async {
    if (_loadedFromPrefs) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final role in ChatRole.values) {
        final key = 'caferio_chat_history_${role.name}';
        final raw = prefs.getString(key);
        if (raw != null) {
          final list = jsonDecode(raw) as List;
          _roleHistories[role] = list
              .map((item) =>
                  ChatMessage.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
      _loadedFromPrefs = true;
    } catch (e) {
      debugPrint('Error loading chat history from storage: $e');
    }
  }

  /// Returns existing chat memory for the given role.
  List<ChatMessage> getHistory(ChatRole role) {
    return List<ChatMessage>.from(_roleHistories[role] ?? []);
  }

  /// Records a new message to the persistent role memory.
  Future<void> addMessage(ChatRole role, ChatMessage message) async {
    _roleHistories[role] ??= [];
    _roleHistories[role]!.add(message);
    await _saveToStorage(role);
  }

  /// Clears stored chat memory for the specified role.
  Future<void> clearHistory(ChatRole role) async {
    _roleHistories[role]?.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('caferio_chat_history_${role.name}');
    } catch (e) {
      debugPrint('Error clearing chat history: $e');
    }
  }

  Future<void> _saveToStorage(ChatRole role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'caferio_chat_history_${role.name}';
      final list = _roleHistories[role] ?? [];
      // Keep up to 60 messages to keep storage fast & snappy
      final toSave = list.length > 60 ? list.sublist(list.length - 60) : list;
      final jsonStr = jsonEncode(toSave.map((m) => m.toJson()).toList());
      await prefs.setString(key, jsonStr);
    } catch (e) {
      debugPrint('Error saving chat history to storage: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // RAG Query
  // ---------------------------------------------------------------------------

  /// Sends [question] + recent [history] to the assistant.
  ///
  /// Tries the deployed Supabase Edge Function first; if not reachable,
  /// smoothly falls back to direct Gemini generation with strict role isolation and
  /// multi-model resilience.
  Future<String> ask(
    String question,
    List<ChatMessage> history, {
    ChatRole role = ChatRole.customer,
    String? dashboardContext,
    String? extraContext,
  }) async {
    final liveContext = dashboardContext ?? extraContext;

    // 1. Try Supabase Edge Function first
    try {
      final res = await _client.functions.invoke(
        'rag-chat',
        body: {
          'question': question,
          'history': history.map((m) => m.toHistory()).toList(),
          'extra_context': ?liveContext,
        },
      ).timeout(const Duration(seconds: 4));

      if (res.status == 200 && res.data != null) {
        final data = res.data as Map<dynamic, dynamic>;
        final ans = data['answer'] as String?;
        if (ans != null && ans.trim().isNotEmpty) {
          return ans.trim();
        }
      }
    } catch (e) {
      debugPrint('Edge function unavailable, using direct RAG with live dashboard data: $e');
    }

    // 2. Direct RAG with role-scoped context & model fallback
    return await _askGeminiDirect(question, history, role, liveContext);
  }

  Future<String> _askGeminiDirect(
    String question,
    List<ChatMessage> history,
    ChatRole role,
    String? liveDashboardContext,
  ) async {
    try {
      final contextText =
          (liveDashboardContext != null && liveDashboardContext.trim().isNotEmpty)
              ? liveDashboardContext
              : await _buildRoleContext(role);

      final systemPrompt = _getSystemPrompt(role, contextText);

      final contents = <Map<String, dynamic>>[];

      // Recent history turns (up to last 6)
      final recentHistory =
          history.length > 6 ? history.sublist(history.length - 6) : history;
      for (final msg in recentHistory) {
        contents.add({
          'role': msg.isUser ? 'user' : 'model',
          'parts': [
            {'text': msg.text}
          ],
        });
      }

      // Current question
      contents.add({
        'role': 'user',
        'parts': [
          {'text': question}
        ],
      });

      // Try primary model and automatically cycle through fallbacks if 503/429
      for (final model in _fallbackModels) {
        try {
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$geminiApiKey',
          );

          final res = await http
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'systemInstruction': {
                    'parts': [
                      {'text': systemPrompt}
                    ]
                  },
                  'contents': contents,
                  'generationConfig': {
                    'temperature': 0.3,
                    'maxOutputTokens': 800,
                    'thinkingConfig': {
                      'thinkingBudget': 0, // fast instant reply
                    },
                  },
                }),
              )
              .timeout(const Duration(seconds: 10));

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            final candidate = (data['candidates'] as List?)?.firstOrNull;
            final parts = candidate?['content']?['parts'] as List?;
            final answer = parts?.map((p) => p['text']).join('').trim();

            if (answer != null && answer.isNotEmpty) {
              return answer;
            }
          } else {
            debugPrint('Model $model returned ${res.statusCode}: ${res.body}, trying next model...');
          }
        } catch (e) {
          debugPrint('Error with model $model: $e, trying next model...');
        }
      }

      return "I'm having a brief connection delay with the AI service. Please tap again in a few seconds!";
    } catch (e) {
      debugPrint('Direct Gemini error: $e');
      return "Sorry, I'm having trouble connecting right now. Please try again shortly.";
    }
  }

  String _getSystemPrompt(ChatRole role, String context) {
    switch (role) {
      case ChatRole.customer:
        return '''
You are "Waiters", Caferio restaurant's intelligent and helpful digital waiter.
You have real-time live access to the customer's entire dashboard:
1. Live Track Order status: When the customer asks "Where is my order?", "Track my order", "What is my order status?", or mentions their order, look up the "LIVE TRACK ORDER STATUS" section below and give them their exact order status (e.g. Order Received, Start preparing, Half done, Preparation completed, or Served), order #ID, items, and total amount!
2. Active Shopping Cart: When the customer asks what is in their cart, check the "LIVE CART STATUS" section and list their items and cart total.
3. Restaurant Menu: Recommend dishes, answer questions on ingredients, prices in ₹, dietary options (Veg / Non-veg), and dish availability.

Formatting rules:
- Format lists with clean bullet points like •.
- Bold important details like dish names, order statuses, and amounts (e.g. **Order Received**, **Start preparing**).
- State prices in Indian Rupees (₹).
- Keep answers warm, courteous, appetizing, and concise.

Strict Security Boundaries:
- Base all answers ONLY on the live Caferio Dashboard Data below.
- You can only see the current customer's own active orders and cart. NEVER invent other customers' private data, restaurant backend revenues, or admin credentials.

Live Customer Dashboard Data:
$context
''';

      case ChatRole.chef:
        return '''
You are the Caferio Kitchen Assistant for the chef and kitchen crew.
You have real-time live access to the entire kitchen dashboard:
1. Live Kitchen Tickets: Pending orders, orders in preparation, dish items, and ticket IDs.
2. Inventory Shortage: Items running low or out of stock in the kitchen.
3. Dish Recipes & Ingredients.

Formatting rules:
- Format lists with clean bullet points like •.
- Bold ticket numbers and urgent statuses.
- Keep answers fast, concise, practical, and structured for quick reading in a busy kitchen.

Strict Security Boundaries:
- NEVER reveal restaurant financial revenues, customer credit card or contact details, or administrator credentials.

Live Kitchen Dashboard Data:
$context
''';

      case ChatRole.admin:
        return '''
You are the Caferio Executive Management Assistant for restaurant administrators and managers.
You have real-time live access to the entire admin dashboard:
1. Live Sales Metrics: Today's revenue, completed order counts, total order throughput.
2. Orders Breakdown: All active and past orders with statuses.
3. Inventory & ML Stockout Alerts: Out-of-stock items, critical shortages, warning thresholds.
4. Menu Management & Stock toggles.

Guidelines:
- Provide clear, professional, concise, and structured metrics.
- Point out any out-of-stock items, bottlenecks, or inventory risks.

Live Admin Dashboard Data:
$context
''';
    }
  }

  Future<String> _buildRoleContext(ChatRole role) async {
    final buffer = StringBuffer();

    try {
      if (role == ChatRole.customer) {
        // Fetch only customer-safe menu items
        final items = await _client
            .from('menu_items')
            .select('name, description, price, category, is_available')
            .order('category');

        buffer.writeln('Available Caferio Dishes:');
        for (final item in items) {
          final name = item['name'] ?? 'Unnamed';
          final desc = item['description'] ?? '';
          final price = item['price'] ?? 0;
          final cat = item['category'] ?? 'General';
          final avail = (item['is_available'] == false) ? 'Out of Stock' : 'Available';
          buffer.writeln('• $name ($cat, ₹$price) [$avail]: $desc');
        }
      } else if (role == ChatRole.chef) {
        // Fetch orders currently in progress and shortage items
        final orders = await _client
            .from('orders')
            .select('id, status, created_at, items')
            .inFilter('status', ['received', 'preparing'])
            .order('created_at', ascending: true)
            .limit(20);

        buffer.writeln('Active Kitchen Orders:');
        for (final o in orders) {
          final id = o['id']?.toString().substring(0, 8) ?? '';
          final status = o['status'];
          final items = o['items'] ?? [];
          buffer.writeln('• Order #$id [Status: $status]: $items');
        }

        final shortage = await _client
            .from('inventory')
            .select('name, category, is_out_of_stock')
            .eq('is_out_of_stock', true);

        if (shortage.isNotEmpty) {
          buffer.writeln('\nKitchen Shortage / Out of Stock:');
          for (final s in shortage) {
            buffer.writeln('• ${s['name']} (${s['category']})');
          }
        }
      } else {
        // Admin: summary of orders, sales, and shortage
        final orders = await _client
            .from('orders')
            .select('id, status, total_amount, created_at')
            .order('created_at', ascending: false)
            .limit(30);

        double totalRevenue = 0;
        int receivedCount = 0;
        int completedCount = 0;

        for (final o in orders) {
          final total = (o['total_amount'] as num?)?.toDouble() ?? 0;
          totalRevenue += total;
          final s = o['status']?.toString();
          if (s == 'received' || s == 'preparing') receivedCount++;
          if (s == 'completed' || s == 'served') completedCount++;
        }

        buffer.writeln('Recent Orders Overview:');
        buffer.writeln('• Sampled Orders: ${orders.length}');
        buffer.writeln('• In-progress Orders: $receivedCount');
        buffer.writeln('• Completed Orders: $completedCount');
        buffer.writeln('• Sampled Revenue: ₹${totalRevenue.toStringAsFixed(2)}');

        final shortage = await _client
            .from('inventory')
            .select('name, category, is_out_of_stock')
            .eq('is_out_of_stock', true);

        buffer.writeln('\nItems Currently Out of Stock: ${shortage.length}');
        for (final s in shortage) {
          buffer.writeln('• ${s['name']} (${s['category']})');
        }
      }
    } catch (e) {
      debugPrint('Error fetching context from database: $e');
      buffer.writeln('(Live database fetch timed out; use default restaurant knowledge)');
    }

    return buffer.toString();
  }
}
