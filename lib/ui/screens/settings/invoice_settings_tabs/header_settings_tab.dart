import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../../services/invoice/invoice_settings_service.dart';

class HeaderSettingsTab extends StatefulWidget {
  final String invoiceType;

  const HeaderSettingsTab({super.key, required this.invoiceType});

  @override
  State<HeaderSettingsTab> createState() => _HeaderSettingsTabState();
}

class _HeaderSettingsTabState extends State<HeaderSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  final InvoiceSettingsService _service = InvoiceSettingsService();

  late TextEditingController _companyNameController;
  late TextEditingController _companyTaglineController;
  late TextEditingController _companyAddressController;
  late TextEditingController _companyPhoneController;
  late TextEditingController _companyEmailController;
  late TextEditingController _companyWebsiteController;
  late TextEditingController _taxIdController;
  late TextEditingController _registrationNumberController;
  late TextEditingController _invoiceTitleController;
  late TextEditingController _titleFontSizeController;

  bool _showCompanyLogo = true;
  String? _logoPath;
  String _logoPosition = 'LEFT';
  bool _showCompanyAddress = true;
  bool _showCompanyPhone = true;
  bool _showCompanyEmail = true;
  bool _showCompanyWebsite = false;
  bool _showTaxId = true;
  String _taxIdLabel = 'Tax ID';
  bool _showRegistrationNumber = false;
  String _pageSize = 'A4';
  String _pageOrientation = 'PORTRAIT';
  String _headerAlignment = 'LEFT';
  String _headerTextColor = '#000000';
  bool _showInvoiceTitle = true;
  bool _showInvoiceNumber = true;
  bool _showInvoiceDate = true;
  bool _showDueDate = true;

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _companyNameController = TextEditingController();
    _companyTaglineController = TextEditingController();
    _companyAddressController = TextEditingController();
    _companyPhoneController = TextEditingController();
    _companyEmailController = TextEditingController();
    _companyWebsiteController = TextEditingController();
    _taxIdController = TextEditingController();
    _registrationNumberController = TextEditingController();
    _invoiceTitleController = TextEditingController();
    _titleFontSizeController = TextEditingController(text: '24');
    _loadSettings();
  }

  @override
  void didUpdateWidget(HeaderSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.invoiceType != widget.invoiceType) {
      _loadSettings();
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyTaglineController.dispose();
    _companyAddressController.dispose();
    _companyPhoneController.dispose();
    _companyEmailController.dispose();
    _companyWebsiteController.dispose();
    _taxIdController.dispose();
    _registrationNumberController.dispose();
    _invoiceTitleController.dispose();
    _titleFontSizeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      var settings = await _service.getHeaderSettings(widget.invoiceType);
      if (settings == null) {
        await _service.initializeDefaultSettings(widget.invoiceType);
        settings = await _service.getHeaderSettings(widget.invoiceType);
      }

      if (settings != null && mounted) {
        setState(() {
          _showCompanyLogo = (settings!['show_company_logo'] as int? ?? 1) == 1;
          _logoPath = settings['logo_path'] as String?;
          _logoPosition = settings['logo_position'] as String? ?? 'LEFT';
          _companyNameController.text = settings['company_name'] as String? ?? '';
          _companyTaglineController.text = settings['company_tagline'] as String? ?? '';
          _showCompanyAddress = (settings['show_company_address'] as int? ?? 1) == 1;
          _companyAddressController.text = settings['company_address'] as String? ?? '';
          _showCompanyPhone = (settings['show_company_phone'] as int? ?? 1) == 1;
          _companyPhoneController.text = settings['company_phone'] as String? ?? '';
          _showCompanyEmail = (settings['show_company_email'] as int? ?? 1) == 1;
          _companyEmailController.text = settings['company_email'] as String? ?? '';
          _showCompanyWebsite = (settings['show_company_website'] as int? ?? 0) == 1;
          _companyWebsiteController.text = settings['company_website'] as String? ?? '';
          _showTaxId = (settings['show_tax_id'] as int? ?? 1) == 1;
          _taxIdLabel = settings['tax_id_label'] as String? ?? 'Tax ID';
          _taxIdController.text = settings['tax_id'] as String? ?? '';
          _showRegistrationNumber = (settings['show_registration_number'] as int? ?? 0) == 1;
          _registrationNumberController.text = settings['registration_number'] as String? ?? '';
          _pageSize = settings['page_size'] as String? ?? 'A4';
          _pageOrientation = settings['page_orientation'] as String? ?? 'PORTRAIT';
          _headerAlignment = settings['header_alignment'] as String? ?? 'LEFT';
          _headerTextColor = settings['header_text_color'] as String? ?? '#000000';
          _showInvoiceTitle = (settings['show_invoice_title'] as int? ?? 1) == 1;
          _invoiceTitleController.text = settings['invoice_title'] as String? ?? 'INVOICE';
          _titleFontSizeController.text = (settings['title_font_size'] as int? ?? 24).toString();
          _showInvoiceNumber = (settings['show_invoice_number'] as int? ?? 1) == 1;
          _showInvoiceDate = (settings['show_invoice_date'] as int? ?? 1) == 1;
          _showDueDate = (settings['show_due_date'] as int? ?? 1) == 1;
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

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'svg'],
        dialogTitle: 'Select Company Logo',
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _logoPath = result.files.first.path;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting logo: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await _service.saveHeaderSettings({
        'invoice_type': widget.invoiceType,
        'show_company_logo': _showCompanyLogo ? 1 : 0,
        'logo_path': _logoPath,
        'logo_width': 150,
        'logo_height': 80,
        'logo_position': _logoPosition,
        'company_name': _companyNameController.text.trim(),
        'company_tagline': _companyTaglineController.text.trim(),
        'show_company_address': _showCompanyAddress ? 1 : 0,
        'company_address': _companyAddressController.text.trim(),
        'show_company_phone': _showCompanyPhone ? 1 : 0,
        'company_phone': _companyPhoneController.text.trim(),
        'show_company_email': _showCompanyEmail ? 1 : 0,
        'company_email': _companyEmailController.text.trim(),
        'show_company_website': _showCompanyWebsite ? 1 : 0,
        'company_website': _companyWebsiteController.text.trim(),
        'show_tax_id': _showTaxId ? 1 : 0,
        'tax_id_label': _taxIdLabel,
        'tax_id': _taxIdController.text.trim(),
        'show_registration_number': _showRegistrationNumber ? 1 : 0,
        'registration_number': _registrationNumberController.text.trim(),
        'page_size': _pageSize,
        'page_orientation': _pageOrientation,
        'header_alignment': _headerAlignment,
        'header_text_color': _headerTextColor,
        'show_invoice_title': _showInvoiceTitle ? 1 : 0,
        'invoice_title': _invoiceTitleController.text.trim(),
        'title_font_size': int.parse(_titleFontSizeController.text),
        'show_invoice_number': _showInvoiceNumber ? 1 : 0,
        'show_invoice_date': _showInvoiceDate ? 1 : 0,
        'show_due_date': _showDueDate ? 1 : 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Header settings saved successfully'), backgroundColor: Colors.green),
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
          // Company Logo
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Company Logo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Company Logo'),
                    value: _showCompanyLogo,
                    onChanged: (v) => setState(() => _showCompanyLogo = v),
                  ),
                  if (_showCompanyLogo) ...[
                    const SizedBox(height: 16),
                    if (_logoPath != null && File(_logoPath!).existsSync()) ...[
                      Center(
                        child: Image.file(
                          File(_logoPath!),
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    ElevatedButton.icon(
                      onPressed: _pickLogo,
                      icon: const Icon(Icons.upload_file),
                      label: Text(_logoPath == null ? 'Select Logo' : 'Change Logo'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _logoPosition,
                      decoration: const InputDecoration(
                        labelText: 'Logo Position',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'LEFT', child: Text('Left')),
                        DropdownMenuItem(value: 'CENTER', child: Text('Center')),
                        DropdownMenuItem(value: 'RIGHT', child: Text('Right')),
                      ],
                      onChanged: (v) => setState(() => _logoPosition = v!),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Company Details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Company Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _companyNameController,
                    decoration: const InputDecoration(
                      labelText: 'Company Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _companyTaglineController,
                    decoration: const InputDecoration(
                      labelText: 'Company Tagline (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Address'),
                    value: _showCompanyAddress,
                    onChanged: (v) => setState(() => _showCompanyAddress = v),
                  ),
                  if (_showCompanyAddress) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _companyAddressController,
                      decoration: const InputDecoration(
                        labelText: 'Company Address',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Phone'),
                    value: _showCompanyPhone,
                    onChanged: (v) => setState(() => _showCompanyPhone = v),
                  ),
                  if (_showCompanyPhone) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _companyPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Company Phone',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Email'),
                    value: _showCompanyEmail,
                    onChanged: (v) => setState(() => _showCompanyEmail = v),
                  ),
                  if (_showCompanyEmail) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _companyEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Company Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Website'),
                    value: _showCompanyWebsite,
                    onChanged: (v) => setState(() => _showCompanyWebsite = v),
                  ),
                  if (_showCompanyWebsite) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _companyWebsiteController,
                      decoration: const InputDecoration(
                        labelText: 'Company Website',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tax & Registration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tax & Registration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Tax ID'),
                    value: _showTaxId,
                    onChanged: (v) => setState(() => _showTaxId = v),
                  ),
                  if (_showTaxId) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _taxIdLabel,
                      decoration: const InputDecoration(
                        labelText: 'Tax ID Label',
                        hintText: 'Tax ID, VAT, GST, etc.',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => _taxIdLabel = v,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _taxIdController,
                      decoration: const InputDecoration(
                        labelText: 'Tax ID Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Registration Number'),
                    value: _showRegistrationNumber,
                    onChanged: (v) => setState(() => _showRegistrationNumber = v),
                  ),
                  if (_showRegistrationNumber) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _registrationNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Registration Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Page Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Page Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _pageSize,
                          decoration: const InputDecoration(
                            labelText: 'Page Size',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'A4', child: Text('A4')),
                            DropdownMenuItem(value: 'Letter', child: Text('Letter')),
                            DropdownMenuItem(value: 'Legal', child: Text('Legal')),
                            DropdownMenuItem(value: 'Thermal80mm', child: Text('Thermal 80mm')),
                          ],
                          onChanged: (v) => setState(() => _pageSize = v!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _pageOrientation,
                          decoration: const InputDecoration(
                            labelText: 'Orientation',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'PORTRAIT', child: Text('Portrait')),
                            DropdownMenuItem(value: 'LANDSCAPE', child: Text('Landscape')),
                          ],
                          onChanged: (v) => setState(() => _pageOrientation = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _headerAlignment,
                    decoration: const InputDecoration(
                      labelText: 'Header Alignment',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'LEFT', child: Text('Left')),
                      DropdownMenuItem(value: 'CENTER', child: Text('Center')),
                      DropdownMenuItem(value: 'RIGHT', child: Text('Right')),
                    ],
                    onChanged: (v) => setState(() => _headerAlignment = v!),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Invoice Title
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Invoice Title', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Invoice Title'),
                    value: _showInvoiceTitle,
                    onChanged: (v) => setState(() => _showInvoiceTitle = v),
                  ),
                  if (_showInvoiceTitle) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _invoiceTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Invoice Title',
                        hintText: 'INVOICE, SALES INVOICE, etc.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleFontSizeController,
                      decoration: const InputDecoration(
                        labelText: 'Title Font Size',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ],
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Invoice Number'),
                    value: _showInvoiceNumber,
                    onChanged: (v) => setState(() => _showInvoiceNumber = v),
                  ),
                  SwitchListTile(
                    title: const Text('Show Invoice Date'),
                    value: _showInvoiceDate,
                    onChanged: (v) => setState(() => _showInvoiceDate = v),
                  ),
                  SwitchListTile(
                    title: const Text('Show Due Date'),
                    value: _showDueDate,
                    onChanged: (v) => setState(() => _showDueDate = v),
                  ),
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
                : const Padding(padding: EdgeInsets.all(16), child: Text('Save Header Settings')),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
