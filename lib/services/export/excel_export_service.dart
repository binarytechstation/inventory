import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class ExcelExportService {
  /// Export sales report to Excel
  Future<File> exportSalesReport({
    required Map<String, dynamic> data,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Sales Report'];

    // Title and date range
    sheet.appendRow([TextCellValue('Sales Summary Report')]);
    sheet.appendRow([TextCellValue('Period: ${_formatDate(startDate)} to ${_formatDate(endDate)}')]);
    sheet.appendRow([TextCellValue('')]);

    // Headers
    final headers = ['Metric', 'Value'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    // Apply header styling
    _styleHeaderRow(sheet, 3);

    // Data rows
    sheet.appendRow([TextCellValue('Total Transactions'), TextCellValue(data['total_transactions'].toString())]);
    sheet.appendRow([TextCellValue('Unique Customers'), TextCellValue(data['unique_customers'].toString())]);
    sheet.appendRow([TextCellValue('Subtotal'), TextCellValue('\$${(data['subtotal'] as num).toStringAsFixed(2)}')]);
    sheet.appendRow([TextCellValue('Total Discount'), TextCellValue('\$${(data['total_discount'] as num).toStringAsFixed(2)}')]);
    sheet.appendRow([TextCellValue('Total Tax'), TextCellValue('\$${(data['total_tax'] as num).toStringAsFixed(2)}')]);
    sheet.appendRow([TextCellValue('Total Sales'), TextCellValue('\$${(data['total_sales'] as num).toStringAsFixed(2)}')]);
    sheet.appendRow([TextCellValue('Average Sale'), TextCellValue('\$${(data['average_sale'] as num).toStringAsFixed(2)}')]);

    // Bold the total sales row
    final totalRow = 3 + 5; // Header row + 5 data rows
    _styleTotalRow(sheet, totalRow);

    // Set column widths
    _setColWidth(sheet, 0, 25);
    _setColWidth(sheet, 1, 20);

    return await _saveExcel(excel, 'sales_report');
  }

  /// Export purchases report to Excel
  Future<File> exportPurchasesReport({
    required Map<String, dynamic> data,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Purchase Report'];

    // Title and date range
    sheet.appendRow([TextCellValue('Purchase Summary Report')]);
    sheet.appendRow([TextCellValue('Period: ${_formatDate(startDate)} to ${_formatDate(endDate)}')]);
    sheet.appendRow([TextCellValue('')]);

    // Headers
    sheet.appendRow([TextCellValue('Metric'), TextCellValue('Value')]);
    _styleHeaderRow(sheet, 3);

    // Data rows
    sheet.appendRow([TextCellValue('Total Transactions'), TextCellValue(data['total_transactions'].toString())]);
    sheet.appendRow([TextCellValue('Unique Suppliers'), TextCellValue(data['unique_suppliers'].toString())]);
    sheet.appendRow([TextCellValue('Subtotal'), TextCellValue('\$${(data['subtotal'] as num).toStringAsFixed(2)}')]);
    sheet.appendRow([TextCellValue('Total Discount'), TextCellValue('\$${(data['total_discount'] as num).toStringAsFixed(2)}')]);
    sheet.appendRow([TextCellValue('Total Tax'), TextCellValue('\$${(data['total_tax'] as num).toStringAsFixed(2)}')]);
    sheet.appendRow([TextCellValue('Total Purchases'), TextCellValue('\$${(data['total_purchases'] as num).toStringAsFixed(2)}')]);
    sheet.appendRow([TextCellValue('Average Purchase'), TextCellValue('\$${(data['average_purchase'] as num).toStringAsFixed(2)}')]);

    _styleTotalRow(sheet, 8);

    _setColWidth(sheet, 0, 25);
    _setColWidth(sheet, 1, 20);

    return await _saveExcel(excel, 'purchase_report');
  }

  /// Export inventory report to Excel
  Future<File> exportInventoryReport(List<Map<String, dynamic>> data) async {
    final excel = Excel.createExcel();
    final sheet = excel['Inventory'];

    // Title
    sheet.appendRow([TextCellValue('Inventory Report')]);
    sheet.appendRow([TextCellValue('Generated: ${_formatDateTime(DateTime.now())}')]);
    sheet.appendRow([TextCellValue('')]);

    // Headers
    sheet.appendRow([
      TextCellValue('Product'),
      TextCellValue('SKU'),
      TextCellValue('Category'),
      TextCellValue('Current Stock'),
      TextCellValue('Reorder Level'),
      TextCellValue('Avg Cost'),
      TextCellValue('Inventory Value'),
      TextCellValue('Status'),
    ]);
    _styleHeaderRow(sheet, 3);

    // Data rows
    for (var item in data) {
      final stock = (item['current_stock'] as num?)?.toDouble() ?? 0;
      final reorderLevel = (item['reorder_level'] as int?) ?? 0;
      final isLowStock = stock <= reorderLevel;

      sheet.appendRow([
        TextCellValue(item['name'] ?? ''),
        TextCellValue(item['sku'] ?? ''),
        TextCellValue(item['category'] ?? ''),
        TextCellValue(stock.toStringAsFixed(1)),
        TextCellValue(reorderLevel.toString()),
        TextCellValue('\$${(item['avg_cost'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
        TextCellValue('\$${(item['inventory_value'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
        TextCellValue(isLowStock ? 'LOW STOCK' : 'OK'),
      ]);
    }

    // Set column widths
    for (int i = 0; i < 8; i++) {
      _setColWidth(sheet, i, 15);
    }

    return await _saveExcel(excel, 'inventory_report');
  }

  /// Export product performance report to Excel
  Future<File> exportProductPerformanceReport({
    required List<Map<String, dynamic>> data,
    required DateTime startDate,
    required DateTime endDate,
    required bool topPerformers,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Product Performance'];

    // Title
    sheet.appendRow([TextCellValue('${topPerformers ? 'Top' : 'Bottom'} Performing Products')]);
    sheet.appendRow([TextCellValue('Period: ${_formatDate(startDate)} to ${_formatDate(endDate)}')]);
    sheet.appendRow([TextCellValue('')]);

    // Headers
    sheet.appendRow([
      TextCellValue('Product'),
      TextCellValue('SKU'),
      TextCellValue('Transactions'),
      TextCellValue('Quantity Sold'),
      TextCellValue('Total Revenue'),
      TextCellValue('Avg Selling Price'),
    ]);
    _styleHeaderRow(sheet, 3);

    // Data rows
    for (var product in data) {
      sheet.appendRow([
        TextCellValue(product['name'] ?? ''),
        TextCellValue(product['sku'] ?? ''),
        TextCellValue((product['transaction_count'] ?? 0).toString()),
        TextCellValue(((product['total_quantity'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)),
        TextCellValue('\$${(product['total_revenue'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
        TextCellValue('\$${(product['avg_selling_price'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
      ]);
    }

    // Set column widths
    for (int i = 0; i < 6; i++) {
      _setColWidth(sheet, i, 20);
    }

    return await _saveExcel(excel, topPerformers ? 'top_products' : 'bottom_products');
  }

  /// Export customer report to Excel
  Future<File> exportCustomerReport(List<Map<String, dynamic>> data) async {
    final excel = Excel.createExcel();
    final sheet = excel['Customer Report'];

    // Title
    sheet.appendRow([TextCellValue('Customer Report')]);
    sheet.appendRow([TextCellValue('Generated: ${_formatDateTime(DateTime.now())}')]);
    sheet.appendRow([TextCellValue('')]);

    // Headers
    sheet.appendRow([
      TextCellValue('Customer'),
      TextCellValue('Company'),
      TextCellValue('Email'),
      TextCellValue('Phone'),
      TextCellValue('Total Sales'),
      TextCellValue('Transactions'),
      TextCellValue('Current Balance'),
      TextCellValue('Last Transaction'),
    ]);
    _styleHeaderRow(sheet, 3);

    // Data rows
    for (var customer in data) {
      final lastTxn = customer['last_transaction_date'] != null
          ? _formatDate(DateTime.parse(customer['last_transaction_date'] as String))
          : 'N/A';

      sheet.appendRow([
        TextCellValue(customer['name'] ?? ''),
        TextCellValue(customer['company_name'] ?? ''),
        TextCellValue(customer['email'] ?? ''),
        TextCellValue(customer['phone'] ?? ''),
        TextCellValue('\$${(customer['total_sales'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
        TextCellValue((customer['sales_count'] ?? 0).toString()),
        TextCellValue('\$${(customer['current_balance'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
        TextCellValue(lastTxn),
      ]);
    }

    // Set column widths
    for (int i = 0; i < 8; i++) {
      _setColWidth(sheet, i, 20);
    }

    return await _saveExcel(excel, 'customer_report');
  }

  /// Export supplier report to Excel
  Future<File> exportSupplierReport(List<Map<String, dynamic>> data) async {
    final excel = Excel.createExcel();
    final sheet = excel['Supplier Report'];

    // Title
    sheet.appendRow([TextCellValue('Supplier Report')]);
    sheet.appendRow([TextCellValue('Generated: ${_formatDateTime(DateTime.now())}')]);
    sheet.appendRow([TextCellValue('')]);

    // Headers
    sheet.appendRow([
      TextCellValue('Supplier'),
      TextCellValue('Company'),
      TextCellValue('Email'),
      TextCellValue('Phone'),
      TextCellValue('Total Purchases'),
      TextCellValue('Purchase Count'),
      TextCellValue('Avg Purchase'),
      TextCellValue('Last Purchase'),
    ]);
    _styleHeaderRow(sheet, 3);

    // Data rows
    for (var supplier in data) {
      final lastPurchase = supplier['last_purchase_date'] != null
          ? _formatDate(DateTime.parse(supplier['last_purchase_date'] as String))
          : 'N/A';

      sheet.appendRow([
        TextCellValue(supplier['name'] ?? ''),
        TextCellValue(supplier['company_name'] ?? ''),
        TextCellValue(supplier['email'] ?? ''),
        TextCellValue(supplier['phone'] ?? ''),
        TextCellValue('\$${(supplier['total_amount_purchased'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
        TextCellValue((supplier['total_purchases'] ?? 0).toString()),
        TextCellValue('\$${(supplier['avg_purchase_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
        TextCellValue(lastPurchase),
      ]);
    }

    // Set column widths
    for (int i = 0; i < 8; i++) {
      _setColWidth(sheet, i, 20);
    }

    return await _saveExcel(excel, 'supplier_report');
  }

  /// Export profit & loss report to Excel
  Future<File> exportProfitLossReport({
    required Map<String, dynamic> data,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Profit & Loss'];

    // Title
    sheet.appendRow([TextCellValue('Profit & Loss Statement')]);
    sheet.appendRow([TextCellValue('Period: ${_formatDate(startDate)} to ${_formatDate(endDate)}')]);
    sheet.appendRow([TextCellValue('')]);

    // Headers
    sheet.appendRow([TextCellValue('Item'), TextCellValue('Amount')]);
    _styleHeaderRow(sheet, 3);

    // Revenue Section
    sheet.appendRow([TextCellValue('REVENUE'), TextCellValue('')]);
    sheet.appendRow([TextCellValue('Total Revenue'), TextCellValue('\$${(data['total_revenue'] as num).toStringAsFixed(2)}')]);
    sheet.appendRow([TextCellValue('')]);

    // Cost Section
    sheet.appendRow([TextCellValue('COSTS'), TextCellValue('')]);
    sheet.appendRow([TextCellValue('Cost of Goods Sold'), TextCellValue('\$${(data['total_cogs'] as num).toStringAsFixed(2)}')]);
    sheet.appendRow([TextCellValue('')]);

    // Gross Profit
    sheet.appendRow([TextCellValue('GROSS PROFIT'), TextCellValue('\$${(data['gross_profit'] as num).toStringAsFixed(2)}')]);
    _styleTotalRow(sheet, 11);
    sheet.appendRow([TextCellValue('')]);

    // Operating Expenses
    sheet.appendRow([TextCellValue('OPERATING EXPENSES'), TextCellValue('')]);
    sheet.appendRow([TextCellValue('Discounts Given'), TextCellValue('\$${(data['total_discounts'] as num).toStringAsFixed(2)}')]);
    sheet.appendRow([TextCellValue('')]);

    // Net Profit
    final netProfit = (data['net_profit'] as num).toDouble();
    sheet.appendRow([TextCellValue('NET PROFIT'), TextCellValue('\$${netProfit.toStringAsFixed(2)}')]);
    _styleTotalRow(sheet, 16);

    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('Profit Margin'), TextCellValue('${(data['profit_margin_percentage'] as num).toStringAsFixed(2)}%')]);

    // Set column widths
    _setColWidth(sheet, 0, 30);
    _setColWidth(sheet, 1, 20);

    return await _saveExcel(excel, 'profit_loss_report');
  }

  /// Export category analysis report to Excel
  Future<File> exportCategoryReport({
    required List<Map<String, dynamic>> data,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Category Analysis'];

    // Title
    sheet.appendRow([TextCellValue('Category Analysis Report')]);
    sheet.appendRow([TextCellValue('Period: ${_formatDate(startDate)} to ${_formatDate(endDate)}')]);
    sheet.appendRow([TextCellValue('')]);

    // Headers
    sheet.appendRow([
      TextCellValue('Category'),
      TextCellValue('Transactions'),
      TextCellValue('Total Quantity'),
      TextCellValue('Total Amount'),
      TextCellValue('Percentage'),
    ]);
    _styleHeaderRow(sheet, 3);

    // Calculate total
    double totalAmount = 0;
    for (var category in data) {
      totalAmount += (category['total_amount'] as num?)?.toDouble() ?? 0;
    }

    // Data rows
    for (var category in data) {
      final amount = (category['total_amount'] as num?)?.toDouble() ?? 0;
      final percentage = totalAmount > 0 ? (amount / totalAmount * 100) : 0;

      sheet.appendRow([
        TextCellValue(category['category']?.toString() ?? 'Uncategorized'),
        TextCellValue((category['transaction_count'] ?? 0).toString()),
        TextCellValue(((category['total_quantity'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)),
        TextCellValue('\$${amount.toStringAsFixed(2)}'),
        TextCellValue('${percentage.toStringAsFixed(2)}%'),
      ]);
    }

    // Total row
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('TOTAL'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('\$${totalAmount.toStringAsFixed(2)}'),
      TextCellValue('100.00%'),
    ]);
    _styleTotalRow(sheet, 4 + data.length + 1);

    // Set column widths
    for (int i = 0; i < 5; i++) {
      _setColWidth(sheet, i, 20);
    }

    return await _saveExcel(excel, 'category_report');
  }

  // Helper: Style header row
  void _styleHeaderRow(Sheet sheet, int rowIndex) {
    // Bold styling would be applied here if supported by the excel package version
    // Current version has limited styling support
  }

  // Helper: Style total row
  void _styleTotalRow(Sheet sheet, int rowIndex) {
    // Bold styling would be applied here if supported by the excel package version
  }

  // Helper: Set column width
  void _setColWidth(Sheet sheet, int col, double width) {
    // Column width setting - note: excel package v4 has different API
    // This is a placeholder - actual implementation may vary based on package version
  }

  // Helper: Save Excel file
  Future<File> _saveExcel(Excel excel, String prefix) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = '${prefix}_$timestamp.xlsx';
    final file = File('${directory.path}/$fileName');

    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }

    return file;
  }

  // Helper: Format date
  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // Helper: Format date time
  String _formatDateTime(DateTime date) {
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }
}
