import '../../data/database/database_helper.dart';
import '../invoice/invoice_settings_service.dart';
import '../currency/currency_service.dart';

class TransactionService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final InvoiceSettingsService _invoiceSettingsService = InvoiceSettingsService();
  final CurrencyService _currencyService = CurrencyService();

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
    String status = 'COMPLETED',
  }) async {
    final db = await _dbHelper.database;

    // Generate invoice number BEFORE starting transaction to avoid deadlock
    final invoiceNo = await _generateInvoiceNumberBeforeTransaction(type);

    // Get current currency settings BEFORE starting transaction to avoid deadlock
    final currencyCode = await _currencyService.getCurrencyCode();
    final currencySymbol = await _currencyService.getCurrencySymbol();

    return await db.transaction((txn) async {

      // Get party name
      String? partyName;
      if (partyType == 'customer') {
        final customers = await txn.query('customers', where: 'id = ?', whereArgs: [partyId]);
        partyName = customers.isNotEmpty ? customers.first['name'] as String? : null;
      } else {
        final suppliers = await txn.query('suppliers', where: 'id = ?', whereArgs: [partyId]);
        partyName = suppliers.isNotEmpty ? suppliers.first['name'] as String? : null;
      }

      // Create transaction record
      final transactionId = await txn.insert('transactions', {
        'invoice_number': invoiceNo,
        'transaction_type': type,
        'transaction_date': date.toIso8601String(),
        'party_id': partyId,
        'party_type': partyType,
        'party_name': partyName,
        'subtotal': subtotal,
        'discount_amount': discount,
        'tax_amount': tax,
        'total_amount': total,
        'payment_mode': paymentMode,
        'status': status,
        'notes': notes,
        'currency_code': currencyCode,
        'currency_symbol': currencySymbol,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Insert transaction lines and update inventory
      for (final item in items) {
        // Get product details using lot-based schema
        final int productId = item['product_id'];
        final int lotId = item['lot_id'] ?? 1; // Default to lot 1 if not specified

        final products = await txn.query('products',
          where: 'product_id = ? AND lot_id = ?',
          whereArgs: [productId, lotId]);
        final productName = products.isNotEmpty ? products.first['product_name'] as String : 'Unknown';
        final productUnit = products.isNotEmpty ? products.first['unit'] as String? : 'piece';

        await txn.insert('transaction_lines', {
          'transaction_id': transactionId,
          'product_id': productId,
          'lot_id': lotId,
          'product_name': productName,
          'quantity': item['quantity'],
          'unit': productUnit,
          'unit_price': item['unit_price'],
          'discount_amount': item['discount'] ?? 0,
          'tax_amount': item['tax'] ?? 0,
          'line_total': item['subtotal'],
        });

        // Update inventory based on transaction type
        if (type == 'BUY') {
          // Increase stock count for purchase
          await txn.rawUpdate('''
            UPDATE stock
            SET count = count + ?,
                last_stock_update = ?,
                updated_at = ?
            WHERE product_id = ? AND lot_id = ?
          ''', [item['quantity'], DateTime.now().toIso8601String(), DateTime.now().toIso8601String(), productId, lotId]);
        } else if (type == 'SELL') {
          // Reduce stock count for sale
          await txn.rawUpdate('''
            UPDATE stock
            SET count = count - ?,
                last_stock_update = ?,
                updated_at = ?
            WHERE product_id = ? AND lot_id = ?
          ''', [item['quantity'], DateTime.now().toIso8601String(), DateTime.now().toIso8601String(), productId, lotId]);
        } else if (type == 'RETURN') {
          if (partyType == 'customer') {
            // Customer return - add stock back
            await txn.rawUpdate('''
              UPDATE stock
              SET count = count + ?,
                  last_stock_update = ?,
                  updated_at = ?
              WHERE product_id = ? AND lot_id = ?
            ''', [item['quantity'], DateTime.now().toIso8601String(), DateTime.now().toIso8601String(), productId, lotId]);
          } else {
            // Supplier return - reduce stock
            await txn.rawUpdate('''
              UPDATE stock
              SET count = count - ?,
                  last_stock_update = ?,
                  updated_at = ?
              WHERE product_id = ? AND lot_id = ?
            ''', [item['quantity'], DateTime.now().toIso8601String(), DateTime.now().toIso8601String(), productId, lotId]);
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

  /// Generate invoice number based on transaction type using invoice settings
  /// This is called BEFORE starting a database transaction to avoid deadlock
  Future<String> _generateInvoiceNumberBeforeTransaction(String type) async {
    // Map transaction type to invoice type used in settings
    final invoiceType = type == 'BUY' ? 'PURCHASE' : (type == 'SELL' ? 'SALE' : 'RETURN');

    try {
      // Use InvoiceSettingsService to generate invoice number
      return await _invoiceSettingsService.generateInvoiceNumber(invoiceType);
    } catch (e) {
      // Fallback to old hardcoded format if settings not found
      final db = await _dbHelper.database;
      final prefix = type == 'BUY' ? 'PO' : (type == 'SELL' ? 'INV' : 'RET');
      final year = DateTime.now().year;

      final result = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM transactions
        WHERE transaction_type = ? AND strftime('%Y', transaction_date) = ?
      ''', [type, year.toString()]);

      final count = (result.first['count'] as int?) ?? 0;
      final number = (count + 1).toString().padLeft(5, '0');

      return '$prefix-$year-$number';
    }
  }


  /// Get all transactions with filters
  Future<List<Map<String, dynamic>>> getTransactions({
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    int? partyId,
    String? paymentMode,
    String sortBy = 'transaction_date',
    String sortOrder = 'DESC',
  }) async {
    final db = await _dbHelper.database;

    final whereConditions = <String>[];
    final whereArgs = <dynamic>[];

    if (type != null) {
      whereConditions.add('transaction_type = ?');
      whereArgs.add(type);
    }

    if (startDate != null) {
      whereConditions.add('transaction_date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereConditions.add('transaction_date <= ?');
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

    // Add product names for each transaction for search functionality
    final enrichedTransactions = <Map<String, dynamic>>[];
    for (final transaction in transactions) {
      final txnMap = Map<String, dynamic>.from(transaction);

      // Get product names for this transaction
      final lines = await db.rawQuery('''
        SELECT GROUP_CONCAT(p.product_name, ', ') as product_names
        FROM transaction_lines tl
        LEFT JOIN products p ON tl.product_id = p.product_id AND tl.lot_id = p.lot_id
        WHERE tl.transaction_id = ?
      ''', [transaction['id']]);

      txnMap['product_names'] = lines.isNotEmpty ? (lines.first['product_names'] ?? '') : '';
      enrichedTransactions.add(txnMap);
    }

    return enrichedTransactions;
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
    final lines = await db.query(
      'transaction_lines',
      where: 'transaction_id = ?',
      whereArgs: [id],
    );

    transaction['lines'] = lines;

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
        COALESCE(SUM(total_amount), 0) as total_sales,
        COALESCE(SUM(CASE WHEN payment_mode = 'cash' THEN total_amount ELSE 0 END), 0) as cash_sales,
        COALESCE(SUM(CASE WHEN payment_mode = 'credit' THEN total_amount ELSE 0 END), 0) as credit_sales
      FROM transactions
      WHERE transaction_type = 'SELL'
        AND transaction_date >= ?
        AND transaction_date < ?
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
        COALESCE(SUM(total_amount), 0) as total_purchases
      FROM transactions
      WHERE transaction_type = 'BUY'
        AND transaction_date >= ?
        AND transaction_date < ?
    ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String()]);

    return result.first;
  }

  /// Get sales report for date range
  Future<Map<String, dynamic>> getSalesReport(DateTime startDate, DateTime endDate) async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as transaction_count,
        COALESCE(SUM(total_amount), 0) as total_sales,
        COALESCE(SUM(subtotal), 0) as subtotal,
        COALESCE(SUM(discount_amount), 0) as total_discount,
        COALESCE(SUM(tax_amount), 0) as total_tax,
        COALESCE(AVG(total_amount), 0) as average_sale
      FROM transactions
      WHERE transaction_type = 'SELL'
        AND transaction_date >= ?
        AND transaction_date <= ?
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
      final type = transaction['transaction_type'] as String;

      // Get transaction lines
      final lines = await txn.query(
        'transaction_lines',
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );

      // Reverse inventory changes
      for (final line in lines) {
        final productId = line['product_id'] as int;
        final lotId = line['lot_id'] as int? ?? 1;
        final quantity = (line['quantity'] as num).toDouble();

        if (type == 'BUY') {
          // Reverse purchase - decrease stock
          await txn.rawUpdate('''
            UPDATE stock
            SET count = count - ?,
                last_stock_update = ?,
                updated_at = ?
            WHERE product_id = ? AND lot_id = ?
          ''', [quantity, DateTime.now().toIso8601String(), DateTime.now().toIso8601String(), productId, lotId]);
        } else if (type == 'SELL') {
          // Reverse sale - add stock back
          await txn.rawUpdate('''
            UPDATE stock
            SET count = count + ?,
                last_stock_update = ?,
                updated_at = ?
            WHERE product_id = ? AND lot_id = ?
          ''', [quantity, DateTime.now().toIso8601String(), DateTime.now().toIso8601String(), productId, lotId]);
        }
      }

      // Mark transaction as cancelled
      await txn.update(
        'transactions',
        {'status': 'CANCELLED'},
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    });
  }
}
