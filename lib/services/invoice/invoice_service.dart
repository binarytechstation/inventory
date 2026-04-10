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

  /// Load Unicode-capable TTF fonts from Windows system fonts
  Future<({pw.ThemeData? theme, pw.Font? base})> _loadTheme() async {
    try {
      final regularFile = File('C:\\Windows\\Fonts\\arial.ttf');
      final boldFile    = File('C:\\Windows\\Fonts\\arialbd.ttf');
      final italicFile  = File('C:\\Windows\\Fonts\\ariali.ttf');
      final courierFile = File('C:\\Windows\\Fonts\\cour.ttf');

      if (!regularFile.existsSync() || !boldFile.existsSync()) {
        return (theme: null, base: null);
      }

      final regular = pw.Font.ttf((await regularFile.readAsBytes()).buffer.asByteData());
      final bold    = pw.Font.ttf((await boldFile.readAsBytes()).buffer.asByteData());
      final italic  = italicFile.existsSync()
          ? pw.Font.ttf((await italicFile.readAsBytes()).buffer.asByteData())
          : regular;

      // Load Courier New as font fallback to suppress "Courier has no Unicode support" warnings
      final List<pw.Font> fallback = [];
      if (courierFile.existsSync()) {
        fallback.add(pw.Font.ttf((await courierFile.readAsBytes()).buffer.asByteData()));
      }

      final theme = pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        italic: italic,
        boldItalic: bold,
        fontFallback: fallback,
      );
      return (theme: theme, base: regular);
    } catch (_) {
      return (theme: null, base: null);
    }
  }

  /// Build the PDF document
  Future<pw.Document> _buildInvoicePDF(
    Map<String, dynamic> transaction,
    Map<String, dynamic> settings,
  ) async {
    final pdf = pw.Document();
    final (:theme, base: _) = await _loadTheme();

    final headerSettings = settings['header'] as Map<String, dynamic>?;
    final footerSettings = settings['footer'] as Map<String, dynamic>?;
    final bodySettings = settings['body'] as Map<String, dynamic>?;
    final printSettings = settings['print'] as Map<String, dynamic>?;
    final profile = settings['profile'] as Map<String, dynamic>?;

    // Use 'Tk' for PDF compatibility instead of '৳' which has font rendering issues
    String currencySymbol = transaction['currency_symbol'] as String? ?? 'Tk';
    if (currencySymbol == '৳') currencySymbol = 'Tk';

    // Watermark settings
    final showWatermark = (printSettings?['show_watermark'] == 1 ||
                           printSettings?['show_watermark'] == true);
    final watermarkText = printSettings?['watermark_text'] as String? ?? 'DRAFT';
    final watermarkOpacity = (printSettings?['watermark_opacity'] as num?)?.toDouble() ?? 0.1;

    // Barcode settings
    final showBarcode = (printSettings?['show_barcode'] == 1 ||
                         printSettings?['show_barcode'] == true);
    final barcodeContent = printSettings?['barcode_content'] as String? ?? transaction['invoice_number'] as String;

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          buildBackground: showWatermark
              ? (pw.Context context) => pw.Center(
                    child: pw.Transform.rotate(
                      angle: -0.5,
                      child: pw.Opacity(
                        opacity: watermarkOpacity,
                        child: pw.Text(
                          watermarkText,
                          style: pw.TextStyle(
                            fontSize: 80,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey,
                          ),
                        ),
                      ),
                    ),
                  )
              : null,
        ),
        header: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(transaction, headerSettings, profile),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _buildInvoiceDetails(transaction, headerSettings)),
                if (showBarcode) ...[
                  pw.SizedBox(width: 20),
                  _buildBarcode(barcodeContent),
                ],
              ],
            ),
            pw.SizedBox(height: 10),
            if ((bodySettings?['show_party_name'] as int? ?? 1) == 1) ...[
              _buildPartyDetails(transaction, bodySettings),
              pw.SizedBox(height: 10),
            ],
          ],
        ),
        footer: (pw.Context context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ],
          ),
        ),
        build: (pw.Context context) => [
          // Items table
          _buildItemsTable(transaction, bodySettings, currencySymbol),
          pw.SizedBox(height: 15),
          // Totals
          _buildTotals(transaction, bodySettings, currencySymbol),
          pw.SizedBox(height: 20),
          // Footer content: terms, signature, QR, footer text
          _buildFooter(footerSettings, bodySettings, transaction),
        ],
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

    // Show flags for basic fields
    final showAddress = (headerSettings?['show_company_address'] == 1 ||
                         headerSettings?['show_company_address'] == true);
    final showPhone = (headerSettings?['show_company_phone'] == 1 ||
                       headerSettings?['show_company_phone'] == true);
    final showEmail = (headerSettings?['show_company_email'] == 1 ||
                       headerSettings?['show_company_email'] == true);

    // Additional header fields
    final companyTagline = headerSettings?['company_tagline'] as String? ?? '';
    final companyWebsite = headerSettings?['company_website'] as String? ?? '';
    final taxId = headerSettings?['tax_id'] as String? ?? '';
    final registrationNumber = headerSettings?['registration_number'] as String? ?? '';

    // Handle both int and bool for show flags
    final showTagline = (headerSettings?['show_company_tagline'] == 1 ||
                         headerSettings?['show_company_tagline'] == true);
    final showWebsite = (headerSettings?['show_company_website'] == 1 ||
                         headerSettings?['show_company_website'] == true);
    final showTaxId = (headerSettings?['show_tax_id'] == 1 ||
                       headerSettings?['show_tax_id'] == true);
    final showRegistrationNumber = (headerSettings?['show_registration_number'] == 1 ||
                                     headerSettings?['show_registration_number'] == true);

    final showInvoiceTitle = (headerSettings?['show_invoice_title'] == 1 ||
                              headerSettings?['show_invoice_title'] == true);
    final invoiceTitle = headerSettings?['invoice_title'] as String? ?? 'INVOICE';

    // Logo settings
    final showLogo = (headerSettings?['show_company_logo'] == 1 ||
                      headerSettings?['show_company_logo'] == true);
    final logoPath = headerSettings?['logo_path'] as String?;
    final logoWidth = (headerSettings?['logo_width'] as int?) ?? 150;
    final logoHeight = (headerSettings?['logo_height'] as int?) ?? 80;
    final logoPosition = (headerSettings?['logo_position'] as String? ?? 'LEFT').toUpperCase();

    // Load logo image if available
    pw.ImageProvider? logoImage;
    if (showLogo && logoPath != null && logoPath.isNotEmpty) {
      try {
        final logoFile = File(logoPath);
        if (logoFile.existsSync()) {
          final bytes = logoFile.readAsBytesSync();
          logoImage = pw.MemoryImage(bytes);
        }
      } catch (e) {
        // Logo loading failed, continue without logo
      }
    }

    // Company info column (shared for all logo positions)
    final companyInfoColumn = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          companyName,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        if (showTagline && companyTagline.isNotEmpty)
          pw.Text(
            companyTagline,
            style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
          ),
        if (showAddress && companyAddress.isNotEmpty)
          pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 10)),
        if (showPhone && companyPhone.isNotEmpty)
          pw.Text('Tel: $companyPhone', style: const pw.TextStyle(fontSize: 10)),
        if (showEmail && companyEmail.isNotEmpty)
          pw.Text('Email: $companyEmail', style: const pw.TextStyle(fontSize: 10)),
        if (showWebsite && companyWebsite.isNotEmpty)
          pw.Text('Website: $companyWebsite', style: const pw.TextStyle(fontSize: 10)),
        if (showTaxId && taxId.isNotEmpty)
          pw.Text('Tax ID: $taxId', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        if (showRegistrationNumber && registrationNumber.isNotEmpty)
          pw.Text('Reg. No: $registrationNumber', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ],
    );

    final logoWidget = logoImage != null
        ? pw.Container(
            width: logoWidth.toDouble(),
            height: logoHeight.toDouble(),
            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
          )
        : null;

    final invoiceTitleWidget = showInvoiceTitle
        ? pw.Text(
            invoiceTitle,
            style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue),
          )
        : null;

    pw.Widget headerRow;
    if (logoPosition == 'CENTER') {
      // Logo centered above, then company name left + invoice title right
      headerRow = pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logoWidget != null)
            pw.Center(child: logoWidget),
          if (logoWidget != null)
            pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 2, child: companyInfoColumn),
              if (invoiceTitleWidget != null) invoiceTitleWidget,
            ],
          ),
        ],
      );
    } else {
      // LEFT or RIGHT
      headerRow = pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left side: logo (if LEFT) + company info
          pw.Expanded(
            flex: 2,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoWidget != null && logoPosition == 'LEFT') ...[
                  logoWidget,
                  pw.SizedBox(width: 15),
                ],
                pw.Expanded(child: companyInfoColumn),
              ],
            ),
          ),
          // Right side: logo (if RIGHT) + invoice title
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (logoWidget != null && logoPosition == 'RIGHT') logoWidget,
              if (invoiceTitleWidget != null) invoiceTitleWidget,
            ],
          ),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        headerRow,
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 2),
      ],
    );
  }

  /// Build invoice details section
  pw.Widget _buildInvoiceDetails(
    Map<String, dynamic> transaction,
    Map<String, dynamic>? headerSettings,
  ) {
    final showInvoiceNumber = (headerSettings?['show_invoice_number'] == 1 || headerSettings?['show_invoice_number'] == true);
    final showInvoiceDate = (headerSettings?['show_invoice_date'] == 1 || headerSettings?['show_invoice_date'] == true);
    final invoiceNumber = transaction['invoice_number'] as String;
    final date = DateTime.parse(transaction['transaction_date'] as String);

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (showInvoiceNumber)
              pw.Text(
                'Invoice Number: $invoiceNumber',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            if (showInvoiceDate)
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

    final showCompany = (bodySettings?['show_party_company'] as int? ?? 1) == 1;
    final showAddress = (bodySettings?['show_party_address'] as int? ?? 1) == 1;
    final showPhone = (bodySettings?['show_party_phone'] as int? ?? 1) == 1;
    final showEmail = (bodySettings?['show_party_email'] as int? ?? 1) == 1;

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
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
          pw.SizedBox(height: 5),
          pw.Text(partyName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          if (partyDetails != null) ...[
            if (showCompany && partyDetails['company_name'] != null && (partyDetails['company_name'] as String).isNotEmpty)
              pw.Text(partyDetails['company_name'] as String),
            if (showAddress && partyDetails['address'] != null && (partyDetails['address'] as String).isNotEmpty)
              pw.Text(partyDetails['address'] as String),
            if (showPhone && partyDetails['phone'] != null && (partyDetails['phone'] as String).isNotEmpty)
              pw.Text('Phone: ${partyDetails['phone']}'),
            if (showEmail && partyDetails['email'] != null && (partyDetails['email'] as String).isNotEmpty)
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
    final paid = (transaction['paid_amount'] as num?)?.toDouble() ?? 0.0;
    final due = (transaction['credit_amount'] as num?)?.toDouble() ?? 0.0;

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
              if ((bodySettings?['show_grand_total'] as int? ?? 1) == 1)
                _buildTotalRow(
                  bodySettings?['grand_total_label'] as String? ?? 'Grand Total:',
                  '$currencySymbol${total.toStringAsFixed(2)}',
                  isBold: true,
                  fontSize: ((bodySettings?['grand_total_font_size'] as int?) ?? 14).toDouble(),
                ),
              if (paid > 0 || due > 0) ...[
                pw.SizedBox(height: 4),
                _buildTotalRow(
                  'Paid:',
                  '$currencySymbol${paid.toStringAsFixed(2)}',
                  color: PdfColors.green700,
                ),
                if (due > 0)
                  _buildTotalRow(
                    'Balance Due:',
                    '$currencySymbol${due.toStringAsFixed(2)}',
                    color: PdfColors.red700,
                    isBold: true,
                  ),
              ],
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
    PdfColor? color,
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
              color: color,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: fontSize,
              color: color,
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
    // Default booleans to ON (1) when settings row is missing
    bool flag(String key, {int defaultVal = 1}) =>
        (footerSettings?[key] as int? ?? defaultVal) == 1;

    final showFooterText = flag('show_footer_text');
    final footerText = footerSettings?['footer_text'] as String? ?? 'Thank you for your business!';
    final showTerms = flag('show_terms_and_conditions');
    final terms = footerSettings?['terms_and_conditions'] as String?;
    final showPaymentInstructions = flag('show_payment_instructions', defaultVal: 0);
    final paymentInstructions = footerSettings?['payment_instructions'] as String?;
    final showBankDetails = flag('show_bank_details', defaultVal: 0);
    final bankName = footerSettings?['bank_name'] as String?;
    final accountHolder = footerSettings?['account_holder_name'] as String?;
    final accountNumber = footerSettings?['account_number'] as String?;
    final swiftCode = footerSettings?['swift_code'] as String?;
    final iban = footerSettings?['iban'] as String?;

    // Signature and stamp settings
    final showSignature = flag('show_signature');
    final signaturePath = footerSettings?['signature_image_path'] as String?;
    final signatureLabel = footerSettings?['signature_label'] as String? ?? 'Authorized Signature';
    final signaturePositionRaw = (footerSettings?['signature_position'] as String? ?? 'RIGHT').toUpperCase();
    final pw.MainAxisAlignment signatureAlignment;
    switch (signaturePositionRaw) {
      case 'RIGHT':
        signatureAlignment = pw.MainAxisAlignment.end;
        break;
      case 'CENTER':
        signatureAlignment = pw.MainAxisAlignment.center;
        break;
      default:
        signatureAlignment = pw.MainAxisAlignment.start;
    }

    final showStamp = flag('show_stamp', defaultVal: 0);
    final stampPath = footerSettings?['stamp_image_path'] as String?;

    // Load signature image if available
    pw.ImageProvider? signatureImage;
    if (showSignature && signaturePath != null && signaturePath.isNotEmpty) {
      try {
        final signatureFile = File(signaturePath);
        if (signatureFile.existsSync()) {
          signatureImage = pw.MemoryImage(signatureFile.readAsBytesSync());
        }
      } catch (_) {}
    }

    // Load stamp image if available
    pw.ImageProvider? stampImage;
    if (showStamp && stampPath != null && stampPath.isNotEmpty) {
      try {
        final stampFile = File(stampPath);
        if (stampFile.existsSync()) {
          stampImage = pw.MemoryImage(stampFile.readAsBytesSync());
        }
      } catch (_) {}
    }

    // QR code settings are in body settings
    final showQR = (bodySettings?['show_qr_code'] == 1 || bodySettings?['show_qr_code'] == true);
    final qrContent = bodySettings?['qr_code_content'] as String? ?? '{invoice_number}';
    final qrSize = (bodySettings?['qr_code_size'] as int?) ?? 100;

    // Generate QR code if enabled
    pw.Widget? qrWidget;
    if (showQR) {
      try {
        // Replace placeholders in QR content
        final totalStr = (transaction['total_amount'] as num).toStringAsFixed(2);
        String qrText = qrContent
            .replaceAll('{invoice_number}', transaction['invoice_number'] as String)
            .replaceAll('{total_amount}', totalStr)
            .replaceAll('{total}', totalStr)
            .replaceAll('{date}', DateFormat('dd/MM/yyyy').format(DateTime.parse(transaction['transaction_date'] as String)));

        // Generate QR code using BarcodeWidget
        qrWidget = pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: qrText,
          width: qrSize.toDouble(),
          height: qrSize.toDouble(),
          drawText: false,
        );
      } catch (e) {
        // QR generation failed, continue without QR code
        print('Error generating QR code: $e');
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(),
        // Terms and conditions
        if (showTerms && terms != null && terms.isNotEmpty) ...[
          pw.Text(
            'Terms and Conditions',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            terms,
            style: const pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.left,
          ),
          pw.SizedBox(height: 10),
        ],
        // Payment instructions
        if (showPaymentInstructions && paymentInstructions != null && paymentInstructions.isNotEmpty) ...[
          pw.Text(
            'Payment Instructions',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            paymentInstructions,
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 10),
        ],
        // Bank details
        if (showBankDetails && bankName != null && bankName.isNotEmpty) ...[
          pw.Text(
            'Bank Details',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.SizedBox(height: 4),
          if (bankName.isNotEmpty) pw.Text('Bank: $bankName', style: const pw.TextStyle(fontSize: 8)),
          if (accountHolder != null && accountHolder.isNotEmpty)
            pw.Text('Account Holder: $accountHolder', style: const pw.TextStyle(fontSize: 8)),
          if (accountNumber != null && accountNumber.isNotEmpty)
            pw.Text('Account No: $accountNumber', style: const pw.TextStyle(fontSize: 8)),
          if (swiftCode != null && swiftCode.isNotEmpty)
            pw.Text('SWIFT: $swiftCode', style: const pw.TextStyle(fontSize: 8)),
          if (iban != null && iban.isNotEmpty)
            pw.Text('IBAN: $iban', style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 10),
        ],
        // Signature and stamp row
        if (showSignature || stampImage != null) ...[
          pw.Row(
            mainAxisAlignment: stampImage != null ? pw.MainAxisAlignment.spaceEvenly : signatureAlignment,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              // Signature section — shown even without image (empty line for manual signing)
              if (showSignature)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (signatureImage != null) ...[
                      pw.Container(
                        width: 150,
                        height: 70,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                        ),
                        child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                      ),
                    ] else
                      pw.SizedBox(height: 50), // blank space for manual signature
                    pw.SizedBox(height: 5),
                    pw.Container(
                      width: 150,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey700)),
                      ),
                      padding: const pw.EdgeInsets.only(top: 5),
                      child: pw.Text(
                        signatureLabel,
                        style: const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
              // Stamp section
              if (stampImage != null)
                pw.Column(
                  children: [
                    pw.Container(
                      width: 100,
                      height: 80,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Image(stampImage, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Company Stamp',
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 15),
        ],
        // Footer text and QR code side by side
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            if (showFooterText)
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
              if (showFooterText) pw.SizedBox(width: 20),
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

  /// Build barcode widget
  pw.Widget _buildBarcode(String content) {
    return pw.Column(
      children: [
        pw.Container(
          width: 120,
          height: 50,
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.code128(),
            data: content,
            drawText: false,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          content,
          style: const pw.TextStyle(fontSize: 8),
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
