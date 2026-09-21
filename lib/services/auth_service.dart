import 'package:supabase_flutter/supabase_flutter.dart';

/// Caferio Auth Service.
///
/// Security model:
///   - Supabase Auth manages sessions and issues signed JWTs.
///   - Passwords are bcrypt-hashed server-side (never stored in plaintext).
///   - Role lives in JWT `app_metadata` — only writeable by Postgres triggers,
///     never by the client.
///   - Usernames are mapped to an internal email domain so Supabase's email
///     field is satisfied without ever sending emails or exposing addresses.
///   - The mapping is one-way and consistent: same username always produces
///     the same internal address. Two different usernames cannot collide.
class AuthService {
  GoTrueClient get _auth => Supabase.instance.client.auth;

  Session? get session => _auth.currentSession;
  User? get currentUser => _auth.currentUser;

  /// The raw JWT — contains `app_metadata.role` set server-side only.
  String? get accessToken => _auth.currentSession?.accessToken;

  Stream<AuthState> get authChanges => _auth.onAuthStateChange;

  // ── Username ↔ email mapping ──────────────────────────────────────────────
  // Internal email domain. Never exposed to users, never sent to any inbox.
  static const _domain = 'myapp.app';

  /// Maps a public username to the internal Supabase email.
  /// Usernames are normalised to lowercase so "Chef" == "chef".
  static String _toEmail(String username) =>
      '${username.trim().toLowerCase()}@$_domain';

  // ── Public API ────────────────────────────────────────────────────────────

  Future<AuthResponse> signIn(String username, String password) {
    return _auth.signInWithPassword(
      email: _toEmail(username),
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String username,
    required String password,
    String? fullName,
  }) {
    final normalised = username.trim().toLowerCase();
    return _auth.signUp(
      email: _toEmail(normalised),
      password: password,
      data: {
        // Stored in raw_user_meta_data — readable by the handle_new_user trigger.
        'username': normalised,
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
      },
    );
  }

  Future<void> signOut() => _auth.signOut();
}
