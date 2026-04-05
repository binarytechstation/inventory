import '../../data/database/database_helper.dart';
import '../invoice/invoice_settings_service.dart';
import '../currency/currency_service.dart';

class TransactionService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final InvoiceSettingsService _invoiceSettingsService = InvoiceSettingsService();
  final CurrencyService _currencyService = CurrencyService();

  /// Create a new transaction (BUY, SELL, RETURN, CUSTOMER_RETURN, SUPPLIER_RETURN)
  /// [paidAmount] is cash paid upfront; the remainder becomes credit.
  Future<int> createTransaction({
    required String type,
    required DateTime date,
    required int partyId,
    required String partyType,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
    required String paymentMode, // 'cash', 'credit', 'mixed'
    double? paidAmount,          // explicit cash portion for mixed payments
    String? notes,
    String status = 'COMPLETED',
    // For defective returns
    String returnType = 'NORMAL',   // 'NORMAL' or 'DEFECTIVE'
    bool isRefundable = true,
    // When true, skip the automatic supplier/customer balance adjustment.
    // Use for replacement returns where no money changes hands.
    bool skipBalanceAdjustment = false,
    // Links a RETURN transaction back to the original SELL/BUY it was returned from.
    int? referenceTransactionId,
  }) async {
    final db = await _dbHelper.database;

    final invoiceNo = await _generateInvoiceNumberBeforeTransaction(type);
    final currencyCode = await _currencyService.getCurrencyCode();
    final currencySymbol = await _currencyService.getCurrencySymbol();

    // Resolve paid/credit amounts
    final double resolvedPaid;
    final double resolvedCredit;
    final String paymentStatus;

    if (paymentMode == 'cash') {
      resolvedPaid = total;
      resolvedCredit = 0;
      paymentStatus = 'PAID';
    } else if (paymentMode == 'credit') {
      resolvedPaid = 0;
      resolvedCredit = total;
      paymentStatus = 'CREDIT';
    } else {
      // mixed
      resolvedPaid = (paidAmount ?? 0).clamp(0, total);
      resolvedCredit = total - resolvedPaid;
      paymentStatus = resolvedCredit <= 0 ? 'PAID' : 'PARTIAL';
    }

    return await db.transaction((txn) async {
      String? partyName;
      if (partyType == 'customer') {
        final rows = await txn.query('customers', where: 'id = ?', whereArgs: [partyId]);
        partyName = rows.isNotEmpty ? rows.first['name'] as String? : null;
      } else {
        final rows = await txn.query('suppliers', where: 'id = ?', whereArgs: [partyId]);
        partyName = rows.isNotEmpty ? rows.first['name'] as String? : null;
      }

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
        'paid_amount': resolvedPaid,
        'credit_amount': resolvedCredit,
        'payment_mode': paymentMode,
        'payment_status': paymentStatus,
        'status': status,
        'notes': notes,
        'currency_code': currencyCode,
        'currency_symbol': currencySymbol,
        'reference_transaction_id': referenceTransactionId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      for (final item in items) {
        final int productId = item['product_id'];
        final int lotId = item['lot_id'] ?? 1;

        final products = await txn.query('products',
            where: 'product_id = ? AND lot_id = ?', whereArgs: [productId, lotId]);
        final productName = products.isNotEmpty ? products.first['product_name'] as String : 'Unknown';
        final productUnit = products.isNotEmpty ? products.first['unit'] as String? : 'piece';

        final itemReturnType = item['return_type'] as String? ?? returnType;
        final itemRefundable = item['is_refundable'] as bool? ?? isRefundable;

        await txn.insert('transaction_lines', {
          'transaction_id': transactionId,
          'product_id': productId,
          'lot_id': lotId,
          'product_name': productName,
          'quantity': item['quantity'],
          'unit': productUnit,
          'unit_price': item['unit_price'],
          'total_price': item['subtotal'],
          'discount_amount': item['discount'] ?? 0,
          'tax_amount': item['tax'] ?? 0,
          'line_total': item['subtotal'],
          'return_type': itemReturnType,
          'is_refundable': itemRefundable ? 1 : 0,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Update inventory
        if (type == 'BUY') {
          await txn.rawUpdate('''
            UPDATE stock SET count = count + ?, last_stock_update = ?, updated_at = ?
            WHERE product_id = ? AND lot_id = ?
          ''', [item['quantity'], DateTime.now().toIso8601String(), DateTime.now().toIso8601String(), productId, lotId]);
        } else if (type == 'SELL') {
          await txn.rawUpdate('''
            UPDATE stock SET count = count - ?, last_stock_update = ?, updated_at = ?
            WHERE product_id = ? AND lot_id = ?
          ''', [item['quantity'], DateTime.now().toIso8601String(), DateTime.now().toIso8601String(), productId, lotId]);
        } else if (type == 'RETURN') {
          if (partyType == 'customer') {
            // Customer return: normal goes back to stock, defective goes to defective_stock
            if (itemReturnType == 'DEFECTIVE') {
              await txn.insert('defective_stock', {
                'product_id': productId,
                'lot_id': lotId,
                'product_name': productName,
                'quantity': item['quantity'],
                'source': 'CUSTOMER_RETURN',
                'source_transaction_id': transactionId,
                'party_id': partyId,
                'party_type': 'customer',
                'party_name': partyName,
                'reason': item['reason'] ?? 'Customer return - defective',
                'supplier_return_status': 'PENDING',
                'is_refundable': itemRefundable ? 1 : 0,
                'refund_amount': item['unit_price'] ?? 0,
                'reported_by': null,
                'reported_at': DateTime.now().toIso8601String(),
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              });
              // Defective items do NOT go back to regular stock
            } else {
              // Normal return - goes back to stock
              await txn.rawUpdate('''
                UPDATE stock SET count = count + ?, last_stock_update = ?, updated_at = ?
                WHERE product_id = ? AND lot_id = ?
              ''', [item['quantity'], DateTime.now().toIso8601String(), DateTime.now().toIso8601String(), productId, lotId]);
            }
          } else {
            // Supplier return (we send back to supplier) - reduce our stock
            await txn.rawUpdate('''
              UPDATE stock SET count = count - ?, last_stock_update = ?, updated_at = ?
              WHERE product_id = ? AND lot_id = ?
            ''', [item['quantity'], DateTime.now().toIso8601String(), DateTime.now().toIso8601String(), productId, lotId]);
          }
        }
      }

      if (!skipBalanceAdjustment) {
        // Update party balance based on credit amount
        if (resolvedCredit > 0) {
          if (partyType == 'customer' && type == 'SELL') {
            await txn.rawUpdate('''
              UPDATE customers SET current_balance = current_balance + ?, updated_at = ?
              WHERE id = ?
            ''', [resolvedCredit, DateTime.now().toIso8601String(), partyId]);
          } else if (partyType == 'supplier' && type == 'BUY') {
            await txn.rawUpdate('''
              UPDATE suppliers SET current_balance = current_balance + ?, updated_at = ?
              WHERE id = ?
            ''', [resolvedCredit, DateTime.now().toIso8601String(), partyId]);
          }
        }

        // If it's a customer RETURN, reduce their balance by the refunded amount
        if (type == 'RETURN' && partyType == 'customer') {
          final refundCredit = resolvedCredit > 0 ? resolvedCredit : total;
          await txn.rawUpdate('''
            UPDATE customers SET current_balance = MAX(0, current_balance - ?), updated_at = ?
            WHERE id = ?
          ''', [refundCredit, DateTime.now().toIso8601String(), partyId]);
        }

        // If it's a supplier RETURN (refund from supplier), reduce our payable
        if (type == 'RETURN' && partyType == 'supplier') {
          await txn.rawUpdate('''
            UPDATE suppliers SET current_balance = MAX(0, current_balance - ?), updated_at = ?
            WHERE id = ?
          ''', [total, DateTime.now().toIso8601String(), partyId]);
        }
      }

      return transactionId;
    });
  }

  Future<String> _generateInvoiceNumberBeforeTransaction(String type) async {
    final invoiceType = type == 'BUY' ? 'PURCHASE' : (type == 'SELL' ? 'SALE' : 'RETURN');
    try {
      return await _invoiceSettingsService.generateInvoiceNumber(invoiceType);
    } catch (e) {
      final db = await _dbHelper.database;
      final prefix = type == 'BUY' ? 'PO' : (type == 'SELL' ? 'INV' : 'RET');
      final year = DateTime.now().year;
      final result = await db.rawQuery('''
        SELECT COUNT(*) as count FROM transactions
        WHERE transaction_type = ? AND strftime('%Y', transaction_date) = ?
      ''', [type, year.toString()]);
      final count = (result.first['count'] as int?) ?? 0;
      return '$prefix-$year-${(count + 1).toString().padLeft(5, '0')}';
    }
  }

  Future<List<Map<String, dynamic>>> getTransactions({
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    int? partyId,
    String? paymentMode,
    String? paymentStatus,
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
    if (paymentStatus != null) {
      whereConditions.add('payment_status = ?');
      whereArgs.add(paymentStatus);
    }

    final whereClause = whereConditions.isNotEmpty ? whereConditions.join(' AND ') : null;

    final transactions = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: '$sortBy $sortOrder',
    );

    final enrichedTransactions = <Map<String, dynamic>>[];
    for (final transaction in transactions) {
      final txnMap = Map<String, dynamic>.from(transaction);
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

  Future<Map<String, dynamic>?> getTransactionById(int id) async {
    final db = await _dbHelper.database;
    final transactions = await db.query('transactions', where: 'id = ?', whereArgs: [id], limit: 1);
    if (transactions.isEmpty) return null;
    final transaction = Map<String, dynamic>.from(transactions.first);
    final lines = await db.query('transaction_lines', where: 'transaction_id = ?', whereArgs: [id]);
    transaction['lines'] = lines;
    return transaction;
  }

  Future<Map<String, dynamic>> getTodaysSales() async {
    final db = await _dbHelper.database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final start = startOfDay.toIso8601String();
    final end = endOfDay.toIso8601String();

    final salesResult = await db.rawQuery('''
      SELECT
        COUNT(*) as transaction_count,
        COALESCE(SUM(total_amount), 0) as total_sales,
        COALESCE(SUM(paid_amount), 0) as cash_sales,
        COALESCE(SUM(credit_amount), 0) as credit_sales
      FROM transactions
      WHERE transaction_type = 'SELL'
        AND transaction_date >= ? AND transaction_date < ?
    ''', [start, end]);

    // Credit dues cleared by customers today (previous balance payments)
    final clearedResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as credit_cleared
      FROM customer_payments
      WHERE payment_date >= ? AND payment_date < ?
    ''', [start, end]);

    final row = Map<String, dynamic>.from(salesResult.first);
    final creditCleared = (clearedResult.first['credit_cleared'] as num?)?.toDouble() ?? 0.0;
    final cashSales = (row['cash_sales'] as num?)?.toDouble() ?? 0.0;
    row['credit_cleared_today'] = creditCleared;
    row['cash_collected'] = cashSales + creditCleared;
    return row;
  }

  Future<Map<String, dynamic>> getTodaysPurchases() async {
    final db = await _dbHelper.database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final start = startOfDay.toIso8601String();
    final end = endOfDay.toIso8601String();

    final result = await db.rawQuery('''
      SELECT COUNT(*) as transaction_count,
             COALESCE(SUM(total_amount), 0) as total_purchases,
             COALESCE(SUM(paid_amount), 0) as cash_purchases,
             COALESCE(SUM(credit_amount), 0) as credit_purchases
      FROM transactions
      WHERE transaction_type = 'BUY'
        AND transaction_date >= ? AND transaction_date < ?
    ''', [start, end]);

    // Supplier dues cleared today (cash paid out for previous credit purchases)
    final clearedResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as supplier_cleared
      FROM supplier_payments
      WHERE payment_date >= ? AND payment_date < ?
    ''', [start, end]);

    final row = Map<String, dynamic>.from(result.first);
    final supplierCleared = (clearedResult.first['supplier_cleared'] as num?)?.toDouble() ?? 0.0;
    row['supplier_cleared_today'] = supplierCleared;
    return row;
  }

  /// Returns already-returned quantities for each (product_id, lot_id) pair
  /// from all RETURN transactions that reference [originalTransactionId].
  /// Result: {productId: {lotId: returnedQty}}
  Future<Map<int, Map<int, double>>> getReturnedQuantities(int originalTransactionId) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT tl.product_id, tl.lot_id, COALESCE(SUM(tl.quantity), 0) as returned_qty
      FROM transaction_lines tl
      INNER JOIN transactions t ON tl.transaction_id = t.id
      WHERE t.transaction_type = 'RETURN'
        AND t.reference_transaction_id = ?
      GROUP BY tl.product_id, tl.lot_id
    ''', [originalTransactionId]);

    final map = <int, Map<int, double>>{};
    for (final row in rows) {
      final productId = (row['product_id'] as num).toInt();
      final lotId = (row['lot_id'] as num).toInt();
      final qty = (row['returned_qty'] as num).toDouble();
      map.putIfAbsent(productId, () => {})[lotId] = qty;
    }
    return map;
  }

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
        AND transaction_date >= ? AND transaction_date <= ?
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);
    return result.first;
  }

  Future<void> cancelTransaction(int transactionId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final transactions = await txn.query('transactions', where: 'id = ?', whereArgs: [transactionId], limit: 1);
      if (transactions.isEmpty) throw Exception('Transaction not found');

      final transaction = transactions.first;
      final type = transaction['transaction_type'] as String;
      final partyId = transaction['party_id'] as int?;
      final partyType = transaction['party_type'] as String?;
      final creditAmount = (transaction['credit_amount'] as num?)?.toDouble() ?? 0;

      final lines = await txn.query('transaction_lines', where: 'transaction_id = ?', whereArgs: [transactionId]);

      for (final line in lines) {
        final productId = line['product_id'] as int;
        final lotId = line['lot_id'] as int? ?? 1;
        final quantity = (line['quantity'] as num).toDouble();

        if (type == 'BUY') {
          await txn.rawUpdate('''
            UPDATE stock SET count = count - ?, last_stock_update = ?, updated_at = ?
            WHERE product_id = ? AND lot_id = ?
          ''', [quantity, DateTime.now().toIso8601String(), DateTime.now().toIso8601String(), productId, lotId]);
        } else if (type == 'SELL') {
          await txn.rawUpdate('''
            UPDATE stock SET count = count + ?, last_stock_update = ?, updated_at = ?
            WHERE product_id = ? AND lot_id = ?
          ''', [quantity, DateTime.now().toIso8601String(), DateTime.now().toIso8601String(), productId, lotId]);
        }
      }

      // Reverse balance changes
      if (creditAmount > 0 && partyId != null) {
        if (partyType == 'customer' && type == 'SELL') {
          await txn.rawUpdate('''
            UPDATE customers SET current_balance = MAX(0, current_balance - ?), updated_at = ?
            WHERE id = ?
          ''', [creditAmount, DateTime.now().toIso8601String(), partyId]);
        } else if (partyType == 'supplier' && type == 'BUY') {
          await txn.rawUpdate('''
            UPDATE suppliers SET current_balance = MAX(0, current_balance - ?), updated_at = ?
            WHERE id = ?
          ''', [creditAmount, DateTime.now().toIso8601String(), partyId]);
        }
      }

      await txn.update('transactions', {'status': 'CANCELLED'}, where: 'id = ?', whereArgs: [transactionId]);
    });
  }

  /// Create a purchase order with a new lot and products
  Future<int> createPurchaseOrderWithLot({
    required int supplierId,
    required DateTime date,
    required Map<String, dynamic> lotData,
    required List<Map<String, dynamic>> products,
    required String paymentMode,
    double? paidAmount,
    String? notes,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
  }) async {
    final db = await _dbHelper.database;
    final invoiceNo = await _generateInvoiceNumberBeforeTransaction('BUY');
    final currencyCode = await _currencyService.getCurrencyCode();
    final currencySymbol = await _currencyService.getCurrencySymbol();

    final double resolvedPaid;
    final double resolvedCredit;
    final String paymentStatus;

    if (paymentMode == 'cash') {
      resolvedPaid = total;
      resolvedCredit = 0;
      paymentStatus = 'PAID';
    } else if (paymentMode == 'credit') {
      resolvedPaid = 0;
      resolvedCredit = total;
      paymentStatus = 'CREDIT';
    } else {
      resolvedPaid = (paidAmount ?? 0).clamp(0, total);
      resolvedCredit = total - resolvedPaid;
      paymentStatus = resolvedCredit <= 0 ? 'PAID' : 'PARTIAL';
    }

    return await db.transaction((txn) async {
      final maxLotResult = await txn.rawQuery('SELECT COALESCE(MAX(lot_id), 0) + 1 as next_id FROM lots');
      final lotId = maxLotResult.first['next_id'] as int;

      await txn.insert('lots', {
        'lot_id': lotId,
        'received_date': lotData['received_date'] ?? date.toIso8601String(),
        'description': lotData['lot_name'] ?? 'Lot #$lotId',
        'supplier_id': supplierId,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      final suppliers = await txn.query('suppliers', where: 'id = ?', whereArgs: [supplierId]);
      final supplierName = suppliers.isNotEmpty ? suppliers.first['name'] as String? : null;

      final transactionId = await txn.insert('transactions', {
        'invoice_number': invoiceNo,
        'transaction_type': 'BUY',
        'transaction_date': date.toIso8601String(),
        'lot_id': lotId,
        'party_id': supplierId,
        'party_type': 'supplier',
        'party_name': supplierName,
        'subtotal': subtotal,
        'discount_amount': discount,
        'tax_amount': tax,
        'total_amount': total,
        'paid_amount': resolvedPaid,
        'credit_amount': resolvedCredit,
        'payment_mode': paymentMode,
        'payment_status': paymentStatus,
        'status': 'COMPLETED',
        'notes': notes,
        'currency_code': currencyCode,
        'currency_symbol': currencySymbol,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      for (final productData in products) {
        int productId;
        final productName = productData['product_name'] as String;

        final existingProducts = await txn.query('products',
            where: 'product_name = ? AND is_active = 1', whereArgs: [productName], limit: 1);

        if (existingProducts.isNotEmpty) {
          productId = existingProducts.first['product_id'] as int;
          await txn.update('products', {
            'category': productData['category'] ?? existingProducts.first['category'],
            'product_description': productData['description'] ?? existingProducts.first['product_description'],
            'unit': productData['unit'] ?? existingProducts.first['unit'],
            'updated_at': DateTime.now().toIso8601String(),
          }, where: 'product_name = ? AND is_active = 1', whereArgs: [productName]);

          await txn.insert('products', {
            'product_id': productId,
            'lot_id': lotId,
            'product_name': productName,
            'unit_price': productData['buying_price'],
            'selling_price': productData['selling_price'] ?? existingProducts.first['selling_price'],
            'product_image': existingProducts.first['product_image'],
            'unit': productData['unit'] ?? existingProducts.first['unit'],
            'category': productData['category'] ?? existingProducts.first['category'],
            'sku': productData['sku'] ?? existingProducts.first['sku'],
            'barcode': productData['barcode'] ?? existingProducts.first['barcode'],
            'product_description': productData['description'] ?? existingProducts.first['product_description'],
            'is_active': 1,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } else {
          final maxProductResult = await txn.rawQuery('SELECT COALESCE(MAX(product_id), 0) + 1 as next_id FROM products');
          productId = maxProductResult.first['next_id'] as int;

          await txn.insert('products', {
            'product_id': productId,
            'lot_id': lotId,
            'product_name': productName,
            'unit_price': productData['buying_price'],
            'selling_price': productData['selling_price'],
            'unit': productData['unit'],
            'category': productData['category'] ?? '',
            'sku': productData['sku'] ?? '',
            'barcode': productData['barcode'] ?? '',
            'product_description': productData['description'] ?? '',
            'is_active': 1,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }

        await txn.insert('stock', {
          'lot_id': lotId,
          'product_id': productId,
          'count': productData['quantity'],
          'reorder_level': productData['reorder_level'] ?? 0,
          'reserved_quantity': 0,
          'last_stock_update': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        final lineTotal = (productData['quantity'] as double) * (productData['buying_price'] as double);
        await txn.insert('transaction_lines', {
          'transaction_id': transactionId,
          'product_id': productId,
          'lot_id': lotId,
          'product_name': productData['product_name'],
          'quantity': productData['quantity'],
          'unit': productData['unit'],
          'unit_price': productData['buying_price'],
          'total_price': lineTotal,
          'discount_amount': 0,
          'tax_amount': 0,
          'line_total': lineTotal,
          'return_type': 'NORMAL',
          'is_refundable': 1,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Update supplier balance for credit purchases
      if (resolvedCredit > 0) {
        await txn.rawUpdate('''
          UPDATE suppliers SET current_balance = current_balance + ?, updated_at = ?
          WHERE id = ?
        ''', [resolvedCredit, DateTime.now().toIso8601String(), supplierId]);
      }

      return transactionId;
    });
  }

  /// Get line items for a specific transaction
  Future<List<Map<String, dynamic>>> getTransactionLines(int transactionId) async {
    final db = await _dbHelper.database;
    return await db.query(
      'transaction_lines',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }

  /// Get credit transactions (unpaid/partial) for a party
  Future<List<Map<String, dynamic>>> getCreditTransactions({
    required int partyId,
    required String partyType,
  }) async {
    final db = await _dbHelper.database;
    // Only show BUY transactions for suppliers, SELL for customers.
    // RETURN transactions are credits the OTHER party owes US — not our unpaid bills.
    final txType = partyType == 'supplier' ? 'BUY' : 'SELL';
    return await db.rawQuery('''
      SELECT * FROM transactions
      WHERE party_id = ? AND party_type = ? AND transaction_type = ?
        AND payment_status IN ('CREDIT', 'PARTIAL')
        AND status != 'CANCELLED'
      ORDER BY transaction_date DESC
    ''', [partyId, partyType, txType]);
  }

  /// Get total outstanding balance for a party across all credit transactions
  Future<double> getOutstandingBalance({
    required int partyId,
    required String partyType,
  }) async {
    final db = await _dbHelper.database;
    final txType = partyType == 'supplier' ? 'BUY' : 'SELL';
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(credit_amount), 0) as total
      FROM transactions
      WHERE party_id = ? AND party_type = ? AND transaction_type = ?
        AND payment_status IN ('CREDIT', 'PARTIAL')
        AND status != 'CANCELLED'
    ''', [partyId, partyType, txType]);
    return (result.first['total'] as num).toDouble();
  }

  /// Mark a transaction as partially or fully paid after a payment
  Future<void> applyPaymentToTransaction(int transactionId, double paymentAmount) async {
    final db = await _dbHelper.database;
    final txns = await db.query('transactions', where: 'id = ?', whereArgs: [transactionId], limit: 1);
    if (txns.isEmpty) return;
    final tx = txns.first;
    final currentCredit = (tx['credit_amount'] as num).toDouble();
    final newCredit = (currentCredit - paymentAmount).clamp(0, currentCredit);
    final newPaid = (tx['paid_amount'] as num).toDouble() + paymentAmount;
    final newStatus = newCredit <= 0 ? 'PAID' : 'PARTIAL';
    await db.update('transactions', {
      'credit_amount': newCredit,
      'paid_amount': newPaid,
      'payment_status': newStatus,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [transactionId]);
  }
}
