/// Product model for lot-based inventory system
/// Uses composite primary key (product_id, lot_id)
class ProductLotModel {
  final int productId;
  final int lotId;
  final String productName;
  final double unitPrice;
  final String? productImage;
  final String? productDescription;
  final String unit;
  final String? sku;
  final String? barcode;
  final String? category;
  final double taxRate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductLotModel({
    required this.productId,
    required this.lotId,
    required this.productName,
    required this.unitPrice,
    this.productImage,
    this.productDescription,
    this.unit = 'piece',
    this.sku,
    this.barcode,
    this.category,
    this.taxRate = 0.0,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Convert from database Map
  factory ProductLotModel.fromMap(Map<String, dynamic> map) {
    return ProductLotModel(
      productId: map['product_id'] as int,
      lotId: map['lot_id'] as int,
      productName: map['product_name'] as String,
      unitPrice: (map['unit_price'] as num).toDouble(),
      productImage: map['product_image'] as String?,
      productDescription: map['product_description'] as String?,
      unit: (map['unit'] as String?) ?? 'piece',
      sku: map['sku'] as String?,
      barcode: map['barcode'] as String?,
      category: map['category'] as String?,
      taxRate: ((map['tax_rate'] as num?) ?? 0).toDouble(),
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Convert to database Map
  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'lot_id': lotId,
      'product_name': productName,
      'unit_price': unitPrice,
      'product_image': productImage,
      'product_description': productDescription,
      'unit': unit,
      'sku': sku,
      'barcode': barcode,
      'category': category,
      'tax_rate': taxRate,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create a copy with modified fields
  ProductLotModel copyWith({
    int? productId,
    int? lotId,
    String? productName,
    double? unitPrice,
    String? productImage,
    String? productDescription,
    String? unit,
    String? sku,
    String? barcode,
    String? category,
    double? taxRate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductLotModel(
      productId: productId ?? this.productId,
      lotId: lotId ?? this.lotId,
      productName: productName ?? this.productName,
      unitPrice: unitPrice ?? this.unitPrice,
      productImage: productImage ?? this.productImage,
      productDescription: productDescription ?? this.productDescription,
      unit: unit ?? this.unit,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      taxRate: taxRate ?? this.taxRate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ProductLotModel(productId: $productId, lotId: $lotId, name: $productName, price: $unitPrice)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ProductLotModel &&
        other.productId == productId &&
        other.lotId == lotId &&
        other.productName == productName &&
        other.unitPrice == unitPrice &&
        other.unit == unit;
  }

  @override
  int get hashCode {
    return Object.hash(
      productId,
      lotId,
      productName,
      unitPrice,
      unit,
    );
  }
}
