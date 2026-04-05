import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/supplier_model.dart';

class SupplierService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Balance subquery: sum of remaining credit on unpaid BUY transactions only.
  /// This is the source of truth — derived from transaction data, not a stored counter
  /// which can drift when RETURN transactions (incorrectly) reduce it.
  static const _balanceSubquery = '''
    COALESCE((
      SELECT SUM(t.credit_amount)
      FROM transactions t
      WHERE t.party_id = s.id AND t.party_type = 'supplier'
        AND t.transaction_type = 'BUY'
        AND t.payment_status IN ('CREDIT', 'PARTIAL')
        AND t.status != 'CANCELLED'
    ), 0)
  ''';

  Future<List<SupplierModel>> getAllSuppliers({String sortBy = 'name'}) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT s.*, $_balanceSubquery as current_balance
      FROM suppliers s
      WHERE s.is_active = 1
      ORDER BY s.$sortBy
    ''');
    return maps.map((m) => SupplierModel.fromMap(m)).toList();
  }

  Future<SupplierModel?> getSupplierById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT s.*, $_balanceSubquery as current_balance
      FROM suppliers s
      WHERE s.id = ? AND s.is_active = 1
      LIMIT 1
    ''', [id]);
    if (maps.isEmpty) return null;
    return SupplierModel.fromMap(maps.first);
  }

  Future<List<SupplierModel>> searchSuppliers(String query) async {
    final db = await _dbHelper.database;
    final q = '%$query%';
    final maps = await db.query('suppliers',
        where: 'is_active = ? AND (name LIKE ? OR company_name LIKE ? OR phone LIKE ? OR email LIKE ?)',
        whereArgs: [1, q, q, q, q],
        orderBy: 'name');
    return maps.map((m) => SupplierModel.fromMap(m)).toList();
  }

  Future<int> createSupplier(SupplierModel supplier) async {
    final db = await _dbHelper.database;
    return await db.insert('suppliers', supplier.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateSupplier(SupplierModel supplier) async {
    final db = await _dbHelper.database;
    return await db.update('suppliers', supplier.toMap(), where: 'id = ?', whereArgs: [supplier.id]);
  }

  Future<int> deactivateSupplier(int id) async {
    final db = await _dbHelper.database;
    return await db.update('suppliers', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteSupplier(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getSupplierCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM suppliers WHERE is_active = 1');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<bool> isSupplierExists(String name, String companyName, {int? excludeId}) async {
    final db = await _dbHelper.database;
    final whereClause = excludeId != null
        ? 'is_active = ? AND (name = ? OR company_name = ?) AND id != ?'
        : 'is_active = ? AND (name = ? OR company_name = ?)';
    final whereArgs = excludeId != null ? [1, name, companyName, excludeId] : [1, name, companyName];
    final result = await db.query('suppliers', where: whereClause, whereArgs: whereArgs, limit: 1);
    return result.isNotEmpty;
  }

  /// Get all distinct companies and the dealers in each
  Future<Map<String, List<SupplierModel>>> getSuppliersByCompany() async {
    final suppliers = await getAllSuppliers(sortBy: 'name');
    final Map<String, List<SupplierModel>> grouped = {};
    for (final s in suppliers) {
      final company = s.companyName?.trim().isNotEmpty == true ? s.companyName! : '(No Company)';
      grouped.putIfAbsent(company, () => []).add(s);
    }
    return Map.fromEntries(grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  /// Get all suppliers (dealers) who have outstanding balance
  Future<List<SupplierModel>> getSuppliersWithDues() async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT s.*, $_balanceSubquery as current_balance
      FROM suppliers s
      WHERE s.is_active = 1
        AND ($_balanceSubquery) > 0
      ORDER BY current_balance DESC
    ''');
    return maps.map((m) => SupplierModel.fromMap(m)).toList();
  }

  /// Get total amount owed to all suppliers
  Future<double> getTotalPayable() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(
        (SELECT SUM(t.credit_amount) FROM transactions t
         WHERE t.party_id = s.id AND t.party_type = 'supplier'
           AND t.transaction_type = 'BUY'
           AND t.payment_status IN ('CREDIT', 'PARTIAL')
           AND t.status != 'CANCELLED')
      ), 0) as total
      FROM suppliers s WHERE s.is_active = 1
    ''');
    return (result.first['total'] as num).toDouble();
  }

  /// Update supplier balance (used when payment is made)
  Future<void> updateBalance(int supplierId, double newBalance) async {
    final db = await _dbHelper.database;
    await db.update('suppliers', {
      'current_balance': newBalance,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [supplierId]);
  }

  /// Get detailed stats for a supplier
  Future<Map<String, dynamic>> getSupplierStats(int supplierId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT
        COUNT(t.id) as total_purchases,
        COALESCE(SUM(t.total_amount), 0) as total_amount,
        COALESCE(SUM(t.paid_amount), 0)
          + COALESCE((SELECT SUM(amount) FROM supplier_payments WHERE supplier_id = ?), 0)
          as total_paid,
        (SELECT COALESCE(SUM(credit_amount), 0) FROM transactions
         WHERE party_id = ? AND party_type = 'supplier' AND transaction_type = 'BUY'
           AND payment_status IN ('CREDIT', 'PARTIAL') AND status != 'CANCELLED') as total_credit,
        MAX(t.transaction_date) as last_purchase_date
      FROM transactions t
      WHERE t.party_id = ? AND t.party_type = 'supplier' AND t.transaction_type = 'BUY'
        AND t.status != 'CANCELLED'
    ''', [supplierId, supplierId, supplierId]);
    return result.isNotEmpty ? result.first : {
      'total_purchases': 0, 'total_amount': 0.0,
      'total_paid': 0.0, 'total_credit': 0.0, 'last_purchase_date': null,
    };
  }

  Future<List<Map<String, dynamic>>> getSuppliersWithPurchases({int limit = 10}) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT s.*, COUNT(t.id) as purchase_count,
             COALESCE(SUM(t.total_amount), 0) as total_purchases,
             MAX(t.transaction_date) as last_purchase_date
      FROM suppliers s
      LEFT JOIN transactions t ON s.id = t.party_id AND t.party_type = 'supplier' AND t.transaction_type = 'BUY'
      WHERE s.is_active = 1
      GROUP BY s.id
      ORDER BY last_purchase_date DESC
      LIMIT ?
    ''', [limit]);
  }
}
