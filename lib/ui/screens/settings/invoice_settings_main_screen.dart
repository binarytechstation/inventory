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
      final types = await _service.getAllInvoiceTypes();
      setState(() {
        _invoiceTypes = types;
        _isLoading = false;
      });
    } catch (e) {
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
                : DropdownButtonFormField<String>(
                    value: _selectedInvoiceType,
                    decoration: InputDecoration(
                      labelText: 'Select Invoice Type',
                      prefixIcon: const Icon(Icons.receipt_long),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    items: _invoiceTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type['type_code'] as String,
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: _parseColor(type['color_code'] as String?),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(type['type_name'] as String),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedInvoiceType = value);
                      }
                    },
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
                      GeneralSettingsTab(invoiceType: _selectedInvoiceType),
                      HeaderSettingsTab(invoiceType: _selectedInvoiceType),
                      FooterSettingsTab(invoiceType: _selectedInvoiceType),
                      BodySettingsTab(invoiceType: _selectedInvoiceType),
                      PrintSettingsTab(invoiceType: _selectedInvoiceType),
                    ],
                  ),
          ),
        ],
      ),
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
