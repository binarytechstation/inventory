import 'package:flutter/material.dart';
import '../../../services/invoice/invoice_settings_service.dart';
import 'invoice_settings_tabs/general_settings_tab.dart';
import 'invoice_settings_tabs/header_settings_tab.dart';
import 'invoice_settings_tabs/footer_settings_tab.dart';
import 'invoice_settings_tabs/body_settings_tab.dart';
import 'invoice_settings_tabs/print_settings_tab.dart';

class InvoiceSettingsMainScreen extends StatefulWidget {
  const InvoiceSettingsMainScreen({super.key});

  @override
  State<InvoiceSettingsMainScreen> createState() => _InvoiceSettingsMainScreenState();
}

class _InvoiceSettingsMainScreenState extends State<InvoiceSettingsMainScreen> with SingleTickerProviderStateMixin {
  final InvoiceSettingsService _service = InvoiceSettingsService();
  late TabController _tabController;

  String _selectedInvoiceType = 'SALE';
  List<Map<String, dynamic>> _invoiceTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadInvoiceTypes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoiceTypes() async {
    setState(() => _isLoading = true);
    try {
      var types = await _service.getAllInvoiceTypes();
      print('DEBUG: Loaded ${types.length} invoice types');

      // If no types exist, seed default types
      if (types.isEmpty) {
        print('DEBUG: No invoice types found, seeding defaults...');
        await _seedDefaultInvoiceTypes();
        types = await _service.getAllInvoiceTypes();
        print('DEBUG: After seeding, loaded ${types.length} invoice types');
      }

      for (var type in types) {
        print('DEBUG: Invoice type: ${type['type_code']} - ${type['type_name']}');
      }
      setState(() {
        _invoiceTypes = types;
        // Set default selection if types are available
        if (_invoiceTypes.isNotEmpty && !_invoiceTypes.any((t) => t['type_code'] == _selectedInvoiceType)) {
          _selectedInvoiceType = _invoiceTypes.first['type_code'] as String;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('DEBUG ERROR: Failed to load invoice types: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading invoice types: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _seedDefaultInvoiceTypes() async {
    final now = DateTime.now().toIso8601String();
    final invoiceTypes = [
      {
        'type_code': 'SALE',
        'type_name': 'Sales Invoice',
        'description': 'Invoice for product sales',
        'prefix': 'INV',
        'title': 'SALES INVOICE',
        'enable_party_selection': 1,
        'party_label': 'Customer',
        'color_code': '#4CAF50',
        'is_active': 1,
        'display_order': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'type_code': 'PURCHASE',
        'type_name': 'Purchase Invoice',
        'description': 'Invoice for product purchases',
        'prefix': 'PUR',
        'title': 'PURCHASE INVOICE',
        'enable_party_selection': 1,
        'party_label': 'Supplier',
        'color_code': '#2196F3',
        'is_active': 1,
        'display_order': 2,
        'created_at': now,
        'updated_at': now,
      },
    ];

    for (var type in invoiceTypes) {
      await _service.saveInvoiceType(type);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Settings'),
        foregroundColor: Colors.white,
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
      ),
      body: Column(
        children: [
          // Invoice Type Selector - Moved outside AppBar for better spacing
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long, color: Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showInvoiceTypeDialog(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          if (_invoiceTypes.any((type) => type['type_code'] == _selectedInvoiceType)) ...[
                                            Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: _parseColor(
                                                  _invoiceTypes.firstWhere(
                                                    (type) => type['type_code'] == _selectedInvoiceType,
                                                  )['color_code'] as String?,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                _invoiceTypes.firstWhere(
                                                  (type) => type['type_code'] == _selectedInvoiceType,
                                                )['type_name'] as String,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 16),
                                              ),
                                            ),
                                          ] else
                                            const Text(
                                              'Select Invoice Type',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down, color: Colors.blue),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          // Tab Bar with better styling
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Theme.of(context).primaryColor,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
              tabs: const [
                Tab(icon: Icon(Icons.settings), text: 'General'),
                Tab(icon: Icon(Icons.vertical_align_top), text: 'Header'),
                Tab(icon: Icon(Icons.vertical_align_bottom), text: 'Footer'),
                Tab(icon: Icon(Icons.table_chart), text: 'Body'),
                Tab(icon: Icon(Icons.print), text: 'Print'),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      GeneralSettingsTab(key: ValueKey('general_$_selectedInvoiceType'), invoiceType: _selectedInvoiceType),
                      HeaderSettingsTab(key: ValueKey('header_$_selectedInvoiceType'), invoiceType: _selectedInvoiceType),
                      FooterSettingsTab(key: ValueKey('footer_$_selectedInvoiceType'), invoiceType: _selectedInvoiceType),
                      BodySettingsTab(key: ValueKey('body_$_selectedInvoiceType'), invoiceType: _selectedInvoiceType),
                      PrintSettingsTab(key: ValueKey('print_$_selectedInvoiceType'), invoiceType: _selectedInvoiceType),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _showInvoiceTypeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Invoice Type'),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: SizedBox(
            width: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _invoiceTypes.length,
              itemBuilder: (context, index) {
                final type = _invoiceTypes[index];
                final typeCode = type['type_code'] as String;
                final typeName = type['type_name'] as String;
                final colorCode = type['color_code'] as String?;
                final isSelected = typeCode == _selectedInvoiceType;

                return ListTile(
                  leading: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _parseColor(colorCode),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(typeName),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  selected: isSelected,
                  selectedTileColor: Colors.blue.withValues(alpha: 0.1),
                  onTap: () {
                    setState(() => _selectedInvoiceType = typeCode);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Color _parseColor(String? colorCode) {
    if (colorCode == null || colorCode.isEmpty) return Colors.grey;
    try {
      return Color(int.parse(colorCode.replaceAll('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }
}
