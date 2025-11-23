import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/database/database_helper.dart';

class InvoiceSettingsScreen extends StatefulWidget {
  const InvoiceSettingsScreen({super.key});

  @override
  State<InvoiceSettingsScreen> createState() => _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState extends State<InvoiceSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  late TextEditingController _invoicePrefixController;
  late TextEditingController _startingNumberController;
  late TextEditingController _taxRateController;
  late TextEditingController _footerTextController;
  late TextEditingController _termsController;

  bool _isLoading = false;
  bool _enableTax = false;

  @override
  void initState() {
    super.initState();
    _invoicePrefixController = TextEditingController();
    _startingNumberController = TextEditingController();
    _taxRateController = TextEditingController();
    _footerTextController = TextEditingController();
    _termsController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _invoicePrefixController.dispose();
    _startingNumberController.dispose();
    _taxRateController.dispose();
    _footerTextController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final db = await _dbHelper.database;

      // Load all invoice settings
      final results = await db.query(
        'settings',
        where: 'key IN (?, ?, ?, ?, ?, ?)',
        whereArgs: [
          'invoice_prefix',
          'invoice_start_number',
          'enable_tax',
          'default_tax_rate',
          'invoice_footer',
          'invoice_terms',
        ],
      );

      // Convert results to map
      final settingsMap = <String, String>{};
      for (var row in results) {
        settingsMap[row['key'] as String] = row['value'] as String? ?? '';
      }

      // Update controllers with loaded values
      setState(() {
        _invoicePrefixController.text = settingsMap['invoice_prefix'] ?? 'INV-';
        _startingNumberController.text = settingsMap['invoice_start_number'] ?? '1000';
        _enableTax = settingsMap['enable_tax'] == '1' || settingsMap['enable_tax'] == 'true';
        _taxRateController.text = settingsMap['default_tax_rate'] ?? '0';
        _footerTextController.text = settingsMap['invoice_footer'] ?? '';
        _termsController.text = settingsMap['invoice_terms'] ?? '';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final db = await _dbHelper.database;

      // Prepare settings data
      final settings = {
        'invoice_prefix': _invoicePrefixController.text.trim(),
        'invoice_start_number': _startingNumberController.text.trim(),
        'enable_tax': _enableTax ? '1' : '0',
        'default_tax_rate': _taxRateController.text.trim(),
        'invoice_footer': _footerTextController.text.trim(),
        'invoice_terms': _termsController.text.trim(),
      };

      // Save each setting using INSERT OR REPLACE
      await db.transaction((txn) async {
        for (var entry in settings.entries) {
          await txn.rawInsert(
            '''
            INSERT OR REPLACE INTO settings (key, value, updated_at)
            VALUES (?, ?, ?)
            ''',
            [entry.key, entry.value, DateTime.now().toIso8601String()],
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Invoice Number Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _invoicePrefixController,
                            decoration: const InputDecoration(
                              labelText: 'Invoice Prefix',
                              hintText: 'e.g., INV-',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.text_fields),
                              helperText: 'Prefix for invoice numbers (e.g., INV-0001)',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter an invoice prefix';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _startingNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Starting Invoice Number',
                              hintText: 'e.g., 1000',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.numbers),
                              helperText: 'Starting number for new invoices',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a starting number';
                              }
                              final number = int.tryParse(value.trim());
                              if (number == null || number < 1) {
                                return 'Please enter a positive number';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tax Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Enable Tax'),
                            subtitle: const Text('Apply tax to invoices by default'),
                            value: _enableTax,
                            onChanged: (value) {
                              setState(() => _enableTax = value);
                            },
                            secondary: const Icon(Icons.receipt_long),
                          ),
                          if (_enableTax) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _taxRateController,
                              decoration: const InputDecoration(
                                labelText: 'Default Tax Rate (%)',
                                hintText: 'e.g., 18',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.percent),
                                helperText: 'Default tax rate percentage',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              validator: (value) {
                                if (_enableTax) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter a tax rate';
                                  }
                                  final rate = double.tryParse(value.trim());
                                  if (rate == null || rate < 0 || rate > 100) {
                                    return 'Tax rate must be between 0 and 100';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Invoice Footer & Terms',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _footerTextController,
                            decoration: const InputDecoration(
                              labelText: 'Invoice Footer Text',
                              hintText: 'e.g., Thank you for your business!',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.notes),
                              helperText: 'Text displayed at the bottom of invoices',
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _termsController,
                            decoration: const InputDecoration(
                              labelText: 'Terms and Conditions',
                              hintText: 'Enter terms and conditions...',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.article),
                              helperText: 'Terms and conditions for invoices',
                              alignLabelWithHint: true,
                            ),
                            maxLines: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => Navigator.pop(context),
                          child: const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Cancel'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveSettings,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('Save Settings'),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
