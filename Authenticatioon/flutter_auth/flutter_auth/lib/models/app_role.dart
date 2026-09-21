import 'package:supabase_flutter/supabase_flutter.dart';

enum AppRole {
  admin,
  kitchen,
  user;

  /// Role lives in the JWT under `app_metadata.role`.
  /// app_metadata can only be written server-side, so the client cannot fake it.
  static AppRole fromUser(User user) {
    final raw = user.appMetadata['role'] as String?;
    return AppRole.values.firstWhere(
      (r) => r.name == raw,
      orElse: () => AppRole.user,
    );
  }
}
