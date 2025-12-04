import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/database/database_helper.dart';
import '../../../services/invoice/invoice_service.dart';
import 'dart:io';

class AdvancedInvoiceSettingsScreen extends StatefulWidget {
  const AdvancedInvoiceSettingsScreen({super.key});

  @override
  State<AdvancedInvoiceSettingsScreen> createState() => _AdvancedInvoiceSettingsScreenState();
}

class _AdvancedInvoiceSettingsScreenState extends State<AdvancedInvoiceSettingsScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final InvoiceService _invoiceService = InvoiceService();

  late TabController _tabController;
  String _selectedInvoiceType = 'SALE';
  bool _isLoading = false;

  // Body Settings Controllers
  final Map<String, dynamic> _bodySettings = {};

  // Print Settings Controllers
  final Map<String, dynamic> _printSettings = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final db = await _dbHelper.database;

      // Load body settings
      final bodyResults = await db.query(
        'invoice_body_settings',
        where: 'invoice_type = ?',
        whereArgs: [_selectedInvoiceType],
      );

      if (bodyResults.isNotEmpty) {
        _bodySettings.clear();
        _bodySettings.addAll(bodyResults.first);
      } else {
        // Create default body settings
        await _createDefaultBodySettings(db);
      }

      // Load print settings
      final printResults = await db.query(
        'invoice_print_settings',
        where: 'invoice_type = ?',
        whereArgs: [_selectedInvoiceType],
      );

      if (printResults.isNotEmpty) {
        _printSettings.clear();
        _printSettings.addAll(printResults.first);
      } else {
        // Create default print settings
        await _createDefaultPrintSettings(db);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }

  Future<void> _createDefaultBodySettings(dynamic db) async {
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('invoice_body_settings', {
      'invoice_type': _selectedInvoiceType,
      'show_party_details': 1,
      'party_label': 'Bill To',
      'show_party_name': 1,
      'show_party_company': 1,
      'show_party_address': 1,
      'show_party_phone': 1,
      'show_party_email': 1,
      'show_party_tax_id': 0,
      'show_item_image': 0,
      'show_item_code': 1,
      'show_item_description': 1,
      'show_hsn_code': 0,
      'show_unit_column': 1,
      'show_quantity_column': 1,
      'show_unit_price_column': 1,
      'show_discount_column': 1,
      'show_tax_column': 1,
      'show_amount_column': 1,
      'table_border_style': 'SOLID',
      'table_border_color': '#CCCCCC',
      'table_header_bg_color': '#F5F5F5',
      'show_subtotal': 1,
      'show_total_discount': 1,
      'show_total_tax': 1,
      'show_shipping_charges': 0,
      'show_other_charges': 0,
      'show_grand_total': 1,
      'grand_total_label': 'Grand Total',
      'grand_total_font_size': 16,
      'show_amount_in_words': 1,
      'show_qr_code': 0,
      'qr_code_size': 100,
      'color_theme': 'DEFAULT',
      'created_at': now,
      'updated_at': now,
    });

    // Reload settings
    final results = await db.query(
      'invoice_body_settings',
      where: 'id = ?',
      whereArgs: [id],
    );
    _bodySettings.clear();
    _bodySettings.addAll(results.first);
  }

  Future<void> _createDefaultPrintSettings(dynamic db) async {
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('invoice_print_settings', {
      'invoice_type': _selectedInvoiceType,
      'paper_size': 'A4',
      'paper_orientation': 'PORTRAIT',
      'layout_type': 'STANDARD',
      'print_format': 'PDF',
      'copies': 1,
      'print_color': 1,
      'print_duplex': 0,
      'margin_top': 20.0,
      'margin_bottom': 20.0,
      'margin_left': 20.0,
      'margin_right': 20.0,
      'show_watermark': 0,
      'watermark_opacity': 0.3,
      'watermark_rotation': 45,
      'watermark_position': 'CENTER',
      'compress_pdf': 1,
      'pdf_quality': 90,
      'enable_thermal_print': 0,
      'thermal_width': 80,
      'thermal_font_size': 10,
      'thermal_line_spacing': 1.2,
      'enable_qr_code': 0,
      'enable_barcode': 0,
      'barcode_type': 'CODE128',
      'created_at': now,
      'updated_at': now,
    });

    // Reload settings
    final results = await db.query(
      'invoice_print_settings',
      where: 'id = ?',
      whereArgs: [id],
    );
    _printSettings.clear();
    _printSettings.addAll(results.first);
  }

  Future<void> _saveBodySettings() async {
    setState(() => _isLoading = true);
    try {
      final db = await _dbHelper.database;

      final id = _bodySettings['id'] as int;
      await db.update(
        'invoice_body_settings',
        {
          ..._bodySettings,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Body settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePrintSettings() async {
    setState(() => _isLoading = true);
    try {
      final db = await _dbHelper.database;

      final id = _printSettings['id'] as int;
      await db.update(
        'invoice_print_settings',
        {
          ..._printSettings,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Print settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testPrint() async {
    // Show dialog to select test transaction
    showDialog(
      context: context,
      builder: (context) => _TestPrintDialog(invoiceService: _invoiceService),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Invoice Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Body Settings', icon: Icon(Icons.article)),
            Tab(text: 'Print Settings', icon: Icon(Icons.print)),
            Tab(text: 'Test Print', icon: Icon(Icons.preview)),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _selectedInvoiceType,
              dropdownColor: Theme.of(context).appBarTheme.backgroundColor ?? Colors.blue[700],
              style: const TextStyle(color: Colors.white, fontSize: 14),
              underline: Container(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              iconEnabledColor: Colors.white,
              items: const [
                DropdownMenuItem(
                  value: 'SALE',
                  child: Text('Sales Invoice', style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: 'PURCHASE',
                  child: Text('Purchase Invoice', style: TextStyle(color: Colors.white)),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedInvoiceType = value;
                  });
                  _loadSettings();
                }
              },
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBodySettingsTab(),
                _buildPrintSettingsTab(),
                _buildTestPrintTab(),
              ],
            ),
    );
  }

  Widget _buildBodySettingsTab() {
    if (_bodySettings.isEmpty) {
      return const Center(child: Text('No settings available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Party Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Show Party Details'),
            value: (_bodySettings['show_party_details'] as int?) == 1,
            onChanged: (value) {
              setState(() {
                _bodySettings['show_party_details'] = value ? 1 : 0;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Show Party Name'),
            value: (_bodySettings['show_party_name'] as int?) == 1,
            onChanged: (value) {
              setState(() {
                _bodySettings['show_party_name'] = value ? 1 : 0;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Show Party Company'),
            value: (_bodySettings['show_party_company'] as int?) == 1,
            onChanged: (value) {
              setState(() {
                _bodySettings['show_party_company'] = value ? 1 : 0;
              });
            },
          ),
          const Divider(height: 32),
          const Text(
            'Item Columns',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Show Item Code/SKU'),
            value: (_bodySettings['show_item_code'] as int?) == 1,
            onChanged: (value) {
              setState(() {
                _bodySettings['show_item_code'] = value ? 1 : 0;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Show Item Description'),
            value: (_bodySettings['show_item_description'] as int?) == 1,
            onChanged: (value) {
              setState(() {
                _bodySettings['show_item_description'] = value ? 1 : 0;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Show Discount Column'),
            value: (_bodySettings['show_discount_column'] as int?) == 1,
            onChanged: (value) {
              setState(() {
                _bodySettings['show_discount_column'] = value ? 1 : 0;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Show Tax Column'),
            value: (_bodySettings['show_tax_column'] as int?) == 1,
            onChanged: (value) {
              setState(() {
                _bodySettings['show_tax_column'] = value ? 1 : 0;
              });
            },
          ),
          const Divider(height: 32),
          const Text(
            'Totals Section',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Show Subtotal'),
            value: (_bodySettings['show_subtotal'] as int?) == 1,
            onChanged: (value) {
              setState(() {
                _bodySettings['show_subtotal'] = value ? 1 : 0;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Show Total Discount'),
            value: (_bodySettings['show_total_discount'] as int?) == 1,
            onChanged: (value) {
              setState(() {
                _bodySettings['show_total_discount'] = value ? 1 : 0;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Show Total Tax'),
            value: (_bodySettings['show_total_tax'] as int?) == 1,
            onChanged: (value) {
              setState(() {
                _bodySettings['show_total_tax'] = value ? 1 : 0;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Show Amount in Words'),
            value: (_bodySettings['show_amount_in_words'] as int?) == 1,
            onChanged: (value) {
              setState(() {
                _bodySettings['show_amount_in_words'] = value ? 1 : 0;
              });
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveBodySettings,
              icon: const Icon(Icons.save),
              label: const Text('Save Body Settings'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrintSettingsTab() {
    if (_printSettings.isEmpty) {
      return const Center(child: Text('No settings available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paper Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Paper Size'),
            subtitle: Text(_printSettings['paper_size'] as String? ?? 'A4'),
            trailing: DropdownButton<String>(
              value: _printSettings['paper_size'] as String? ?? 'A4',
              items: const [
                DropdownMenuItem(value: 'A4', child: Text('A4')),
                DropdownMenuItem(value: 'LETTER', child: Text('Letter')),
                DropdownMenuItem(value: 'LEGAL', child: Text('Legal')),
              ],
              onChanged: (value) {
                setState(() {
                  _printSettings['paper_size'] = value;
                });
              },
            ),
          ),
          ListTile(
            title: const Text('Orientation'),
            subtitle: Text(_printSettings['paper_orientation'] as String? ?? 'PORTRAIT'),
            trailing: DropdownButton<String>(
              value: _printSettings['paper_orientation'] as String? ?? 'PORTRAIT',
              items: const [
                DropdownMenuItem(value: 'PORTRAIT', child: Text('Portrait')),
                DropdownMenuItem(value: 'LANDSCAPE', child: Text('Landscape')),
              ],
              onChanged: (value) {
                setState(() {
                  _printSettings['paper_orientation'] = value;
                });
              },
            ),
          ),
          const Divider(height: 32),
          const Text(
            'PDF Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Compress PDF'),
            subtitle: const Text('Reduce file size'),
            value: (_printSettings['compress_pdf'] as int?) == 1,
            onChanged: (value) {
              setState(() {
                _printSettings['compress_pdf'] = value ? 1 : 0;
              });
            },
          ),
          ListTile(
            title: const Text('PDF Quality'),
            subtitle: Slider(
              value: ((_printSettings['pdf_quality'] as int?) ?? 90).toDouble(),
              min: 50,
              max: 100,
              divisions: 10,
              label: '${_printSettings['pdf_quality']}%',
              onChanged: (value) {
                setState(() {
                  _printSettings['pdf_quality'] = value.toInt();
                });
              },
            ),
          ),
          const Divider(height: 32),
          const Text(
            'Margins (in mm)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: (_printSettings['margin_top'] as num?)?.toString() ?? '20',
                  decoration: const InputDecoration(
                    labelText: 'Top',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _printSettings['margin_top'] = double.tryParse(value) ?? 20.0;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  initialValue: (_printSettings['margin_bottom'] as num?)?.toString() ?? '20',
                  decoration: const InputDecoration(
                    labelText: 'Bottom',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _printSettings['margin_bottom'] = double.tryParse(value) ?? 20.0;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: (_printSettings['margin_left'] as num?)?.toString() ?? '20',
                  decoration: const InputDecoration(
                    labelText: 'Left',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _printSettings['margin_left'] = double.tryParse(value) ?? 20.0;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  initialValue: (_printSettings['margin_right'] as num?)?.toString() ?? '20',
                  decoration: const InputDecoration(
                    labelText: 'Right',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _printSettings['margin_right'] = double.tryParse(value) ?? 20.0;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savePrintSettings,
              icon: const Icon(Icons.save),
              label: const Text('Save Print Settings'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestPrintTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.print, size: 100, color: Colors.grey),
          const SizedBox(height: 24),
          const Text(
            'Test Invoice Printing',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Generate a test invoice using the current settings to preview how your invoices will look.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _testPrint,
            icon: const Icon(Icons.print),
            label: const Text('Generate Test Invoice'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _TestPrintDialog extends StatefulWidget {
  final InvoiceService invoiceService;

  const _TestPrintDialog({required this.invoiceService});

  @override
  State<_TestPrintDialog> createState() => _TestPrintDialogState();
}

class _TestPrintDialogState extends State<_TestPrintDialog> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _transactions = [];
  int? _selectedTransactionId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final db = await _dbHelper.database;
      final transactions = await db.query(
        'transactions',
        orderBy: 'created_at DESC',
        limit: 10,
      );

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

  Future<void> _generateTestInvoice() async {
    if (_selectedTransactionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a transaction')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pdfPath = await widget.invoiceService.generateInvoicePDF(
        transactionId: _selectedTransactionId!,
        saveToFile: true,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);

        // Show success dialog with option to open
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Test Invoice Generated'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Test invoice has been generated successfully!'),
                const SizedBox(height: 16),
                const Text('File saved to:'),
                const SizedBox(height: 8),
                SelectableText(
                  pdfPath,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
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
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating invoice: $e')),
        );
      }
    }
  }

  Future<void> _openPDF(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Transaction for Test Print'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _transactions.isEmpty
                ? const Center(
                    child: Text('No transactions available.\nCreate a sale first to test printing.'),
                  )
                : ListView.builder(
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _transactions[index];
                      final isSelected = _selectedTransactionId == transaction['id'];

                      return Card(
                        color: isSelected ? Colors.blue.shade50 : null,
                        child: ListTile(
                          selected: isSelected,
                          leading: CircleAvatar(
                            child: Text('${index + 1}'),
                          ),
                          title: Text(
                            transaction['invoice_number'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Type: ${transaction['transaction_type']}'),
                              Text('Amount: \$${(transaction['total_amount'] as num).toStringAsFixed(2)}'),
                              Text('Party: ${transaction['party_name'] ?? 'N/A'}'),
                            ],
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: Colors.blue)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedTransactionId = transaction['id'] as int;
                            });
                          },
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _generateTestInvoice,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.print),
          label: const Text('Generate'),
        ),
      ],
    );
  }
}
