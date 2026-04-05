import '../../data/database/database_helper.dart';
import '../../data/models/defective_stock_model.dart';

class DefectiveStockService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<DefectiveStockModel>> getAllDefectiveStock() async {
    final db = await _dbHelper.database;
    final rows = await db.query('defective_stock', orderBy: 'reported_at DESC');
    return rows.map((r) => DefectiveStockModel.fromMap(r)).toList();
  }

  Future<List<DefectiveStockModel>> getDefectiveStockByProduct(int productId, int lotId) async {
    final db = await _dbHelper.database;
    final rows = await db.query('defective_stock',
        where: 'product_id = ? AND lot_id = ?', whereArgs: [productId, lotId]);
    return rows.map((r) => DefectiveStockModel.fromMap(r)).toList();
  }

  Future<List<DefectiveStockModel>> getPendingSupplierReturns() async {
    final db = await _dbHelper.database;
    final rows = await db.query('defective_stock',
        where: "supplier_return_status = 'PENDING' AND is_refundable = 1",
        orderBy: 'reported_at DESC');
    return rows.map((r) => DefectiveStockModel.fromMap(r)).toList();
  }

  Future<int> addDefectiveStock(DefectiveStockModel item) async {
    final db = await _dbHelper.database;
    return await db.insert('defective_stock', item.toMap());
  }

  /// Mark defective items as accepted by supplier (they will refund)
  Future<void> markSupplierAccepted(int defectiveId, int returnTransactionId) async {
    final db = await _dbHelper.database;
    await db.update('defective_stock', {
      'supplier_return_status': 'ACCEPTED',
      'supplier_return_transaction_id': returnTransactionId,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [defectiveId]);
  }

  /// Mark defective items as rejected by supplier (not refundable)
  Future<void> markSupplierRejected(int defectiveId) async {
    final db = await _dbHelper.database;
    await db.update('defective_stock', {
      'supplier_return_status': 'REJECTED',
      'is_refundable': 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [defectiveId]);
  }

  /// Get total defective quantity for a product across all lots
  Future<double> getTotalDefectiveQuantity(int productId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
        'SELECT COALESCE(SUM(quantity), 0) as total FROM defective_stock WHERE product_id = ?',
        [productId]);
    return (result.first['total'] as num).toDouble();
  }

  /// Restore a defective item back to sellable stock after inspection.
  /// Updates stock.count, marks the defective record RETURNED_TO_STOCK,
  /// and writes an audit entry to lot_history.
  Future<void> returnToStock({
    required int defectiveId,
    required int productId,
    required int lotId,
    required double quantity,
    int? userId,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // 1. Get current stock count for audit trail
      final stockRows = await txn.query(
        'stock',
        columns: ['count'],
        where: 'product_id = ? AND lot_id = ?',
        whereArgs: [productId, lotId],
      );
      final before = stockRows.isNotEmpty
          ? (stockRows.first['count'] as num).toDouble()
          : 0.0;
      final after = before + quantity;

      // 2. Add quantity back to stock
      await txn.rawUpdate('''
        UPDATE stock SET count = count + ?, last_stock_update = ?, updated_at = ?
        WHERE product_id = ? AND lot_id = ?
      ''', [quantity, now, now, productId, lotId]);

      // 3. Mark defective record as returned to stock
      await txn.update(
        'defective_stock',
        {
          'supplier_return_status': 'RETURNED_TO_STOCK',
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [defectiveId],
      );

      // 4. Write audit trail to lot_history
      await txn.insert('lot_history', {
        'lot_id': lotId,
        'product_id': productId,
        'action': 'RESTOCK_DEFECTIVE',
        'quantity_change': quantity,
        'quantity_before': before,
        'quantity_after': after,
        'reference_type': 'defective_stock',
        'reference_id': defectiveId,
        'user_id': userId,
        'notes': notes ?? 'Defective item inspected and returned to stock',
        'created_at': now,
      });
    });
  }

  /// Get defective stock summary per product (for product page display)
  Future<List<Map<String, dynamic>>> getDefectiveSummaryByProduct() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT product_id, lot_id, product_name,
             SUM(quantity) as total_defective,
             SUM(CASE WHEN supplier_return_status = 'PENDING' THEN quantity ELSE 0 END) as pending_return,
             SUM(CASE WHEN supplier_return_status = 'ACCEPTED' THEN quantity ELSE 0 END) as accepted_return,
             SUM(CASE WHEN supplier_return_status = 'REJECTED' OR is_refundable = 0 THEN quantity ELSE 0 END) as write_off
      FROM defective_stock
      GROUP BY product_id, lot_id
      ORDER BY product_name
    ''');
  }
}
