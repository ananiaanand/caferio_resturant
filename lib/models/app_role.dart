import 'package:supabase_flutter/supabase_flutter.dart';

/// Role values that live in the JWT under `app_metadata.role`.
/// app_metadata is only writable server-side (via trigger or service-role key),
/// so the client cannot forge or escalate its own role.
enum AppRole {
  admin,
  kitchen,
  user;

  /// Reads the role directly from the JWT claim — no DB round-trip, unforgeable.
  static AppRole fromUser(User user) {
    final raw = user.appMetadata['role'] as String?;
    return AppRole.values.firstWhere(
      (r) => r.name == raw,
      orElse: () => AppRole.user,
    );
  }
}
