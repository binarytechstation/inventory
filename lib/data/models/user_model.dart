class UserModel {
  final int? id;
  final String username;
  final String passwordHash;
  final String role;
  final String name;
  final String? email;
  final String? phone;
  final String? profilePicturePath;
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
    this.profilePicturePath,
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
      'profile_picture_path': profilePicturePath,
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
      profilePicturePath: map['profile_picture_path'] as String?,
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
    String? profilePicturePath,
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
      profilePicturePath: profilePicturePath ?? this.profilePicturePath,
      isActive: isActive ?? this.isActive,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  bool hasPermission(String permission) {
    switch (role.toLowerCase()) {
      case 'admin':
        return true; // Admin has full access to everything

      case 'manager':
        // Manager can: manage products, create/edit transactions, view reports, export reports
        // Manager CANNOT: manage users, change system settings
        return [
          'view_products', 'create_product', 'edit_product', 'delete_product',
          'view_transactions', 'create_sale', 'create_purchase', 'edit_transaction', 'delete_transaction',
          'view_customers', 'create_customer', 'edit_customer', 'delete_customer',
          'view_suppliers', 'create_supplier', 'edit_supplier', 'delete_supplier',
          'view_reports', 'export_reports',
          'print_invoice',
        ].contains(permission);

      case 'cashier':
        // Cashier can: create sales, view products only
        // Cashier CANNOT: access purchases, edit/delete anything, view reports, manage customers/suppliers
        return [
          'view_products',
          'create_sale',
          'view_transactions',
        ].contains(permission);

      case 'viewer':
        // Viewer can: only view, no create/edit/delete/print
        return [
          'view_products',
          'view_transactions',
          'view_customers',
          'view_suppliers',
          'view_reports',
          'view_dashboard',
        ].contains(permission);

      default:
        return false;
    }
  }

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isManager => role.toLowerCase() == 'manager';
  bool get isCashier => role.toLowerCase() == 'cashier';
  bool get isViewer => role.toLowerCase() == 'viewer';
}
