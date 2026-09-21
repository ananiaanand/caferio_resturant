import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over Supabase Auth.
/// Supabase issues a JWT access token + refresh token, stores the session
/// on device and refreshes the token automatically.
class AuthService {
  GoTrueClient get _auth => Supabase.instance.client.auth;

  Session? get session => _auth.currentSession;
  User? get currentUser => _auth.currentUser;
  String? get accessToken => _auth.currentSession?.accessToken; // the JWT

  Stream<AuthState> get authChanges => _auth.onAuthStateChange;

  Future<AuthResponse> signIn(String email, String password) {
    return _auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) {
    return _auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
      },
    );
  }

  Future<void> signOut() => _auth.signOut();
}
