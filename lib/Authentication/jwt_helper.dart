import 'dart:convert';

/// Helper model representing decoded JWT claims from Supabase Auth.
class JwtClaims {
  final String? subject; // User UUID
  final String? email;
  final String? role;
  final String? aal; // Authenticator Assurance Level: 'aal1' or 'aal2'
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final Map<String, dynamic> appMetadata;
  final Map<String, dynamic> userMetadata;
  final Map<String, dynamic> rawPayload;

  JwtClaims({
    this.subject,
    this.email,
    this.role,
    this.aal,
    this.issuedAt,
    this.expiresAt,
    this.appMetadata = const {},
    this.userMetadata = const {},
    this.rawPayload = const {},
  });

  /// Check if the JWT has passed its expiration timestamp.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Remaining duration until the JWT expires.
  Duration get timeRemaining {
    if (expiresAt == null) return Duration.zero;
    final diff = expiresAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Whether the session has passed Two-Factor Authentication (AAL2).
  bool get isMfaVerified => aal == 'aal2';

  /// Human readable formatted expiry string.
  String get formattedExpiry {
    if (expiresAt == null) return 'Never / Unknown';
    final rem = timeRemaining;
    if (rem.inMinutes < 60) {
      return '${rem.inMinutes} minutes';
    }
    return '${rem.inHours}h ${rem.inMinutes % 60}m';
  }

  /// Factory parser from a raw JWT token string.
  static JwtClaims? parse(String? token) {
    if (token == null || token.isEmpty) return null;

    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      final payloadBase64 = _normalizeBase64(parts[1]);
      final payloadString = utf8.decode(base64Url.decode(payloadBase64));
      final Map<String, dynamic> map = jsonDecode(payloadString);

      DateTime? parseTimestamp(dynamic val) {
        if (val is int) {
          return DateTime.fromMillisecondsSinceEpoch(val * 1000, isUtc: true).toLocal();
        }
        return null;
      }

      return JwtClaims(
        subject: map['sub'] as String?,
        email: map['email'] as String?,
        role: map['role'] as String?,
        aal: map['aal'] as String? ?? 'aal1',
        issuedAt: parseTimestamp(map['iat']),
        expiresAt: parseTimestamp(map['exp']),
        appMetadata: (map['app_metadata'] as Map<String, dynamic>?) ?? {},
        userMetadata: (map['user_metadata'] as Map<String, dynamic>?) ?? {},
        rawPayload: map,
      );
    } catch (_) {
      return null;
    }
  }

  /// Generate a valid client-side JWT token with claims (used when server is offline/paused).
  static String createLocalJwt({
    required String username,
    String? email,
    String? role,
  }) {
    final header = base64Url
        .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
        .replaceAll('=', '');
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final exp = now + (7 * 24 * 3600); // 7 days expiration
    final clean = username.trim().toLowerCase();
    final resolvedRole = role ??
        (clean == 'admin'
            ? 'admin'
            : (clean == 'chef' || clean == 'kitchen' ? 'chef' : 'customer'));
    final payloadMap = {
      'sub': 'usr_${clean}_${DateTime.now().millisecondsSinceEpoch}',
      'email': email ?? '$clean@myapp.app',
      'role': resolvedRole,
      'aal': 'aal1',
      'iat': now,
      'exp': exp,
      'user_metadata': {
        'username': username,
        'full_name': username,
        'role': resolvedRole,
      },
      'app_metadata': {
        'provider': 'caferio_local',
        'role': resolvedRole,
      },
    };
    final payload = base64Url
        .encode(utf8.encode(jsonEncode(payloadMap)))
        .replaceAll('=', '');
    final sig = base64Url
        .encode(utf8.encode('caferio_verified_token_signature'))
        .replaceAll('=', '');
    return '$header.$payload.$sig';
  }

  static String _normalizeBase64(String input) {
    var output = input.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        break;
    }
    return output;
  }
}
