import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://rpuzznremhzsrwgzpggk.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJwdXp6bnJlbWh6c3J3Z3pwZ2drIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY5MjA1ODYsImV4cCI6MjA3MjQ5NjU4Nn0.sSi9oYbhkyn3uXnd8twbUa-wH99ySvSkCPCS45J_Be8',
  );

  try {
    final response = await supabase.auth.signInWithPassword(
      email: 'admin@myapp.app',
      password: 'admin',
    );
    print('SUCCESS! User ID: ${response.user?.id}');
  } on AuthException catch (e) {
    print('AUTH ERROR: ${e.message} (code: ${e.statusCode})');
  } catch (e) {
    print('OTHER ERROR: $e');
  }
}
