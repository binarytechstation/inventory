import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/reports/reports_service.dart';
import '../../../services/export/pdf_export_service.dart';
import '../../../services/export/excel_export_service.dart';
import '../../../services/currency/currency_service.dart';
import '../../providers/auth_provider.dart';
import 'transaction_details_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportsService _reportsService = ReportsService();
  final PdfExportService _pdfService = PdfExportService();
  final ExcelExportService _excelService = ExcelExportService();
  final CurrencyService _currencyService = CurrencyService();
  String _currencySymbol = 'Tk';

  // Store current report data for export
  Map<String, dynamic>? _currentSalesData;
  Map<String, dynamic>? _currentPurchaseData;
  List<Map<String, dynamic>>? _currentInventoryData;
  List<Map<String, dynamic>>? _currentProductPerformanceData;
  List<Map<String, dynamic>>? _currentCustomerData;
  List<Map<String, dynamic>>? _currentSupplierData;
  Map<String, dynamic>? _currentProfitLossData;
  List<Map<String, dynamic>>? _currentCategoryData;
  DateTimeRange? _currentDateRange;
  bool _isTopPerformers = true;

  @override
  void initState() {
    super.initState();
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    try {
      final symbol = await _currencyService.getCurrencySymbol();
      // Use 'Tk' for display instead of ৳
      if (mounted) {
        setState(() {
          _currencySymbol = symbol == '৳' ? 'Tk' : symbol;
        });
      }
    } catch (e) {
      // Use default
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: const Text(
                'Business Reports',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade800, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 56),
                    child: Row(
                      children: [
                        _headerStat(Icons.receipt_long, 'Transactions', Colors.white),
                        const SizedBox(width: 16),
                        _headerStat(Icons.trending_up, 'Sales', Colors.greenAccent),
                        const SizedBox(width: 16),
                        _headerStat(Icons.inventory_2, 'Inventory', Colors.amberAccent),
                        const SizedBox(width: 16),
                        _headerStat(Icons.account_balance, 'P & L', Colors.pinkAccent),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('Financial Reports', Icons.attach_money, Colors.green, isDark),
                  const SizedBox(height: 12),
                  _buildReportsRow([
                    _buildReportCard(
                      title: 'Sales Summary',
                      description: 'Revenue, discounts, taxes, and transaction counts',
                      icon: Icons.trending_up,
                      color: Colors.green,
                      onView: () => _showSalesReport(context),
                      onExportPDF: () => _exportToPDF('Sales Summary'),
                      onExportExcel: () => _exportToExcel('Sales Summary'),
                    ),
                    _buildReportCard(
                      title: 'Purchase Summary',
                      description: 'Procurement costs, suppliers, and order history',
                      icon: Icons.shopping_cart,
                      color: Colors.blue,
                      onView: () => _showPurchaseReport(context),
                      onExportPDF: () => _exportToPDF('Purchase Summary'),
                      onExportExcel: () => _exportToExcel('Purchase Summary'),
                    ),
                    _buildReportCard(
                      title: 'Profit & Loss',
                      description: 'Revenue vs expenses and profitability analysis',
                      icon: Icons.account_balance,
                      color: Colors.indigo,
                      onView: () => _showProfitLossReport(context),
                      onExportPDF: () => _exportToPDF('Profit & Loss'),
                      onExportExcel: () => _exportToExcel('Profit & Loss'),
                    ),
                  ]),
                  const SizedBox(height: 28),
                  _sectionHeader('Inventory & Products', Icons.inventory_2, Colors.orange, isDark),
                  const SizedBox(height: 12),
                  _buildReportsRow([
                    _buildReportCard(
                      title: 'Inventory Report',
                      description: 'Stock levels, valuations, and batch details',
                      icon: Icons.inventory_2,
                      color: Colors.orange,
                      onView: () => _showInventoryReport(context),
                      onExportPDF: () => _exportToPDF('Inventory Report'),
                      onExportExcel: () => _exportToExcel('Inventory Report'),
                    ),
                    _buildReportCard(
                      title: 'Product Performance',
                      description: 'Top selling products and category trends',
                      icon: Icons.star,
                      color: Colors.amber,
                      onView: () => _showProductPerformanceReport(context),
                      onExportPDF: () => _exportToPDF('Product Performance'),
                      onExportExcel: () => _exportToExcel('Product Performance'),
                    ),
                    _buildReportCard(
                      title: 'Category Analysis',
                      description: 'Sales performance broken down by product category',
                      icon: Icons.category,
                      color: Colors.pink,
                      onView: () => _showCategoryReport(context),
                      onExportPDF: () => _exportToPDF('Category Analysis'),
                      onExportExcel: () => _exportToExcel('Category Analysis'),
                    ),
                  ]),
                  const SizedBox(height: 28),
                  _sectionHeader('Parties & Transactions', Icons.people, Colors.purple, isDark),
                  const SizedBox(height: 12),
                  _buildReportsRow([
                    _buildReportCard(
                      title: 'Customer Report',
                      description: 'Balances, credit limits, and purchase history',
                      icon: Icons.people,
                      color: Colors.purple,
                      onView: () => _showCustomerReport(context),
                      onExportPDF: () => _exportToPDF('Customer Report'),
                      onExportExcel: () => _exportToExcel('Customer Report'),
                    ),
                    _buildReportCard(
                      title: 'Supplier Report',
                      description: 'Supplier statistics and procurement analysis',
                      icon: Icons.local_shipping,
                      color: Colors.teal,
                      onView: () => _showSupplierReport(context),
                      onExportPDF: () => _exportToPDF('Supplier Report'),
                      onExportExcel: () => _exportToExcel('Supplier Report'),
                    ),
                    _buildReportCard(
                      title: 'Transaction Details',
                      description: 'Detailed transaction log with hourly analysis',
                      icon: Icons.receipt_long,
                      color: Colors.cyan,
                      onView: () => _navigateToTransactionDetails(context),
                      onExportPDF: null,
                      onExportExcel: null,
                    ),
                  ]),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStat(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color, bool isDark) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.grey[850],
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Divider(color: color.withValues(alpha: 0.3), thickness: 1)),
    ]);
  }

  Widget _buildReportsRow(List<Widget> cards) {
    final items = <Widget>[];
    for (int i = 0; i < cards.length; i++) {
      if (i > 0) items.add(const SizedBox(width: 16));
      items.add(Expanded(child: cards[i]));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: items);
  }

  void _navigateToTransactionDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TransactionDetailsScreen(),
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onView,
    VoidCallback? onExportPDF,
    VoidCallback? onExportExcel,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 3,
      shadowColor: color.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Colored gradient banner with icon
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onView,
                    icon: const Icon(Icons.bar_chart, size: 16),
                    label: const Text('View Report', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                if (onExportPDF != null || onExportExcel != null) ...[
                  const SizedBox(height: 8),
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      final canExport = authProvider.currentUser?.hasPermission('export_reports') ?? false;
                      return Row(children: [
                        if (onExportPDF != null)
                          Expanded(
                            child: Tooltip(
                              message: canExport ? '' : 'Admin only',
                              child: OutlinedButton.icon(
                                onPressed: canExport ? onExportPDF : null,
                                icon: Icon(Icons.picture_as_pdf, size: 14, color: canExport ? Colors.red[700] : null),
                                label: const Text('PDF', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  side: BorderSide(color: canExport ? Colors.red.shade300 : Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ),
                        if (onExportPDF != null && onExportExcel != null) const SizedBox(width: 6),
                        if (onExportExcel != null)
                          Expanded(
                            child: Tooltip(
                              message: canExport ? '' : 'Admin only',
                              child: OutlinedButton.icon(
                                onPressed: canExport ? onExportExcel : null,
                                icon: Icon(Icons.table_chart, size: 14, color: canExport ? Colors.green[700] : null),
                                label: const Text('Excel', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  side: BorderSide(color: canExport ? Colors.green.shade300 : Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ),
                      ]);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Sales Report
  Future<void> _showSalesReport(BuildContext context) async {
    final dateRange = await _showDateRangePicker(context, 'Sales Summary Report');
    if (dateRange == null) return;

    if (!context.mounted) return;
    _showLoadingDialog(context);

    try {
      final report = await _reportsService.getSalesSummary(
        dateRange.start,
        dateRange.end,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Store data for export
      setState(() {
        _currentSalesData = report;
        _currentDateRange = dateRange;
      });

      // Check if there are any transactions
      final totalTransactions = (report['total_transactions'] as int?) ?? 0;

      if (totalTransactions == 0) {
        _showEmptyReportDialog(
          context,
          'Sales Summary Report',
          Icons.shopping_bag_outlined,
          'No sales found',
          'No sales transactions found in the selected period.\nTry selecting a different date range or make some sales.',
          dateRange,
        );
        return;
      }

      _showReportDialog(
        context,
        'Sales Summary Report',
        [
          _buildReportItem('Date Range',
              '${_formatDate(dateRange.start)} - ${_formatDate(dateRange.end)}'),
          _buildReportItem('Total Transactions',
              report['total_transactions'].toString()),
          _buildReportItem('Unique Customers',
              report['unique_customers'].toString()),
          _buildReportItem('Subtotal',
              '$_currencySymbol${(report['subtotal'] as num).toStringAsFixed(2)}'),
          _buildReportItem('Total Discount',
              '$_currencySymbol${(report['total_discount'] as num).toStringAsFixed(2)}'),
          _buildReportItem('Total Tax',
              '$_currencySymbol${(report['total_tax'] as num).toStringAsFixed(2)}'),
          _buildReportItem('Total Sales',
              '$_currencySymbol${(report['total_sales'] as num).toStringAsFixed(2)}',
              isHighlighted: true),
          _buildReportItem('Average Sale',
              '$_currencySymbol${(report['average_sale'] as num).toStringAsFixed(2)}'),
        ],
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading report: $e')),
      );
    }
  }

  // Purchase Report
  Future<void> _showPurchaseReport(BuildContext context) async {
    final dateRange = await _showDateRangePicker(context, 'Purchase Summary Report');
    if (dateRange == null) return;

    if (!context.mounted) return;
    _showLoadingDialog(context);

    try {
      final report = await _reportsService.getPurchasesSummary(
        dateRange.start,
        dateRange.end,
      );

      if (!context.mounted) return;
      Navigator.pop(context);

      // Store data for export
      setState(() {
        _currentPurchaseData = report;
        _currentDateRange = dateRange;
      });

      // Check if there are any transactions
      final totalTransactions = (report['total_transactions'] as int?) ?? 0;

      if (totalTransactions == 0) {
        _showEmptyReportDialog(
          context,
          'Purchase Summary Report',
          Icons.shopping_cart_outlined,
          'No purchases found',
          'No purchase transactions found in the selected period.\nTry selecting a different date range or make some purchases.',
          dateRange,
        );
        return;
      }

      _showReportDialog(
        context,
        'Purchase Summary Report',
        [
          _buildReportItem('Date Range',
              '${_formatDate(dateRange.start)} - ${_formatDate(dateRange.end)}'),
          _buildReportItem('Total Transactions',
              report['total_transactions'].toString()),
          _buildReportItem('Unique Suppliers',
              report['unique_suppliers'].toString()),
          _buildReportItem('Subtotal',
              '$_currencySymbol${(report['subtotal'] as num).toStringAsFixed(2)}'),
          _buildReportItem('Total Discount',
              '$_currencySymbol${(report['total_discount'] as num).toStringAsFixed(2)}'),
          _buildReportItem('Total Tax',
              '$_currencySymbol${(report['total_tax'] as num).toStringAsFixed(2)}'),
          _buildReportItem('Total Purchases',
              '$_currencySymbol${(report['total_purchases'] as num).toStringAsFixed(2)}',
              isHighlighted: true),
          _buildReportItem('Average Purchase',
              '$_currencySymbol${(report['average_purchase'] as num).toStringAsFixed(2)}'),
        ],
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading report: $e')),
      );
    }
  }

  // Inventory Report
  Future<void> _showInventoryReport(BuildContext context) async {
    _showLoadingDialog(context);

    try {
      final report = await _reportsService.getInventoryReport();

      print('DEBUG INVENTORY REPORT: Got ${report.length} items');
      if (report.isNotEmpty) {
        print('DEBUG FIRST ITEM: ${report.first}');
        print('DEBUG FIRST ITEM KEYS: ${report.first.keys.toList()}');
      }

      if (!context.mounted) return;
      Navigator.pop(context);

      // Store data for export
      setState(() {
        _currentInventoryData = report;
      });

      // Check if there are any products
      if (report.isEmpty) {
        _showEmptyReportDialog(
          context,
          'Inventory Report',
          Icons.inventory_2_outlined,
          'No products in inventory',
          'Add products to your inventory to see the inventory report.',
          null,
        );
        return;
      }

      // Calculate totals
      double totalValue = 0;
      int totalProducts = report.length;
      int lowStockCount = 0;

      for (var item in report) {
        totalValue += (item['inventory_value'] as num?)?.toDouble() ?? 0;
        final stock = (item['current_stock'] as num?)?.toDouble() ?? 0;
        final reorderLevel = (item['reorder_level'] as num?)?.toDouble() ?? 0;
        if (stock <= reorderLevel) lowStockCount++;
      }

      _showInventoryReportDialog(
        context,
        report,
        totalProducts,
        totalValue,
        lowStockCount,
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading report: $e')),
      );
    }
  }

  // Product Performance Report
  Future<void> _showProductPerformanceReport(BuildContext context) async {
    final dateRange = await _showDateRangePicker(context, 'Product Performance Report');
    if (dateRange == null) return;

    if (!context.mounted) return;
    _showLoadingDialog(context);

    try {
      final topProducts = await _reportsService.getProductPerformance(
        dateRange.start,
        dateRange.end,
        limit: 10,
        topPerformers: true,
      );

      if (!context.mounted) return;
      Navigator.pop(context);

      // Store data for export
      setState(() {
        _currentProductPerformanceData = topProducts;
        _currentDateRange = dateRange;
        _isTopPerformers = true;
      });

      _showProductPerformanceDialog(context, topProducts, dateRange, true);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading report: $e')),
      );
    }
  }

  // Customer Report
  Future<void> _showCustomerReport(BuildContext context) async {
    _showLoadingDialog(context);

    try {
      final report = await _reportsService.getCustomerReport();

      if (!context.mounted) return;
      Navigator.pop(context);

      // Store data for export
      setState(() {
        _currentCustomerData = report;
      });

      _showCustomerReportDialog(context, report);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading report: $e')),
      );
    }
  }

  // Supplier Report
  Future<void> _showSupplierReport(BuildContext context) async {
    _showLoadingDialog(context);

    try {
      final report = await _reportsService.getSupplierReport();

      if (!context.mounted) return;
      Navigator.pop(context);

      // Store data for export
      setState(() {
        _currentSupplierData = report;
      });

      _showSupplierReportDialog(context, report);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading report: $e')),
      );
    }
  }

  // Profit & Loss Report
  Future<void> _showProfitLossReport(BuildContext context) async {
    final dateRange = await _showDateRangePicker(context, 'Profit & Loss Report');
    if (dateRange == null) return;

    if (!context.mounted) return;
    _showLoadingDialog(context);

    try {
      final report = await _reportsService.getProfitLossReport(
        dateRange.start,
        dateRange.end,
      );

      if (!context.mounted) return;
      Navigator.pop(context);

      // Store data for export
      setState(() {
        _currentProfitLossData = report;
        _currentDateRange = dateRange;
      });

      // Check if there is any revenue
      final totalRevenue = (report['total_revenue'] as num?)?.toDouble() ?? 0;

      if (totalRevenue == 0) {
        _showEmptyReportDialog(
          context,
          'Profit & Loss Report',
          Icons.account_balance_outlined,
          'No financial data',
          'No revenue or transactions found in the selected period.\nTry selecting a different date range or make some sales.',
          dateRange,
        );
        return;
      }

      final netProfit = (report['net_profit'] as num).toDouble();
      final isProfit = netProfit >= 0;

      _showReportDialog(
        context,
        'Profit & Loss Report',
        [
          _buildReportItem('Date Range',
              '${_formatDate(dateRange.start)} - ${_formatDate(dateRange.end)}'),
          _buildReportItem('Total Revenue',
              '$_currencySymbol${(report['total_revenue'] as num).toStringAsFixed(2)}'),
          _buildReportItem('Cost of Goods Sold',
              '$_currencySymbol${(report['total_cogs'] as num).toStringAsFixed(2)}'),
          _buildReportItem('Gross Profit',
              '$_currencySymbol${(report['gross_profit'] as num).toStringAsFixed(2)}'),
          _buildReportItem('Discounts Given',
              '$_currencySymbol${(report['total_discounts'] as num).toStringAsFixed(2)}'),
          _buildReportItem(
            'Net Profit',
            '$_currencySymbol${netProfit.toStringAsFixed(2)}',
            isHighlighted: true,
            color: isProfit ? Colors.green : Colors.red,
          ),
          _buildReportItem('Profit Margin',
              '${(report['profit_margin_percentage'] as num).toStringAsFixed(2)}%'),
        ],
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading report: $e')),
      );
    }
  }

  // Category Report
  Future<void> _showCategoryReport(BuildContext context) async {
    final dateRange = await _showDateRangePicker(context, 'Category Analysis Report');
    if (dateRange == null) return;

    if (!context.mounted) return;
    _showLoadingDialog(context);

    try {
      final report = await _reportsService.getCategoryWiseReport(
        dateRange.start,
        dateRange.end,
      );

      if (!context.mounted) return;
      Navigator.pop(context);

      // Store data for export
      setState(() {
        _currentCategoryData = report;
        _currentDateRange = dateRange;
      });

      _showCategoryReportDialog(context, report, dateRange);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading report: $e')),
      );
    }
  }

  // Helper: Date Range Picker
  Future<DateTimeRange?> _showDateRangePicker(BuildContext context, String title) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    DateTime? startDate = DateTime(now.year, now.month, 1);
    DateTime? endDate = now;

    return showDialog<DateTimeRange>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.date_range, color: Theme.of(context).primaryColor, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Date Range',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const Divider(height: 32),

                    // Quick Select Buttons
                    Text(
                      'Quick Select',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildQuickDateChip(context, 'Today', () {
                          setState(() {
                            startDate = DateTime(now.year, now.month, now.day);
                            endDate = now;
                          });
                        }),
                        _buildQuickDateChip(context, 'Yesterday', () {
                          final yesterday = now.subtract(const Duration(days: 1));
                          setState(() {
                            startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
                            endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59);
                          });
                        }),
                        _buildQuickDateChip(context, 'Last 7 Days', () {
                          setState(() {
                            startDate = now.subtract(const Duration(days: 7));
                            endDate = now;
                          });
                        }),
                        _buildQuickDateChip(context, 'Last 30 Days', () {
                          setState(() {
                            startDate = now.subtract(const Duration(days: 30));
                            endDate = now;
                          });
                        }),
                        _buildQuickDateChip(context, 'This Month', () {
                          setState(() {
                            startDate = DateTime(now.year, now.month, 1);
                            endDate = now;
                          });
                        }),
                        _buildQuickDateChip(context, 'Last Month', () {
                          final lastMonth = DateTime(now.year, now.month - 1, 1);
                          final lastDayOfLastMonth = DateTime(now.year, now.month, 0);
                          setState(() {
                            startDate = lastMonth;
                            endDate = DateTime(lastDayOfLastMonth.year, lastDayOfLastMonth.month, lastDayOfLastMonth.day, 23, 59);
                          });
                        }),
                        _buildQuickDateChip(context, 'This Year', () {
                          setState(() {
                            startDate = DateTime(now.year, 1, 1);
                            endDate = now;
                          });
                        }),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Custom Date Selection
                    Text(
                      'Custom Range',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateButton(
                            context,
                            'Start Date',
                            startDate,
                            () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate ?? now,
                                firstDate: DateTime(2020),
                                lastDate: endDate ?? now,
                              );
                              if (picked != null) {
                                setState(() => startDate = picked);
                              }
                            },
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.arrow_forward, color: Colors.grey),
                        ),
                        Expanded(
                          child: _buildDateButton(
                            context,
                            'End Date',
                            endDate,
                            () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate ?? now,
                                firstDate: startDate ?? DateTime(2020),
                                lastDate: now,
                              );
                              if (picked != null) {
                                setState(() => endDate = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (startDate != null && endDate != null) {
                              Navigator.of(context).pop(
                                DateTimeRange(start: startDate!, end: endDate!),
                              );
                            }
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Apply'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickDateChip(BuildContext context, String label, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey[100],
      labelStyle: TextStyle(
        fontSize: 13,
        color: isDark ? Colors.white : Colors.black,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildDateButton(BuildContext context, String label, DateTime? date, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isDark ? const Color(0xFF334155) : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date != null
                  ? '${date.day}/${date.month}/${date.year}'
                  : 'Select date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper: Loading Dialog
  void _showLoadingDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Generating Report',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait...',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper: Generic Report Dialog
  void _showReportDialog(BuildContext context, String title, List<Widget> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Container(
          width: 600,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.analytics, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Generated on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: items,
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper: Empty Report Dialog
  void _showEmptyReportDialog(
    BuildContext context,
    String title,
    IconData icon,
    String message,
    String subtitle,
    DateTimeRange? dateRange,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with background
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 64, color: Colors.orange),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                message,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Date range if provided
              if (dateRange != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatDate(dateRange.start)} - ${_formatDate(dateRange.end)}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Subtitle
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Close', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper: Inventory Report Dialog
  void _showInventoryReportDialog(
    BuildContext context,
    List<Map<String, dynamic>> items,
    int totalProducts,
    double totalValue,
    int lowStockCount,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          'Inventory Report',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: SizedBox(
          width: 800,
          height: 600,
          child: Column(
            children: [
              // Summary cards
              Row(
                children: [
                  Expanded(
                    child: Card(
                      color: isDark
                          ? Colors.blue.shade900.withValues(alpha: 0.3)
                          : Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              'Total Products',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              totalProducts.toString(),
                              style: TextStyle(
                                fontSize: 24,
                                color: isDark ? Colors.blue.shade200 : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Card(
                      color: isDark
                          ? Colors.green.shade900.withValues(alpha: 0.3)
                          : Colors.green[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              'Total Value',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$_currencySymbol${totalValue.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 24,
                                color: isDark ? Colors.green.shade200 : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Card(
                      color: isDark
                          ? Colors.orange.shade900.withValues(alpha: 0.3)
                          : Colors.orange[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              'Low Stock',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              lowStockCount.toString(),
                              style: TextStyle(
                                fontSize: 24,
                                color: isDark ? Colors.orange.shade200 : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Product list or empty state
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No products in inventory',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add products to see inventory details',
                              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Product')),
                            DataColumn(label: Text('Lots')),
                            DataColumn(label: Text('Stock')),
                            DataColumn(label: Text('Value')),
                          ],
                          rows: items.map((item) {
                            final stock = (item['current_stock'] as num?)?.toDouble() ?? 0;
                            final reorderLevel = (item['reorder_level'] as num?)?.toDouble() ?? 0;
                            final lotCount = (item['lot_count'] as int?) ?? 0;
                            final isLowStock = stock <= reorderLevel;

                            return DataRow(
                              color: isLowStock
                                  ? WidgetStateProperty.all(Colors.orange[50])
                                  : null,
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 200,
                                    child: Text(
                                      item['name'] ?? '',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(Text(lotCount.toString())),
                                DataCell(Text(stock.toStringAsFixed(1))),
                                DataCell(Text('$_currencySymbol${(item['inventory_value'] as num?)?.toStringAsFixed(2) ?? '0.00'}')),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Helper: Product Performance Dialog
  void _showProductPerformanceDialog(
    BuildContext context,
    List<Map<String, dynamic>> products,
    DateTimeRange dateRange,
    bool isTop,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${isTop ? 'Top' : 'Bottom'} Performing Products'),
        content: SizedBox(
          width: 700,
          height: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Period: ${_formatDate(dateRange.start)} - ${_formatDate(dateRange.end)}'),
              const SizedBox(height: 16),
              Expanded(
                child: products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.trending_up_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No sales data available',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Make some sales to see product performance',
                              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Product')),
                            DataColumn(label: Text('Qty Sold')),
                            DataColumn(label: Text('Revenue')),
                            DataColumn(label: Text('Avg Price')),
                          ],
                          rows: products.map((product) {
                            return DataRow(
                              cells: [
                                DataCell(Text(product['name'] ?? '')),
                                DataCell(Text(((product['total_quantity'] as num?)?.toDouble() ?? 0).toStringAsFixed(0))),
                                DataCell(Text('\$${(product['total_revenue'] as num?)?.toStringAsFixed(2) ?? '0.00'}')),
                                DataCell(Text('\$${(product['avg_selling_price'] as num?)?.toStringAsFixed(2) ?? '0.00'}')),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Helper: Customer Report Dialog
  void _showCustomerReportDialog(BuildContext context, List<Map<String, dynamic>> customers) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Customer Report'),
        content: SizedBox(
          width: 800,
          height: 600,
          child: customers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No customers found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add customers to see their reports',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Customer')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Sales')),
                      DataColumn(label: Text('Balance')),
                    ],
                    rows: customers.map((customer) {
                      return DataRow(
                        cells: [
                          DataCell(Text(customer['name'] ?? '')),
                          DataCell(Text(customer['email'] ?? '')),
                          DataCell(Text('\$${(customer['total_sales'] as num?)?.toStringAsFixed(2) ?? '0.00'}')),
                          DataCell(Text('\$${(customer['current_balance'] as num?)?.toStringAsFixed(2) ?? '0.00'}')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Helper: Supplier Report Dialog
  void _showSupplierReportDialog(BuildContext context, List<Map<String, dynamic>> suppliers) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supplier Report'),
        content: SizedBox(
          width: 800,
          height: 600,
          child: suppliers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No suppliers found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add suppliers to see their reports',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Supplier')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Purchases')),
                      DataColumn(label: Text('Amount')),
                    ],
                    rows: suppliers.map((supplier) {
                      return DataRow(
                        cells: [
                          DataCell(Text(supplier['name'] ?? '')),
                          DataCell(Text(supplier['email'] ?? '')),
                          DataCell(Text((supplier['total_purchases'] as int?)?.toString() ?? '0')),
                          DataCell(Text('\$${(supplier['total_amount_purchased'] as num?)?.toStringAsFixed(2) ?? '0.00'}')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Helper: Category Report Dialog
  void _showCategoryReportDialog(
    BuildContext context,
    List<Map<String, dynamic>> categories,
    DateTimeRange dateRange,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Category Analysis Report'),
        content: SizedBox(
          width: 600,
          height: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Period: ${_formatDate(dateRange.start)} - ${_formatDate(dateRange.end)}'),
              const SizedBox(height: 16),
              Expanded(
                child: categories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.category_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No category data available',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Make sales in the selected period to see category analysis',
                              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Category')),
                            DataColumn(label: Text('Transactions')),
                            DataColumn(label: Text('Quantity')),
                            DataColumn(label: Text('Amount')),
                          ],
                          rows: categories.map((category) {
                            return DataRow(
                              cells: [
                                DataCell(Text(category['category']?.toString() ?? 'Uncategorized')),
                                DataCell(Text((category['transaction_count'] as int?)?.toString() ?? '0')),
                                DataCell(Text(((category['total_quantity'] as num?)?.toDouble() ?? 0).toStringAsFixed(0))),
                                DataCell(Text('\$${(category['total_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}')),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Helper: Build Report Item
  Widget _buildReportItem(String label, String value, {bool isHighlighted = false, Color? color}) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isHighlighted
                ? (isDark ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.08))
                : (isDark ? const Color(0xFF334155) : Colors.grey.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHighlighted
                  ? (isDark ? Colors.blue.shade700 : Colors.blue.withValues(alpha: 0.3))
                  : (isDark ? Colors.grey[700]! : Colors.grey.withValues(alpha: 0.1)),
              width: isHighlighted ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (isHighlighted)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.blue.shade800.withValues(alpha: 0.3)
                              : Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.star,
                          size: 16,
                          color: isDark ? Colors.blue.shade300 : Colors.blue,
                        ),
                      ),
                    if (isHighlighted) const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                          fontSize: isHighlighted ? 15 : 14,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isHighlighted ? 16 : 12,
                  vertical: isHighlighted ? 8 : 6,
                ),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? (isDark ? Colors.blue.shade700 : Colors.blue)
                      : (isDark ? const Color(0xFF475569) : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
                    fontSize: isHighlighted ? 16 : 14,
                    color: isHighlighted
                        ? Colors.white
                        : (color ?? (isDark ? Colors.white : Colors.grey[800])),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper: Export to PDF
  Future<void> _exportToPDF(String reportName) async {
    try {
      File? file;

      if (reportName == 'Sales Summary' && _currentSalesData != null && _currentDateRange != null) {
        file = await _pdfService.generateSalesReportPdf(
          data: _currentSalesData!,
          startDate: _currentDateRange!.start,
          endDate: _currentDateRange!.end,
        );
      } else if (reportName == 'Purchase Summary' && _currentPurchaseData != null && _currentDateRange != null) {
        file = await _pdfService.generateSalesReportPdf(
          data: _currentPurchaseData!,
          startDate: _currentDateRange!.start,
          endDate: _currentDateRange!.end,
        );
      } else if (reportName == 'Inventory Report' && _currentInventoryData != null) {
        file = await _pdfService.generateInventoryReportPdf(_currentInventoryData!);
      } else if (reportName == 'Profit & Loss' && _currentProfitLossData != null && _currentDateRange != null) {
        file = await _pdfService.generateProfitLossReportPdf(
          data: _currentProfitLossData!,
          startDate: _currentDateRange!.start,
          endDate: _currentDateRange!.end,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please view the report first before exporting'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF exported successfully to:\n${file.path}'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper: Export to Excel
  Future<void> _exportToExcel(String reportName) async {
    try {
      File? file;

      if (reportName == 'Sales Summary' && _currentSalesData != null && _currentDateRange != null) {
        file = await _excelService.exportSalesReport(
          data: _currentSalesData!,
          startDate: _currentDateRange!.start,
          endDate: _currentDateRange!.end,
        );
      } else if (reportName == 'Purchase Summary' && _currentPurchaseData != null && _currentDateRange != null) {
        file = await _excelService.exportPurchasesReport(
          data: _currentPurchaseData!,
          startDate: _currentDateRange!.start,
          endDate: _currentDateRange!.end,
        );
      } else if (reportName == 'Inventory Report' && _currentInventoryData != null) {
        file = await _excelService.exportInventoryReport(_currentInventoryData!);
      } else if (reportName == 'Product Performance' && _currentProductPerformanceData != null && _currentDateRange != null) {
        file = await _excelService.exportProductPerformanceReport(
          data: _currentProductPerformanceData!,
          startDate: _currentDateRange!.start,
          endDate: _currentDateRange!.end,
          topPerformers: _isTopPerformers,
        );
      } else if (reportName == 'Customer Report' && _currentCustomerData != null) {
        file = await _excelService.exportCustomerReport(_currentCustomerData!);
      } else if (reportName == 'Supplier Report' && _currentSupplierData != null) {
        file = await _excelService.exportSupplierReport(_currentSupplierData!);
      } else if (reportName == 'Profit & Loss' && _currentProfitLossData != null && _currentDateRange != null) {
        file = await _excelService.exportProfitLossReport(
          data: _currentProfitLossData!,
          startDate: _currentDateRange!.start,
          endDate: _currentDateRange!.end,
        );
      } else if (reportName == 'Category Analysis' && _currentCategoryData != null && _currentDateRange != null) {
        file = await _excelService.exportCategoryReport(
          data: _currentCategoryData!,
          startDate: _currentDateRange!.start,
          endDate: _currentDateRange!.end,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please view the report first before exporting'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel exported successfully to:\n${file.path}'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting Excel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper: Format Date
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
