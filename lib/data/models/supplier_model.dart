class SupplierModel {
  final int? id;
  final String name;
  final String? companyName;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxId;
  final String? notes;
  final double creditLimit;
  final double currentBalance;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupplierModel({
    this.id,
    required this.name,
    this.companyName,
    this.phone,
    this.email,
    this.address,
    this.taxId,
    this.notes,
    this.creditLimit = 0,
    this.currentBalance = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Amount we owe this supplier (unpaid purchases)
  double get amountDue => currentBalance;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'company_name': companyName,
      'phone': phone,
      'email': email,
      'address': address,
      'tax_id': taxId,
      'notes': notes,
      'credit_limit': creditLimit,
      'current_balance': currentBalance,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    return SupplierModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      companyName: map['company_name'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      taxId: map['tax_id'] as String?,
      notes: map['notes'] as String?,
      creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0,
      currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  SupplierModel copyWith({
    int? id,
    String? name,
    String? companyName,
    String? phone,
    String? email,
    String? address,
    String? taxId,
    String? notes,
    double? creditLimit,
    double? currentBalance,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      taxId: taxId ?? this.taxId,
      notes: notes ?? this.notes,
      creditLimit: creditLimit ?? this.creditLimit,
      currentBalance: currentBalance ?? this.currentBalance,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
