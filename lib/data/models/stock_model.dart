class StockModel {
  final int? stockId;
  final int lotId;
  final int productId;
  final double count;
  final double reorderLevel;
  final double reservedQuantity;
  final String? lastStockUpdate;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed field
  double get availableQuantity => count - reservedQuantity;

  // Stock status based on reorder level
  String get stockStatus {
    if (count == 0) return 'OUT_OF_STOCK';
    if (reorderLevel > 0 && count <= reorderLevel) return 'LOW';
    if (reorderLevel > 0 && count > (reorderLevel * 3)) return 'OVERSTOCK';
    return 'NORMAL';
  }

  StockModel({
    this.stockId,
    required this.lotId,
    required this.productId,
    this.count = 0.0,
    this.reorderLevel = 0.0,
    this.reservedQuantity = 0.0,
    this.lastStockUpdate,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Convert from database Map
  factory StockModel.fromMap(Map<String, dynamic> map) {
    return StockModel(
      stockId: map['stock_id'] as int?,
      lotId: map['lot_id'] as int,
      productId: map['product_id'] as int,
      count: ((map['count'] as num?) ?? 0).toDouble(),
      reorderLevel: ((map['reorder_level'] as num?) ?? 0).toDouble(),
      reservedQuantity: ((map['reserved_quantity'] as num?) ?? 0).toDouble(),
      lastStockUpdate: map['last_stock_update'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Convert to database Map
  Map<String, dynamic> toMap() {
    return {
      if (stockId != null) 'stock_id': stockId,
      'lot_id': lotId,
      'product_id': productId,
      'count': count,
      'reorder_level': reorderLevel,
      'reserved_quantity': reservedQuantity,
      'last_stock_update': lastStockUpdate,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create a copy with modified fields
  StockModel copyWith({
    int? stockId,
    int? lotId,
    int? productId,
    double? count,
    double? reorderLevel,
    double? reservedQuantity,
    String? lastStockUpdate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StockModel(
      stockId: stockId ?? this.stockId,
      lotId: lotId ?? this.lotId,
      productId: productId ?? this.productId,
      count: count ?? this.count,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      reservedQuantity: reservedQuantity ?? this.reservedQuantity,
      lastStockUpdate: lastStockUpdate ?? this.lastStockUpdate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Update stock count
  StockModel updateCount(double newCount) {
    return copyWith(
      count: newCount,
      lastStockUpdate: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now(),
    );
  }

  // Add to stock
  StockModel addStock(double quantity) {
    return updateCount(count + quantity);
  }

  // Remove from stock
  StockModel removeStock(double quantity) {
    final newCount = count - quantity;
    if (newCount < 0) {
      throw Exception('Cannot reduce stock below 0. Current: $count, Requested: $quantity');
    }
    return updateCount(newCount);
  }

  // Reserve quantity
  StockModel reserve(double quantity) {
    final newReserved = reservedQuantity + quantity;
    if (newReserved > count) {
      throw Exception('Cannot reserve more than available. Available: $availableQuantity, Requested: $quantity');
    }
    return copyWith(
      reservedQuantity: newReserved,
      updatedAt: DateTime.now(),
    );
  }

  // Release reserved quantity
  StockModel releaseReserved(double quantity) {
    final newReserved = reservedQuantity - quantity;
    if (newReserved < 0) {
      throw Exception('Cannot release more than reserved. Reserved: $reservedQuantity, Requested: $quantity');
    }
    return copyWith(
      reservedQuantity: newReserved,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'StockModel(stockId: $stockId, lotId: $lotId, productId: $productId, count: $count, available: $availableQuantity, status: $stockStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is StockModel &&
        other.stockId == stockId &&
        other.lotId == lotId &&
        other.productId == productId &&
        other.count == count &&
        other.reorderLevel == reorderLevel;
  }

  @override
  int get hashCode {
    return Object.hash(
      stockId,
      lotId,
      productId,
      count,
      reorderLevel,
    );
  }
}
