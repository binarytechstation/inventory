class LotModel {
  final int? lotId;
  final String receivedDate;
  final String? description;
  final int? supplierId;
  final String? referenceNumber;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  LotModel({
    this.lotId,
    required this.receivedDate,
    this.description,
    this.supplierId,
    this.referenceNumber,
    this.notes,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Convert from database Map
  factory LotModel.fromMap(Map<String, dynamic> map) {
    return LotModel(
      lotId: map['lot_id'] as int?,
      receivedDate: map['received_date'] as String,
      description: map['description'] as String?,
      supplierId: map['supplier_id'] as int?,
      referenceNumber: map['reference_number'] as String?,
      notes: map['notes'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Convert to database Map
  Map<String, dynamic> toMap() {
    return {
      if (lotId != null) 'lot_id': lotId,
      'received_date': receivedDate,
      'description': description,
      'supplier_id': supplierId,
      'reference_number': referenceNumber,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create a copy with modified fields
  LotModel copyWith({
    int? lotId,
    String? receivedDate,
    String? description,
    int? supplierId,
    String? referenceNumber,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LotModel(
      lotId: lotId ?? this.lotId,
      receivedDate: receivedDate ?? this.receivedDate,
      description: description ?? this.description,
      supplierId: supplierId ?? this.supplierId,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'LotModel(lotId: $lotId, receivedDate: $receivedDate, description: $description, referenceNumber: $referenceNumber)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LotModel &&
        other.lotId == lotId &&
        other.receivedDate == receivedDate &&
        other.description == description &&
        other.supplierId == supplierId &&
        other.referenceNumber == referenceNumber &&
        other.notes == notes &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(
      lotId,
      receivedDate,
      description,
      supplierId,
      referenceNumber,
      notes,
      isActive,
    );
  }
}
