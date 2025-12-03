import '../../data/database/database_helper.dart';
import '../../data/models/product_lot_model.dart';
import '../../data/models/lot_model.dart';
import '../../data/models/product_model.dart';

/// Product Service for lot-based inventory system
/// Note: Products are now tied to lots with composite key (product_id, lot_id)
class ProductService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Get all products across all lots (aggregated)
  Future<List<Map<String, dynamic>>> getAllProductsAggregated({String sortBy = 'product_name'}) async {
    final db = await _dbHelper.database;

    // Aggregate products across all lots BY PRODUCT NAME
    // This groups same product names together even if they have different product_ids
    final maps = await db.rawQuery('''
      SELECT
        MIN(p.product_id) as product_id,
        p.product_name,
        p.unit,
        p.category,
        p.product_image,
        p.product_description,
        SUM(s.count) as total_stock,
        SUM(s.count - COALESCE(s.reserved_quantity, 0)) as total_available,
        AVG(p.unit_price) as avg_price,
        MIN(p.unit_price) as min_price,
        MAX(p.unit_price) as max_price,
        COUNT(DISTINCT p.lot_id) as lots_count,
        MIN(s.reorder_level) as reorder_level,
        MAX(p.is_active) as is_active
      FROM products p
      INNER JOIN stock s ON p.product_id = s.product_id AND p.lot_id = s.lot_id
      WHERE p.is_active = 1
      GROUP BY p.product_name, p.unit, p.category, p.product_image, p.product_description
      ORDER BY p.$sortBy ASC
    ''');

    return maps;
  }

  // Get products in a specific lot
  Future<List<Map<String, dynamic>>> getProductsInLot(int lotId) async {
    final db = await _dbHelper.database;

    final maps = await db.rawQuery('''
      SELECT
        p.product_id,
        p.lot_id,
        p.product_name,
        p.unit_price,
        p.unit,
        p.category,
        p.sku,
        p.barcode,
        p.product_image,
        p.product_description,
        s.count as current_stock,
        (s.count - COALESCE(s.reserved_quantity, 0)) as available_stock,
        s.reorder_level,
        l.received_date,
        l.description as lot_description
      FROM products p
      INNER JOIN stock s ON p.product_id = s.product_id AND p.lot_id = s.lot_id
      INNER JOIN lots l ON p.lot_id = l.lot_id
      WHERE p.lot_id = ?
        AND p.is_active = 1
      ORDER BY p.product_name ASC
    ''', [lotId]);

    return maps;
  }

  // Get all lots for a specific product (by product_name)
  Future<List<Map<String, dynamic>>> getAllLotsForProduct(String productName) async {
    final db = await _dbHelper.database;

    final maps = await db.rawQuery('''
      SELECT
        p.product_id,
        p.lot_id,
        p.product_name,
        p.unit_price,
        p.selling_price,
        p.unit,
        p.category,
        p.sku,
        p.barcode,
        p.product_image,
        p.product_description,
        s.count as current_stock,
        (s.count - COALESCE(s.reserved_quantity, 0)) as available_stock,
        s.reorder_level,
        l.received_date,
        l.description as lot_description
      FROM products p
      INNER JOIN stock s ON p.product_id = s.product_id AND p.lot_id = s.lot_id
      INNER JOIN lots l ON p.lot_id = l.lot_id
      WHERE p.product_name = ?
        AND p.is_active = 1
      ORDER BY l.received_date DESC, p.lot_id DESC
    ''', [productName]);

    return maps;
  }

  // Get all unique product names for autocomplete
  Future<List<String>> getAllProductNames() async {
    final db = await _dbHelper.database;

    final maps = await db.rawQuery('''
      SELECT DISTINCT product_name
      FROM products
      WHERE is_active = 1
      ORDER BY product_name ASC
    ''');

    return maps.map((m) => m['product_name'] as String).toList();
  }

  // Check if a product name already exists
  Future<bool> productNameExists(String productName) async {
    final db = await _dbHelper.database;

    final maps = await db.query(
      'products',
      where: 'product_name = ? AND is_active = 1',
      whereArgs: [productName],
      limit: 1,
    );

    return maps.isNotEmpty;
  }

  // Get product details by name (for reusing in new lots)
  Future<Map<String, dynamic>?> getProductByName(String productName) async {
    final db = await _dbHelper.database;

    final maps = await db.rawQuery('''
      SELECT
        product_name,
        unit,
        category,
        product_image,
        product_description
      FROM products
      WHERE product_name = ? AND is_active = 1
      LIMIT 1
    ''', [productName]);

    return maps.isNotEmpty ? maps.first : null;
  }

  // Update product details (description, category, etc. - NOT lot/inventory data)
  Future<void> updateProductDetails({
    required String productName,
    String? newName,
    String? category,
    String? description,
    String? imagePath,
  }) async {
    final db = await _dbHelper.database;

    final updateData = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (newName != null) updateData['product_name'] = newName;
    if (category != null) updateData['category'] = category;
    if (description != null) updateData['product_description'] = description;
    if (imagePath != null) updateData['product_image'] = imagePath;

    await db.update(
      'products',
      updateData,
      where: 'product_name = ?',
      whereArgs: [productName],
    );
  }

  // Soft delete product by name (sets is_active = 0 for all lots)
  Future<void> deleteProductByName(String productName) async {
    final db = await _dbHelper.database;

    await db.update(
      'products',
      {
        'is_active': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'product_name = ?',
      whereArgs: [productName],
    );
  }

  // Get product details across all lots
  Future<Map<String, dynamic>?> getProductAggregated(int productId) async {
    final db = await _dbHelper.database;

    final maps = await db.rawQuery('''
      SELECT
        p.product_id,
        p.product_name,
        p.unit,
        p.category,
        p.product_image,
        p.product_description,
        SUM(s.count) as total_stock,
        SUM(s.count - COALESCE(s.reserved_quantity, 0)) as total_available,
        AVG(p.unit_price) as avg_price,
        MIN(p.unit_price) as min_price,
        MAX(p.unit_price) as max_price,
        COUNT(DISTINCT p.lot_id) as lots_count
      FROM products p
      INNER JOIN stock s ON p.product_id = s.product_id AND p.lot_id = s.lot_id
      WHERE p.product_id = ?
        AND p.is_active = 1
      GROUP BY p.product_id, p.product_name, p.unit, p.category, p.product_image, p.product_description
    ''', [productId]);

    return maps.isNotEmpty ? maps.first : null;
  }

  // Get specific product in specific lot
  Future<Map<String, dynamic>?> getProductInLot(int productId, int lotId) async {
    final db = await _dbHelper.database;

    final maps = await db.rawQuery('''
      SELECT
        p.*,
        s.count as current_stock,
        (s.count - COALESCE(s.reserved_quantity, 0)) as available_stock,
        s.reorder_level,
        l.received_date,
        l.description as lot_description
      FROM products p
      INNER JOIN stock s ON p.product_id = s.product_id AND p.lot_id = s.lot_id
      INNER JOIN lots l ON p.lot_id = l.lot_id
      WHERE p.product_id = ? AND p.lot_id = ?
      LIMIT 1
    ''', [productId, lotId]);

    return maps.isNotEmpty ? maps.first : null;
  }

  // Search products across all lots
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final db = await _dbHelper.database;

    final maps = await db.rawQuery('''
      SELECT
        p.product_id,
        p.lot_id,
        p.product_name,
        p.unit_price,
        p.unit,
        p.category,
        p.sku,
        p.barcode,
        s.count as current_stock,
        (s.count - COALESCE(s.reserved_quantity, 0)) as available_stock,
        l.received_date,
        l.description as lot_description
      FROM products p
      INNER JOIN stock s ON p.product_id = s.product_id AND p.lot_id = s.lot_id
      INNER JOIN lots l ON p.lot_id = l.lot_id
      WHERE (p.product_name LIKE ? OR p.barcode LIKE ? OR p.sku LIKE ?)
        AND p.is_active = 1
        AND s.count > 0
      ORDER BY l.received_date DESC, p.product_name ASC
    ''', ['%$query%', '%$query%', '%$query%']);

    return maps;
  }

  // Get products by category (aggregated)
  Future<List<Map<String, dynamic>>> getProductsByCategory(String category) async {
    final db = await _dbHelper.database;

    final maps = await db.rawQuery('''
      SELECT
        p.product_id,
        p.product_name,
        p.unit,
        p.category,
        SUM(s.count) as total_stock,
        AVG(p.unit_price) as avg_price,
        COUNT(DISTINCT p.lot_id) as lots_count
      FROM products p
      INNER JOIN stock s ON p.product_id = s.product_id AND p.lot_id = s.lot_id
      WHERE p.category = ? AND p.is_active = 1
      GROUP BY p.product_id, p.product_name, p.unit, p.category
      ORDER BY p.product_name ASC
    ''', [category]);

    return maps;
  }

  // Get low stock products
  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    final db = await _dbHelper.database;

    final maps = await db.rawQuery('''
      SELECT
        p.product_id,
        p.lot_id,
        p.product_name,
        p.unit_price,
        p.unit,
        s.count,
        s.reorder_level,
        l.received_date,
        l.description as lot_description
      FROM products p
      INNER JOIN stock s ON p.product_id = s.product_id AND p.lot_id = s.lot_id
      INNER JOIN lots l ON p.lot_id = l.lot_id
      WHERE s.count <= s.reorder_level
        AND s.reorder_level > 0
        AND p.is_active = 1
      ORDER BY (s.count / NULLIF(s.reorder_level, 0)) ASC
    ''');

    return maps;
  }

  // Create product in a lot
  Future<void> createProductInLot({
    required int lotId,
    required int productId,
    required String productName,
    required double unitPrice,
    String? productImage,
    String? productDescription,
    String unit = 'piece',
    String? sku,
    String? barcode,
    String? category,
    double taxRate = 0.0,
    required double initialStock,
    double reorderLevel = 0.0,
  }) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      // Check if there's an existing product with the same name and copy its details
      final existingProducts = await txn.query(
        'products',
        where: 'product_name = ? AND is_active = 1',
        whereArgs: [productName],
        limit: 1,
      );

      // If product exists, inherit image, category, and description
      if (existingProducts.isNotEmpty) {
        final existing = existingProducts.first;
        productImage ??= existing['product_image'] as String?;
        productDescription ??= existing['product_description'] as String?;
        category ??= existing['category'] as String?;
        sku ??= existing['sku'] as String?;
        barcode ??= existing['barcode'] as String?;
      }

      // 1. Create product in lot
      await txn.insert('products', {
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
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });

      // 2. Create stock record
      await txn.insert('stock', {
        'lot_id': lotId,
        'product_id': productId,
        'count': initialStock,
        'reorder_level': reorderLevel,
        'reserved_quantity': 0.0,
        'last_stock_update': now,
        'created_at': now,
        'updated_at': now,
      });

      // 3. Create history record
      await txn.insert('lot_history', {
        'lot_id': lotId,
        'product_id': productId,
        'action': 'CREATED',
        'quantity_change': initialStock,
        'quantity_before': 0.0,
        'quantity_after': initialStock,
        'reference_type': 'PRODUCT_CREATION',
        'notes': 'Product created in lot',
        'created_at': now,
      });
    });
  }

  // Update product in lot
  Future<int> updateProductInLot(ProductLotModel product) async {
    final db = await _dbHelper.database;

    return await db.update(
      'products',
      product.toMap(),
      where: 'product_id = ? AND lot_id = ?',
      whereArgs: [product.productId, product.lotId],
    );
  }

  // Delete product (deactivate)
  Future<int> deleteProduct(int productId, int lotId) async {
    final db = await _dbHelper.database;
    return await db.update(
      'products',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'product_id = ? AND lot_id = ?',
      whereArgs: [productId, lotId],
    );
  }

  // Get total unique product count
  Future<int> getProductCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(DISTINCT product_id) as count FROM products WHERE is_active = 1',
    );
    return result.first['count'] as int;
  }

  // Get product stock from all lots
  Future<double> getProductStock(int productId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(s.count), 0) as stock FROM stock s INNER JOIN products p ON s.product_id = p.product_id AND s.lot_id = p.lot_id WHERE p.product_id = ? AND p.is_active = 1',
      [productId],
    );
    return (result.first['stock'] as num?)?.toDouble() ?? 0.0;
  }

  // Get all categories
  Future<List<String>> getAllCategories() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND category != "" ORDER BY category',
    );
    return result.map((row) => row['category'] as String).toList();
  }

  // Get product master catalog (for quick selection)
  Future<List<Map<String, dynamic>>> getProductMasterCatalog() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'product_master',
      where: 'is_active = 1',
      orderBy: 'product_name ASC',
    );
    return result;
  }

  // Get next product ID
  Future<int> getNextProductId() async {
    final db = await _dbHelper.database;

    // Try product_master first
    final masterResult = await db.rawQuery(
      'SELECT COALESCE(MAX(product_id), 0) + 1 as next_id FROM product_master'
    );

    final masterId = masterResult.first['next_id'] as int;

    // Also check products table
    final productsResult = await db.rawQuery(
      'SELECT COALESCE(MAX(product_id), 0) + 1 as next_id FROM products'
    );

    final productsId = productsResult.first['next_id'] as int;

    // Return the higher value
    return masterId > productsId ? masterId : productsId;
  }

  // Get all lots
  Future<List<LotModel>> getAllLots() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'lots',
      where: 'is_active = 1',
      orderBy: 'received_date DESC',
    );
    return maps.map((map) => LotModel.fromMap(map)).toList();
  }

  // Get lots with product counts
  Future<List<Map<String, dynamic>>> getLotsWithSummary() async {
    final db = await _dbHelper.database;

    final maps = await db.rawQuery('''
      SELECT
        l.*,
        COUNT(DISTINCT p.product_id) as product_count,
        SUM(s.count) as total_items,
        SUM(s.count * p.unit_price) as total_value
      FROM lots l
      LEFT JOIN products p ON l.lot_id = p.lot_id AND p.is_active = 1
      LEFT JOIN stock s ON p.product_id = s.product_id AND p.lot_id = s.lot_id
      WHERE l.is_active = 1
      GROUP BY l.lot_id
      ORDER BY l.received_date DESC
    ''');

    return maps;
  }

  // ============================================================
  // COMPATIBILITY METHODS (for legacy UI screens)
  // ============================================================

  /// Get all products in old ProductModel-compatible format (aggregated across lots)
  /// This method is for backward compatibility with existing UI screens
  Future<List<dynamic>> getAllProducts({String sortBy = 'name'}) async {
    final aggregated = await getAllProductsAggregated(sortBy: 'product_name');

    // Convert to ProductModel-like objects with aggregated data
    return aggregated.map((product) {
      return {
        'id': product['product_id'],
        'name': product['product_name'],
        'sku': null, // Not available in aggregated view
        'barcode': null, // Not available in aggregated view
        'description': product['product_description'],
        'unit': product['unit'],
        'default_purchase_price': product['avg_price'],
        'default_selling_price': product['avg_price'],
        'tax_rate': 0.0,
        'reorder_level': product['reorder_level'] ?? 0,
        'category': product['category'],
        'image_path': product['product_image'],
        'supplier_id': null,
        'is_active': 1,
        'current_stock': product['total_stock'] ?? 0.0,
        'lots_count': product['lots_count'] ?? 0,
        'min_price': product['min_price'],
        'max_price': product['max_price'],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
    }).toList();
  }

  /// Get product by ID in old ProductModel-compatible format
  Future<dynamic> getProductById(int id) async {
    final product = await getProductAggregated(id);
    if (product == null) return null;

    return {
      'id': product['product_id'],
      'name': product['product_name'],
      'sku': null,
      'barcode': null,
      'description': product['product_description'],
      'unit': product['unit'],
      'default_purchase_price': product['avg_price'],
      'default_selling_price': product['avg_price'],
      'tax_rate': 0.0,
      'reorder_level': 0,
      'category': product['category'],
      'image_path': product['product_image'],
      'supplier_id': null,
      'is_active': 1,
      'current_stock': product['total_stock'] ?? 0.0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Deactivate all instances of a product across all lots
  Future<int> deactivateProduct(int productId) async {
    final db = await _dbHelper.database;
    return await db.update(
      'products',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  /// Create a product - compatibility method for old ProductModel
  /// Creates the product in a default lot (lot_id = 1)
  Future<int> createProduct(ProductModel product) async {
    final db = await _dbHelper.database;

    // Get or create default lot
    int defaultLotId = 1;
    final lots = await db.query('lots', where: 'lot_id = ?', whereArgs: [defaultLotId]);

    if (lots.isEmpty) {
      // Create default lot if it doesn't exist
      await db.insert('lots', {
        'lot_id': defaultLotId,
        'received_date': DateTime.now().toIso8601String(),
        'description': 'Default Lot',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    // Get next product ID
    final nextId = await getNextProductId();

    // Insert into products table
    await db.insert('products', {
      'product_id': nextId,
      'lot_id': defaultLotId,
      'product_name': product.name,
      'unit_price': product.defaultPurchasePrice,
      'product_image': product.imagePath,
      'product_description': product.description,
      'unit': product.unit,
      'category': product.category,
      'is_active': product.isActive ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Insert into stock table
    await db.insert('stock', {
      'lot_id': defaultLotId,
      'product_id': nextId,
      'count': product.currentStock ?? 0,
      'reorder_level': product.reorderLevel ?? 0,
      'reserved_quantity': 0,
      'last_stock_update': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    return nextId;
  }

  /// Update a product - compatibility method for old ProductModel
  /// Updates the product in the default lot (lot_id = 1)
  Future<int> updateProduct(ProductModel product) async {
    final db = await _dbHelper.database;
    final defaultLotId = 1;

    // Update products table
    final rowsAffected = await db.update(
      'products',
      {
        'product_name': product.name,
        'unit_price': product.defaultPurchasePrice,
        'product_image': product.imagePath,
        'product_description': product.description,
        'unit': product.unit,
        'category': product.category,
        'is_active': product.isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'product_id = ? AND lot_id = ?',
      whereArgs: [product.id, defaultLotId],
    );

    // Update stock if it exists
    final stockExists = await db.query(
      'stock',
      where: 'product_id = ? AND lot_id = ?',
      whereArgs: [product.id, defaultLotId],
    );

    if (stockExists.isNotEmpty) {
      await db.update(
        'stock',
        {
          'count': product.currentStock ?? 0,
          'reorder_level': product.reorderLevel,
          'last_stock_update': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'product_id = ? AND lot_id = ?',
        whereArgs: [product.id, defaultLotId],
      );
    } else {
      // Create stock record if it doesn't exist
      await db.insert('stock', {
        'lot_id': defaultLotId,
        'product_id': product.id,
        'count': product.currentStock ?? 0,
        'reorder_level': product.reorderLevel,
        'reserved_quantity': 0,
        'last_stock_update': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    return rowsAffected;
  }

  /// Update lot-wise data for a specific product in a specific lot
  Future<void> updateLotData({
    required int productId,
    required int lotId,
    String? lotName,
    double? unitPrice,
    double? sellingPrice,
    double? currentStock,
    String? receivedDate,
    String? notes,
  }) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      // Update lot name (product name) if provided
      if (lotName != null) {
        await txn.update(
          'products',
          {
            'product_name': lotName,
            'updated_at': now,
          },
          where: 'product_id = ? AND lot_id = ?',
          whereArgs: [productId, lotId],
        );
      }

      // Update product prices if provided
      final Map<String, dynamic> priceUpdates = {'updated_at': now};
      if (unitPrice != null) priceUpdates['unit_price'] = unitPrice;
      if (sellingPrice != null) priceUpdates['selling_price'] = sellingPrice;

      if (priceUpdates.length > 1) {
        await txn.update(
          'products',
          priceUpdates,
          where: 'product_id = ? AND lot_id = ?',
          whereArgs: [productId, lotId],
        );
      }

      // Update stock if provided
      if (currentStock != null) {
        // Get current stock for history
        final stockQuery = await txn.query(
          'stock',
          where: 'product_id = ? AND lot_id = ?',
          whereArgs: [productId, lotId],
        );

        final oldStock = stockQuery.isNotEmpty
            ? (stockQuery.first['count'] as num?)?.toDouble() ?? 0.0
            : 0.0;

        await txn.update(
          'stock',
          {
            'count': currentStock,
            'last_stock_update': now,
            'updated_at': now,
          },
          where: 'product_id = ? AND lot_id = ?',
          whereArgs: [productId, lotId],
        );

        // Create history record
        await txn.insert('lot_history', {
          'lot_id': lotId,
          'product_id': productId,
          'action': 'MANUAL_ADJUSTMENT',
          'quantity_change': currentStock - oldStock,
          'quantity_before': oldStock,
          'quantity_after': currentStock,
          'reference_type': 'LOT_EDIT',
          'notes': notes ?? 'Manual lot adjustment via UI',
          'created_at': now,
        });
      }

      // Update lot received date if provided
      if (receivedDate != null) {
        await txn.update(
          'lots',
          {
            'received_date': receivedDate,
            'updated_at': now,
          },
          where: 'lot_id = ?',
          whereArgs: [lotId],
        );
      }

      // Update lot description/notes if provided
      if (notes != null) {
        await txn.update(
          'lots',
          {
            'description': notes,
            'updated_at': now,
          },
          where: 'lot_id = ?',
          whereArgs: [lotId],
        );
      }
    });
  }

  /// Get products grouped by category
  Future<Map<String, List<Map<String, dynamic>>>> getProductsGroupedByCategory() async {
    final products = await getAllProducts();
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var product in products) {
      final productMap = product as Map<String, dynamic>;
      final category = (productMap['category'] as String?) ?? 'Uncategorized';

      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(productMap);
    }

    return grouped;
  }
}
