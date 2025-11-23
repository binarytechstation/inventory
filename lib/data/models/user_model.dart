class UserModel {
  final int? id;
  final String username;
  final String passwordHash;
  final String role;
  final String name;
  final String? email;
  final String? phone;
  final bool isActive;
  final bool mustChangePassword;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLogin;

  UserModel({
    this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    required this.name,
    this.email,
    this.phone,
    this.isActive = true,
    this.mustChangePassword = false,
    required this.createdAt,
    required this.updatedAt,
    this.lastLogin,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'role': role,
      'name': name,
      'email': email,
      'phone': phone,
      'is_active': isActive ? 1 : 0,
      'must_change_password': mustChangePassword ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      role: map['role'] as String,
      name: map['name'] as String,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      isActive: (map['is_active'] as int) == 1,
      mustChangePassword: (map['must_change_password'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      lastLogin: map['last_login'] != null ? DateTime.parse(map['last_login'] as String) : null,
    );
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? passwordHash,
    String? role,
    String? name,
    String? email,
    String? phone,
    bool? isActive,
    bool? mustChangePassword,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLogin,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  bool hasPermission(String permission) {
    switch (role) {
      case 'admin':
        return true; // Admin has all permissions
      case 'manager':
        return permission != 'manage_users' && permission != 'manage_settings';
      case 'cashier':
        return permission == 'create_sale' || permission == 'view_products' || permission == 'print_receipt';
      case 'viewer':
        return permission.startsWith('view_');
      default:
        return false;
    }
  }
}
