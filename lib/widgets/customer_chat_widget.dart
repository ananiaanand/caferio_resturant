// lib/widgets/customer_chat_widget.dart
//
// Customer-facing AI chatbot — a polished floating chat button + full-screen
// slide-up panel for customers browsing the menu.
//
// Access: Customer role only. Shows only public menu information.
// Usage: Add a CustomerChatFab() to DashboardScreen / MainLayout.
//
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:caferio/providers/app_provider.dart';
import 'package:caferio/models/order.dart';
import 'package:caferio/utils/theme.dart';
import 'package:caferio/services/rag_service.dart';

// ---------------------------------------------------------------------------
// FAB that opens the chat panel
// ---------------------------------------------------------------------------

class CustomerChatFab extends StatelessWidget {
  const CustomerChatFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'customer_chat_fab',
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 6,
      icon: const Icon(Icons.room_service_rounded),
      label: const Text(
        'Waiters',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      onPressed: () => CustomerChatSheet.show(context),
    );
  }
}

// ---------------------------------------------------------------------------
// The chat sheet
// ---------------------------------------------------------------------------

class CustomerChatSheet extends StatefulWidget {
  const CustomerChatSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CustomerChatSheet(),
    );
  }

  @override
  State<CustomerChatSheet> createState() => _CustomerChatSheetState();
}

class _CustomerChatSheetState extends State<CustomerChatSheet>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loading = false;
  late AnimationController _fabAnimController;

  static const _suggestions = [
    '🍗 What chicken dishes do you have?',
    '🌱 Are there vegetarian options?',
    '📍 Where is my order?',
    '🛒 What is in my cart?',
    '⭐ What are your bestsellers?',
    '💰 What\'s under ₹200?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.addAll(RagService.instance.getHistory(ChatRole.customer));
    RagService.instance.initStorage().then((_) {
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(RagService.instance.getHistory(ChatRole.customer));
        });
        _scrollDown();
      }
    });
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _fabAnimController.dispose();
    super.dispose();
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear chat history?'),
        content: const Text('This will reset your conversation with the assistant.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              RagService.instance.clearHistory(ChatRole.customer);
              setState(() => _messages.clear());
            },
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _buildCustomerDashboardContext(AppProvider provider) {
    final buffer = StringBuffer();

    // 1. LIVE TRACK ORDER STATUS
    buffer.writeln('=== LIVE TRACK ORDER STATUS ===');
    final customerOrders = provider.orders;
    if (customerOrders.isEmpty) {
      buffer.writeln('Customer has placed no orders yet.');
    } else {
      final activeOrders =
          customerOrders.where((o) => o.status != OrderStatus.served).toList();
      if (activeOrders.isNotEmpty) {
        buffer.writeln(
            'Active Orders currently in progress (${activeOrders.length}):');
        for (final order in activeOrders) {
          final id =
              order.id.length > 8 ? order.id.substring(0, 8) : order.id;
          final itemsStr = order.items
              .map((i) =>
                  '${i.quantity}x ${i.menuItem.name} (₹${(i.quantity * i.menuItem.price).toInt()})')
              .join(', ');
          buffer.writeln(
              '• Order #$id: [Status: ${order.status.label}] - Total: ₹${order.totalAmount.toInt()}');
          buffer.writeln('  Items: $itemsStr');
        }
      } else {
        buffer.writeln('No active orders currently pending preparation.');
      }

      final servedOrders =
          customerOrders.where((o) => o.status == OrderStatus.served).take(3);
      if (servedOrders.isNotEmpty) {
        buffer.writeln('\nRecently Served Orders:');
        for (final order in servedOrders) {
          final id =
              order.id.length > 8 ? order.id.substring(0, 8) : order.id;
          final itemsStr =
              order.items.map((i) => '${i.quantity}x ${i.menuItem.name}').join(', ');
          buffer.writeln(
              '• Order #$id: [Status: Served] - Total: ₹${order.totalAmount.toInt()} (Items: $itemsStr)');
        }
      }
    }

    // 2. LIVE CART STATUS
    buffer.writeln('\n=== LIVE CART STATUS ===');
    if (provider.cart.isEmpty) {
      buffer.writeln('Customer Cart is currently empty (0 items).');
    } else {
      final cartItemsStr = provider.cart
          .map((c) =>
              '${c.quantity}x ${c.menuItem.name} (₹${(c.quantity * c.menuItem.price).toInt()})')
          .join(', ');
      final cartTotal = provider.cart.fold<double>(
          0, (sum, c) => sum + (c.quantity * c.menuItem.price));
      buffer.writeln('Items in Cart: $cartItemsStr');
      buffer.writeln('Cart Total: ₹${cartTotal.toInt()}');
    }

    // 3. CAFERIO MENU ITEMS
    buffer.writeln('\n=== CAFERIO RESTAURANT MENU ===');
    for (final item in provider.menuItems) {
      final avail = item.isOutOfStock ? 'Out of Stock' : 'Available';
      buffer.writeln(
          '• ${item.name} (${item.category}, ₹${item.price.toInt()}) [$avail]: ${item.description}');
    }

    return buffer.toString();
  }

  Future<void> _send([String? prefilled]) async {
    final q = (prefilled ?? _controller.text).trim();
    if (q.isEmpty || _loading) return;

    String? dashboardContext;
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      dashboardContext = _buildCustomerDashboardContext(provider);
    } catch (_) {}

    final history = List<ChatMessage>.from(_messages);
    final userMsg = ChatMessage(isUser: true, text: q);
    setState(() {
      _messages.add(userMsg);
      _loading = true;
      _controller.clear();
    });
    await RagService.instance.addMessage(ChatRole.customer, userMsg);
    _scrollDown();

    try {
      final answer = await RagService.instance.ask(
        q,
        history,
        role: ChatRole.customer,
        dashboardContext: dashboardContext,
      );
      final aiMsg = ChatMessage(isUser: false, text: answer);
      await RagService.instance.addMessage(ChatRole.customer, aiMsg);
      if (mounted) {
        setState(() => _messages.add(aiMsg));
      }
    } catch (_) {
      final localAnswer = RagService.instance.generateSmartLocalResponse(
        q,
        ChatRole.customer,
        dashboardContext,
      );
      final aiMsg = ChatMessage(isUser: false, text: localAnswer);
      await RagService.instance.addMessage(ChatRole.customer, aiMsg);
      if (mounted) {
        setState(() => _messages.add(aiMsg));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollDown();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F8FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // ---------- Drag handle ----------
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ---------- Header ----------
          _buildHeader(),

          // ---------- Messages or suggestions ----------
          Expanded(
            child: _messages.isEmpty ? _buildWelcome() : _buildMessageList(),
          ),

          // ---------- Loading indicator ----------
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Row(
                children: [
                  _typingDots(),
                ],
              ),
            ),

          // ---------- Input bar ----------
          _buildInputBar(bottomInset),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, Color(0xFFC01018)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Waiters',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Online · Powered by Gemini AI',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'Clear Chat',
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFF9CA3AF), size: 21),
              onPressed: _clearChat,
            ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting bubble
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('👋 Hello! Welcome to Caferio!',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1A1A2E))),
                SizedBox(height: 8),
                Text(
                  "I'm your personal food guide. Ask me anything about our menu — dishes, ingredients, prices, or what's available today!",
                  style: TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Try asking:',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF6B7280),
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          ..._suggestions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SuggestionChip(label: s, onTap: () => _send(s)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _MessageBubble(message: _messages[i]),
    );
  }

  Widget _typingDots() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.smart_toy_rounded, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          _AnimatedDot(delay: 0),
          const SizedBox(width: 4),
          _AnimatedDot(delay: 150),
          const SizedBox(width: 4),
          _AnimatedDot(delay: 300),
        ],
      ),
    );
  }

  Widget _buildInputBar(double bottomInset) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(28),
              ),
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.send,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Ask about our menu…',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _send(),
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, Color(0xFFC01018)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message bubble
// ---------------------------------------------------------------------------

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, Color(0xFFC01018)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft:
                      isUser ? const Radius.circular(20) : const Radius.circular(4),
                  bottomRight:
                      isUser ? const Radius.circular(4) : const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _FormattedMessageText(
                text: message.text,
                isUser: isUser,
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Suggestion chip
// ---------------------------------------------------------------------------

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF374151),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated typing dot
// ---------------------------------------------------------------------------

