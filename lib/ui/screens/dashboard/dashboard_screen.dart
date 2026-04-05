import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/auth_provider.dart';
import '../supplier/suppliers_screen.dart';
import '../customer/customers_screen.dart';
import '../product/products_screen.dart';
import '../transaction/transactions_screen.dart';
import '../user/users_screen.dart';
import '../settings/settings_screen.dart';
import '../reports/reports_screen.dart';
import '../pos/pos_screen.dart';
import '../held_bills/held_bills_screen.dart';
import '../transaction/purchase_order_screen.dart';
import '../expense/expense_screen.dart';
import '../../../services/product/product_service.dart';
import '../../../services/transaction/transaction_service.dart';
import '../../../services/currency/currency_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final ProductService _productService = ProductService();
  final TransactionService _transactionService = TransactionService();
  final CurrencyService _currencyService = CurrencyService();

  // KPI Data
  Map<String, dynamic>? _todaysSales;
  Map<String, dynamic>? _todaysPurchases;
  int _lowStockCount = 0;
  int _totalProducts = 0;
  bool _isLoadingKPIs = true;  // Start with true to show loading on initial load
  String _currencySymbol = '৳';

  // Navigation params — set by KPI card taps, reset by NavRail
  int _transactionsInitialTab = 0;
  String? _transactionsDateFilter;
  bool _productsLowStockOnly = false;

  // Auto-refresh timer
  Timer? _refreshTimer;
  List<Map<String, dynamic>> _recentTransactions = [];
  List<FlSpot> _salesChartData = [];

  final List<String> _menuTitles = [
    'Dashboard',
    'Products',
    'Suppliers',
    'Customers',
    'Transactions',
    'Held Bills',
    'Reports',
    'Users',
    'Settings',
    'Expenses',
  ];

  final List<IconData> _menuIcons = [
    Icons.dashboard,
    Icons.inventory,
    Icons.local_shipping,
    Icons.people,
    Icons.receipt_long,
    Icons.pause_circle_outline,
    Icons.analytics,
    Icons.group,
    Icons.settings,
    Icons.money_off_csred,
  ];

  // Get menu items based on user permissions
  List<int> _getAllowedMenuIndices(AuthProvider authProvider) {
    final user = authProvider.currentUser;
    if (user == null) return [0]; // Only Dashboard

    List<int> allowed = [0]; // Dashboard always visible

    if (user.hasPermission('view_products')) allowed.add(1); // Products
    if (user.hasPermission('view_suppliers')) allowed.add(2); // Suppliers
    if (user.hasPermission('view_customers')) allowed.add(3); // Customers
    if (user.hasPermission('view_transactions')) allowed.add(4); // Transactions
    if (user.hasPermission('view_transactions')) allowed.add(5); // Held Bills
    if (user.hasPermission('view_reports')) allowed.add(6); // Reports
    if (user.isAdmin) allowed.add(7); // Users (admin only)
    if (user.isAdmin) allowed.add(8); // Settings (admin only)
    if (user.hasPermission('view_reports')) allowed.add(9); // Expenses

    return allowed;
  }

  @override
  void initState() {
    super.initState();
    _loadCurrencySymbol();
    // Set up auto-refresh every 30 seconds when on dashboard
    _startAutoRefresh();

    // Defer data loading until after first frame to avoid blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadDashboardData();
      }
    });
  }

  Future<void> _loadCurrencySymbol() async {
    try {
      final symbol = await _currencyService.getCurrencySymbol();
      if (mounted) {
        setState(() {
          _currencySymbol = symbol;
        });
      }
    } catch (e) {
      // Use default Taka symbol if error
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    // Reduced frequency: refresh every 2 minutes instead of 30 seconds
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (_selectedIndex == 0 && mounted) {
        _loadDashboardData();
      }
    });
  }

  Future<void> _loadDashboardData() async {
    // Only load if we're on the dashboard screen
    if (_selectedIndex != 0 || !mounted) return;

    if (mounted) setState(() => _isLoadingKPIs = true);
    try {
      final sales = await _transactionService.getTodaysSales();
      final purchases = await _transactionService.getTodaysPurchases();
      final lowStock = await _productService.getLowStockProducts();
      final productCount = await _productService.getProductCount();
      final recentTransactions = await _transactionService.getTransactions(
        sortBy: 'created_at',
        sortOrder: 'DESC',
      );

      // PERFORMANCE: Chart disabled, skip chart data loading
      final salesChartData = await _getLast7DaysSales();

      if (mounted) {
        setState(() {
          _todaysSales = sales;
          _todaysPurchases = purchases;
          _lowStockCount = lowStock.length;
          _totalProducts = productCount;
          _recentTransactions = recentTransactions.take(5).toList();
          _salesChartData = salesChartData;
          _isLoadingKPIs = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingKPIs = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e')),
        );
      }
    }
  }

  Future<List<FlSpot>> _getLast7DaysSales() async {
    final List<FlSpot> spots = [];
    final now = DateTime.now();

    // OPTIMIZED: Fetch all transactions from the last 7 days in ONE query
    final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final endDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

    final allTransactions = await _transactionService.getTransactions(
      type: 'SELL',
      startDate: startDate,
      endDate: endDate,
    );

    // Group transactions by day
    final Map<int, double> dailyTotals = {};
    for (int i = 0; i <= 6; i++) {
      dailyTotals[i] = 0;
    }

    final today = DateTime(now.year, now.month, now.day);

    for (var transaction in allTransactions) {
      // Use transaction_date (the actual sale date), not created_at (DB insert time)
      final raw = DateTime.parse(transaction['transaction_date'] as String);
      // Strip time so day-diff is always an exact integer
      final txDay = DateTime(raw.year, raw.month, raw.day);
      final daysDiff = today.difference(txDay).inDays;

      if (daysDiff >= 0 && daysDiff <= 6) {
        final index = 6 - daysDiff;
        dailyTotals[index] = (dailyTotals[index] ?? 0) + (transaction['total_amount'] as num).toDouble();
      }
    }

    // Convert to chart data points
    for (int i = 0; i <= 6; i++) {
      spots.add(FlSpot(i.toDouble(), dailyTotals[i] ?? 0));
    }

    return spots;
  }

  @override
  Widget build(BuildContext context) {
    // PERFORMANCE: Use listen: false to prevent rebuilding on every auth change
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    return Scaffold(
      body: Row(
        children: [
          // Left sidebar navigation
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: IntrinsicHeight(
                child: Builder(
                  builder: (context) {
                    // Use the authProvider from the parent context instead of creating a new one
                    final allowedIndices = _getAllowedMenuIndices(authProvider);

                    // Map selected index to allowed indices
                    int displayIndex = allowedIndices.indexOf(_selectedIndex);
                    if (displayIndex == -1) displayIndex = 0;

                    return NavigationRail(
                      selectedIndex: displayIndex,
                      onDestinationSelected: (displayIndex) {
                        final newIndex = allowedIndices[displayIndex];
                        setState(() {
                          _selectedIndex = newIndex;
                          // Reset nav params when switching manually via rail
                          _transactionsInitialTab = 0;
                          _transactionsDateFilter = null;
                          _productsLowStockOnly = false;
                        });
                        // Reload dashboard data when switching to dashboard
                        if (newIndex == 0) {
                          _loadDashboardData();
                        }
                      },
                      labelType: NavigationRailLabelType.all,
                      leading: Column(
                        children: [
                          const SizedBox(height: 8),
                          const Icon(Icons.inventory_2, size: 48, color: Colors.blue),
                          const SizedBox(height: 8),
                          const Text(
                            'Inventory',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                      trailing: Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  child: Text(
                                    user?.name.substring(0, 1).toUpperCase() ?? 'U',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  user?.name ?? 'User',
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  user?.role ?? '',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                IconButton(
                                  icon: const Icon(Icons.logout),
                                  tooltip: 'Logout',
                                  onPressed: () {
                                    _handleLogout(context);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      destinations: allowedIndices.map((index) => NavigationRailDestination(
                        icon: Icon(_menuIcons[index]),
                        label: Text(_menuTitles[index]),
                      )).toList(),
                    );
                  },
                ),
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main content area
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // PERFORMANCE: Only build the selected screen, nothing else
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardView();
      case 1:
        return ProductsScreen(showLowStockOnly: _productsLowStockOnly);
      case 2:
        return const SuppliersScreen();
      case 3:
        return const CustomersScreen();
      case 4:
        return TransactionsScreen(
          initialTabIndex: _transactionsInitialTab,
          initialDateFilter: _transactionsDateFilter,
        );
      case 5:
        return const HeldBillsScreen();
      case 6:
        return const ReportsScreen();
      case 7:
        return const UsersScreen();
      case 8:
        return const SettingsScreen();
      case 9:
        return const ExpenseScreen();
      default:
        return _buildDashboardView();
    }
  }

  Widget _buildDashboardView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              final canCreatePurchase = authProvider.currentUser?.hasPermission('create_purchase') ?? false;
              return Tooltip(
                message: canCreatePurchase ? '' : 'Admin access only',
                child: ElevatedButton.icon(
                  onPressed: canCreatePurchase
                      ? () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const PurchaseOrderScreen()))
                      : null,
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: const Text('New Purchase'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canCreatePurchase ? Colors.blue.shade600 : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              final canCreateSale = authProvider.currentUser?.hasPermission('create_sale') ?? false;

              return Tooltip(
                message: canCreateSale ? '' : 'Admin access only',
                child: ElevatedButton.icon(
                  onPressed: canCreateSale
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const POSScreen()),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text('New Sale'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canCreateSale ? Colors.green : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          if (_isLoadingKPIs)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadDashboardData,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // KPI Cards
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                // ── Today's Sales ───────────────────────────────
                _buildKPICard(
                  'Today\'s Sales',
                  _todaysSales != null
                      ? '$_currencySymbol${(_todaysSales!['total_sales'] as num).toStringAsFixed(2)}'
                      : '...',
                  Icons.point_of_sale,
                  Colors.green,
                  subtitle: _todaysSales != null
                      ? '${_todaysSales!['transaction_count']} transactions'
                      : null,
                  subMetrics: _todaysSales == null ? null : [
                    (
                      label: 'Cash Collected',
                      value: '$_currencySymbol${(_todaysSales!['cash_collected'] as num).toStringAsFixed(2)}',
                      color: Colors.green.shade700,
                    ),
                    if (((_todaysSales!['cash_refunded_today'] ?? 0) as num) > 0)
                      (
                        label: 'Cash Refunded',
                        value: '-$_currencySymbol${((_todaysSales!['cash_refunded_today'] ?? 0) as num).toStringAsFixed(2)}',
                        color: Colors.red.shade600,
                      ),
                    (
                      label: 'Credit (Due)',
                      value: '$_currencySymbol${(_todaysSales!['credit_sales'] as num).toStringAsFixed(2)}',
                      color: Colors.orange.shade700,
                    ),
                    if ((_todaysSales!['credit_cleared_today'] as num) > 0)
                      (
                        label: 'Due Cleared',
                        value: '$_currencySymbol${(_todaysSales!['credit_cleared_today'] as num).toStringAsFixed(2)}',
                        color: Colors.teal.shade700,
                      ),
                  ],
                  onTap: () => setState(() {
                    _transactionsInitialTab = 1;
                    _transactionsDateFilter = 'today';
                    _selectedIndex = 4;
                  }),
                ),

                // ── Today's Purchases ────────────────────────────
                _buildKPICard(
                  'Today\'s Purchases',
                  _todaysPurchases != null
                      ? '$_currencySymbol${(_todaysPurchases!['total_purchases'] as num).toStringAsFixed(2)}'
                      : '...',
                  Icons.shopping_cart,
                  Colors.blue,
                  subtitle: _todaysPurchases != null
                      ? '${_todaysPurchases!['transaction_count']} orders'
                      : null,
                  subMetrics: _todaysPurchases == null ? null : [
                    (
                      label: 'Cash Paid',
                      value: '$_currencySymbol${(_todaysPurchases!['cash_purchases'] as num).toStringAsFixed(2)}',
                      color: Colors.blue.shade700,
                    ),
                    (
                      label: 'Credit (Due)',
                      value: '$_currencySymbol${(_todaysPurchases!['credit_purchases'] as num).toStringAsFixed(2)}',
                      color: Colors.orange.shade700,
                    ),
                    if ((_todaysPurchases!['supplier_cleared_today'] as num) > 0)
                      (
                        label: 'Supplier Paid',
                        value: '$_currencySymbol${(_todaysPurchases!['supplier_cleared_today'] as num).toStringAsFixed(2)}',
                        color: Colors.teal.shade700,
                      ),
                  ],
                  onTap: () => setState(() {
                    _transactionsInitialTab = 0;
                    _transactionsDateFilter = 'today';
                    _selectedIndex = 4;
                  }),
                ),

                // ── Low Stock ────────────────────────────────────
                _buildKPICard(
                  'Low Stock Items',
                  _lowStockCount.toString(),
                  Icons.warning_amber,
                  Colors.orange,
                  subtitle: 'Needs reorder',
                  onTap: () => setState(() {
                    _productsLowStockOnly = true;
                    _selectedIndex = 1;
                  }),
                ),

                // ── Total Products ───────────────────────────────
                _buildKPICard(
                  'Total Products',
                  _totalProducts.toString(),
                  Icons.inventory_2,
                  Colors.purple,
                  subtitle: 'In catalog',
                  onTap: () => setState(() {
                    _productsLowStockOnly = false;
                    _selectedIndex = 1;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Transactions',
                    Icons.receipt_long,
                    Colors.blue,
                    () {
                      setState(() => _selectedIndex = 4);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    'Products',
                    Icons.inventory_2,
                    Colors.purple,
                    () {
                      setState(() => _selectedIndex = 1);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    'Reports',
                    Icons.analytics,
                    Colors.orange,
                    () {
                      setState(() => _selectedIndex = 6);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sales Chart
                Expanded(
                  flex: 2,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Sales Trend (Last 7 Days)',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Row(children: [
                                  Icon(Icons.bar_chart, size: 13, color: Colors.blue.shade600),
                                  const SizedBox(width: 4),
                                  Text('Daily', style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 200,
                            child: _salesChartData.isEmpty
                                ? const Center(
                                    child: Text('No sales data available',
                                        style: TextStyle(color: Colors.grey)),
                                  )
                                : BarChart(
                                    BarChartData(
                                      alignment: BarChartAlignment.spaceAround,
                                      maxY: () {
                                        final maxVal = _salesChartData.map((e) => e.y).reduce((a, b) => a > b ? a : b);
                                        return maxVal <= 0 ? 100.0 : maxVal * 1.3;
                                      }(),
                                      barTouchData: BarTouchData(
                                        enabled: true,
                                        touchTooltipData: BarTouchTooltipData(
                                          getTooltipColor: (_) => Colors.blueGrey.shade800,
                                          tooltipRoundedRadius: 8,
                                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                            final now = DateTime.now();
                                            final date = now.subtract(Duration(days: 6 - group.x));
                                            return BarTooltipItem(
                                              '${date.day}/${date.month}\n',
                                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                              children: [
                                                TextSpan(
                                                  text: '$_currencySymbol${rod.toY.toStringAsFixed(0)}',
                                                  style: TextStyle(color: Colors.blue.shade200, fontSize: 12),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                      titlesData: FlTitlesData(
                                        show: true,
                                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 28,
                                            getTitlesWidget: (value, meta) {
                                              final now = DateTime.now();
                                              final date = now.subtract(Duration(days: 6 - value.toInt()));
                                              final isToday = value.toInt() == 6;
                                              return SideTitleWidget(
                                                axisSide: meta.axisSide,
                                                space: 6,
                                                child: Text(
                                                  '${date.day}/${date.month}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                                    color: isToday ? Colors.blue.shade700 : Colors.grey,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 46,
                                            getTitlesWidget: (value, meta) {
                                              if (value == 0) return const Text('');
                                              final label = value >= 1000
                                                  ? '${(value / 1000).toStringAsFixed(1)}k'
                                                  : value.toInt().toString();
                                              return Text(label,
                                                  style: const TextStyle(fontSize: 9, color: Colors.grey));
                                            },
                                          ),
                                        ),
                                      ),
                                      gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: false,
                                        getDrawingHorizontalLine: (_) =>
                                            FlLine(color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      barGroups: _salesChartData.map((spot) {
                                        final isToday = spot.x.toInt() == 6;
                                        final hasData = spot.y > 0;
                                        return BarChartGroupData(
                                          x: spot.x.toInt(),
                                          barRods: [
                                            BarChartRodData(
                                              toY: spot.y,
                                              width: 22,
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                              color: hasData
                                                  ? (isToday ? Colors.blue.shade600 : Colors.blue.shade300)
                                                  : Colors.grey.shade200,
                                              backDrawRodData: BackgroundBarChartRodData(
                                                show: true,
                                                toY: _salesChartData.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.3,
                                                color: Colors.grey.withValues(alpha: 0.06),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Recent Transactions
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recent Transactions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: _recentTransactions.isEmpty
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                                        SizedBox(height: 8),
                                        Text(
                                          'No transactions yet',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _recentTransactions.length,
                                    separatorBuilder: (context, index) => const Divider(),
                                    itemBuilder: (context, index) {
                                      final transaction = _recentTransactions[index];
                                      final type = transaction['transaction_type'] as String;
                                      final invoiceNumber = transaction['invoice_number'] as String;
                                      final total = (transaction['total_amount'] as num).toDouble();

                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: type == 'SELL' ? Colors.green : Colors.blue,
                                          child: Icon(
                                            type == 'SELL' ? Icons.arrow_upward : Icons.arrow_downward,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                        title: Text(
                                          invoiceNumber,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        subtitle: Text(
                                          transaction['party_name'] ?? 'N/A',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        trailing: Text(
                                          '$_currencySymbol${total.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: type == 'SELL' ? Colors.green : Colors.blue,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
    VoidCallback? onTap,
    List<({String label, String value, Color color})>? subMetrics,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: _buildKPICardContent(
          title, value, icon, color,
          isDark: isDark,
          subtitle: subtitle,
          subMetrics: subMetrics,
          hasOnTap: onTap != null,
        ),
      ),
    );
  }

  Widget _buildKPICardContent(
    String title,
    String value,
    IconData icon,
    Color color, {
    required bool isDark,
    String? subtitle,
    List<({String label, String value, Color color})>? subMetrics,
    bool hasOnTap = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
            ? [const Color(0xFF1E293B), color.withValues(alpha: 0.15)]
            : [Colors.white, color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
            ? color.withValues(alpha: 0.3)
            : color.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.8), color],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up, color: Colors.green, size: 10),
                      const SizedBox(width: 2),
                      Text(
                        'Live',
                        style: TextStyle(
                          color: isDark ? Colors.green[400] : Colors.green[700],
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
                ],
                // Sub-metrics (Cash / Credit breakdown)
                if (subMetrics != null && subMetrics.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 4),
                  ...subMetrics.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          m.label,
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        Text(
                          m.value,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: m.color,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
                // Tap hint
                if (hasOnTap) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'View details',
                        style: TextStyle(
                          fontSize: 9,
                          color: color.withValues(alpha: 0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_ios, size: 9, color: color.withValues(alpha: 0.7)),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
