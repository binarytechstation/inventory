import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../../../../services/invoice/invoice_settings_service.dart';
import '../../../../services/invoice/invoice_service.dart';
import '../../../../services/transaction/transaction_service.dart';

class PrintSettingsTab extends StatefulWidget {
  final String invoiceType;

  const PrintSettingsTab({super.key, required this.invoiceType});

  @override
  State<PrintSettingsTab> createState() => _PrintSettingsTabState();
}

class _PrintSettingsTabState extends State<PrintSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  final InvoiceSettingsService _service = InvoiceSettingsService();

  // Basic Settings Controllers
  late TextEditingController _copiesController;

  // Margins Controllers
  late TextEditingController _marginTopController;
  late TextEditingController _marginBottomController;
  late TextEditingController _marginLeftController;
  late TextEditingController _marginRightController;

  // Watermark Controllers
  late TextEditingController _watermarkTextController;
  late TextEditingController _watermarkOpacityController;
  late TextEditingController _watermarkRotationController;

  // PDF Controllers
  late TextEditingController _pdfQualityController;

  // Thermal Printer Controllers
  late TextEditingController _thermalWidthController;
  late TextEditingController _thermalFontSizeController;
  late TextEditingController _thermalLineSpacingController;

  // Settings Values
  String _paperSize = 'A4';
  String _paperOrientation = 'PORTRAIT';
  String _layoutType = 'STANDARD';
  String _printFormat = 'PDF';

  // Watermark Settings
  bool _enableWatermark = false;
  String? _watermarkImagePath;
  String _watermarkPosition = 'CENTER';

  // PDF Settings
  bool _compressPdf = true;

  // Thermal Settings
  bool _enableThermalPrint = false;

  // QR/Barcode Settings
  bool _enableQrCode = false;
  bool _enableBarcode = false;
  String _barcodeType = 'CODE128';

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _copiesController = TextEditingController(text: '1');
    _marginTopController = TextEditingController(text: '20');
    _marginBottomController = TextEditingController(text: '20');
    _marginLeftController = TextEditingController(text: '20');
    _marginRightController = TextEditingController(text: '20');
    _watermarkTextController = TextEditingController(text: 'DRAFT');
    _watermarkOpacityController = TextEditingController(text: '30');
    _watermarkRotationController = TextEditingController(text: '45');
    _pdfQualityController = TextEditingController(text: '85');
    _thermalWidthController = TextEditingController(text: '80');
    _thermalFontSizeController = TextEditingController(text: '12');
    _thermalLineSpacingController = TextEditingController(text: '1.5');
    _loadSettings();
  }

  @override
  void didUpdateWidget(PrintSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.invoiceType != widget.invoiceType) {
      _loadSettings();
    }
  }

  @override
  void dispose() {
    _copiesController.dispose();
    _marginTopController.dispose();
    _marginBottomController.dispose();
    _marginLeftController.dispose();
    _marginRightController.dispose();
    _watermarkTextController.dispose();
    _watermarkOpacityController.dispose();
    _watermarkRotationController.dispose();
    _pdfQualityController.dispose();
    _thermalWidthController.dispose();
    _thermalFontSizeController.dispose();
    _thermalLineSpacingController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      var settings = await _service.getPrintSettings(widget.invoiceType);

      if (settings == null) {
        await _service.initializeDefaultSettings(widget.invoiceType);
        settings = await _service.getPrintSettings(widget.invoiceType);
      }

      if (settings != null && mounted) {
        setState(() {
          // Basic Settings - Validate dropdown values
          final paperSizeValue = settings!['paper_size'] as String? ?? 'A4';
          _paperSize = ['A4', 'LETTER', 'LEGAL', 'THERMAL_80MM', 'THERMAL_58MM'].contains(paperSizeValue) ? paperSizeValue : 'A4';

          final orientationValue = settings['paper_orientation'] as String? ?? 'PORTRAIT';
          _paperOrientation = ['PORTRAIT', 'LANDSCAPE'].contains(orientationValue) ? orientationValue : 'PORTRAIT';

          final layoutValue = settings['layout_type'] as String? ?? 'STANDARD';
          _layoutType = ['STANDARD', 'COMPACT', 'DETAILED'].contains(layoutValue) ? layoutValue : 'STANDARD';

          final formatValue = settings['print_format'] as String? ?? 'PDF';
          _printFormat = ['PDF', 'HTML', 'TEXT'].contains(formatValue) ? formatValue : 'PDF';

          // Handle numeric values flexibly (int or double)
          final copies = settings['copies'];
          _copiesController.text = (copies is int ? copies : (copies as num?)?.toInt() ?? 1).toString();

          // Margins - Handle both int and double
          final marginTop = settings['margin_top'];
          _marginTopController.text = (marginTop is num ? marginTop.toDouble() : 20.0).toString();

          final marginBottom = settings['margin_bottom'];
          _marginBottomController.text = (marginBottom is num ? marginBottom.toDouble() : 20.0).toString();

          final marginLeft = settings['margin_left'];
          _marginLeftController.text = (marginLeft is num ? marginLeft.toDouble() : 20.0).toString();

          final marginRight = settings['margin_right'];
          _marginRightController.text = (marginRight is num ? marginRight.toDouble() : 20.0).toString();

          // Watermark
          _enableWatermark = (settings['show_watermark'] as int? ?? 0) == 1;

          _watermarkTextController.text = settings['watermark_text'] as String? ?? 'DRAFT';
          _watermarkImagePath = settings['watermark_image_path'] as String?;

          final opacity = settings['watermark_opacity'];
          _watermarkOpacityController.text = (opacity is int ? opacity : (opacity as num?)?.toInt() ?? 30).toString();

          final rotation = settings['watermark_rotation'];
          _watermarkRotationController.text = (rotation is int ? rotation : (rotation as num?)?.toInt() ?? 45).toString();

          final watermarkPosValue = settings['watermark_position'] as String? ?? 'CENTER';
          _watermarkPosition = ['CENTER', 'TOP_LEFT', 'TOP_RIGHT', 'BOTTOM_LEFT', 'BOTTOM_RIGHT'].contains(watermarkPosValue) ? watermarkPosValue : 'CENTER';

          // PDF Settings
          _compressPdf = (settings['compress_pdf'] as int? ?? 1) == 1;

          final quality = settings['pdf_quality'];
          _pdfQualityController.text = (quality is int ? quality : (quality as num?)?.toInt() ?? 85).toString();

          // Thermal Settings
          _enableThermalPrint = (settings['enable_thermal_print'] as int? ?? 0) == 1;

          final thermalWidth = settings['thermal_width'];
          _thermalWidthController.text = (thermalWidth is int ? thermalWidth : (thermalWidth as num?)?.toInt() ?? 80).toString();

          final thermalFontSize = settings['thermal_font_size'];
          _thermalFontSizeController.text = (thermalFontSize is int ? thermalFontSize : (thermalFontSize as num?)?.toInt() ?? 12).toString();

          final thermalLineSpacing = settings['thermal_line_spacing'];
          _thermalLineSpacingController.text = (thermalLineSpacing is num ? thermalLineSpacing.toDouble() : 1.5).toString();

          // QR/Barcode
          _enableQrCode = (settings['enable_qr_code'] as int? ?? 0) == 1;
          _enableBarcode = (settings['enable_barcode'] as int? ?? 0) == 1;

          final barcodeTypeValue = settings['barcode_type'] as String? ?? 'CODE128';
          _barcodeType = ['CODE128', 'EAN13', 'QR'].contains(barcodeTypeValue) ? barcodeTypeValue : 'CODE128';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      // Helper function to safely parse integers
      int safeParseInt(String text, int defaultValue) {
        try {
          return text.isEmpty ? defaultValue : int.parse(text);
        } catch (e) {
          return defaultValue;
        }
      }

      // Helper function to safely parse doubles
      double safeParseDouble(String text, double defaultValue) {
        try {
          return text.isEmpty ? defaultValue : double.parse(text);
        } catch (e) {
          return defaultValue;
        }
      }

      await _service.savePrintSettings({
        'invoice_type': widget.invoiceType,
        // Basic Settings
        'paper_size': _paperSize,
        'paper_orientation': _paperOrientation,
        'layout_type': _layoutType,
        'print_format': _printFormat,
        'copies': safeParseInt(_copiesController.text, 1),
        // Margins
        'margin_top': safeParseDouble(_marginTopController.text, 20.0),
        'margin_bottom': safeParseDouble(_marginBottomController.text, 20.0),
        'margin_left': safeParseDouble(_marginLeftController.text, 20.0),
        'margin_right': safeParseDouble(_marginRightController.text, 20.0),
        // Watermark
        'show_watermark': _enableWatermark ? 1 : 0,
        'watermark_text': _watermarkTextController.text.trim(),
        'watermark_image_path': _watermarkImagePath,
        'watermark_opacity': safeParseDouble(_watermarkOpacityController.text, 30.0) / 100.0,
        'watermark_rotation': safeParseInt(_watermarkRotationController.text, 45),
        'watermark_position': _watermarkPosition,
        // PDF Settings
        'compress_pdf': _compressPdf ? 1 : 0,
        'pdf_quality': safeParseInt(_pdfQualityController.text, 85),
        // Thermal Settings
        'enable_thermal_print': _enableThermalPrint ? 1 : 0,
        'thermal_width': safeParseInt(_thermalWidthController.text, 80),
        'thermal_font_size': safeParseInt(_thermalFontSizeController.text, 12),
        'thermal_line_spacing': safeParseDouble(_thermalLineSpacingController.text, 1.5),
        // QR/Barcode
        'enable_qr_code': _enableQrCode ? 1 : 0,
        'enable_barcode': _enableBarcode ? 1 : 0,
        'barcode_type': _barcodeType,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Print settings saved successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showTestPrintDialog() async {
    final transactionService = TransactionService();
    final invoiceService = InvoiceService();

    // Get recent transactions
    final allTransactions = await transactionService.getTransactions(sortBy: 'transaction_date', sortOrder: 'DESC');
    final transactions = allTransactions.take(10).toList();

    if (!mounted) return;

    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transactions available. Create a sale or purchase first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int? selectedTransactionId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Test Print - Select Transaction'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select a transaction to generate a test invoice:'),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final txn = transactions[index];
                      final isSelected = selectedTransactionId == txn['id'];
                      return ListTile(
                        selected: isSelected,
                        leading: CircleAvatar(
                          backgroundColor: txn['transaction_type'] == 'BUY' ? Colors.blue : Colors.green,
                          child: Icon(
                            txn['transaction_type'] == 'BUY' ? Icons.shopping_cart : Icons.point_of_sale,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          txn['invoice_number'] as String,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${txn['party_name'] ?? 'N/A'} - \$${(txn['total_amount'] as num).toStringAsFixed(2)}',
                        ),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                        onTap: () {
                          setDialogState(() {
                            selectedTransactionId = txn['id'] as int;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: selectedTransactionId == null
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _generateTestInvoice(invoiceService, selectedTransactionId!);
                    },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Generate PDF'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateTestInvoice(InvoiceService invoiceService, int transactionId) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating test invoice...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Generate PDF
      final pdfPath = await invoiceService.generateInvoicePDF(
        transactionId: transactionId,
        saveToFile: true,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show success dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Success'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Test invoice generated successfully!'),
              const SizedBox(height: 16),
              const Text('Saved to:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                pdfPath,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _openPDF(pdfPath);
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open PDF'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _openPDF(String pdfPath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', pdfPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [pdfPath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [pdfPath]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open PDF: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Basic Print Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Basic Print Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _paperSize,
                          decoration: const InputDecoration(
                            labelText: 'Paper Size',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'A4', child: Text('A4 (210 x 297 mm)')),
                            DropdownMenuItem(value: 'LETTER', child: Text('Letter (8.5 x 11 in)')),
                            DropdownMenuItem(value: 'LEGAL', child: Text('Legal (8.5 x 14 in)')),
                            DropdownMenuItem(value: 'THERMAL_80MM', child: Text('Thermal 80mm')),
                            DropdownMenuItem(value: 'THERMAL_58MM', child: Text('Thermal 58mm')),
                          ],
                          onChanged: (v) => setState(() => _paperSize = v!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _paperOrientation,
                          decoration: const InputDecoration(
                            labelText: 'Orientation',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'PORTRAIT', child: Text('Portrait')),
                            DropdownMenuItem(value: 'LANDSCAPE', child: Text('Landscape')),
                          ],
                          onChanged: (v) => setState(() => _paperOrientation = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _layoutType,
                          decoration: const InputDecoration(
                            labelText: 'Layout Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'STANDARD', child: Text('Standard')),
                            DropdownMenuItem(value: 'COMPACT', child: Text('Compact')),
                            DropdownMenuItem(value: 'DETAILED', child: Text('Detailed')),
                          ],
                          onChanged: (v) => setState(() => _layoutType = v!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _printFormat,
                          decoration: const InputDecoration(
                            labelText: 'Print Format',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'PDF', child: Text('PDF')),
                            DropdownMenuItem(value: 'DIRECT_PRINT', child: Text('Direct Print')),
                          ],
                          onChanged: (v) => setState(() => _printFormat = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 150,
                    child: TextFormField(
                      controller: _copiesController,
                      decoration: const InputDecoration(
                        labelText: 'Number of Copies',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Margins Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Margins Configuration (in mm)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _marginTopController,
                          decoration: const InputDecoration(
                            labelText: 'Top',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _marginBottomController,
                          decoration: const InputDecoration(
                            labelText: 'Bottom',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _marginLeftController,
                          decoration: const InputDecoration(
                            labelText: 'Left',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _marginRightController,
                          decoration: const InputDecoration(
                            labelText: 'Right',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Watermark Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Watermark Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Enable Watermark'),
                    value: _enableWatermark,
                    onChanged: (v) => setState(() => _enableWatermark = v),
                  ),
                  if (_enableWatermark) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _watermarkTextController,
                      decoration: const InputDecoration(
                        labelText: 'Watermark Text',
                        hintText: 'DRAFT / COPY / CONFIDENTIAL',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _watermarkOpacityController,
                            decoration: const InputDecoration(
                              labelText: 'Opacity (%)',
                              hintText: '0-100',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _watermarkRotationController,
                            decoration: const InputDecoration(
                              labelText: 'Rotation (degrees)',
                              hintText: '0-360',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _watermarkPosition,
                      decoration: const InputDecoration(
                        labelText: 'Position',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'CENTER', child: Text('Center')),
                        DropdownMenuItem(value: 'TOP_LEFT', child: Text('Top Left')),
                        DropdownMenuItem(value: 'TOP_RIGHT', child: Text('Top Right')),
                        DropdownMenuItem(value: 'BOTTOM_LEFT', child: Text('Bottom Left')),
                        DropdownMenuItem(value: 'BOTTOM_RIGHT', child: Text('Bottom Right')),
                      ],
                      onChanged: (v) => setState(() => _watermarkPosition = v!),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // PDF Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PDF Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Compress PDF'),
                    subtitle: const Text('Reduce file size by compressing PDF'),
                    value: _compressPdf,
                    onChanged: (v) => setState(() => _compressPdf = v),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pdfQualityController,
                    decoration: const InputDecoration(
                      labelText: 'PDF Quality',
                      hintText: '1-100 (higher is better)',
                      border: OutlineInputBorder(),
                      helperText: 'Recommended: 85',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final val = int.tryParse(v);
                      if (val == null || val < 1 || val > 100) return 'Must be 1-100';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Thermal Printer Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thermal Printer Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Enable Thermal Print'),
                    subtitle: const Text('Optimize for thermal receipt printers'),
                    value: _enableThermalPrint,
                    onChanged: (v) => setState(() => _enableThermalPrint = v),
                  ),
                  if (_enableThermalPrint) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: int.parse(_thermalWidthController.text),
                            decoration: const InputDecoration(
                              labelText: 'Thermal Width (mm)',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 58, child: Text('58mm')),
                              DropdownMenuItem(value: 80, child: Text('80mm')),
                            ],
                            onChanged: (v) => setState(() => _thermalWidthController.text = v.toString()),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _thermalFontSizeController,
                            decoration: const InputDecoration(
                              labelText: 'Font Size',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _thermalLineSpacingController,
                      decoration: const InputDecoration(
                        labelText: 'Line Spacing',
                        hintText: '1.0 - 2.0',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // QR Code & Barcode Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('QR Code & Barcode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Enable QR Code'),
                    subtitle: const Text('Display QR code on invoice'),
                    value: _enableQrCode,
                    onChanged: (v) => setState(() => _enableQrCode = v),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Enable Barcode'),
                    subtitle: const Text('Display barcode on invoice'),
                    value: _enableBarcode,
                    onChanged: (v) => setState(() => _enableBarcode = v),
                  ),
                  if (_enableBarcode) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _barcodeType,
                      decoration: const InputDecoration(
                        labelText: 'Barcode Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'CODE128', child: Text('CODE 128')),
                        DropdownMenuItem(value: 'EAN13', child: Text('EAN-13')),
                        DropdownMenuItem(value: 'QR', child: Text('QR Code')),
                      ],
                      onChanged: (v) => setState(() => _barcodeType = v!),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Padding(padding: EdgeInsets.all(16), child: Text('Save Settings')),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _showTestPrintDialog,
                icon: const Icon(Icons.print),
                label: const Padding(padding: EdgeInsets.all(16), child: Text('Test Print')),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
