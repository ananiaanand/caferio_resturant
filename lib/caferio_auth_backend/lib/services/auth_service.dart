import 'package:supabase_flutter/supabase_flutter.dart';

/// Caferio auth client.
///
/// Drop-in replacement for lib/services/auth_service.dart — same public API
/// (signIn / signUp / signOut / session / currentUser / accessToken / authChanges),
/// so login_screen.dart, signup_screen.dart and auth_gate.dart keep working.
///
/// How it works:
///   * The app NEVER builds an e-mail from the username and never sees one.
///   * Username + password go over TLS to the `auth-login` / `auth-register`
///     Edge Functions. The server resolves the username to a private, random
///     alias and lets **Supabase Auth** verify the password.
///   * The function returns a normal Supabase session; we adopt it with
///     `setSession`, so refresh tokens, expiry, `onAuthStateChange`, sign-out
///     and persistence are all handled by supabase_flutter itself.
///   * No service-role key exists in this app. Roles are set server-side only.
class AuthService {
  SupabaseClient get _client => Supabase.instance.client;
  GoTrueClient get _auth => _client.auth;

  Session? get session => _auth.currentSession;
  User? get currentUser => _auth.currentUser;
  String? get accessToken => _auth.currentSession?.accessToken;
  Stream<AuthState> get authChanges => _auth.onAuthStateChange;

  /// The public username to show in the UI. (`currentUser.email` is an internal
  /// alias and must never be displayed.)
  String? get username {
    final u = currentUser;
    if (u == null) return null;
    return (u.appMetadata['username'] ?? u.userMetadata?['username']) as String?;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<AuthResponse> signIn(String username, String password) async {
    final data = await _call('auth-login', {
      'username': username.trim(),
      'password': password,
    });
    return _adoptSession(data);
  }

  /// [confirmPassword] defaults to [password] (the form already checks equality);
  /// the server re-checks it either way.
  Future<AuthResponse> signUp({
    required String username,
    required String password,
    String? confirmPassword,
    String? fullName,
  }) async {
    final data = await _call('auth-register', {
      'username': username.trim(),
      'password': password,
      'confirm_password': confirmPassword ?? password,
      if (fullName != null && fullName.trim().isNotEmpty)
        'display_name': fullName.trim(),
    });
    final res = await _adoptSession(data);
    if (res.session == null) {
      // Account was created but auto-sign-in failed: sign in explicitly.
      return signIn(username, password);
    }
    return res;
  }

  /// Signs out this device. (Use `_auth.signOut(scope: SignOutScope.global)` for all devices.)
  Future<void> signOut() => _auth.signOut();

  /// Re-authenticates with [current] and changes the password. Other devices are signed out.
  Future<void> changePassword({
    required String current,
    required String next,
    required String confirm,
  }) async {
    await _call('auth-change-password', {
      'current_password': current,
      'new_password': next,
      'confirm_password': confirm,
    });
  }

  /// Admin only (enforced server-side from the database, not from the token).
  Future<void> adminResetPassword({
    required String username,
    required String newPassword,
    bool unban = false,
  }) async {
    await _call('auth-admin-reset-password', {
      'username': username.trim(),
      'new_password': newPassword,
      if (unban) 'unban': true,
    });
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _call(String fn, Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke(fn, body: body);
      final d = res.data;
      return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
    } on FunctionException catch (e) {
      final d = e.details;
      final msg = (d is Map && d['message'] is String)
          ? d['message'] as String
          : 'Something went wrong. Try again.';
      throw AuthException(msg, statusCode: e.status.toString());
    }
  }

  Future<AuthResponse> _adoptSession(Map<String, dynamic> data) async {
    final s = data['session'];
    if (s is! Map || s['refresh_token'] is! String) return AuthResponse();
    // Validates the refresh token with Supabase Auth and stores/persists the session.
    return _auth.setSession(s['refresh_token'] as String);
  }
}
