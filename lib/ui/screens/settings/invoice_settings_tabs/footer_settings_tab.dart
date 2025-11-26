import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../../services/invoice/invoice_settings_service.dart';

class FooterSettingsTab extends StatefulWidget {
  final String invoiceType;

  const FooterSettingsTab({super.key, required this.invoiceType});

  @override
  State<FooterSettingsTab> createState() => _FooterSettingsTabState();
}

class _FooterSettingsTabState extends State<FooterSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  final InvoiceSettingsService _service = InvoiceSettingsService();

  late TextEditingController _footerTextController;
  late TextEditingController _footerFontSizeController;
  late TextEditingController _termsController;
  late TextEditingController _paymentInstructionsController;
  late TextEditingController _bankNameController;
  late TextEditingController _accountHolderController;
  late TextEditingController _accountNumberController;
  late TextEditingController _swiftCodeController;
  late TextEditingController _ibanController;
  late TextEditingController _signatureLabelController;
  late TextEditingController _pageNumberFormatController;
  late TextEditingController _generatedInfoTextController;

  bool _showFooterText = true;
  String _footerAlignment = 'CENTER';
  bool _showTermsAndConditions = true;
  bool _showPaymentInstructions = true;
  bool _showBankDetails = false;
  bool _showSignature = true;
  String? _signatureImagePath;
  String _signaturePosition = 'RIGHT';
  bool _showStamp = false;
  String? _stampImagePath;
  String _stampPosition = 'LEFT';
  bool _showPageNumbers = true;
  bool _showGeneratedInfo = true;
  String _footerTextColor = '#666666';

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _footerTextController = TextEditingController(text: 'Thank you for your business!');
    _footerFontSizeController = TextEditingController(text: '10');
    _termsController = TextEditingController();
    _paymentInstructionsController = TextEditingController();
    _bankNameController = TextEditingController();
    _accountHolderController = TextEditingController();
    _accountNumberController = TextEditingController();
    _swiftCodeController = TextEditingController();
    _ibanController = TextEditingController();
    _signatureLabelController = TextEditingController(text: 'Authorized Signature');
    _pageNumberFormatController = TextEditingController(text: 'Page {current} of {total}');
    _generatedInfoTextController = TextEditingController(text: 'Generated on {date} at {time}');
    _loadSettings();
  }

  @override
  void didUpdateWidget(FooterSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.invoiceType != widget.invoiceType) {
      _loadSettings();
    }
  }

  @override
  void dispose() {
    _footerTextController.dispose();
    _footerFontSizeController.dispose();
    _termsController.dispose();
    _paymentInstructionsController.dispose();
    _bankNameController.dispose();
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    _swiftCodeController.dispose();
    _ibanController.dispose();
    _signatureLabelController.dispose();
    _pageNumberFormatController.dispose();
    _generatedInfoTextController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      var settings = await _service.getFooterSettings(widget.invoiceType);
      if (settings == null) {
        await _service.initializeDefaultSettings(widget.invoiceType);
        settings = await _service.getFooterSettings(widget.invoiceType);
      }

      if (settings != null && mounted) {
        setState(() {
          _showFooterText = (settings!['show_footer_text'] as int? ?? 1) == 1;
          _footerTextController.text = settings['footer_text'] as String? ?? 'Thank you for your business!';
          // Handle both int and double from database
          final fontSize = settings['footer_font_size'];
          _footerFontSizeController.text = (fontSize is int ? fontSize : (fontSize as num?)?.toInt() ?? 10).toString();
          final footerAlignValue = settings['footer_alignment'] as String? ?? 'CENTER';
          _footerAlignment = ['LEFT', 'CENTER', 'RIGHT'].contains(footerAlignValue) ? footerAlignValue : 'CENTER';
          _showTermsAndConditions = (settings['show_terms_and_conditions'] as int? ?? 1) == 1;
          _termsController.text = settings['terms_and_conditions'] as String? ?? '';
          _showPaymentInstructions = (settings['show_payment_instructions'] as int? ?? 1) == 1;
          _paymentInstructionsController.text = settings['payment_instructions'] as String? ?? '';
          _showBankDetails = (settings['show_bank_details'] as int? ?? 0) == 1;
          _bankNameController.text = settings['bank_name'] as String? ?? '';
          _accountHolderController.text = settings['account_holder_name'] as String? ?? '';
          _accountNumberController.text = settings['account_number'] as String? ?? '';
          _swiftCodeController.text = settings['swift_code'] as String? ?? '';
          _ibanController.text = settings['iban'] as String? ?? '';
          _showSignature = (settings['show_signature'] as int? ?? 1) == 1;
          _signatureLabelController.text = settings['signature_label'] as String? ?? 'Authorized Signature';
          _signatureImagePath = settings['signature_image_path'] as String?;
          final sigPosValue = settings['signature_position'] as String? ?? 'RIGHT';
          _signaturePosition = ['LEFT', 'RIGHT'].contains(sigPosValue) ? sigPosValue : 'RIGHT';
          _showStamp = (settings['show_stamp'] as int? ?? 0) == 1;
          _stampImagePath = settings['stamp_image_path'] as String?;
          final stampPosValue = settings['stamp_position'] as String? ?? 'LEFT';
          _stampPosition = ['LEFT', 'RIGHT'].contains(stampPosValue) ? stampPosValue : 'LEFT';
          _showPageNumbers = (settings['show_page_numbers'] as int? ?? 1) == 1;
          _pageNumberFormatController.text = settings['page_number_format'] as String? ?? 'Page {current} of {total}';
          _showGeneratedInfo = (settings['show_generated_info'] as int? ?? 1) == 1;
          _generatedInfoTextController.text = settings['generated_info_text'] as String? ?? 'Generated on {date} at {time}';
          _footerTextColor = settings['footer_text_color'] as String? ?? '#666666';
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

  Future<void> _pickSignature() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        dialogTitle: 'Select Signature Image',
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      if (pickedFile.path == null) {
        throw Exception('Invalid file path');
      }

      // Copy signature to Application Support directory for sandbox compatibility
      final appDataDir = await getApplicationSupportDirectory();
      final signaturesDir = Directory(path.join(appDataDir.path, 'InventoryManagementSystem', 'signatures'));

      // Create directory if it doesn't exist
      if (!await signaturesDir.exists()) {
        await signaturesDir.create(recursive: true);
      }

      // Create unique filename based on invoice type
      final extension = path.extension(pickedFile.path!);
      final fileName = 'signature_${widget.invoiceType.toLowerCase()}$extension';
      final destinationPath = path.join(signaturesDir.path, fileName);

      // Copy file to app data directory
      final sourceFile = File(pickedFile.path!);
      await sourceFile.copy(destinationPath);

      setState(() {
        _signatureImagePath = destinationPath;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signature selected. Click "Save Settings" to apply.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting signature: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickStamp() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        dialogTitle: 'Select Stamp Image',
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      if (pickedFile.path == null) {
        throw Exception('Invalid file path');
      }

      // Copy stamp to Application Support directory for sandbox compatibility
      final appDataDir = await getApplicationSupportDirectory();
      final stampsDir = Directory(path.join(appDataDir.path, 'InventoryManagementSystem', 'stamps'));

      // Create directory if it doesn't exist
      if (!await stampsDir.exists()) {
        await stampsDir.create(recursive: true);
      }

      // Create unique filename based on invoice type
      final extension = path.extension(pickedFile.path!);
      final fileName = 'stamp_${widget.invoiceType.toLowerCase()}$extension';
      final destinationPath = path.join(stampsDir.path, fileName);

      // Copy file to app data directory
      final sourceFile = File(pickedFile.path!);
      await sourceFile.copy(destinationPath);

      setState(() {
        _stampImagePath = destinationPath;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stamp selected. Click "Save Settings" to apply.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting stamp: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await _service.saveFooterSettings({
        'invoice_type': widget.invoiceType,
        'show_footer_text': _showFooterText ? 1 : 0,
        'footer_text': _footerTextController.text.trim(),
        'footer_font_size': int.parse(_footerFontSizeController.text),
        'footer_alignment': _footerAlignment,
        'show_terms_and_conditions': _showTermsAndConditions ? 1 : 0,
        'terms_and_conditions': _termsController.text.trim(),
        'show_payment_instructions': _showPaymentInstructions ? 1 : 0,
        'payment_instructions': _paymentInstructionsController.text.trim(),
        'show_bank_details': _showBankDetails ? 1 : 0,
        'bank_name': _bankNameController.text.trim(),
        'account_holder_name': _accountHolderController.text.trim(),
        'account_number': _accountNumberController.text.trim(),
        'swift_code': _swiftCodeController.text.trim(),
        'iban': _ibanController.text.trim(),
        'show_signature': _showSignature ? 1 : 0,
        'signature_label': _signatureLabelController.text.trim(),
        'signature_image_path': _signatureImagePath,
        'signature_position': _signaturePosition,
        'show_stamp': _showStamp ? 1 : 0,
        'stamp_image_path': _stampImagePath,
        'stamp_position': _stampPosition,
        'show_page_numbers': _showPageNumbers ? 1 : 0,
        'page_number_format': _pageNumberFormatController.text.trim(),
        'show_generated_info': _showGeneratedInfo ? 1 : 0,
        'generated_info_text': _generatedInfoTextController.text.trim(),
        'footer_text_color': _footerTextColor,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Footer settings saved successfully'), backgroundColor: Colors.green),
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
          // Footer Text
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Footer Text', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Footer Text'),
                    value: _showFooterText,
                    onChanged: (v) => setState(() => _showFooterText = v),
                  ),
                  if (_showFooterText) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _footerTextController,
                      decoration: const InputDecoration(
                        labelText: 'Footer Text',
                        hintText: 'Thank you for your business!',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _footerFontSizeController,
                            decoration: const InputDecoration(
                              labelText: 'Font Size',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _footerAlignment,
                            decoration: const InputDecoration(
                              labelText: 'Alignment',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'LEFT', child: Text('Left')),
                              DropdownMenuItem(value: 'CENTER', child: Text('Center')),
                              DropdownMenuItem(value: 'RIGHT', child: Text('Right')),
                            ],
                            onChanged: (v) => setState(() => _footerAlignment = v!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Terms & Conditions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Terms & Conditions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Terms & Conditions'),
                    value: _showTermsAndConditions,
                    onChanged: (v) => setState(() => _showTermsAndConditions = v),
                  ),
                  if (_showTermsAndConditions) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _termsController,
                      decoration: const InputDecoration(
                        labelText: 'Terms & Conditions',
                        hintText: 'Enter terms and conditions...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Payment Instructions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Instructions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Payment Instructions'),
                    value: _showPaymentInstructions,
                    onChanged: (v) => setState(() => _showPaymentInstructions = v),
                  ),
                  if (_showPaymentInstructions) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _paymentInstructionsController,
                      decoration: const InputDecoration(
                        labelText: 'Payment Instructions',
                        hintText: 'Payment is due within 30 days...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Bank Details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bank Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Bank Details'),
                    value: _showBankDetails,
                    onChanged: (v) => setState(() => _showBankDetails = v),
                  ),
                  if (_showBankDetails) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bankNameController,
                      decoration: const InputDecoration(
                        labelText: 'Bank Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _accountHolderController,
                      decoration: const InputDecoration(
                        labelText: 'Account Holder Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _accountNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Account Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _swiftCodeController,
                            decoration: const InputDecoration(
                              labelText: 'SWIFT Code',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _ibanController,
                            decoration: const InputDecoration(
                              labelText: 'IBAN',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Signature & Stamp
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Signature & Stamp', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Signature'),
                    value: _showSignature,
                    onChanged: (v) => setState(() => _showSignature = v),
                  ),
                  if (_showSignature) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _signatureLabelController,
                      decoration: const InputDecoration(
                        labelText: 'Signature Label',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_signatureImagePath != null && File(_signatureImagePath!).existsSync()) ...[
                      Center(
                        child: Image.file(
                          File(_signatureImagePath!),
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    ElevatedButton.icon(
                      onPressed: _pickSignature,
                      icon: const Icon(Icons.upload_file),
                      label: Text(_signatureImagePath == null ? 'Upload Signature' : 'Change Signature'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _signaturePosition,
                      decoration: const InputDecoration(
                        labelText: 'Signature Position',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'LEFT', child: Text('Left')),
                        DropdownMenuItem(value: 'RIGHT', child: Text('Right')),
                      ],
                      onChanged: (v) => setState(() => _signaturePosition = v!),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Stamp'),
                    value: _showStamp,
                    onChanged: (v) => setState(() => _showStamp = v),
                  ),
                  if (_showStamp) ...[
                    const SizedBox(height: 16),
                    if (_stampImagePath != null && File(_stampImagePath!).existsSync()) ...[
                      Center(
                        child: Image.file(
                          File(_stampImagePath!),
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    ElevatedButton.icon(
                      onPressed: _pickStamp,
                      icon: const Icon(Icons.upload_file),
                      label: Text(_stampImagePath == null ? 'Upload Stamp' : 'Change Stamp'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _stampPosition,
                      decoration: const InputDecoration(
                        labelText: 'Stamp Position',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'LEFT', child: Text('Left')),
                        DropdownMenuItem(value: 'RIGHT', child: Text('Right')),
                      ],
                      onChanged: (v) => setState(() => _stampPosition = v!),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Page Numbers & Generated Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Page Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Page Numbers'),
                    value: _showPageNumbers,
                    onChanged: (v) => setState(() => _showPageNumbers = v),
                  ),
                  if (_showPageNumbers) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pageNumberFormatController,
                      decoration: const InputDecoration(
                        labelText: 'Page Number Format',
                        hintText: 'Page {current} of {total}',
                        border: OutlineInputBorder(),
                        helperText: 'Use {current} and {total} placeholders',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Generated Info'),
                    value: _showGeneratedInfo,
                    onChanged: (v) => setState(() => _showGeneratedInfo = v),
                  ),
                  if (_showGeneratedInfo) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _generatedInfoTextController,
                      decoration: const InputDecoration(
                        labelText: 'Generated Info Text',
                        hintText: 'Generated on {date} at {time}',
                        border: OutlineInputBorder(),
                        helperText: 'Use {date} and {time} placeholders',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          ElevatedButton(
            onPressed: _isSaving ? null : _saveSettings,
            child: _isSaving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Padding(padding: EdgeInsets.all(16), child: Text('Save Footer Settings')),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
