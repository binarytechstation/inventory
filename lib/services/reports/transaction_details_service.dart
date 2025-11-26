import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import '../../data/database/database_helper.dart';
import '../../core/utils/file_save_helper.dart';

class TransactionDetailsService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Get transactions by date range
  Future<List<Map<String, dynamic>>> getTransactionsByDateRange({
    required String type, // 'BUY' or 'SELL'
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _dbHelper.database;

    // Adjust end date to include the whole day
    final adjustedEndDate = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
    );

    final transactions = await db.query(
      'transactions',
      where: 'transaction_type = ? AND transaction_date >= ? AND transaction_date <= ?',
      whereArgs: [
        type,
        startDate.toIso8601String(),
        adjustedEndDate.toIso8601String(),
      ],
      orderBy: 'transaction_date DESC',
    );

    // Enrich each transaction with lines and user info
    final enrichedTransactions = <Map<String, dynamic>>[];
    for (final transaction in transactions) {
      final enriched = Map<String, dynamic>.from(transaction);

      // Get transaction lines
      final lines = await db.query(
        'transaction_lines',
        where: 'transaction_id = ?',
        whereArgs: [transaction['id']],
      );
      enriched['lines'] = lines;

      // Get user name who created the transaction
      if (transaction['user_id'] != null) {
        final users = await db.query(
          'users',
          where: 'id = ?',
          whereArgs: [transaction['user_id']],
        );
        if (users.isNotEmpty) {
          enriched['user_name'] = users.first['name'];
        } else {
          enriched['user_name'] = 'Unknown User';
        }
      } else {
        enriched['user_name'] = 'System';
      }

      enrichedTransactions.add(enriched);
    }

    return enrichedTransactions;
  }

  /// Get today's transactions grouped by hour (backward compatibility)
  Future<List<Map<String, dynamic>>> getTodayHourlyTransactions({
    required String type, // 'BUY' or 'SELL'
  }) async {
    return getHourlyTransactions(type: type, date: DateTime.now());
  }

  /// Get hourly transactions for a specific date with optional hour range
  Future<List<Map<String, dynamic>>> getHourlyTransactions({
    required String type, // 'BUY' or 'SELL'
    required DateTime date,
    int? startHour, // Optional: filter by start hour (0-23)
    int? endHour, // Optional: filter by end hour (0-23)
  }) async {
    final db = await _dbHelper.database;

    // Set start of day or specific hour
    final startOfDay = startHour != null
        ? DateTime(date.year, date.month, date.day, startHour, 0, 0)
        : DateTime(date.year, date.month, date.day, 0, 0, 0);

    // Set end of day or specific hour
    final endOfDay = endHour != null
        ? DateTime(date.year, date.month, date.day, endHour, 59, 59)
        : DateTime(date.year, date.month, date.day, 23, 59, 59);

    final transactions = await db.query(
      'transactions',
      where: 'transaction_type = ? AND transaction_date >= ? AND transaction_date <= ?',
      whereArgs: [
        type,
        startOfDay.toIso8601String(),
        endOfDay.toIso8601String(),
      ],
      orderBy: 'transaction_date DESC',
    );

    // Enrich each transaction with lines and user info
    final enrichedTransactions = <Map<String, dynamic>>[];
    for (final transaction in transactions) {
      final enriched = Map<String, dynamic>.from(transaction);

      // Get transaction lines
      final lines = await db.query(
        'transaction_lines',
        where: 'transaction_id = ?',
        whereArgs: [transaction['id']],
      );
      enriched['lines'] = lines;

      // Get user name who created the transaction
      if (transaction['user_id'] != null) {
        final users = await db.query(
          'users',
          where: 'id = ?',
          whereArgs: [transaction['user_id']],
        );
        if (users.isNotEmpty) {
          enriched['user_name'] = users.first['name'];
        } else {
          enriched['user_name'] = 'Unknown User';
        }
      } else {
        enriched['user_name'] = 'System';
      }

      enrichedTransactions.add(enriched);
    }

    return enrichedTransactions;
  }

  /// Export transactions to Excel
  Future<String> exportToExcel({
    required List<Map<String, dynamic>> transactions,
    required String type,
    required String reportType, // 'date_range' or 'hourly'
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Transaction Details'];

    // Title
    final typeLabel = type == 'BUY' ? 'Purchase' : 'Sales';
    final reportTypeLabel = reportType == 'date_range' ? 'Date Range' : 'Hourly (Today)';

    sheet.appendRow([TextCellValue('$typeLabel Transaction Details - $reportTypeLabel')]);

    // Date range info
    if (reportType == 'date_range' && startDate != null && endDate != null) {
      sheet.appendRow([TextCellValue('Period: ${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}')]);
    } else if (reportType == 'hourly') {
      sheet.appendRow([TextCellValue('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}')]);
    }

    sheet.appendRow([TextCellValue('')]);

    // Headers
    final headers = ['Invoice', 'Date', 'Time', 'Party', 'Products', 'Quantity', 'Discount', 'User', 'Total'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    // Data rows
    double grandTotal = 0;

    for (final transaction in transactions) {
      final date = DateTime.parse(transaction['transaction_date'] as String);
      final lines = transaction['lines'] as List;

      // Build product names
      final productNames = lines.map((l) => l['product_name'] as String).join(', ');

      // Calculate total quantity
      final totalQty = lines.fold<double>(
        0,
        (sum, l) => sum + (l['quantity'] as num).toDouble(),
      );

      final total = (transaction['total_amount'] as num).toDouble();
      grandTotal += total;

      sheet.appendRow([
        TextCellValue(transaction['invoice_number'] as String),
        TextCellValue(DateFormat('dd MMM yyyy').format(date)),
        TextCellValue(DateFormat('HH:mm:ss').format(date)),
        TextCellValue(transaction['party_name'] as String? ?? 'N/A'),
        TextCellValue(productNames),
        TextCellValue(totalQty.toStringAsFixed(2)),
        TextCellValue((transaction['discount_amount'] as num).toStringAsFixed(2)),
        TextCellValue(transaction['user_name'] as String),
        TextCellValue(total.toStringAsFixed(2)),
      ]);
    }

    // Grand Total Row
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('GRAND TOTAL'),
      TextCellValue(grandTotal.toStringAsFixed(2)),
    ]);

    // Save file
    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel file');
    }

    final fileName = '${typeLabel}_${reportTypeLabel}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

    final savedPath = await FileSaveHelper.saveExcel(
      excelBytes: bytes,
      fileName: fileName,
    );

    if (savedPath == null) {
      // Fallback to temp directory
      final tempPath = await FileSaveHelper.getTempFilePath(fileName);
      final file = File(tempPath);
      await file.writeAsBytes(bytes);
      return tempPath;
    }

    return savedPath;
  }
}
