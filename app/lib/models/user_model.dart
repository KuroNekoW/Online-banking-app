class UserModel {
  final String id;
  final String email;
  final String? phone;
  final String? username;
  final String fullName;
  final String status;
  final List<String> roles;
  final DateTime? lastLoginAt;

  UserModel({
    required this.id,
    required this.email,
    this.phone,
    this.username,
    required this.fullName,
    required this.status,
    this.roles = const [],
    this.lastLoginAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      username: json['username'] as String?,
      fullName: json['full_name'] as String? ?? 'Khách hàng',
      status: json['status'] as String? ?? 'active',
      roles: (json['roles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      lastLoginAt: json['last_login_at'] != null ? DateTime.tryParse(json['last_login_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'username': username,
      'full_name': fullName,
      'status': status,
      'roles': roles,
      'last_login_at': lastLoginAt?.toIso8601String(),
    };
  }

  bool get isActive => status == 'active';
  bool get isAdmin => roles.contains('ADMIN');
}
