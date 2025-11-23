class CustomerModel {
  final int? id;
  final String name;
  final String? companyName;
  final String? phone;
  final String? email;
  final String? address;
  final double creditLimit;
  final double currentBalance;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomerModel({
    this.id,
    required this.name,
    this.companyName,
    this.phone,
    this.email,
    this.address,
    this.creditLimit = 0,
    this.currentBalance = 0,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'company_name': companyName,
      'phone': phone,
      'email': email,
      'address': address,
      'credit_limit': creditLimit,
      'current_balance': currentBalance,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      companyName: map['company_name'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0,
      currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  bool hasAvailableCredit(double amount) {
    return (currentBalance + amount) <= creditLimit;
  }
}
