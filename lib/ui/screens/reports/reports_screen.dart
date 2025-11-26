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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Business Reports',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate and export comprehensive business reports',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            _buildReportsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 24,
      mainAxisSpacing: 24,
      childAspectRatio: 1.2,
      children: [
        _buildReportCard(
          title: 'Transaction Details',
          description: 'Detailed transaction reports with date range and hourly analysis',
          icon: Icons.receipt_long,
          color: Colors.cyan,
          onView: () => _navigateToTransactionDetails(context),
          onExportPDF: null, // Export handled in detail screen
          onExportExcel: null, // Export handled in detail screen
        ),
        _buildReportCard(
          title: 'Sales Summary',
          description: 'View sales performance, revenue, and transaction details',
          icon: Icons.trending_up,
          color: Colors.green,
          onView: () => _showSalesReport(context),
          onExportPDF: () => _exportToPDF('Sales Summary'),
          onExportExcel: () => _exportToExcel('Sales Summary'),
        ),
        _buildReportCard(
          title: 'Purchase Summary',
          description: 'Track purchases, suppliers, and procurement costs',
          icon: Icons.shopping_cart,
          color: Colors.blue,
          onView: () => _showPurchaseReport(context),
          onExportPDF: () => _exportToPDF('Purchase Summary'),
          onExportExcel: () => _exportToExcel('Purchase Summary'),
        ),
        _buildReportCard(
          title: 'Inventory Report',
          description: 'Current stock levels, valuations, and batch details',
          icon: Icons.inventory_2,
          color: Colors.orange,
          onView: () => _showInventoryReport(context),
          onExportPDF: () => _exportToPDF('Inventory Report'),
          onExportExcel: () => _exportToExcel('Inventory Report'),
        ),
        _buildReportCard(
          title: 'Product Performance',
          description: 'Top selling products and sales trends',
          icon: Icons.star,
          color: Colors.amber,
          onView: () => _showProductPerformanceReport(context),
          onExportPDF: () => _exportToPDF('Product Performance'),
          onExportExcel: () => _exportToExcel('Product Performance'),
        ),
        _buildReportCard(
          title: 'Customer Report',
          description: 'Customer balances, credit limits, and purchase history',
          icon: Icons.people,
          color: Colors.purple,
          onView: () => _showCustomerReport(context),
          onExportPDF: () => _exportToPDF('Customer Report'),
          onExportExcel: () => _exportToExcel('Customer Report'),
        ),
        _buildReportCard(
          title: 'Supplier Report',
          description: 'Supplier statistics and purchase analysis',
          icon: Icons.local_shipping,
          color: Colors.teal,
          onView: () => _showSupplierReport(context),
          onExportPDF: () => _exportToPDF('Supplier Report'),
          onExportExcel: () => _exportToExcel('Supplier Report'),
        ),
        _buildReportCard(
          title: 'Profit & Loss',
          description: 'Revenue, expenses, and profitability analysis',
          icon: Icons.account_balance,
          color: Colors.indigo,
          onView: () => _showProfitLossReport(context),
          onExportPDF: () => _exportToPDF('Profit & Loss'),
          onExportExcel: () => _exportToExcel('Profit & Loss'),
        ),
        _buildReportCard(
          title: 'Category Analysis',
          description: 'Sales performance by product category',
          icon: Icons.category,
          color: Colors.pink,
          onView: () => _showCategoryReport(context),
          onExportPDF: () => _exportToPDF('Category Analysis'),
          onExportExcel: () => _exportToExcel('Category Analysis'),
        ),
      ],
    );
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon and title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Description
            Expanded(
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            // Action buttons
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onView,
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (onExportPDF != null || onExportExcel != null)
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      final canExport = authProvider.currentUser?.hasPermission('export_reports') ?? false;

                      return Row(
                        children: [
                          if (onExportPDF != null)
                            Expanded(
                              child: Tooltip(
                                message: canExport ? '' : 'Admin access only',
                                child: OutlinedButton.icon(
                                  onPressed: canExport ? onExportPDF : null,
                                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                                  label: const Text('PDF'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (onExportPDF != null && onExportExcel != null)
                            const SizedBox(width: 8),
                          if (onExportExcel != null)
                            Expanded(
                              child: Tooltip(
                                message: canExport ? '' : 'Admin access only',
                                child: OutlinedButton.icon(
                                  onPressed: canExport ? onExportExcel : null,
                                  icon: const Icon(Icons.table_chart, size: 16),
                                  label: const Text('Excel'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
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

      if (!context.mounted) return;
      Navigator.pop(context);

      // Store data for export
      setState(() {
        _currentInventoryData = report;
      });

      // Calculate totals
      double totalValue = 0;
      int totalProducts = report.length;
      int lowStockCount = 0;

      for (var item in report) {
        totalValue += (item['inventory_value'] as num?)?.toDouble() ?? 0;
        final stock = (item['current_stock'] as num?)?.toDouble() ?? 0;
        final reorderLevel = (item['reorder_level'] as int?) ?? 0;
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
    final now = DateTime.now();
    final firstDate = DateTime(2020);
    final lastDate = now;

    return showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      ),
      builder: (context, child) {
        return child!;
      },
    );
  }

  // Helper: Loading Dialog
  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading report...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper: Generic Report Dialog
  void _showReportDialog(BuildContext context, String title, List<Widget> items) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: items,
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

  // Helper: Inventory Report Dialog
  void _showInventoryReportDialog(
    BuildContext context,
    List<Map<String, dynamic>> items,
    int totalProducts,
    double totalValue,
    int lowStockCount,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inventory Report'),
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
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text('Total Products',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(totalProducts.toString(),
                                style: const TextStyle(fontSize: 24)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Card(
                      color: Colors.green[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text('Total Value',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('$_currencySymbol${totalValue.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 24)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Card(
                      color: Colors.orange[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text('Low Stock',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(lowStockCount.toString(),
                                style: const TextStyle(fontSize: 24)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Product list
              Expanded(
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('SKU')),
                      DataColumn(label: Text('Stock')),
                      DataColumn(label: Text('Value')),
                    ],
                    rows: items.map((item) {
                      final stock = (item['current_stock'] as num?)?.toDouble() ?? 0;
                      final reorderLevel = (item['reorder_level'] as int?) ?? 0;
                      final isLowStock = stock <= reorderLevel;

                      return DataRow(
                        color: isLowStock
                            ? WidgetStateProperty.all(Colors.orange[50])
                            : null,
                        cells: [
                          DataCell(Text(item['name'] ?? '')),
                          DataCell(Text(item['sku'] ?? '')),
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
                child: SingleChildScrollView(
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
          child: SingleChildScrollView(
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
          child: SingleChildScrollView(
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
                child: SingleChildScrollView(
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              fontSize: isHighlighted ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              fontSize: isHighlighted ? 18 : 14,
              color: color,
            ),
          ),
        ],
      ),
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
