import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../data/database/database_helper.dart';
import '../../core/utils/file_save_helper.dart';

class InvoiceService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Generate invoice PDF for a transaction
  Future<String> generateInvoicePDF({
    required int transactionId,
    bool saveToFile = true,
  }) async {
    // Get transaction details
    final transaction = await _getTransactionDetails(transactionId);
    if (transaction == null) {
      throw Exception('Transaction not found');
    }

    // Get invoice settings based on transaction type
    final invoiceType = transaction['transaction_type'] as String;
    final settings = await _getInvoiceSettings(invoiceType);

    // Generate PDF
    final pdf = await _buildInvoicePDF(transaction, settings);

    if (saveToFile) {
      // Save to file
      final file = await _savePDFToFile(pdf, transaction['invoice_number'] as String);
      return file.path;
    } else {
      // Return temp path for preview
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${transaction['invoice_number']}.pdf');
      await tempFile.writeAsBytes(await pdf.save());
      return tempFile.path;
    }
  }

  /// Get transaction with all details
  Future<Map<String, dynamic>?> _getTransactionDetails(int transactionId) async {
    final db = await _dbHelper.database;

    final transactions = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
    );

    if (transactions.isEmpty) return null;

    final transaction = Map<String, dynamic>.from(transactions.first);

    // Get transaction lines
    final lines = await db.query(
      'transaction_lines',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );

    transaction['lines'] = lines;

    // Get party details
    final partyType = transaction['party_type'] as String?;
    final partyId = transaction['party_id'] as int?;

    if (partyType != null && partyId != null) {
      final tableName = partyType == 'customer' ? 'customers' : 'suppliers';
      final parties = await db.query(
        tableName,
        where: 'id = ?',
        whereArgs: [partyId],
      );

      if (parties.isNotEmpty) {
        transaction['party_details'] = parties.first;
      }
    }

    return transaction;
  }

  /// Get invoice settings for the transaction type
  Future<Map<String, dynamic>> _getInvoiceSettings(String transactionType) async {
    final db = await _dbHelper.database;

    // Map transaction type to invoice type
    String invoiceType;
    switch (transactionType) {
      case 'SELL':
        invoiceType = 'SALE';
        break;
      case 'BUY':
        invoiceType = 'PURCHASE';
        break;
      default:
        invoiceType = 'SALE';
    }

    final settings = <String, dynamic>{};

    // Get general invoice settings
    final generalSettings = await db.query(
      'invoice_settings',
      where: 'invoice_type = ?',
      whereArgs: [invoiceType],
    );

    if (generalSettings.isNotEmpty) {
      settings['general'] = generalSettings.first;
    }

    // Get header settings
    final headerSettings = await db.query(
      'invoice_header_settings',
      where: 'invoice_type = ?',
      whereArgs: [invoiceType],
    );

    if (headerSettings.isNotEmpty) {
      settings['header'] = headerSettings.first;
    }

    // Get footer settings
    final footerSettings = await db.query(
      'invoice_footer_settings',
      where: 'invoice_type = ?',
      whereArgs: [invoiceType],
    );

    if (footerSettings.isNotEmpty) {
      settings['footer'] = footerSettings.first;
    }

    // Get body settings
    final bodySettings = await db.query(
      'invoice_body_settings',
      where: 'invoice_type = ?',
      whereArgs: [invoiceType],
    );

    if (bodySettings.isNotEmpty) {
      settings['body'] = bodySettings.first;
    }

    // Get print settings
    final printSettings = await db.query(
      'invoice_print_settings',
      where: 'invoice_type = ?',
      whereArgs: [invoiceType],
    );

    if (printSettings.isNotEmpty) {
      settings['print'] = printSettings.first;
    }

    // Get company profile
    final profile = await db.query('profile', limit: 1);
    if (profile.isNotEmpty) {
      settings['profile'] = profile.first;
    }

    return settings;
  }

  /// Build the PDF document
  Future<pw.Document> _buildInvoicePDF(
    Map<String, dynamic> transaction,
    Map<String, dynamic> settings,
  ) async {
    final pdf = pw.Document();

    final headerSettings = settings['header'] as Map<String, dynamic>?;
    final footerSettings = settings['footer'] as Map<String, dynamic>?;
    final bodySettings = settings['body'] as Map<String, dynamic>?;
    final profile = settings['profile'] as Map<String, dynamic>?;

    // Get currency symbol from transaction (preserves historical currency)
    // Use 'Tk' for PDF compatibility instead of '৳' which has font rendering issues
    String currencySymbol = transaction['currency_symbol'] as String? ?? 'Tk';
    // Replace ৳ with Tk for PDF rendering
    if (currencySymbol == '৳') {
      currencySymbol = 'Tk';
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(transaction, headerSettings, profile),
              pw.SizedBox(height: 20),

              // Invoice details
              _buildInvoiceDetails(transaction),
              pw.SizedBox(height: 20),

              // Party details
              if (bodySettings?['show_party_details'] == 1)
                _buildPartyDetails(transaction, bodySettings),
              pw.SizedBox(height: 20),

              // Items table
              _buildItemsTable(transaction, bodySettings, currencySymbol),
              pw.SizedBox(height: 20),

              // Totals
              _buildTotals(transaction, bodySettings, currencySymbol),

              // Footer
              pw.Spacer(),
              if (footerSettings?['show_footer_text'] == 1)
                _buildFooter(footerSettings, bodySettings, transaction),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// Build invoice header
  pw.Widget _buildHeader(
    Map<String, dynamic> transaction,
    Map<String, dynamic>? headerSettings,
    Map<String, dynamic>? profile,
  ) {
    final companyName = headerSettings?['company_name'] as String? ??
                        profile?['company_name'] as String? ??
                        'Company Name';

    final companyAddress = headerSettings?['company_address'] as String? ??
                           profile?['address'] as String? ??
                           '';

    final companyPhone = headerSettings?['company_phone'] as String? ??
                         profile?['phone'] as String? ??
                         '';

    final companyEmail = headerSettings?['company_email'] as String? ??
                         profile?['email'] as String? ??
                         '';

    final showInvoiceTitle = headerSettings?['show_invoice_title'] == 1;
    final invoiceTitle = headerSettings?['invoice_title'] as String? ?? 'INVOICE';

    // Logo settings
    final showLogo = headerSettings?['show_company_logo'] == 1;
    final logoPath = headerSettings?['logo_path'] as String?;
    final logoWidth = (headerSettings?['logo_width'] as int?) ?? 150;
    final logoHeight = (headerSettings?['logo_height'] as int?) ?? 80;
    final logoPosition = headerSettings?['logo_position'] as String? ?? 'LEFT';

    // Load logo image if available
    pw.ImageProvider? logoImage;
    if (showLogo && logoPath != null && logoPath.isNotEmpty) {
      try {
        final logoFile = File(logoPath);
        if (logoFile.existsSync()) {
          logoImage = pw.MemoryImage(logoFile.readAsBytesSync());
        }
      } catch (e) {
        // Logo loading failed, continue without logo
        print('Error loading logo: $e');
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left side: Logo (if position is LEFT) and Company info
            pw.Expanded(
              flex: 2,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Logo on the left
                  if (logoImage != null && logoPosition == 'LEFT') ...[
                    pw.Container(
                      width: logoWidth.toDouble(),
                      height: logoHeight.toDouble(),
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(width: 15),
                  ],
                  // Company details
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          companyName,
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (companyAddress.isNotEmpty)
                          pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 10)),
                        if (companyPhone.isNotEmpty)
                          pw.Text('Tel: $companyPhone', style: const pw.TextStyle(fontSize: 10)),
                        if (companyEmail.isNotEmpty)
                          pw.Text('Email: $companyEmail', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Right side: Invoice title or logo
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (logoImage != null && logoPosition == 'RIGHT')
                  pw.Container(
                    width: logoWidth.toDouble(),
                    height: logoHeight.toDouble(),
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                if (showInvoiceTitle)
                  pw.Text(
                    invoiceTitle,
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
                    ),
                  ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 2),
      ],
    );
  }

  /// Build invoice details section
  pw.Widget _buildInvoiceDetails(Map<String, dynamic> transaction) {
    final invoiceNumber = transaction['invoice_number'] as String;
    final date = DateTime.parse(transaction['transaction_date'] as String);

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Invoice Number: $invoiceNumber',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Date: ${DateFormat('dd MMM yyyy').format(date)}'),
            pw.Text('Payment Mode: ${(transaction['payment_mode'] as String).toUpperCase()}'),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Status: ${transaction['status']}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  /// Build party details section
  pw.Widget _buildPartyDetails(
    Map<String, dynamic> transaction,
    Map<String, dynamic>? bodySettings,
  ) {
    final partyDetails = transaction['party_details'] as Map<String, dynamic>?;
    final partyName = transaction['party_name'] as String? ?? 'N/A';
    final partyLabel = bodySettings?['party_label'] as String? ?? 'Bill To';

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            partyLabel,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(partyName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          if (partyDetails != null) ...[
            if (partyDetails['company_name'] != null && (partyDetails['company_name'] as String).isNotEmpty)
              pw.Text(partyDetails['company_name'] as String),
            if (partyDetails['address'] != null && (partyDetails['address'] as String).isNotEmpty)
              pw.Text(partyDetails['address'] as String),
            if (partyDetails['phone'] != null && (partyDetails['phone'] as String).isNotEmpty)
              pw.Text('Phone: ${partyDetails['phone']}'),
            if (partyDetails['email'] != null && (partyDetails['email'] as String).isNotEmpty)
              pw.Text('Email: ${partyDetails['email']}'),
          ],
        ],
      ),
    );
  }

  /// Build items table
  pw.Widget _buildItemsTable(
    Map<String, dynamic> transaction,
    Map<String, dynamic>? bodySettings,
    String currencySymbol,
  ) {
    final lines = transaction['lines'] as List<Map<String, dynamic>>;

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('#', isHeader: true),
            _buildTableCell('Item', isHeader: true),
            _buildTableCell('Qty', isHeader: true),
            _buildTableCell('Unit Price', isHeader: true),
            if (bodySettings?['show_discount_column'] == 1)
              _buildTableCell('Discount', isHeader: true),
            if (bodySettings?['show_tax_column'] == 1)
              _buildTableCell('Tax', isHeader: true),
            _buildTableCell('Amount', isHeader: true),
          ],
        ),
        // Data rows
        ...lines.asMap().entries.map((entry) {
          final index = entry.key;
          final line = entry.value;

          return pw.TableRow(
            children: [
              _buildTableCell('${index + 1}'),
              _buildTableCell(line['product_name'] as String),
              _buildTableCell('${line['quantity']} ${line['unit'] ?? ''}'),
              _buildTableCell('$currencySymbol${(line['unit_price'] as num).toStringAsFixed(2)}'),
              if (bodySettings?['show_discount_column'] == 1)
                _buildTableCell('$currencySymbol${(line['discount_amount'] as num).toStringAsFixed(2)}'),
              if (bodySettings?['show_tax_column'] == 1)
                _buildTableCell('$currencySymbol${(line['tax_amount'] as num).toStringAsFixed(2)}'),
              _buildTableCell(
                '$currencySymbol${(line['line_total'] as num).toStringAsFixed(2)}',
                isBold: true,
              ),
            ],
          );
        }),
      ],
    );
  }

  /// Build table cell
  pw.Widget _buildTableCell(String text, {bool isHeader = false, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: isHeader ? 10 : 9,
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  /// Build totals section
  pw.Widget _buildTotals(
    Map<String, dynamic> transaction,
    Map<String, dynamic>? bodySettings,
    String currencySymbol,
  ) {
    final subtotal = (transaction['subtotal'] as num).toDouble();
    final discount = (transaction['discount_amount'] as num).toDouble();
    final tax = (transaction['tax_amount'] as num).toDouble();
    final total = (transaction['total_amount'] as num).toDouble();

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 250,
          child: pw.Column(
            children: [
              if (bodySettings?['show_subtotal'] == 1)
                _buildTotalRow('Subtotal:', '$currencySymbol${subtotal.toStringAsFixed(2)}'),
              if (bodySettings?['show_total_discount'] == 1)
                _buildTotalRow('Discount:', '-$currencySymbol${discount.toStringAsFixed(2)}'),
              if (bodySettings?['show_total_tax'] == 1)
                _buildTotalRow('Tax:', '$currencySymbol${tax.toStringAsFixed(2)}'),
              pw.Divider(thickness: 2),
              _buildTotalRow(
                bodySettings?['grand_total_label'] as String? ?? 'Total:',
                '$currencySymbol${total.toStringAsFixed(2)}',
                isBold: true,
                fontSize: 14,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build total row
  pw.Widget _buildTotalRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 11,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: fontSize,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  /// Build footer
  pw.Widget _buildFooter(
    Map<String, dynamic>? footerSettings,
    Map<String, dynamic>? bodySettings,
    Map<String, dynamic> transaction,
  ) {
    final footerText = footerSettings?['footer_text'] as String? ??
                       'Thank you for your business!';
    final showTerms = footerSettings?['show_terms_and_conditions'] == 1;
    final terms = footerSettings?['terms_and_conditions'] as String?;

    // QR code settings are in body settings
    final showQR = bodySettings?['show_qr_code'] == 1;
    final qrContent = bodySettings?['qr_code_content'] as String? ?? '{invoice_number}';
    final qrSize = (bodySettings?['qr_code_size'] as int?) ?? 100;

    // Generate QR code if enabled
    pw.Widget? qrWidget;
    if (showQR) {
      try {
        // Replace placeholders in QR content
        String qrText = qrContent
            .replaceAll('{invoice_number}', transaction['invoice_number'] as String)
            .replaceAll('{total}', (transaction['total_amount'] as num).toStringAsFixed(2))
            .replaceAll('{date}', DateFormat('dd/MM/yyyy').format(DateTime.parse(transaction['transaction_date'] as String)));

        // Generate QR code using BarcodeWidget
        qrWidget = pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: qrText,
          width: qrSize.toDouble(),
          height: qrSize.toDouble(),
        );
      } catch (e) {
        // QR generation failed, continue without QR code
        print('Error generating QR code: $e');
      }
    }

    return pw.Column(
      children: [
        pw.Divider(),
        if (showTerms && terms != null && terms.isNotEmpty) ...[
          pw.Text(
            'Terms and Conditions',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.SizedBox(height: 5),
          pw.Text(terms, style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 10),
        ],
        // Footer text and QR code side by side
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    footerText,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Generated on ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
            if (qrWidget != null) ...[
              pw.SizedBox(width: 20),
              pw.Column(
                children: [
                  qrWidget,
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Scan QR Code',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Save PDF to file
  Future<File> _savePDFToFile(pw.Document pdf, String invoiceNumber) async {
    final fileName = '$invoiceNumber-${DateTime.now().millisecondsSinceEpoch}.pdf';
    final pdfBytes = await pdf.save();

    // Use FileSaveHelper for cross-platform saving
    final savedPath = await FileSaveHelper.savePdf(
      pdfBytes: pdfBytes,
      fileName: fileName,
    );

    if (savedPath == null) {
      // User cancelled or error occurred - save to temp directory as fallback
      final tempPath = await FileSaveHelper.getTempFilePath(fileName);
      final file = File(tempPath);
      await file.writeAsBytes(pdfBytes);
      return file;
    }

    return File(savedPath);
  }

  /// Print invoice (generates PDF for manual printing)
  Future<String> printInvoice(int transactionId) async {
    final pdfPath = await generateInvoicePDF(transactionId: transactionId, saveToFile: true);

    // Note: Actual printing functionality would require the 'printing' package
    // and platform-specific print dialog. For now, we just generate the PDF.
    // The user can open the PDF and print from their PDF viewer.

    return pdfPath;
  }
}
