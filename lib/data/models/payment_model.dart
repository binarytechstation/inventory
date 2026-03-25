class PaymentModel {
  final int? id;
  final int partyId;
  final String partyType; // 'supplier' or 'customer'
  final double amount;
  final DateTime paymentDate;
  final String paymentMethod; // 'cash', 'bank', 'cheque', etc.
  final String? referenceNumber;
  final String? notes;
  final int? createdBy;
  final DateTime createdAt;

  PaymentModel({
    this.id,
    required this.partyId,
    required this.partyType,
    required this.amount,
    required this.paymentDate,
    this.paymentMethod = 'cash',
    this.referenceNumber,
    this.notes,
    this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      partyType == 'supplier' ? 'supplier_id' : 'customer_id': partyId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'payment_method': paymentMethod,
      'reference_number': referenceNumber,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map, String partyType) {
    return PaymentModel(
      id: map['id'] as int?,
      partyId: (map['supplier_id'] ?? map['customer_id']) as int,
      partyType: partyType,
      amount: (map['amount'] as num).toDouble(),
      paymentDate: DateTime.parse(map['payment_date'] as String),
      paymentMethod: map['payment_method'] as String? ?? 'cash',
      referenceNumber: map['reference_number'] as String?,
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
