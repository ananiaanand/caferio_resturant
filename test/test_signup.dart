import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://rpuzznremhzsrwgzpggk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJwdXp6bnJlbWh6c3J3Z3pwZ2drIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY5MjA1ODYsImV4cCI6MjA3MjQ5NjU4Nn0.sSi9oYbhkyn3uXnd8twbUa-wH99ySvSkCPCS45J_Be8',
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.implicit),
  );

  final supabase = Supabase.instance.client;
  final rand = Random().nextInt(100000);
  final username = 'testuser$rand';
  final email = '$username@myapp.app';

  try {
    print('Attempting to sign up user: $username');
    final response = await supabase.auth.signUp(
      email: email,
      password: 'password123',
      data: {
        'username': username,
        'full_name': 'Test User',
      },
    );
    print('SUCCESS! User ID: ${response.user?.id}');
  } on AuthException catch (e) {
    print('AUTH ERROR: ${e.message} (code: ${e.statusCode})');
  } catch (e) {
    print('OTHER ERROR: $e');
  }
}
