class Profile {
  final String id;
  final String role;
  final String fullName;
  final String? phoneNumber;
  final DateTime createdAt;

  Profile({
    required this.id,
    required this.role,
    required this.fullName,
    this.phoneNumber,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      role: json['role'] ?? 'customer',
      fullName: json['full_name'],
      phoneNumber: json['phone_number'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