class _AnimatedDot extends StatefulWidget {
  final int delay;
  const _AnimatedDot({required this.delay});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Markdown & Clean Bullet Text Formatter
// ---------------------------------------------------------------------------

class _FormattedMessageText extends StatelessWidget {
  final String text;
  final bool isUser;

  const _FormattedMessageText({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final baseColor = isUser ? Colors.white : const Color(0xFF1A1A2E);
    final baseStyle = TextStyle(
      color: baseColor,
      fontSize: 14,
      height: 1.5,
    );

    final lines = text.split('\n');
    final children = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      var line = lines[i];

      bool isBullet = false;
      if (line.trimLeft().startsWith('* ') || line.trimLeft().startsWith('- ')) {
        isBullet = true;
        line = line.replaceFirst(RegExp(r'^\s*[\*\-]\s+'), '');
      } else if (line.trimLeft().startsWith('• ')) {
        isBullet = true;
        line = line.replaceFirst(RegExp(r'^\s*•\s+'), '');
      }

      final spans = _parseInlineSpans(line, baseStyle);

      if (isBullet) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: baseStyle.copyWith(fontWeight: FontWeight.bold)),
                Expanded(
                  child: RichText(
                    text: TextSpan(children: spans, style: baseStyle),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 6));
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: RichText(
              text: TextSpan(children: spans, style: baseStyle),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  List<TextSpan> _parseInlineSpans(String text, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: baseStyle.copyWith(fontWeight: FontWeight.bold),
      ));
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return spans;
  }
}
