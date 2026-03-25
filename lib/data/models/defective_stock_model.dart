class DefectiveStockModel {
  final int? id;
  final int productId;
  final int lotId;
  final String productName;
  final double quantity;
  final String source; // 'CUSTOMER_RETURN' or 'INTERNAL'
  final int? sourceTransactionId;
  final int? partyId;
  final String? partyType;
  final String? partyName;
  final String? reason;
  /// 'PENDING', 'ACCEPTED', 'REJECTED', 'NOT_APPLICABLE'
  final String supplierReturnStatus;
  final int? supplierReturnTransactionId;
  final bool isRefundable;
  final double refundAmount;
  final int? reportedBy;
  final DateTime reportedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  DefectiveStockModel({
    this.id,
    required this.productId,
    required this.lotId,
    required this.productName,
    required this.quantity,
    required this.source,
    this.sourceTransactionId,
    this.partyId,
    this.partyType,
    this.partyName,
    this.reason,
    this.supplierReturnStatus = 'PENDING',
    this.supplierReturnTransactionId,
    this.isRefundable = true,
    this.refundAmount = 0,
    this.reportedBy,
    required this.reportedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'lot_id': lotId,
      'product_name': productName,
      'quantity': quantity,
      'source': source,
      'source_transaction_id': sourceTransactionId,
      'party_id': partyId,
      'party_type': partyType,
      'party_name': partyName,
      'reason': reason,
      'supplier_return_status': supplierReturnStatus,
      'supplier_return_transaction_id': supplierReturnTransactionId,
      'is_refundable': isRefundable ? 1 : 0,
      'refund_amount': refundAmount,
      'reported_by': reportedBy,
      'reported_at': reportedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DefectiveStockModel.fromMap(Map<String, dynamic> map) {
    return DefectiveStockModel(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      lotId: map['lot_id'] as int,
      productName: map['product_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      source: map['source'] as String,
      sourceTransactionId: map['source_transaction_id'] as int?,
      partyId: map['party_id'] as int?,
      partyType: map['party_type'] as String?,
      partyName: map['party_name'] as String?,
      reason: map['reason'] as String?,
      supplierReturnStatus: map['supplier_return_status'] as String? ?? 'PENDING',
      supplierReturnTransactionId: map['supplier_return_transaction_id'] as int?,
      isRefundable: (map['is_refundable'] as int?) == 1,
      refundAmount: (map['refund_amount'] as num?)?.toDouble() ?? 0,
      reportedBy: map['reported_by'] as int?,
      reportedAt: DateTime.parse(map['reported_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  DefectiveStockModel copyWith({
    String? supplierReturnStatus,
    int? supplierReturnTransactionId,
    bool? isRefundable,
    double? refundAmount,
    DateTime? updatedAt,
  }) {
    return DefectiveStockModel(
      id: id,
      productId: productId,
      lotId: lotId,
      productName: productName,
      quantity: quantity,
      source: source,
      sourceTransactionId: sourceTransactionId,
      partyId: partyId,
      partyType: partyType,
      partyName: partyName,
      reason: reason,
      supplierReturnStatus: supplierReturnStatus ?? this.supplierReturnStatus,
      supplierReturnTransactionId: supplierReturnTransactionId ?? this.supplierReturnTransactionId,
      isRefundable: isRefundable ?? this.isRefundable,
      refundAmount: refundAmount ?? this.refundAmount,
      reportedBy: reportedBy,
      reportedAt: reportedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
