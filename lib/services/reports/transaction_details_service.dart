import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import '../../data/database/database_helper.dart';
import '../../core/utils/file_save_helper.dart';

class TransactionDetailsService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ─── Transaction Ledger ─────────────────────────────────────────────────────

  /// Get BUY or SELL transactions enriched with lines, payment breakdown, user.
  Future<List<Map<String, dynamic>>> getTransactionsByDateRange({
    required String type,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _dbHelper.database;

    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final transactions = await db.query(
      'transactions',
      where:
          'transaction_type = ? AND transaction_date >= ? AND transaction_date <= ?',
      whereArgs: [type, startDate.toIso8601String(), end.toIso8601String()],
      orderBy: 'transaction_date DESC',
    );

    final enriched = <Map<String, dynamic>>[];
    for (final t in transactions) {
      final row = Map<String, dynamic>.from(t);

      final lines = await db.rawQuery('''
        SELECT tl.*, l.description AS lot_description
        FROM transaction_lines tl
        LEFT JOIN lots l ON tl.lot_id = l.lot_id
        WHERE tl.transaction_id = ?
      ''', [t['id']]);
      row['lines'] = lines;

      if (t['created_by'] != null) {
        final users = await db
            .query('users', where: 'id = ?', whereArgs: [t['created_by']]);
        row['user_name'] =
            users.isNotEmpty ? users.first['username'] ?? users.first['name'] : 'Unknown';
      } else {
        row['user_name'] = 'System';
      }

      enriched.add(row);
    }
    return enriched;
  }

  /// Get hourly transactions for a specific date with optional hour range.
  Future<List<Map<String, dynamic>>> getHourlyTransactions({
    required String type,
    required DateTime date,
    int? startHour,
    int? endHour,
  }) async {
    final db = await _dbHelper.database;

    final start = DateTime(date.year, date.month, date.day, startHour ?? 0, 0, 0);
    final end = DateTime(date.year, date.month, date.day, endHour ?? 23, 59, 59);

    final transactions = await db.query(
      'transactions',
      where:
          'transaction_type = ? AND transaction_date >= ? AND transaction_date <= ?',
      whereArgs: [type, start.toIso8601String(), end.toIso8601String()],
      orderBy: 'transaction_date DESC',
    );

    final enriched = <Map<String, dynamic>>[];
    for (final t in transactions) {
      final row = Map<String, dynamic>.from(t);
      final lines = await db.rawQuery('''
        SELECT tl.*, l.description AS lot_description
        FROM transaction_lines tl
        LEFT JOIN lots l ON tl.lot_id = l.lot_id
        WHERE tl.transaction_id = ?
      ''', [t['id']]);
      row['lines'] = lines;
      enriched.add(row);
    }
    return enriched;
  }

  /// Backward-compatible alias.
  Future<List<Map<String, dynamic>>> getTodayHourlyTransactions({
    required String type,
  }) =>
      getHourlyTransactions(type: type, date: DateTime.now());

  // ─── Dues ────────────────────────────────────────────────────────────────────

  /// Returns all active parties (supplier or customer) that have an
  /// outstanding balance, enriched with unpaid transactions and recent payments.
  Future<List<Map<String, dynamic>>> getPartyDues({
    required String partyType, // 'supplier' | 'customer'
  }) async {
    final db = await _dbHelper.database;

    final table = partyType == 'supplier' ? 'suppliers' : 'customers';
    final payTable =
        partyType == 'supplier' ? 'supplier_payments' : 'customer_payments';
    final payCol =
        partyType == 'supplier' ? 'supplier_id' : 'customer_id';
    final txnType = partyType == 'supplier' ? 'BUY' : 'SELL';

    final parties = await db.rawQuery('''
      SELECT
        p.*,
        COUNT(DISTINCT t.id)           AS total_transactions,
        COALESCE(SUM(t.total_amount),0) AS total_business,
        COALESCE(SUM(t.paid_amount), 0)
          + COALESCE((SELECT SUM(amount) FROM $payTable WHERE $payCol = p.id), 0)
                                        AS total_paid_ever,
        COALESCE(
          (SELECT SUM(amount) FROM $payTable WHERE $payCol = p.id), 0
        )                               AS payments_cleared,
        (SELECT MAX(payment_date) FROM $payTable WHERE $payCol = p.id)
                                        AS last_payment_date,
        (SELECT MIN(transaction_date) FROM transactions
          WHERE party_id = p.id AND party_type = ?
            AND transaction_type = ?
            AND payment_status != 'PAID')
                                        AS oldest_unpaid_date
      FROM $table p
      LEFT JOIN transactions t
        ON t.party_id = p.id
        AND t.party_type = ?
        AND t.transaction_type = ?
        AND t.status != 'CANCELLED'
      WHERE p.is_active = 1 AND p.current_balance > 0
      GROUP BY p.id
      ORDER BY p.current_balance DESC
    ''', [partyType, txnType, partyType, txnType]);

    final result = <Map<String, dynamic>>[];
    for (final party in parties) {
      final row = Map<String, dynamic>.from(party);

      // Unpaid / partial transactions
      final unpaid = await db.query(
        'transactions',
        where:
            "party_id = ? AND party_type = ? AND transaction_type = ? AND payment_status != 'PAID'",
        whereArgs: [party['id'], partyType, txnType],
        orderBy: 'transaction_date ASC',
      );
      row['unpaid_transactions'] = unpaid;

      // Recent payment records (last 5)
      final payments = await db.query(
        payTable,
        where: '$payCol = ?',
        whereArgs: [party['id']],
        orderBy: 'payment_date DESC',
        limit: 5,
      );
      row['recent_payments'] = payments;

      result.add(row);
    }
    return result;
  }

  // ─── Returns & Defectives ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getReturnsAndDefectives({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;

    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = DateTime(
      (endDate ?? DateTime.now()).year,
      (endDate ?? DateTime.now()).month,
      (endDate ?? DateTime.now()).day,
      23, 59, 59,
    );

    // All RETURN-type transactions
    final returns = await db.query(
      'transactions',
      where:
          "transaction_type = 'RETURN' AND transaction_date >= ? AND transaction_date <= ? AND status != 'CANCELLED'",
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'transaction_date DESC',
    );

    final enrichedReturns = <Map<String, dynamic>>[];
    for (final r in returns) {
      final row = Map<String, dynamic>.from(r);
      final lines = await db.rawQuery('''
        SELECT tl.*, l.description AS lot_description
        FROM transaction_lines tl
        LEFT JOIN lots l ON tl.lot_id = l.lot_id
        WHERE tl.transaction_id = ?
      ''', [r['id']]);
      row['lines'] = lines;
      enrichedReturns.add(row);
    }

    // Defective stock items in the period
    final defectives = await db.rawQuery('''
      SELECT ds.*
      FROM defective_stock ds
      WHERE ds.reported_at >= ? AND ds.reported_at <= ?
      ORDER BY ds.reported_at DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    final totalReturnValue = enrichedReturns.fold<double>(
        0, (s, r) => s + (r['total_amount'] as num).toDouble());
    final cashRefunded = enrichedReturns.fold<double>(
        0, (s, r) => s + ((r['paid_amount'] as num?)?.toDouble() ?? 0));
    final creditRefunded = enrichedReturns.fold<double>(
        0, (s, r) => s + ((r['credit_amount'] as num?)?.toDouble() ?? 0));
    final totalDefectiveQty = defectives.fold<double>(
        0, (s, d) => s + (d['quantity'] as num).toDouble());
    final totalDefectiveRefund = defectives.fold<double>(
        0, (s, d) => s + ((d['refund_amount'] as num?)?.toDouble() ?? 0));

    return {
      'returns': enrichedReturns,
      'defectives': defectives,
      'total_return_value': totalReturnValue,
      'cash_refunded': cashRefunded,
      'credit_refunded': creditRefunded,
      'total_defective_qty': totalDefectiveQty,
      'total_defective_refund': totalDefectiveRefund,
    };
  }

  // ─── Cash Flow ───────────────────────────────────────────────────────────────

  /// Returns a day-by-day cash flow breakdown for the given period.
  ///
  /// Cash INFLOWS (money actually received on that day):
  ///   • Cash portion of SELL transactions on that day (paid_amount where payment_mode='cash' or partial cash)
  ///   • Customer due payments collected on that day (customer_payments table)
  ///   • Cash refunds received from suppliers on that day (RETURN transactions where party_type='supplier', paid_amount)
  ///
  /// Cash OUTFLOWS (money actually paid out on that day):
  ///   • Cash portion of BUY transactions on that day (paid_amount)
  ///   • Supplier due payments made on that day (supplier_payments table)
  ///   • Cash refunds given to customers (RETURN transactions where party_type='customer', paid_amount where payment_mode='cash')
  ///   • Expenses on that day
  ///
  /// Accrual totals (value of goods bought/sold including credit):
  ///   • total_sales: all SELL total_amount in period
  ///   • total_purchases: all BUY total_amount in period
  ///   • total_profit_accrual: total_sales − total_purchases
  Future<Map<String, dynamic>> getCashFlowReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _dbHelper.database;
    final start = startDate.toIso8601String();
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59).toIso8601String();

    // ── 1. Cash from SELL transactions (actual cash received at sale time) ──
    final sellCash = await db.rawQuery('''
      SELECT DATE(transaction_date) as day,
             COALESCE(SUM(paid_amount), 0) as cash_in
      FROM transactions
      WHERE transaction_type = 'SELL'
        AND status != 'CANCELLED'
        AND transaction_date >= ? AND transaction_date <= ?
      GROUP BY DATE(transaction_date)
    ''', [start, end]);

    // ── 2. Customer due payments collected (payment_date = when cash arrived) ──
    final customerPayments = await db.rawQuery('''
      SELECT DATE(payment_date) as day,
             COALESCE(SUM(amount), 0) as cash_in
      FROM customer_payments
      WHERE payment_date >= ? AND payment_date <= ?
      GROUP BY DATE(payment_date)
    ''', [start, end]);

    // ── 3. Refund from supplier (we return goods, they pay us back) ──
    final supplierReturnCash = await db.rawQuery('''
      SELECT DATE(transaction_date) as day,
             COALESCE(SUM(paid_amount), 0) as cash_in
      FROM transactions
      WHERE transaction_type = 'RETURN'
        AND party_type = 'supplier'
        AND status != 'CANCELLED'
        AND transaction_date >= ? AND transaction_date <= ?
      GROUP BY DATE(transaction_date)
    ''', [start, end]);

    // ── 4. Cash spent on BUY transactions ──
    final buyCash = await db.rawQuery('''
      SELECT DATE(transaction_date) as day,
             COALESCE(SUM(paid_amount), 0) as cash_out
      FROM transactions
      WHERE transaction_type = 'BUY'
        AND status != 'CANCELLED'
        AND transaction_date >= ? AND transaction_date <= ?
      GROUP BY DATE(transaction_date)
    ''', [start, end]);

    // ── 5. Supplier due payments made ──
    final supplierPayments = await db.rawQuery('''
      SELECT DATE(payment_date) as day,
             COALESCE(SUM(amount), 0) as cash_out
      FROM supplier_payments
      WHERE payment_date >= ? AND payment_date <= ?
      GROUP BY DATE(payment_date)
    ''', [start, end]);

    // ── 6. Cash refunds to customers (customer returns, cash refund method) ──
    final customerReturnCash = await db.rawQuery('''
      SELECT DATE(transaction_date) as day,
             COALESCE(SUM(paid_amount), 0) as cash_out
      FROM transactions
      WHERE transaction_type = 'RETURN'
        AND party_type = 'customer'
        AND payment_mode = 'cash'
        AND status != 'CANCELLED'
        AND transaction_date >= ? AND transaction_date <= ?
      GROUP BY DATE(transaction_date)
    ''', [start, end]);

    // ── 7. Expenses ──
    final expenses = await db.rawQuery('''
      SELECT DATE(expense_date) as day,
             COALESCE(SUM(amount), 0) as cash_out,
             GROUP_CONCAT(title, ' | ') as titles
      FROM expenses
      WHERE expense_date >= ? AND expense_date <= ?
      GROUP BY DATE(expense_date)
    ''', [start, end]);

    // ── Accrual totals (for big-picture summary) ──
    final accrualSell = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as total,
             COALESCE(SUM(paid_amount), 0) as paid,
             COALESCE(SUM(credit_amount), 0) as credit
      FROM transactions
      WHERE transaction_type = 'SELL' AND status != 'CANCELLED'
        AND transaction_date >= ? AND transaction_date <= ?
    ''', [start, end]);

    final accrualBuy = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as total,
             COALESCE(SUM(paid_amount), 0) as paid,
             COALESCE(SUM(credit_amount), 0) as credit
      FROM transactions
      WHERE transaction_type = 'BUY' AND status != 'CANCELLED'
        AND transaction_date >= ? AND transaction_date <= ?
    ''', [start, end]);

    final totalExpenses = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM expenses
      WHERE expense_date >= ? AND expense_date <= ?
    ''', [start, end]);

    // ── Build day-keyed map ──
    final days = <String, Map<String, dynamic>>{};

    void addIn(List<Map<String, dynamic>> rows, String field) {
      for (final r in rows) {
        final day = r['day'] as String;
        days.putIfAbsent(day, () => _emptyDay(day));
        days[day]![field] = (days[day]![field] as double) + (r['cash_in'] as num).toDouble();
      }
    }

    void addOut(List<Map<String, dynamic>> rows, String field, {String? labelField}) {
      for (final r in rows) {
        final day = r['day'] as String;
        days.putIfAbsent(day, () => _emptyDay(day));
        days[day]![field] = (days[day]![field] as double) + (r['cash_out'] as num).toDouble();
        if (labelField != null && r[labelField] != null) {
          final existing = days[day]!['expense_titles'] as String? ?? '';
          days[day]!['expense_titles'] =
              existing.isEmpty ? r[labelField] as String : '$existing | ${r[labelField]}';
        }
      }
    }

    addIn(sellCash, 'sell_cash');
    addIn(customerPayments, 'customer_payments');
    addIn(supplierReturnCash, 'supplier_return_cash');
    addOut(buyCash, 'buy_cash');
    addOut(supplierPayments, 'supplier_payments');
    addOut(customerReturnCash, 'customer_return_cash');
    addOut(expenses, 'expenses', labelField: 'titles');

    // Compute net for each day
    for (final d in days.values) {
      d['total_in'] = (d['sell_cash'] as double) +
          (d['customer_payments'] as double) +
          (d['supplier_return_cash'] as double);
      d['total_out'] = (d['buy_cash'] as double) +
          (d['supplier_payments'] as double) +
          (d['customer_return_cash'] as double) +
          (d['expenses'] as double);
      d['net'] = (d['total_in'] as double) - (d['total_out'] as double);
    }

    final sortedDays = days.values.toList()
      ..sort((a, b) => (a['day'] as String).compareTo(b['day'] as String));

    // Grand totals
    double grandIn = 0, grandOut = 0;
    for (final d in sortedDays) {
      grandIn += d['total_in'] as double;
      grandOut += d['total_out'] as double;
    }

    final totalSales = (accrualSell.first['total'] as num).toDouble();
    final totalSalesPaid = (accrualSell.first['paid'] as num).toDouble();
    final totalSalesCredit = (accrualSell.first['credit'] as num).toDouble();
    final totalPurchases = (accrualBuy.first['total'] as num).toDouble();
    final totalPurchasesPaid = (accrualBuy.first['paid'] as num).toDouble();
    final totalPurchasesCredit = (accrualBuy.first['credit'] as num).toDouble();
    final totalExp = (totalExpenses.first['total'] as num).toDouble();

    return {
      'days': sortedDays,
      'grand_cash_in': grandIn,
      'grand_cash_out': grandOut,
      'net_cash': grandIn - grandOut,
      // Accrual summary
      'total_sales': totalSales,
      'total_sales_paid': totalSalesPaid,
      'total_sales_credit': totalSalesCredit,
      'total_purchases': totalPurchases,
      'total_purchases_paid': totalPurchasesPaid,
      'total_purchases_credit': totalPurchasesCredit,
      'total_expenses': totalExp,
      'gross_profit_accrual': totalSales - totalPurchases,
      'net_profit_accrual': totalSales - totalPurchases - totalExp,
    };
  }

  Map<String, dynamic> _emptyDay(String day) => {
        'day': day,
        'sell_cash': 0.0,
        'customer_payments': 0.0,
        'supplier_return_cash': 0.0,
        'buy_cash': 0.0,
        'supplier_payments': 0.0,
        'customer_return_cash': 0.0,
        'expenses': 0.0,
        'expense_titles': '',
        'total_in': 0.0,
        'total_out': 0.0,
        'net': 0.0,
      };

  // ─── Export ──────────────────────────────────────────────────────────────────

  Future<String> exportToExcel({
    required List<Map<String, dynamic>> transactions,
    required String type,
    required String reportType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Transaction Details'];
    final typeLabel = type == 'BUY' ? 'Purchase' : 'Sales';

    sheet.appendRow([
      TextCellValue('$typeLabel Transaction Report — ${reportType == 'date_range' ? 'Date Range' : 'Hourly'}')
    ]);
    if (startDate != null && endDate != null) {
      sheet.appendRow([
        TextCellValue(
            'Period: ${DateFormat('dd MMM yyyy').format(startDate)} – ${DateFormat('dd MMM yyyy').format(endDate)}')
      ]);
    }
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      'Invoice', 'Date', 'Time', 'Party', 'Products', 'Qty',
      'Subtotal', 'Discount', 'Total', 'Cash Paid', 'Credit', 'Status', 'Mode', 'Created By',
    ].map(TextCellValue.new).toList());

    double grandTotal = 0, grandCash = 0, grandCredit = 0;

    for (final t in transactions) {
      final date = DateTime.parse(t['transaction_date'] as String);
      final lines = t['lines'] as List;
      final total = (t['total_amount'] as num).toDouble();
      final cash = ((t['paid_amount'] as num?)?.toDouble() ?? 0);
      final credit = ((t['credit_amount'] as num?)?.toDouble() ?? 0);
      grandTotal += total;
      grandCash += cash;
      grandCredit += credit;

      sheet.appendRow([
        TextCellValue(t['invoice_number'] as String),
        TextCellValue(DateFormat('dd MMM yyyy').format(date)),
        TextCellValue(DateFormat('HH:mm').format(date)),
        TextCellValue(t['party_name'] as String? ?? 'N/A'),
        TextCellValue(lines.map((l) => l['product_name']).join(', ')),
        TextCellValue(lines.fold<double>(0, (s, l) => s + (l['quantity'] as num).toDouble()).toStringAsFixed(2)),
        TextCellValue((t['subtotal'] as num).toStringAsFixed(2)),
        TextCellValue((t['discount_amount'] as num).toStringAsFixed(2)),
        TextCellValue(total.toStringAsFixed(2)),
        TextCellValue(cash.toStringAsFixed(2)),
        TextCellValue(credit.toStringAsFixed(2)),
        TextCellValue(t['payment_status'] as String? ?? 'PAID'),
        TextCellValue(t['payment_mode'] as String? ?? 'cash'),
        TextCellValue(t['user_name'] as String? ?? 'System'),
      ]);
    }

    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue(''), TextCellValue(''), TextCellValue(''),
      TextCellValue(''), TextCellValue(''), TextCellValue(''),
      TextCellValue(''), TextCellValue('GRAND TOTAL'),
      TextCellValue(grandTotal.toStringAsFixed(2)),
      TextCellValue(grandCash.toStringAsFixed(2)),
      TextCellValue(grandCredit.toStringAsFixed(2)),
    ]);

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Failed to encode Excel');

    final fileName =
        '${typeLabel}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    final savedPath = await FileSaveHelper.saveExcel(excelBytes: bytes, fileName: fileName);

    if (savedPath != null) return savedPath;
    final tempPath = await FileSaveHelper.getTempFilePath(fileName);
    await File(tempPath).writeAsBytes(bytes);
    return tempPath;
  }
}
