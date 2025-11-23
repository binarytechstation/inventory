import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../data/database/database_helper.dart';

class TransactionService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Create a new transaction (BUY, SELL, or RETURN)
  Future<int> createTransaction({
    required String type, // 'BUY', 'SELL', 'RETURN'
    required DateTime date,
    required int partyId,
    required String partyType, // 'supplier' or 'customer'
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
    required String paymentMode, // 'cash' or 'credit'
    String? notes,
    String status = 'completed',
  }) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      // Generate invoice number
      final invoiceNo = await _generateInvoiceNumber(txn, type);

      // Create transaction record
      final transactionId = await txn.insert('transactions', {
        'invoice_no': invoiceNo,
        'type': type,
        'date': date.toIso8601String(),
        'party_id': partyId,
        'party_type': partyType,
        'subtotal': subtotal,
        'discount': discount,
        'tax': tax,
        'total': total,
        'payment_mode': paymentMode,
        'status': status,
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Insert transaction lines and update inventory
      for (final item in items) {
        await txn.insert('transaction_lines', {
          'transaction_id': transactionId,
          'product_id': item['product_id'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
          'discount': item['discount'] ?? 0,
          'tax': item['tax'] ?? 0,
          'subtotal': item['subtotal'],
        });

        // Update inventory based on transaction type
        if (type == 'BUY') {
          // Create product batch for purchase
          await txn.insert('product_batches', {
            'product_id': item['product_id'],
            'purchase_price': item['unit_price'],
            'quantity_added': item['quantity'],
            'quantity_remaining': item['quantity'],
            'batch_date': date.toIso8601String(),
            'supplier_id': partyId,
            'transaction_id': transactionId,
          });
        } else if (type == 'SELL') {
          // Reduce stock using FIFO method
          await _reduceStock(txn, item['product_id'], item['quantity']);
        } else if (type == 'RETURN') {
          if (partyType == 'customer') {
            // Customer return - add stock back
            await _addStockFromReturn(txn, item['product_id'], item['quantity'], partyId);
          } else {
            // Supplier return - reduce stock
            await _reduceStock(txn, item['product_id'], item['quantity']);
          }
        }
      }

      // Update customer/supplier balance if payment mode is credit
      if (paymentMode == 'credit') {
        if (partyType == 'customer') {
          await txn.rawUpdate('''
            UPDATE customers
            SET current_balance = current_balance + ?,
                updated_at = ?
            WHERE id = ?
          ''', [total, DateTime.now().toIso8601String(), partyId]);
        }
        // For suppliers, we could track payables here if needed
      }

      return transactionId;
    });
  }

  /// Generate invoice number based on transaction type
  Future<String> _generateInvoiceNumber(Transaction txn, String type) async {
    final prefix = type == 'BUY' ? 'PO' : (type == 'SELL' ? 'INV' : 'RET');
    final year = DateTime.now().year;

    final result = await txn.rawQuery('''
      SELECT COUNT(*) as count
      FROM transactions
      WHERE type = ? AND strftime('%Y', date) = ?
    ''', [type, year.toString()]);

    final count = (result.first['count'] as int?) ?? 0;
    final number = (count + 1).toString().padLeft(5, '0');

    return '$prefix-$year-$number';
  }

  /// Reduce stock using FIFO (First In, First Out) method
  Future<void> _reduceStock(Transaction txn, int productId, double quantity) async {
    var remainingQty = quantity;

    // Get batches ordered by date (FIFO)
    final batches = await txn.query(
      'product_batches',
      where: 'product_id = ? AND quantity_remaining > 0',
      whereArgs: [productId],
      orderBy: 'batch_date ASC',
    );

    for (final batch in batches) {
      if (remainingQty <= 0) break;

      final batchId = batch['id'] as int;
      final available = (batch['quantity_remaining'] as num).toDouble();
      final toReduce = remainingQty > available ? available : remainingQty;

      await txn.update(
        'product_batches',
        {'quantity_remaining': available - toReduce},
        where: 'id = ?',
        whereArgs: [batchId],
      );

      remainingQty -= toReduce;
    }

    if (remainingQty > 0) {
      throw Exception('Insufficient stock for product ID $productId. Short by $remainingQty units.');
    }
  }

  /// Add stock back from return
  Future<void> _addStockFromReturn(Transaction txn, int productId, double quantity, int supplierId) async {
    // For returns, add as a new batch
    await txn.insert('product_batches', {
      'product_id': productId,
      'purchase_price': 0, // Return items
      'quantity_added': quantity,
      'quantity_remaining': quantity,
      'batch_date': DateTime.now().toIso8601String(),
      'supplier_id': supplierId,
      'transaction_id': null,
    });
  }

  /// Get all transactions with filters
  Future<List<Map<String, dynamic>>> getTransactions({
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    int? partyId,
    String? paymentMode,
    String sortBy = 'date',
    String sortOrder = 'DESC',
  }) async {
    final db = await _dbHelper.database;

    final whereConditions = <String>[];
    final whereArgs = <dynamic>[];

    if (type != null) {
      whereConditions.add('type = ?');
      whereArgs.add(type);
    }

    if (startDate != null) {
      whereConditions.add('date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereConditions.add('date <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    if (partyId != null) {
      whereConditions.add('party_id = ?');
      whereArgs.add(partyId);
    }

    if (paymentMode != null) {
      whereConditions.add('payment_mode = ?');
      whereArgs.add(paymentMode);
    }

    final whereClause = whereConditions.isNotEmpty
        ? whereConditions.join(' AND ')
        : null;

    final transactions = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: '$sortBy $sortOrder',
    );

    return transactions;
  }

  /// Get transaction by ID with all details
  Future<Map<String, dynamic>?> getTransactionById(int id) async {
    final db = await _dbHelper.database;

    final transactions = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (transactions.isEmpty) return null;

    final transaction = Map<String, dynamic>.from(transactions.first);

    // Get transaction lines
    final lines = await db.rawQuery('''
      SELECT
        tl.*,
        p.name as product_name,
        p.sku as product_sku,
        p.unit as product_unit
      FROM transaction_lines tl
      JOIN products p ON tl.product_id = p.id
      WHERE tl.transaction_id = ?
    ''', [id]);

    transaction['lines'] = lines;

    // Get party details
    final partyType = transaction['party_type'] as String;
    final partyId = transaction['party_id'] as int;

    if (partyType == 'customer') {
      final customers = await db.query(
        'customers',
        where: 'id = ?',
        whereArgs: [partyId],
        limit: 1,
      );
      transaction['party'] = customers.isNotEmpty ? customers.first : null;
    } else {
      final suppliers = await db.query(
        'suppliers',
        where: 'id = ?',
        whereArgs: [partyId],
        limit: 1,
      );
      transaction['party'] = suppliers.isNotEmpty ? suppliers.first : null;
    }

    return transaction;
  }

  /// Get today's sales summary
  Future<Map<String, dynamic>> getTodaysSales() async {
    final db = await _dbHelper.database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as transaction_count,
        COALESCE(SUM(total), 0) as total_sales,
        COALESCE(SUM(CASE WHEN payment_mode = 'cash' THEN total ELSE 0 END), 0) as cash_sales,
        COALESCE(SUM(CASE WHEN payment_mode = 'credit' THEN total ELSE 0 END), 0) as credit_sales
      FROM transactions
      WHERE type = 'SELL'
        AND date >= ?
        AND date < ?
    ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String()]);

    return result.first;
  }

  /// Get today's purchases summary
  Future<Map<String, dynamic>> getTodaysPurchases() async {
    final db = await _dbHelper.database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as transaction_count,
        COALESCE(SUM(total), 0) as total_purchases
      FROM transactions
      WHERE type = 'BUY'
        AND date >= ?
        AND date < ?
    ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String()]);

    return result.first;
  }

  /// Get sales report for date range
  Future<Map<String, dynamic>> getSalesReport(DateTime startDate, DateTime endDate) async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as transaction_count,
        COALESCE(SUM(total), 0) as total_sales,
        COALESCE(SUM(subtotal), 0) as subtotal,
        COALESCE(SUM(discount), 0) as total_discount,
        COALESCE(SUM(tax), 0) as total_tax,
        COALESCE(AVG(total), 0) as average_sale
      FROM transactions
      WHERE type = 'SELL'
        AND date >= ?
        AND date <= ?
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

    return result.first;
  }

  /// Delete/Cancel a transaction
  Future<void> cancelTransaction(int transactionId) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // Get transaction details
      final transactions = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
        limit: 1,
      );

      if (transactions.isEmpty) {
        throw Exception('Transaction not found');
      }

      final transaction = transactions.first;
      final type = transaction['type'] as String;

      // Get transaction lines
      final lines = await txn.query(
        'transaction_lines',
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );

      // Reverse inventory changes
      for (final line in lines) {
        final productId = line['product_id'] as int;
        final quantity = (line['quantity'] as num).toDouble();

        if (type == 'BUY') {
          // Remove the batch created by this transaction
          await txn.delete(
            'product_batches',
            where: 'transaction_id = ?',
            whereArgs: [transactionId],
          );
        } else if (type == 'SELL') {
          // Add stock back (this is simplified; ideally track which batches were used)
          await _addStockFromReturn(txn, productId, quantity, 0);
        }
      }

      // Mark transaction as cancelled
      await txn.update(
        'transactions',
        {'status': 'cancelled'},
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    });
  }
}
