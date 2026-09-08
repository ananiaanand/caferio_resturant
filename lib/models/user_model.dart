import 'dart:convert';

/// Roles supported by the app.
enum UserRole { customer, kitchenStaff, manager }

extension UserRoleExt on UserRole {
  String get stored {
    switch (this) {
      case UserRole.customer:     return 'customer';
      case UserRole.kitchenStaff: return 'kitchen_staff';
      case UserRole.manager:      return 'manager';
    }
  }

  static UserRole fromString(String s) {
    switch (s) {
      case 'kitchen_staff': return UserRole.kitchenStaff;
      case 'manager':       return UserRole.manager;
      default:              return UserRole.customer;
    }
  }
}

/// Represents a registered user stored in the `users` SQLite table.
class UserModel {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final DateTime createdAt;
  DateTime lastLoginAt;
  int loginCount;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
    required this.lastLoginAt,
    required this.loginCount,
  });

  // ─── Convenience getters ───────────────────────────────────────────────────

  bool get isCustomer     => role == UserRole.customer;
  bool get isKitchenStaff => role == UserRole.kitchenStaff;
  bool get isManager      => role == UserRole.manager;

  // ─── JSON (used for session persistence in SharedPreferences) ──────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role.stored,
        'createdAt': createdAt.toIso8601String(),
        'lastLoginAt': lastLoginAt.toIso8601String(),
        'loginCount': loginCount,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        role: UserRoleExt.fromString(json['role'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastLoginAt: DateTime.parse(json['lastLoginAt'] as String),
        loginCount: json['loginCount'] as int? ?? 0,
      );

  String toJsonString() => jsonEncode(toJson());
  factory UserModel.fromJsonString(String s) => UserModel.fromJson(jsonDecode(s) as Map<String, dynamic>);

  // ─── SQLite row mapping ────────────────────────────────────────────────────

  factory UserModel.fromRow(Map<String, dynamic> row) => UserModel(
        id: row['id'] as String,
        email: row['email'] as String,
        name: row['name'] as String,
        role: UserRoleExt.fromString(row['role'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
        lastLoginAt: DateTime.parse(row['last_login_at'] as String),
        loginCount: row['login_count'] as int? ?? 0,
      );
}
