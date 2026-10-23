// lib/services/rag_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatMessage {
  final bool isUser;
  final String text;
  ChatMessage({required this.isUser, required this.text});

  Map<String, String> toHistory() =>
      {'role': isUser ? 'user' : 'model', 'text': text};
}

class RagService {
  RagService._();
  static final instance = RagService._();

  final _client = Supabase.instance.client;

  /// Sends question + short history to the `rag-chat` edge function.
  /// Gemini key never touches the app. Role is resolved server-side.
  Future<String> ask(String question, List<ChatMessage> history) async {
    final res = await _client.functions.invoke(
      'rag-chat',
      body: {
        'question': question,
        'history': history.map((m) => m.toHistory()).toList(),
      },
    );

    if (res.status != 200) {
      throw Exception('RAG error ${res.status}: ${res.data}');
    }
    return (res.data as Map)['answer'] as String;
  }
}
