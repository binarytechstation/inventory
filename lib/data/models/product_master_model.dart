/// Product Master Model - Optional catalog of products independent of lots
/// Used for quick product selection when adding to new lots
class ProductMasterModel {
  final int? productId;
  final String productName;
  final String defaultUnit;
  final String? defaultCategory;
  final String? defaultSkuPrefix;
  final String? defaultImage;
  final String? defaultDescription;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductMasterModel({
    this.productId,
    required this.productName,
    this.defaultUnit = 'piece',
    this.defaultCategory,
    this.defaultSkuPrefix,
    this.defaultImage,
    this.defaultDescription,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Convert from database Map
  factory ProductMasterModel.fromMap(Map<String, dynamic> map) {
    return ProductMasterModel(
      productId: map['product_id'] as int?,
      productName: map['product_name'] as String,
      defaultUnit: (map['default_unit'] as String?) ?? 'piece',
      defaultCategory: map['default_category'] as String?,
      defaultSkuPrefix: map['default_sku_prefix'] as String?,
      defaultImage: map['default_image'] as String?,
      defaultDescription: map['default_description'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Convert to database Map
  Map<String, dynamic> toMap() {
    return {
      if (productId != null) 'product_id': productId,
      'product_name': productName,
      'default_unit': defaultUnit,
      'default_category': defaultCategory,
      'default_sku_prefix': defaultSkuPrefix,
      'default_image': defaultImage,
      'default_description': defaultDescription,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create a copy with modified fields
  ProductMasterModel copyWith({
    int? productId,
    String? productName,
    String? defaultUnit,
    String? defaultCategory,
    String? defaultSkuPrefix,
    String? defaultImage,
    String? defaultDescription,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductMasterModel(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      defaultUnit: defaultUnit ?? this.defaultUnit,
      defaultCategory: defaultCategory ?? this.defaultCategory,
      defaultSkuPrefix: defaultSkuPrefix ?? this.defaultSkuPrefix,
      defaultImage: defaultImage ?? this.defaultImage,
      defaultDescription: defaultDescription ?? this.defaultDescription,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ProductMasterModel(productId: $productId, name: $productName, unit: $defaultUnit)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ProductMasterModel &&
        other.productId == productId &&
        other.productName == productName &&
        other.defaultUnit == defaultUnit;
  }

  @override
  int get hashCode {
    return Object.hash(
      productId,
      productName,
      defaultUnit,
    );
  }
}
