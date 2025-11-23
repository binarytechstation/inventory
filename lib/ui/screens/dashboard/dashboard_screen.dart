import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../supplier/suppliers_screen.dart';
import '../customer/customers_screen.dart';
import '../product/products_screen.dart';
import '../transaction/transactions_screen.dart';
import '../user/users_screen.dart';
import '../settings/settings_screen.dart';
import '../held_bills/held_bills_screen.dart';
import '../../../services/product/product_service.dart';
import '../../../services/transaction/transaction_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final ProductService _productService = ProductService();
  final TransactionService _transactionService = TransactionService();

  // KPI Data
  Map<String, dynamic>? _todaysSales;
  Map<String, dynamic>? _todaysPurchases;
  int _lowStockCount = 0;
  int _totalProducts = 0;
  bool _isLoadingKPIs = false;

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

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoadingKPIs = true);
    try {
      final sales = await _transactionService.getTodaysSales();
      final purchases = await _transactionService.getTodaysPurchases();
      final lowStock = await _productService.getLowStockProducts();
      final productCount = await _productService.getProductCount();

      setState(() {
        _todaysSales = sales;
        _todaysPurchases = purchases;
        _lowStockCount = lowStock.length;
        _totalProducts = productCount;
        _isLoadingKPIs = false;
      });
    } catch (e) {
      setState(() => _isLoadingKPIs = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
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
                child: NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
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
                  destinations: List.generate(
                    _menuTitles.length,
                    (index) => NavigationRailDestination(
                      icon: Icon(_menuIcons[index]),
                      label: Text(_menuTitles[index]),
                    ),
                  ),
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
        return _buildPlaceholder('Reports', Icons.analytics);
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
                      ? '\$${(_todaysSales!['total_sales'] as num).toStringAsFixed(2)}'
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
                      ? '\$${(_todaysPurchases!['total_purchases'] as num).toStringAsFixed(2)}'
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
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('No recent activity'),
                      subtitle: Text('Start by creating your first transaction'),
                    ),
                  ],
                ),
              ),
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

  Widget _buildPlaceholder(String title, IconData icon) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 100, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              '$title Module',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This module is under development',
              style: TextStyle(color: Colors.grey),
            ),
          ],
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
