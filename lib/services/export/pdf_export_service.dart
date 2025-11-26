import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../core/utils/file_save_helper.dart';
import '../currency/currency_service.dart';

class PdfExportService {
  final CurrencyService _currencyService = CurrencyService();

  /// Convert currency symbol to PDF-friendly format
  String _formatCurrencySymbol(String symbol) {
    // Replace ৳ with Tk for PDF font compatibility
    if (symbol == '৳') {
      return 'Tk';
    }
    return symbol;
  }

  /// Generate invoice PDF with all settings applied
  Future<File> generateInvoicePdf({
    required Map<String, dynamic> transaction,
    required Map<String, dynamic> headerSettings,
    required Map<String, dynamic> footerSettings,
    required Map<String, dynamic> bodySettings,
    required Map<String, dynamic> printSettings,
  }) async {
    final pdf = pw.Document();

    // Get currency symbol from settings
    final currencySymbol = _formatCurrencySymbol(await _currencyService.getCurrencySymbol());

    // Get logo if enabled
    pw.ImageProvider? logo;
    if ((headerSettings['show_company_logo'] as int?) == 1 &&
        headerSettings['logo_path'] != null) {
      try {
        final logoFile = File(headerSettings['logo_path'] as String);
        if (await logoFile.exists()) {
          logo = pw.MemoryImage(await logoFile.readAsBytes());
        }
      } catch (e) {
        // Logo loading failed, continue without logo
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: _getPageFormat(printSettings['paper_size'] as String?),
        margin: _getMargins(printSettings),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(headerSettings, logo),
            pw.SizedBox(height: 20),

            // Invoice Details
            _buildInvoiceDetails(transaction, headerSettings),
            pw.SizedBox(height: 20),

            // Party Details
            _buildPartyDetails(transaction, bodySettings),
            pw.SizedBox(height: 20),

            // Items Table
            _buildItemsTable(transaction, bodySettings, currencySymbol),
            pw.SizedBox(height: 20),

            // Totals and QR Code
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // QR Code (if enabled)
                if ((bodySettings['show_qr_code'] as int?) == 1) ...[
                  _buildQRCode(transaction),
                  pw.SizedBox(width: 20),
                ],
                pw.Expanded(
                  child: _buildTotals(transaction, bodySettings, currencySymbol),
                ),
              ],
            ),
            pw.Spacer(),

            // Footer
            _buildFooter(footerSettings),
          ],
        ),
      ),
    );

    // Save to file using cross-platform helper
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'invoice_${transaction['invoice_number']}_$timestamp.pdf';
    final pdfBytes = await pdf.save();

    final savedPath = await FileSaveHelper.savePdf(
      pdfBytes: pdfBytes,
      fileName: fileName,
    );

    if (savedPath == null) {
      // User cancelled or error occurred - save to temp directory
      final tempPath = await FileSaveHelper.getTempFilePath(fileName);
      final file = File(tempPath);
      await file.writeAsBytes(pdfBytes);
      return file;
    }

    return File(savedPath);
  }

  /// Generate sales report PDF
  Future<File> generateSalesReportPdf({
    required Map<String, dynamic> data,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();

    // Get currency symbol from settings
    final currencySymbol = _formatCurrencySymbol(await _currencyService.getCurrencySymbol());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          // Title
          pw.Header(
            level: 0,
            child: pw.Text(
              'Sales Summary Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 10),

          // Date Range
          pw.Text(
            'Period: ${_formatDate(startDate)} to ${_formatDate(endDate)}',
          ),
          pw.SizedBox(height: 20),

          // Summary Table
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              _buildPdfRow(
                'Total Transactions',
                data['total_transactions'].toString(),
                isHeader: false,
              ),
              _buildPdfRow(
                'Unique Customers',
                data['unique_customers'].toString(),
                isHeader: false,
              ),
              _buildPdfRow(
                'Subtotal',
                '$currencySymbol${(data['subtotal'] as num).toStringAsFixed(2)}',
                isHeader: false,
              ),
              _buildPdfRow(
                'Total Discount',
                '$currencySymbol${(data['total_discount'] as num).toStringAsFixed(2)}',
                isHeader: false,
              ),
              _buildPdfRow(
                'Total Tax',
                '$currencySymbol${(data['total_tax'] as num).toStringAsFixed(2)}',
                isHeader: false,
              ),
              _buildPdfRow(
                'Total Sales',
                '$currencySymbol${(data['total_sales'] as num).toStringAsFixed(2)}',
                isHeader: true,
              ),
              _buildPdfRow(
                'Average Sale',
                '$currencySymbol${(data['average_sale'] as num).toStringAsFixed(2)}',
                isHeader: false,
              ),
            ],
          ),
        ],
      ),
    );

    return await _savePdf(pdf, 'sales_report');
  }

  /// Generate inventory report PDF
  Future<File> generateInventoryReportPdf(
    List<Map<String, dynamic>> data,
  ) async {
    final pdf = pw.Document();

    // Get currency symbol from settings
    final currencySymbol = _formatCurrencySymbol(await _currencyService.getCurrencySymbol());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          // Title
          pw.Header(
            level: 0,
            child: pw.Text(
              'Inventory Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),

          // Products Table
          pw.Table.fromTextArray(
            headers: ['Product', 'SKU', 'Stock', 'Value'],
            data: data
                .map(
                  (item) => [
                    item['name'] ?? '',
                    item['sku'] ?? '',
                    ((item['current_stock'] as num?)?.toDouble() ?? 0)
                        .toStringAsFixed(1),
                    '$currencySymbol${(item['inventory_value'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    return await _savePdf(pdf, 'inventory_report');
  }

  /// Generate profit & loss report PDF
  Future<File> generateProfitLossReportPdf({
    required Map<String, dynamic> data,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();

    // Get currency symbol from settings
    final currencySymbol = _formatCurrencySymbol(await _currencyService.getCurrencySymbol());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          // Title
          pw.Header(
            level: 0,
            child: pw.Text(
              'Profit & Loss Statement',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 10),

          // Date Range
          pw.Text(
            'Period: ${_formatDate(startDate)} to ${_formatDate(endDate)}',
          ),
          pw.SizedBox(height: 20),

          // P&L Table
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              _buildPdfRow(
                'Total Revenue',
                '$currencySymbol${(data['total_revenue'] as num).toStringAsFixed(2)}',
                isHeader: false,
              ),
              _buildPdfRow(
                'Cost of Goods Sold',
                '$currencySymbol${(data['total_cogs'] as num).toStringAsFixed(2)}',
                isHeader: false,
              ),
              _buildPdfRow(
                'Gross Profit',
                '$currencySymbol${(data['gross_profit'] as num).toStringAsFixed(2)}',
                isHeader: true,
              ),
              _buildPdfRow(
                'Discounts Given',
                '$currencySymbol${(data['total_discounts'] as num).toStringAsFixed(2)}',
                isHeader: false,
              ),
              _buildPdfRow(
                'Net Profit',
                '$currencySymbol${(data['net_profit'] as num).toStringAsFixed(2)}',
                isHeader: true,
              ),
              _buildPdfRow(
                'Profit Margin',
                '${(data['profit_margin_percentage'] as num).toStringAsFixed(2)}%',
                isHeader: false,
              ),
            ],
          ),
        ],
      ),
    );

    return await _savePdf(pdf, 'profit_loss_report');
  }

  // Helper: Build PDF Header
  pw.Widget _buildHeader(
    Map<String, dynamic> settings,
    pw.ImageProvider? logo,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null) pw.Image(logo, width: 100, height: 50),
            pw.Text(
              settings['company_name'] as String? ?? 'Company Name',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            if ((settings['company_tagline'] as String? ?? '').isNotEmpty)
              pw.Text(settings['company_tagline'] as String? ?? ''),
            if ((settings['show_company_address'] as int?) == 1)
              pw.Text(settings['company_address'] as String? ?? ''),
            if ((settings['show_company_phone'] as int?) == 1)
              pw.Text(settings['company_phone'] as String? ?? ''),
            if ((settings['show_company_email'] as int?) == 1)
              pw.Text(settings['company_email'] as String? ?? ''),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              settings['invoice_title'] as String? ?? 'INVOICE',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  // Helper: Build Invoice Details
  pw.Widget _buildInvoiceDetails(
    Map<String, dynamic> transaction,
    Map<String, dynamic> settings,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Invoice No: ${transaction['invoice_number'] ?? 'N/A'}'),
            pw.Text(
              'Date: ${_formatDate(DateTime.tryParse(transaction['transaction_date'] ?? '') ?? DateTime.now())}',
            ),
          ],
        ),
      ],
    );
  }

  // Helper: Build Party Details
  pw.Widget _buildPartyDetails(
    Map<String, dynamic> transaction,
    Map<String, dynamic> settings,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            settings['party_label'] as String? ?? 'Bill To',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(transaction['party_name'] ?? 'N/A'),
        ],
      ),
    );
  }

  // Helper: Build Items Table
  pw.Widget _buildItemsTable(
    Map<String, dynamic> transaction,
    Map<String, dynamic> settings,
    String currencySymbol,
  ) {
    final items = transaction['items'] as List<Map<String, dynamic>>? ?? [];

    return pw.Table.fromTextArray(
      headers: ['Item', 'Qty', 'Price', 'Amount'],
      data: items
          .map(
            (item) => [
              item['product_name'] ?? '',
              (item['quantity'] ?? 0).toString(),
              '$currencySymbol${(item['unit_price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
              '$currencySymbol${(item['line_total'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
            ],
          )
          .toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  // Helper: Build Totals
  pw.Widget _buildTotals(
    Map<String, dynamic> transaction,
    Map<String, dynamic> settings,
    String currencySymbol,
  ) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 250,
        child: pw.Column(
          children: [
            if ((settings['show_subtotal'] as int?) == 1)
              _buildTotalRow(
                settings['subtotal_label'] as String? ?? 'Subtotal',
                '$currencySymbol${(transaction['subtotal'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
              ),
            if ((settings['show_discount_total'] as int?) == 1 &&
                (transaction['discount_amount'] as num? ?? 0) > 0)
              _buildTotalRow(
                settings['discount_label'] as String? ?? 'Discount',
                '$currencySymbol${(transaction['discount_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
              ),
            if ((settings['show_tax_total'] as int?) == 1)
              _buildTotalRow(
                settings['tax_label'] as String? ?? 'Tax',
                '$currencySymbol${(transaction['tax_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
              ),
            pw.Divider(),
            _buildTotalRow(
              settings['grand_total_label'] as String? ?? 'Grand Total',
              '$currencySymbol${(transaction['total_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  // Helper: Build QR Code
  pw.Widget _buildQRCode(Map<String, dynamic> transaction) {
    // Create QR code data with invoice information
    final qrData = 'Invoice: ${transaction['invoice_number']}\n'
        'Date: ${transaction['transaction_date']}\n'
        'Amount: ${transaction['total_amount']}\n'
        'Party: ${transaction['party_name'] ?? 'N/A'}';

    return pw.Container(
      width: 100,
      height: 100,
      child: pw.BarcodeWidget(
        barcode: pw.Barcode.qrCode(),
        data: qrData,
      ),
    );
  }

  // Helper: Build Total Row
  pw.Widget _buildTotalRow(String label, String value, {bool isBold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: isBold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
        ),
        pw.Text(
          value,
          style: isBold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
        ),
      ],
    );
  }

  // Helper: Build Footer
  pw.Widget _buildFooter(Map<String, dynamic> settings) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if ((settings['show_footer_text'] as int?) == 1)
          pw.Text(settings['footer_text'] as String? ?? ''),
        if ((settings['show_terms_and_conditions'] as int?) == 1) ...[
          pw.SizedBox(height: 10),
          pw.Text(
            'Terms & Conditions:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(settings['terms_and_conditions'] as String? ?? ''),
        ],
      ],
    );
  }

  // Helper: Build PDF Row
  pw.TableRow _buildPdfRow(
    String label,
    String value, {
    bool isHeader = false,
  }) {
    return pw.TableRow(
      decoration: isHeader
          ? const pw.BoxDecoration(color: PdfColors.grey200)
          : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            label,
            style: isHeader
                ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                : null,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            value,
            style: isHeader
                ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                : null,
          ),
        ),
      ],
    );
  }

  // Helper: Get Page Format
  PdfPageFormat _getPageFormat(String? size) {
    switch (size) {
      case 'LETTER':
        return PdfPageFormat.letter;
      case 'LEGAL':
        return PdfPageFormat.legal;
      case 'A4':
      default:
        return PdfPageFormat.a4;
    }
  }

  // Helper: Get Margins
  pw.EdgeInsets _getMargins(Map<String, dynamic> settings) {
    final top = (settings['margin_top'] as num?)?.toDouble() ?? 20.0;
    final bottom = (settings['margin_bottom'] as num?)?.toDouble() ?? 20.0;
    final left = (settings['margin_left'] as num?)?.toDouble() ?? 20.0;
    final right = (settings['margin_right'] as num?)?.toDouble() ?? 20.0;

    return pw.EdgeInsets.fromLTRB(left, top, right, bottom);
  }

  // Helper: Save PDF
  Future<File> _savePdf(pw.Document pdf, String prefix) async {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = '${prefix}_$timestamp.pdf';
    final pdfBytes = await pdf.save();

    // Use FileSaveHelper for cross-platform saving
    // Windows: Saves directly to Documents (existing behavior)
    // macOS/Linux: Shows save dialog for proper permissions
    final savedPath = await FileSaveHelper.savePdf(
      pdfBytes: pdfBytes,
      fileName: fileName,
    );

    if (savedPath == null) {
      // User cancelled or error occurred
      // Fallback: save to temp directory
      final tempPath = await FileSaveHelper.getTempFilePath(fileName);
      final file = File(tempPath);
      await file.writeAsBytes(pdfBytes);
      return file;
    }

    return File(savedPath);
  }

  // Helper: Format Date
  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Preview PDF before saving
  /// NOTE: Temporarily disabled due to printing package build issues on Windows
  /// Uncomment when pdfium download issue is resolved
  // Future<void> previewPdf(pw.Document pdf) async {
  //   await Printing.layoutPdf(
  //     onLayout: (format) async => pdf.save(),
  //   );
  // }

  Future<void> previewPdf(pw.Document pdf) async {
    try {
      // Initialize printing (fixes Windows pdfium download issues)
      await Printing.info();

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      print("PDF preview failed: $e");
    }
  }
}
