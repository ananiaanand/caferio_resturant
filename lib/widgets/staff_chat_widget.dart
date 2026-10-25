// lib/widgets/staff_chat_widget.dart
//
// Internal AI assistant for Staff (Chef / Admin) — accessible via a FAB on
// the admin and kitchen dashboards.
//
// Security: Role is resolved server-side. The chat widget only passes the
//   role for local UI customisation (placeholder text, colors). The actual
//   access control is enforced in the edge function.
//
// Chef sees:  orders, prep notes, ingredient/allergen info
// Admin sees: everything — sales, orders, menu, stock, revenue
//
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:caferio/providers/app_provider.dart';
import 'package:caferio/models/order.dart';
import 'package:caferio/utils/theme.dart';
import 'package:caferio/services/rag_service.dart';
export 'package:caferio/services/rag_service.dart' show ChatRole;

// ---------------------------------------------------------------------------
// FAB
// ---------------------------------------------------------------------------

class StaffChatFab extends StatelessWidget {
  final ChatRole role;
  const StaffChatFab({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == ChatRole.admin;
    return FloatingActionButton(
      heroTag: 'staff_chat_fab_${role.name}',
      backgroundColor: isAdmin ? const Color(0xFF1E1E2E) : AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 8,
      tooltip: isAdmin ? 'Admin AI Assistant' : 'Kitchen AI Assistant',
      onPressed: () => StaffChatSheet.show(context, role: role),
      child: const Icon(Icons.smart_toy_rounded, size: 26),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat sheet
// ---------------------------------------------------------------------------

class StaffChatSheet extends StatefulWidget {
  final ChatRole role;
  const StaffChatSheet({super.key, required this.role});

  static Future<void> show(BuildContext context, {required ChatRole role}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StaffChatSheet(role: role),
    );
  }

  @override
  State<StaffChatSheet> createState() => _StaffChatSheetState();
}

class _StaffChatSheetState extends State<StaffChatSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loading = false;

  // Role-specific suggestions
  static const _chefSuggestions = [
    '🍳 Which orders are still pending?',
    '🥘 What items need to be prepared next?',
    '⚠️ Any orders with special notes or allergies?',
    '📋 Show me completed orders today',
    '🧄 What ingredients does the Chicken Biriyani use?',
  ];

  static const _adminSuggestions = [
    '📊 How many orders have been placed today?',
    '💰 What is today\'s revenue summary?',
    '🍽️ Which menu items are currently unavailable?',
    '📦 What stock items are running low?',
    '🏆 What are our best-selling dishes?',
  ];

  List<String> get _suggestions =>
      widget.role == ChatRole.chef ? _chefSuggestions : _adminSuggestions;

  String get _title =>
      widget.role == ChatRole.chef ? 'Kitchen Assistant' : 'Admin Assistant';

  String get _subtitle => widget.role == ChatRole.chef
      ? 'Orders · Ingredients · Prep notes'
      : 'Sales · Orders · Stock · Menu';

  Color get _accentColor => widget.role == ChatRole.admin
      ? const Color(0xFF1E1E2E)
      : AppTheme.primaryColor;

  @override
  void initState() {
    super.initState();
    _messages.addAll(RagService.instance.getHistory(widget.role));
    RagService.instance.initStorage().then((_) {
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(RagService.instance.getHistory(widget.role));
        });
        _scrollDown();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text('This will reset your conversation history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              RagService.instance.clearHistory(widget.role);
              setState(() => _messages.clear());
            },
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _buildStaffDashboardContext(AppProvider provider) {
    final buffer = StringBuffer();

    if (widget.role == ChatRole.chef) {
      buffer.writeln('=== LIVE KITCHEN TICKETS ===');
      final pending = provider.orders
          .where((o) =>
              o.status == OrderStatus.received ||
              o.status == OrderStatus.preparing ||
              o.status == OrderStatus.halfDone)
          .toList();
      if (pending.isEmpty) {
        buffer.writeln('No active kitchen orders right now. All caught up!');
      } else {
        buffer.writeln('Orders needing preparation (${pending.length}):');
        for (final o in pending) {
          final id = o.id.length > 8 ? o.id.substring(0, 8) : o.id;
          final itemsStr =
              o.items.map((i) => '${i.quantity}x ${i.menuItem.name}').join(', ');
          buffer.writeln('• Ticket #$id [Status: ${o.status.label}]');
          buffer.writeln('  Items: $itemsStr');
        }
      }

      final shortage =
          provider.inventoryItems.where((i) => i.isOutOfStock).toList();
      buffer.writeln('\n=== KITCHEN SHORTAGE / OUT OF STOCK ===');
      if (shortage.isEmpty) {
        buffer.writeln('All ingredients currently in stock.');
      } else {
        for (final s in shortage) {
          buffer.writeln('• ${s.name} (${s.category}) - OUT OF STOCK');
        }
      }

      buffer.writeln('\n=== DISH INGREDIENTS ===');
      for (final item in provider.menuItems) {
        buffer.writeln('• ${item.name}: ${item.ingredients.join(', ')}');
      }
    } else {
      // Admin context
      final today = DateTime.now();
      final completedToday = provider.orders.where((o) {
        final isCompleted =
            o.status == OrderStatus.completed || o.status == OrderStatus.served;
        final isToday = o.createdAt.year == today.year &&
            o.createdAt.month == today.month &&
            o.createdAt.day == today.day;
        return isCompleted && isToday;
      }).toList();

      double revenueToday = 0;
      for (final o in completedToday) {
        revenueToday += o.totalAmount;
      }

      final activeOrders = provider.orders
          .where((o) =>
              o.status != OrderStatus.served &&
              o.status != OrderStatus.completed)
          .toList();

      buffer.writeln('=== LIVE SALES & REVENUE DASHBOARD ===');
      buffer.writeln('• Today\'s Revenue: ₹${revenueToday.toStringAsFixed(0)}');
      buffer.writeln('• Completed Orders Today: ${completedToday.length}');
      buffer.writeln('• Active / In-progress Orders: ${activeOrders.length}');
      buffer.writeln('• Total Orders Recorded: ${provider.orders.length}');

      final shortage =
          provider.inventoryItems.where((i) => i.isOutOfStock).toList();
      final critical = provider.inventoryItems
          .where((i) =>
              i.stockStatus == 'CRITICAL' || i.stockStatus == 'WARNING')
          .toList();

      buffer.writeln('\n=== INVENTORY & STOCK ALERT ===');
      buffer.writeln('• Items Out of Stock: ${shortage.length}');
      for (final s in shortage) {
        buffer.writeln('  - ${s.name} (${s.category})');
      }
      if (critical.isNotEmpty) {
        buffer.writeln('• Items with High Runout Risk (ML Alert):');
        for (final c in critical) {
          buffer.writeln(
              '  - ${c.name}: ${c.stockStatus} (${c.daysLeft} days left)');
        }
      }

      final outOfStockMenu =
          provider.menuItems.where((m) => m.isOutOfStock).toList();
      buffer.writeln('\n=== MENU ITEMS AVAILABILITY ===');
      buffer.writeln('• Total Menu Dishes: ${provider.menuItems.length}');
      buffer.writeln('• Dishes Currently Out of Stock: ${outOfStockMenu.length}');
      for (final m in outOfStockMenu) {
        buffer.writeln('  - ${m.name} (${m.category})');
      }
    }

    return buffer.toString();
  }

  Future<void> _send([String? prefilled]) async {
    final q = (prefilled ?? _controller.text).trim();
    if (q.isEmpty || _loading) return;

    String? dashboardContext;
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      dashboardContext = _buildStaffDashboardContext(provider);
    } catch (_) {}

    final history = List<ChatMessage>.from(_messages);
    final userMsg = ChatMessage(isUser: true, text: q);
    setState(() {
      _messages.add(userMsg);
      _loading = true;
      _controller.clear();
    });
    await RagService.instance.addMessage(widget.role, userMsg);
    _scrollDown();

    try {
      final answer = await RagService.instance.ask(
        q,
        history,
        role: widget.role,
        dashboardContext: dashboardContext,
      );
      final aiMsg = ChatMessage(isUser: false, text: answer);
      await RagService.instance.addMessage(widget.role, aiMsg);
      if (mounted) {
        setState(() => _messages.add(aiMsg));
      }
    } catch (_) {
      final localAnswer = RagService.instance.generateSmartLocalResponse(
        q,
        widget.role,
        dashboardContext,
      );
      final aiMsg = ChatMessage(isUser: false, text: localAnswer);
      await RagService.instance.addMessage(widget.role, aiMsg);
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
          duration: const Duration(milliseconds: 250),
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
      height: screenH * 0.9,
      decoration: BoxDecoration(
        color: widget.role == ChatRole.admin
            ? const Color(0xFF0F0F1A)
            : const Color(0xFFF8F8FA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.role == ChatRole.admin
                    ? Colors.white24
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          _buildHeader(),
          Divider(
            color: widget.role == ChatRole.admin
                ? Colors.white12
                : Colors.grey.shade100,
            height: 1,
          ),

          // Messages / suggestions
          Expanded(
            child: _messages.isEmpty ? _buildWelcome() : _buildMessageList(),
          ),

          // Loading
          if (_loading) _buildTypingIndicator(),

          // Input
          _buildInputBar(bottomInset),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = widget.role == ChatRole.admin;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _accentColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              widget.role == ChatRole.chef
                  ? Icons.restaurant_menu_rounded
                  : Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              Text(
                _subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: isDark ? 0.3 : 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _accentColor.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              widget.role.name.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : _accentColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'Clear Chat',
              icon: Icon(
                Icons.delete_outline_rounded,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                size: 20,
              ),
              onPressed: _clearChat,
            ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: isDark ? Colors.white54 : const Color(0xFF6B7280),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    final isDark = widget.role == ChatRole.admin;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome bubble
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
              border: isDark
                  ? Border.all(color: Colors.white12)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.role == ChatRole.chef
                      ? '👨‍🍳 Kitchen Assistant Ready'
                      : '📊 Admin Assistant Ready',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.role == ChatRole.chef
                      ? 'Ask me about pending orders, prep notes, ingredients, or any kitchen queries. I have access to real-time order and menu data.'
                      : 'Ask me about sales, orders, revenue, stock levels, or menu performance. I have full access to restaurant data.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : const Color(0xFF4B5563),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Quick queries:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isDark ? Colors.white38 : const Color(0xFF6B7280),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          ..._suggestions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _StaffSuggestionChip(
                label: s,
                onTap: () => _send(s),
                isDark: isDark,
                accentColor: _accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    final isDark = widget.role == ChatRole.admin;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _StaffMessageBubble(
        message: _messages[i],
        isDark: isDark,
        accentColor: _accentColor,
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final isDark = widget.role == ChatRole.admin;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: isDark ? Border.all(color: Colors.white12) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.smart_toy_rounded,
                    size: 14, color: _accentColor),
                const SizedBox(width: 8),
                Text(
                  'Thinking…',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(double bottomInset) {
    final isDark = widget.role == ChatRole.admin;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F1A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade100,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(28),
                border: isDark ? Border.all(color: Colors.white12) : null,
              ),
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.send,
                maxLines: 3,
                minLines: 1,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: widget.role == ChatRole.chef
                      ? 'Ask about orders, prep, ingredients…'
                      : 'Ask about sales, stock, orders…',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              decoration: BoxDecoration(
                color: _accentColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _accentColor.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
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
// Message bubble (staff version)
// ---------------------------------------------------------------------------

class _StaffMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;
  final Color accentColor;

  const _StaffMessageBubble({
    required this.message,
    required this.isDark,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Colors.white, size: 15),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? accentColor
                    : (isDark ? const Color(0xFF1A1A2E) : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isUser
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: (!isUser && isDark)
                    ? Border.all(color: Colors.white12)
                    : null,
              ),
              child: _StaffFormattedMessageText(
                text: message.text,
                isUser: isUser,
                isDark: isDark,
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
// Suggestion chip (staff version)
// ---------------------------------------------------------------------------

class _StaffSuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final Color accentColor;

  const _StaffSuggestionChip({
    required this.label,
    required this.onTap,
    required this.isDark,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accentColor.withValues(alpha: isDark ? 0.25 : 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : const Color(0xFF374151),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Markdown & Clean Bullet Text Formatter for Staff
// ---------------------------------------------------------------------------

class _StaffFormattedMessageText extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isDark;

  const _StaffFormattedMessageText({
    required this.text,
    required this.isUser,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isUser
        ? Colors.white
        : (isDark ? Colors.white70 : const Color(0xFF1A1A2E));
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
