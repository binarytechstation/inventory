import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/customer_model.dart';

class CustomerService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Get all active customers
  Future<List<CustomerModel>> getAllCustomers({String sortBy = 'name'}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: sortBy,
    );
    return List.generate(maps.length, (i) => CustomerModel.fromMap(maps[i]));
  }

  /// Get customer by ID
  Future<CustomerModel?> getCustomerById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'id = ? AND is_active = ?',
      whereArgs: [id, 1],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CustomerModel.fromMap(maps.first);
  }

  /// Search customers by name, company, phone, or email
  Future<List<CustomerModel>> searchCustomers(String query) async {
    final db = await _dbHelper.database;
    final searchQuery = '%$query%';
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
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
    return List.generate(maps.length, (i) => CustomerModel.fromMap(maps[i]));
  }

  /// Create a new customer
  Future<int> createCustomer(CustomerModel customer) async {
    final db = await _dbHelper.database;
    return await db.insert(
      'customers',
      customer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing customer
  Future<int> updateCustomer(CustomerModel customer) async {
    final db = await _dbHelper.database;
    return await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  /// Deactivate a customer (soft delete)
  Future<int> deactivateCustomer(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'customers',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete a customer permanently (use with caution)
  Future<int> deleteCustomer(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get total customer count
  Future<int> getCustomerCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM customers WHERE is_active = 1',
    );
    final count = result.first['count'];
    return count is int ? count : 0;
  }

  /// Check if customer name or company name already exists
  Future<bool> isCustomerExists(String name, String companyName, {int? excludeId}) async {
    final db = await _dbHelper.database;
    final whereClause = excludeId != null
        ? 'is_active = ? AND (name = ? OR company_name = ?) AND id != ?'
        : 'is_active = ? AND (name = ? OR company_name = ?)';
    final whereArgs = excludeId != null
        ? [1, name, companyName, excludeId]
        : [1, name, companyName];

    final result = await db.query(
      'customers',
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Get customers with credit balance
  Future<List<CustomerModel>> getCustomersWithCredit() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'is_active = ? AND current_balance > ?',
      whereArgs: [1, 0],
      orderBy: 'current_balance DESC',
    );
    return List.generate(maps.length, (i) => CustomerModel.fromMap(maps[i]));
  }

  /// Update customer current balance
  Future<int> updateCurrentBalance(int customerId, double newBalance) async {
    final db = await _dbHelper.database;
    return await db.update(
      'customers',
      {'current_balance': newBalance, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  /// Get customers with recent purchases
  Future<List<Map<String, dynamic>>> getCustomersWithPurchases({int limit = 10}) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT
        c.*,
        COUNT(t.id) as purchase_count,
        SUM(t.total) as total_purchases,
        MAX(t.date) as last_purchase_date
      FROM customers c
      LEFT JOIN transactions t ON c.id = t.party_id AND t.party_type = 'customer' AND t.type = 'SELL'
      WHERE c.is_active = 1
      GROUP BY c.id
      ORDER BY last_purchase_date DESC
      LIMIT ?
    ''', [limit]);
    return result;
  }

  /// Get customer statistics
  Future<Map<String, dynamic>> getCustomerStats(int customerId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT
        COUNT(t.id) as total_purchases,
        SUM(t.total) as total_amount,
        AVG(t.total) as average_purchase,
        MAX(t.date) as last_purchase_date,
        MIN(t.date) as first_purchase_date
      FROM transactions t
      WHERE t.party_id = ? AND t.party_type = 'customer' AND t.type = 'SELL'
    ''', [customerId]);

    return result.isNotEmpty ? result.first : {
      'total_purchases': 0,
      'total_amount': 0.0,
      'average_purchase': 0.0,
      'last_purchase_date': null,
      'first_purchase_date': null,
    };
  }

  /// Get customers nearing credit limit
  Future<List<CustomerModel>> getCustomersNearCreditLimit({double threshold = 0.8}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM customers
      WHERE is_active = 1
        AND credit_limit > 0
        AND current_balance >= (credit_limit * ?)
      ORDER BY current_balance DESC
    ''', [threshold]);
    return List.generate(maps.length, (i) => CustomerModel.fromMap(maps[i]));
  }
}
