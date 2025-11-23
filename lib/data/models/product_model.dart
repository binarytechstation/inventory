class ProductModel {
  final int? id;
  final String name;
  final String? sku;
  final String? barcode;
  final String? description;
  final String unit;
  final double defaultPurchasePrice;
  final double defaultSellingPrice;
  final double taxRate;
  final int reorderLevel;
  final String? category;
  final String? imagePath;
  final int? supplierId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed fields (not from database)
  double? currentStock;
  double? averageCost;

  ProductModel({
    this.id,
    required this.name,
    this.sku,
    this.barcode,
    this.description,
    this.unit = 'piece',
    this.defaultPurchasePrice = 0,
    this.defaultSellingPrice = 0,
    this.taxRate = 0,
    this.reorderLevel = 0,
    this.category,
    this.imagePath,
    this.supplierId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.currentStock,
    this.averageCost,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'description': description,
      'unit': unit,
      'default_purchase_price': defaultPurchasePrice,
      'default_selling_price': defaultSellingPrice,
      'tax_rate': taxRate,
      'reorder_level': reorderLevel,
      'category': category,
      'image_path': imagePath,
      'supplier_id': supplierId,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      sku: map['sku'] as String?,
      barcode: map['barcode'] as String?,
      description: map['description'] as String?,
      unit: map['unit'] as String? ?? 'piece',
      defaultPurchasePrice: (map['default_purchase_price'] as num?)?.toDouble() ?? 0,
      defaultSellingPrice: (map['default_selling_price'] as num?)?.toDouble() ?? 0,
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0,
      reorderLevel: map['reorder_level'] as int? ?? 0,
      category: map['category'] as String?,
      imagePath: map['image_path'] as String?,
      supplierId: map['supplier_id'] as int?,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      currentStock: (map['current_stock'] as num?)?.toDouble(),
      averageCost: (map['average_cost'] as num?)?.toDouble(),
    );
  }

  ProductModel copyWith({
    int? id,
    String? name,
    String? sku,
    String? barcode,
    String? description,
    String? unit,
    double? defaultPurchasePrice,
    double? defaultSellingPrice,
    double? taxRate,
    int? reorderLevel,
    String? category,
    String? imagePath,
    int? supplierId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? currentStock,
    double? averageCost,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      defaultPurchasePrice: defaultPurchasePrice ?? this.defaultPurchasePrice,
      defaultSellingPrice: defaultSellingPrice ?? this.defaultSellingPrice,
      taxRate: taxRate ?? this.taxRate,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      category: category ?? this.category,
      imagePath: imagePath ?? this.imagePath,
      supplierId: supplierId ?? this.supplierId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currentStock: currentStock ?? this.currentStock,
      averageCost: averageCost ?? this.averageCost,
    );
  }

  bool isLowStock() {
    if (currentStock == null) return false;
    return currentStock! <= reorderLevel;
  }
}
