class LotHistoryModel {
  final int? id;
  final int lotId;
  final int productId;
  final String action;
  final double quantityChange;
  final double quantityBefore;
  final double quantityAfter;
  final String? referenceType;
  final int? referenceId;
  final int? userId;
  final String? notes;
  final DateTime createdAt;

  LotHistoryModel({
    this.id,
    required this.lotId,
    required this.productId,
    required this.action,
    required this.quantityChange,
    required this.quantityBefore,
    required this.quantityAfter,
    this.referenceType,
    this.referenceId,
    this.userId,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert from database Map
  factory LotHistoryModel.fromMap(Map<String, dynamic> map) {
    return LotHistoryModel(
      id: map['id'] as int?,
      lotId: map['lot_id'] as int,
      productId: map['product_id'] as int,
      action: map['action'] as String,
      quantityChange: ((map['quantity_change'] as num?) ?? 0).toDouble(),
      quantityBefore: ((map['quantity_before'] as num?) ?? 0).toDouble(),
      quantityAfter: ((map['quantity_after'] as num?) ?? 0).toDouble(),
      referenceType: map['reference_type'] as String?,
      referenceId: map['reference_id'] as int?,
      userId: map['user_id'] as int?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // Convert to database Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'lot_id': lotId,
      'product_id': productId,
      'action': action,
      'quantity_change': quantityChange,
      'quantity_before': quantityBefore,
      'quantity_after': quantityAfter,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'user_id': userId,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Factory method to create a history entry from stock change
  factory LotHistoryModel.fromStockChange({
    required int lotId,
    required int productId,
    required String action,
    required double quantityBefore,
    required double quantityAfter,
    String? referenceType,
    int? referenceId,
    int? userId,
    String? notes,
  }) {
    return LotHistoryModel(
      lotId: lotId,
      productId: productId,
      action: action,
      quantityChange: quantityAfter - quantityBefore,
      quantityBefore: quantityBefore,
      quantityAfter: quantityAfter,
      referenceType: referenceType,
      referenceId: referenceId,
      userId: userId,
      notes: notes,
    );
  }

  @override
  String toString() {
    return 'LotHistoryModel(id: $id, lotId: $lotId, productId: $productId, action: $action, change: $quantityChange)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LotHistoryModel &&
        other.id == id &&
        other.lotId == lotId &&
        other.productId == productId &&
        other.action == action &&
        other.quantityChange == quantityChange;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      lotId,
      productId,
      action,
      quantityChange,
    );
  }
}
