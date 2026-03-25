import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/customer_model.dart';

class CustomerService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<CustomerModel>> getAllCustomers({String sortBy = 'name'}) async {
    final db = await _dbHelper.database;
    final maps = await db.query('customers', where: 'is_active = ?', whereArgs: [1], orderBy: sortBy);
    return maps.map((m) => CustomerModel.fromMap(m)).toList();
  }

  Future<CustomerModel?> getCustomerById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('customers', where: 'id = ? AND is_active = ?', whereArgs: [id, 1], limit: 1);
    if (maps.isEmpty) return null;
    return CustomerModel.fromMap(maps.first);
  }

  Future<List<CustomerModel>> searchCustomers(String query) async {
    final db = await _dbHelper.database;
    final q = '%$query%';
    final maps = await db.query('customers',
        where: 'is_active = ? AND (name LIKE ? OR company_name LIKE ? OR phone LIKE ? OR email LIKE ?)',
        whereArgs: [1, q, q, q, q],
        orderBy: 'name');
    return maps.map((m) => CustomerModel.fromMap(m)).toList();
  }

  Future<int> createCustomer(CustomerModel customer) async {
    final db = await _dbHelper.database;
    return await db.insert('customers', customer.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateCustomer(CustomerModel customer) async {
    final db = await _dbHelper.database;
    return await db.update('customers', customer.toMap(), where: 'id = ?', whereArgs: [customer.id]);
  }

  Future<int> deactivateCustomer(int id) async {
    final db = await _dbHelper.database;
    return await db.update('customers', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCustomer(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getCustomerCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM customers WHERE is_active = 1');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<bool> isCustomerExists(String name, String companyName, {int? excludeId}) async {
    final db = await _dbHelper.database;
    final whereClause = excludeId != null
        ? 'is_active = ? AND (name = ? OR company_name = ?) AND id != ?'
        : 'is_active = ? AND (name = ? OR company_name = ?)';
    final whereArgs = excludeId != null ? [1, name, companyName, excludeId] : [1, name, companyName];
    final result = await db.query('customers', where: whereClause, whereArgs: whereArgs, limit: 1);
    return result.isNotEmpty;
  }

  Future<List<CustomerModel>> getCustomersWithCredit() async {
    final db = await _dbHelper.database;
    final maps = await db.query('customers',
        where: 'is_active = ? AND current_balance > ?', whereArgs: [1, 0], orderBy: 'current_balance DESC');
    return maps.map((m) => CustomerModel.fromMap(m)).toList();
  }

  Future<int> updateCurrentBalance(int customerId, double newBalance) async {
    final db = await _dbHelper.database;
    return await db.update('customers',
        {'current_balance': newBalance, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [customerId]);
  }

  /// Group customers by company name
  Future<Map<String, List<CustomerModel>>> getCustomersByCompany() async {
    final customers = await getAllCustomers(sortBy: 'name');
    final Map<String, List<CustomerModel>> grouped = {};
    for (final c in customers) {
      final company = c.companyName?.trim().isNotEmpty == true ? c.companyName! : '(Individual)';
      grouped.putIfAbsent(company, () => []).add(c);
    }
    return Map.fromEntries(grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  /// Total receivable from all customers
  Future<double> getTotalReceivable() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
        'SELECT COALESCE(SUM(current_balance), 0) as total FROM customers WHERE is_active = 1');
    return (result.first['total'] as num).toDouble();
  }

  Future<Map<String, dynamic>> getCustomerStats(int customerId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT
        COUNT(t.id) as total_purchases,
        COALESCE(SUM(t.total_amount), 0) as total_amount,
        COALESCE(SUM(t.paid_amount), 0)
          + COALESCE((SELECT SUM(amount) FROM customer_payments WHERE customer_id = ?), 0)
          as total_paid,
        (SELECT current_balance FROM customers WHERE id = ?) as total_credit,
        MAX(t.transaction_date) as last_purchase_date
      FROM transactions t
      WHERE t.party_id = ? AND t.party_type = 'customer' AND t.transaction_type = 'SELL'
        AND t.status != 'CANCELLED'
    ''', [customerId, customerId, customerId]);
    return result.isNotEmpty ? result.first : {
      'total_purchases': 0, 'total_amount': 0.0,
      'total_paid': 0.0, 'total_credit': 0.0, 'last_purchase_date': null,
    };
  }

  Future<List<CustomerModel>> getCustomersNearCreditLimit({double threshold = 0.8}) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT * FROM customers
      WHERE is_active = 1 AND credit_limit > 0 AND current_balance >= (credit_limit * ?)
      ORDER BY current_balance DESC
    ''', [threshold]);
    return maps.map((m) => CustomerModel.fromMap(m)).toList();
  }

  Future<List<Map<String, dynamic>>> getCustomersWithPurchases({int limit = 10}) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT c.*, COUNT(t.id) as purchase_count,
             COALESCE(SUM(t.total_amount), 0) as total_purchases,
             MAX(t.transaction_date) as last_purchase_date
      FROM customers c
      LEFT JOIN transactions t ON c.id = t.party_id AND t.party_type = 'customer' AND t.transaction_type = 'SELL'
      WHERE c.is_active = 1
      GROUP BY c.id
      ORDER BY last_purchase_date DESC
      LIMIT ?
    ''', [limit]);
  }
}
