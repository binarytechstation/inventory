import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../services/invoice/invoice_settings_service.dart';

class GeneralSettingsTab extends StatefulWidget {
  final String invoiceType;

  const GeneralSettingsTab({super.key, required this.invoiceType});

  @override
  State<GeneralSettingsTab> createState() => _GeneralSettingsTabState();
}

class _GeneralSettingsTabState extends State<GeneralSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  final InvoiceSettingsService _service = InvoiceSettingsService();

  late TextEditingController _prefixController;
  late TextEditingController _startingNumberController;
  late TextEditingController _currentNumberController;
  late TextEditingController _numberFormatController;
  late TextEditingController _currencyCodeController;
  late TextEditingController _currencySymbolController;
  late TextEditingController _taxRateController;
  late TextEditingController _decimalPlacesController;

  bool _enableAutoIncrement = true;
  bool _enableTaxByDefault = true;
  bool _enableDiscountByDefault = false;
  String _resetPeriod = 'NEVER';
  String _dateFormat = 'dd/MM/yyyy';
  String _timeFormat = 'HH:mm';

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _prefixController = TextEditingController();
    _startingNumberController = TextEditingController();
    _currentNumberController = TextEditingController();
    _numberFormatController = TextEditingController();
    _currencyCodeController = TextEditingController();
    _currencySymbolController = TextEditingController();
    _taxRateController = TextEditingController();
    _decimalPlacesController = TextEditingController();
    _loadSettings();
  }

  @override
  void didUpdateWidget(GeneralSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.invoiceType != widget.invoiceType) {
      _loadSettings();
    }
  }

  @override
  void dispose() {
    _prefixController.dispose();
    _startingNumberController.dispose();
    _currentNumberController.dispose();
    _numberFormatController.dispose();
    _currencyCodeController.dispose();
    _currencySymbolController.dispose();
    _taxRateController.dispose();
    _decimalPlacesController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      var settings = await _service.getInvoiceSettings(widget.invoiceType);

      // If no settings exist, initialize defaults
      if (settings == null) {
        await _service.initializeDefaultSettings(widget.invoiceType);
        settings = await _service.getInvoiceSettings(widget.invoiceType);
      }

      if (settings != null && mounted) {
        setState(() {
          _prefixController.text = settings!['prefix'] as String? ?? '';
          _startingNumberController.text = (settings['starting_number'] as int? ?? 1000).toString();
          _currentNumberController.text = (settings['current_number'] as int? ?? 1000).toString();
          _numberFormatController.text = settings['number_format'] as String? ?? 'PREFIX-NNNN';
          _currencyCodeController.text = settings['currency_code'] as String? ?? 'USD';
          _currencySymbolController.text = settings['currency_symbol'] as String? ?? '\$';
          _taxRateController.text = (settings['default_tax_rate'] as num? ?? 0).toString();
          _decimalPlacesController.text = (settings['decimal_places'] as int? ?? 2).toString();
          _enableAutoIncrement = (settings['enable_auto_increment'] as int? ?? 1) == 1;
          _enableTaxByDefault = (settings['enable_tax_by_default'] as int? ?? 1) == 1;
          _enableDiscountByDefault = (settings['enable_discount_by_default'] as int? ?? 0) == 1;
          _resetPeriod = settings['reset_period'] as String? ?? 'NEVER';
          _dateFormat = settings['date_format'] as String? ?? 'dd/MM/yyyy';
          _timeFormat = settings['time_format'] as String? ?? 'HH:mm';
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
      await _service.saveInvoiceSettings({
        'invoice_type': widget.invoiceType,
        'prefix': _prefixController.text.trim(),
        'starting_number': int.parse(_startingNumberController.text),
        'current_number': int.parse(_currentNumberController.text),
        'number_format': _numberFormatController.text.trim(),
        'enable_auto_increment': _enableAutoIncrement ? 1 : 0,
        'reset_period': _resetPeriod,
        'currency_code': _currencyCodeController.text.trim(),
        'currency_symbol': _currencySymbolController.text.trim(),
        'default_tax_rate': double.parse(_taxRateController.text),
        'enable_tax_by_default': _enableTaxByDefault ? 1 : 0,
        'enable_discount_by_default': _enableDiscountByDefault ? 1 : 0,
        'decimal_places': int.parse(_decimalPlacesController.text),
        'date_format': _dateFormat,
        'time_format': _timeFormat,
        'language': 'en',
        'is_active': 1,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully'), backgroundColor: Colors.green),
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
          // Invoice Numbering
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Invoice Numbering', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _prefixController,
                    decoration: const InputDecoration(
                      labelText: 'Prefix',
                      hintText: 'e.g., INV, PUR',
                      border: OutlineInputBorder(),
                      helperText: 'Prefix for invoice numbers',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _startingNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Starting Number',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _currentNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Current Number',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _numberFormatController,
                    decoration: const InputDecoration(
                      labelText: 'Number Format',
                      hintText: 'PREFIX-NNNN',
                      border: OutlineInputBorder(),
                      helperText: 'Use PREFIX for prefix, NNNN for numbers',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Auto Increment'),
                    subtitle: const Text('Automatically increment invoice numbers'),
                    value: _enableAutoIncrement,
                    onChanged: (v) => setState(() => _enableAutoIncrement = v),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _resetPeriod,
                    decoration: const InputDecoration(
                      labelText: 'Reset Period',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'NEVER', child: Text('Never')),
                      DropdownMenuItem(value: 'YEARLY', child: Text('Yearly')),
                      DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                      DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                    ],
                    onChanged: (v) => setState(() => _resetPeriod = v!),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Currency Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Currency Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _currencyCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Currency Code',
                            hintText: 'USD',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _currencySymbolController,
                          decoration: const InputDecoration(
                            labelText: 'Currency Symbol',
                            hintText: '\$',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _decimalPlacesController,
                    decoration: const InputDecoration(
                      labelText: 'Decimal Places',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tax & Discount
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tax & Discount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _taxRateController,
                    decoration: const InputDecoration(
                      labelText: 'Default Tax Rate (%)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Enable Tax by Default'),
                    value: _enableTaxByDefault,
                    onChanged: (v) => setState(() => _enableTaxByDefault = v),
                  ),
                  SwitchListTile(
                    title: const Text('Enable Discount by Default'),
                    value: _enableDiscountByDefault,
                    onChanged: (v) => setState(() => _enableDiscountByDefault = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Date & Time Format
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Date & Time Format', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _dateFormat,
                    decoration: const InputDecoration(
                      labelText: 'Date Format',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'dd/MM/yyyy', child: Text('dd/MM/yyyy')),
                      DropdownMenuItem(value: 'MM/dd/yyyy', child: Text('MM/dd/yyyy')),
                      DropdownMenuItem(value: 'yyyy-MM-dd', child: Text('yyyy-MM-dd')),
                    ],
                    onChanged: (v) => setState(() => _dateFormat = v!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _timeFormat,
                    decoration: const InputDecoration(
                      labelText: 'Time Format',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'HH:mm', child: Text('24-hour (HH:mm)')),
                      DropdownMenuItem(value: 'hh:mm a', child: Text('12-hour (hh:mm AM/PM)')),
                    ],
                    onChanged: (v) => setState(() => _timeFormat = v!),
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
                : const Padding(padding: EdgeInsets.all(16), child: Text('Save Settings')),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
