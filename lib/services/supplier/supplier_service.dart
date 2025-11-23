import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/supplier_model.dart';

class SupplierService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Get all active suppliers
  Future<List<SupplierModel>> getAllSuppliers({String sortBy = 'name'}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'suppliers',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: sortBy,
    );
    return List.generate(maps.length, (i) => SupplierModel.fromMap(maps[i]));
  }

  /// Get supplier by ID
  Future<SupplierModel?> getSupplierById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'suppliers',
      where: 'id = ? AND is_active = ?',
      whereArgs: [id, 1],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return SupplierModel.fromMap(maps.first);
  }

  /// Search suppliers by name, company, phone, or email
  Future<List<SupplierModel>> searchSuppliers(String query) async {
    final db = await _dbHelper.database;
    final searchQuery = '%$query%';
    final List<Map<String, dynamic>> maps = await db.query(
      'suppliers',
      where: '''
        is_active = ? AND (
          name LIKE ? OR
          company_name LIKE ? OR
          phone LIKE ? OR
          email LIKE ?
        )
      ''',
      whereArgs: [1, searchQuery, searchQuery, searchQuery, searchQuery],
      orderBy: 'name',
    );
    return List.generate(maps.length, (i) => SupplierModel.fromMap(maps[i]));
  }

  /// Create a new supplier
  Future<int> createSupplier(SupplierModel supplier) async {
    final db = await _dbHelper.database;
    return await db.insert(
      'suppliers',
      supplier.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing supplier
  Future<int> updateSupplier(SupplierModel supplier) async {
    final db = await _dbHelper.database;
    return await db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  /// Deactivate a supplier (soft delete)
  Future<int> deactivateSupplier(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'suppliers',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete a supplier permanently (use with caution)
  Future<int> deleteSupplier(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get total supplier count
  Future<int> getSupplierCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM suppliers WHERE is_active = 1',
    );
    final count = result.first['count'];
    return count is int ? count : 0;
  }

  /// Check if supplier name or company name already exists
  Future<bool> isSupplierExists(String name, String companyName, {int? excludeId}) async {
    final db = await _dbHelper.database;
    final whereClause = excludeId != null
        ? 'is_active = ? AND (name = ? OR company_name = ?) AND id != ?'
        : 'is_active = ? AND (name = ? OR company_name = ?)';
    final whereArgs = excludeId != null
        ? [1, name, companyName, excludeId]
        : [1, name, companyName];

    final result = await db.query(
      'suppliers',
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Get suppliers with recent purchases
  Future<List<Map<String, dynamic>>> getSuppliersWithPurchases({int limit = 10}) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT
        s.*,
        COUNT(t.id) as purchase_count,
        SUM(t.total) as total_purchases,
        MAX(t.date) as last_purchase_date
      FROM suppliers s
      LEFT JOIN transactions t ON s.id = t.party_id AND t.party_type = 'supplier' AND t.type = 'BUY'
      WHERE s.is_active = 1
      GROUP BY s.id
      ORDER BY last_purchase_date DESC
      LIMIT ?
    ''', [limit]);
    return result;
  }

  /// Get supplier statistics
  Future<Map<String, dynamic>> getSupplierStats(int supplierId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT
        COUNT(t.id) as total_purchases,
        SUM(t.total) as total_amount,
        AVG(t.total) as average_purchase,
        MAX(t.date) as last_purchase_date,
        MIN(t.date) as first_purchase_date
      FROM transactions t
      WHERE t.party_id = ? AND t.party_type = 'supplier' AND t.type = 'BUY'
    ''', [supplierId]);

    return result.isNotEmpty ? result.first : {
      'total_purchases': 0,
      'total_amount': 0.0,
      'average_purchase': 0.0,
      'last_purchase_date': null,
      'first_purchase_date': null,
    };
  }
}
