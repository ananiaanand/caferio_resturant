// lib/widgets/rag_chat_sheet.dart
// Use in BOTH chef and admin dashboards:
//
//   FloatingActionButton(
//     onPressed: () => RagChatSheet.show(context),
//     child: const Icon(Icons.smart_toy),
//   )
import 'package:flutter/material.dart';
import '../services/rag_service.dart';

class RagChatSheet extends StatefulWidget {
  const RagChatSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.9,
        child: RagChatSheet(),
      ),
    );
  }

  @override
  State<RagChatSheet> createState() => _RagChatSheetState();
}

class _RagChatSheetState extends State<RagChatSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loading = false;

  Future<void> _send() async {
    final q = _controller.text.trim();
    if (q.isEmpty || _loading) return;

    final history = List<ChatMessage>.from(_messages); // before adding new
    setState(() {
      _messages.add(ChatMessage(isUser: true, text: q));
      _loading = true;
      _controller.clear();
    });
    _scrollDown();

    try {
      final answer = await RagService.instance.ask(q, history);
      setState(() => _messages.add(ChatMessage(isUser: false, text: answer)));
    } catch (e) {
      setState(() => _messages.add(
          ChatMessage(isUser: false, text: 'Something went wrong. Try again.')));
      debugPrint('RAG error: $e');
    } finally {
      setState(() => _loading = false);
      _scrollDown();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Restaurant Assistant',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text('Ask about orders, menu, stock…\n'
                        'e.g. "Which orders are still pending?"',
                        textAlign: TextAlign.center))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      return Align(
                        alignment:
                            m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.8),
                          decoration: BoxDecoration(
                            color: m.isUser
                                ? cs.primaryContainer
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: SelectableText(m.text),
                        ),
                      );
                    },
                  ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _send(),
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: 'Ask something…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
