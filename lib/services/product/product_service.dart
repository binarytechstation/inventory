import '../../data/database/database_helper.dart';
import '../../data/models/product_model.dart';

class ProductService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Get all products
  Future<List<ProductModel>> getAllProducts() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'products',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return maps.map((map) => ProductModel.fromMap(map)).toList();
  }

  // Get product by ID
  Future<ProductModel?> getProductById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ProductModel.fromMap(maps.first);
  }

  // Get product by barcode
  Future<ProductModel?> getProductByBarcode(String barcode) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ProductModel.fromMap(maps.first);
  }

  // Get product by SKU
  Future<ProductModel?> getProductBySku(String sku) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'products',
      where: 'sku = ?',
      whereArgs: [sku],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ProductModel.fromMap(maps.first);
  }

  // Search products
  Future<List<ProductModel>> searchProducts(String query) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'products',
      where: '(name LIKE ? OR barcode LIKE ? OR sku LIKE ?) AND is_active = ?',
      whereArgs: ['%$query%', '%$query%', '%$query%', 1],
      orderBy: 'name ASC',
    );
    return maps.map((map) => ProductModel.fromMap(map)).toList();
  }

  // Get products by category
  Future<List<ProductModel>> getProductsByCategory(String category) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'products',
      where: 'category = ? AND is_active = ?',
      whereArgs: [category, 1],
      orderBy: 'name ASC',
    );
    return maps.map((map) => ProductModel.fromMap(map)).toList();
  }

  // Get low stock products
  Future<List<ProductModel>> getLowStockProducts() async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT p.*, COALESCE(SUM(pb.quantity_remaining), 0) as current_stock
      FROM products p
      LEFT JOIN product_batches pb ON p.id = pb.product_id
      WHERE p.is_active = 1
      GROUP BY p.id
      HAVING current_stock <= p.reorder_level
      ORDER BY current_stock ASC
    ''');
    return maps.map((map) => ProductModel.fromMap(map)).toList();
  }

  // Create product
  Future<int> createProduct(ProductModel product) async {
    final db = await _dbHelper.database;

    // Check if SKU already exists
    if (product.sku != null && product.sku!.isNotEmpty) {
      final existing = await getProductBySku(product.sku!);
      if (existing != null) {
        throw Exception('Product with SKU ${product.sku} already exists');
      }
    }

    // Check if barcode already exists
    if (product.barcode != null && product.barcode!.isNotEmpty) {
      final existing = await getProductByBarcode(product.barcode!);
      if (existing != null) {
        throw Exception('Product with barcode ${product.barcode} already exists');
      }
    }

    return await db.insert('products', product.toMap());
  }

  // Update product
  Future<int> updateProduct(ProductModel product) async {
    final db = await _dbHelper.database;

    // Check if SKU already exists (excluding current product)
    if (product.sku != null && product.sku!.isNotEmpty) {
      final existing = await getProductBySku(product.sku!);
      if (existing != null && existing.id != product.id) {
        throw Exception('Product with SKU ${product.sku} already exists');
      }
    }

    // Check if barcode already exists (excluding current product)
    if (product.barcode != null && product.barcode!.isNotEmpty) {
      final existing = await getProductByBarcode(product.barcode!);
      if (existing != null && existing.id != product.id) {
        throw Exception('Product with barcode ${product.barcode} already exists');
      }
    }

    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  // Delete product (deactivate)
  Future<int> deleteProduct(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'products',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get total product count
  Future<int> getProductCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE is_active = 1',
    );
    return result.first['count'] as int;
  }

  // Get product stock from batches
  Future<double> getProductStock(int productId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(quantity_remaining), 0) as stock FROM product_batches WHERE product_id = ?',
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
}
