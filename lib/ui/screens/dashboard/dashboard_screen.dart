import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../supplier/suppliers_screen.dart';
import '../customer/customers_screen.dart';
import '../product/products_screen.dart';
import '../transaction/transactions_screen.dart';
import '../user/users_screen.dart';
import '../settings/settings_screen.dart';
import '../held_bills/held_bills_screen.dart';
import '../reports/reports_screen.dart';
import '../pos/pos_screen.dart';
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
    if (user.hasPermission('create_sale')) allowed.add(5); // Held Bills (for cashiers)
    if (user.hasPermission('view_reports')) allowed.add(6); // Reports
    if (user.isAdmin) allowed.add(7); // Users (admin only)
    if (user.isAdmin) allowed.add(8); // Settings (admin only)

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
      // final salesChartData = await _getLast7DaysSales();

      if (mounted) {
        setState(() {
          _todaysSales = sales;
          _todaysPurchases = purchases;
          _lowStockCount = lowStock.length;
          _totalProducts = productCount;
          _recentTransactions = recentTransactions.take(5).toList();
          // _salesChartData = salesChartData; // Chart disabled
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

    for (var transaction in allTransactions) {
      final transactionDate = DateTime.parse(transaction['created_at'] as String);
      final daysDiff = now.difference(transactionDate).inDays;

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
        return const ProductsScreen();
      case 2:
        return const SuppliersScreen();
      case 3:
        return const CustomersScreen();
      case 4:
        return const TransactionsScreen();
      case 5:
        return const HeldBillsScreen();
      case 6:
        return const ReportsScreen();
      case 7:
        return const UsersScreen();
      case 8:
        return const SettingsScreen();
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
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildKPICard(
                  'Today\'s Sales',
                  _todaysSales != null
                      ? '$_currencySymbol${(_todaysSales!['total_sales'] as num).toStringAsFixed(2)}'
                      : '...',
                  Icons.shopping_cart,
                  Colors.green,
                  subtitle: _todaysSales != null
                      ? '${_todaysSales!['transaction_count']} transactions'
                      : null,
                ),
                _buildKPICard(
                  'Today\'s Purchases',
                  _todaysPurchases != null
                      ? '$_currencySymbol${(_todaysPurchases!['total_purchases'] as num).toStringAsFixed(2)}'
                      : '...',
                  Icons.add_shopping_cart,
                  Colors.blue,
                  subtitle: _todaysPurchases != null
                      ? '${_todaysPurchases!['transaction_count']} orders'
                      : null,
                ),
                _buildKPICard(
                  'Low Stock Items',
                  _lowStockCount.toString(),
                  Icons.warning_amber,
                  Colors.orange,
                  subtitle: 'Needs reorder',
                ),
                _buildKPICard(
                  'Total Products',
                  _totalProducts.toString(),
                  Icons.inventory_2,
                  Colors.purple,
                  subtitle: 'In catalog',
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
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildActionButton(
                  'New Sale',
                  Icons.point_of_sale,
                  Colors.green,
                  () {
                    setState(() => _selectedIndex = 4);
                  },
                ),
                _buildActionButton(
                  'New Purchase',
                  Icons.add_shopping_cart,
                  Colors.blue,
                  () {
                    setState(() => _selectedIndex = 4);
                  },
                ),
                _buildActionButton(
                  'Add Product',
                  Icons.add_box,
                  Colors.purple,
                  () {
                    setState(() => _selectedIndex = 1);
                  },
                ),
                _buildActionButton(
                  'View Reports',
                  Icons.analytics,
                  Colors.orange,
                  () {
                    setState(() => _selectedIndex = 6);
                  },
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
                          const Text(
                            'Sales Trend (Last 7 Days)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // PERFORMANCE: Chart disabled - fl_chart causes severe lag
                          const SizedBox(
                            height: 200,
                            child: Center(
                              child: Text(
                                'Sales chart temporarily disabled for performance',
                                style: TextStyle(color: Colors.grey),
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

  Widget _buildKPICard(String title, String value, IconData icon, Color color, {String? subtitle}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 32),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.trending_up, color: color, size: 16),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
