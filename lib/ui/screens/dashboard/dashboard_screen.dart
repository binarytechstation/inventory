import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

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
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      body: Row(
        children: [
          // Left sidebar navigation
          NavigationRail(
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
        return _buildPlaceholder('Products', Icons.inventory);
      case 2:
        return _buildPlaceholder('Suppliers', Icons.local_shipping);
      case 3:
        return _buildPlaceholder('Customers', Icons.people);
      case 4:
        return _buildPlaceholder('Transactions', Icons.receipt_long);
      case 5:
        return _buildPlaceholder('Held Bills', Icons.pause_circle_outline);
      case 6:
        return _buildPlaceholder('Reports', Icons.analytics);
      case 7:
        return _buildPlaceholder('Users', Icons.group);
      case 8:
        return _buildPlaceholder('Settings', Icons.settings);
      default:
        return _buildDashboardView();
    }
  }

  Widget _buildDashboardView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh dashboard data
              setState(() {});
            },
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
                  '0',
                  Icons.shopping_cart,
                  Colors.green,
                ),
                _buildKPICard(
                  'Today\'s Purchases',
                  '0',
                  Icons.add_shopping_cart,
                  Colors.blue,
                ),
                _buildKPICard(
                  'Low Stock Items',
                  '0',
                  Icons.warning_amber,
                  Colors.orange,
                ),
                _buildKPICard(
                  'Total Products',
                  '0',
                  Icons.inventory_2,
                  Colors.purple,
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

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.arrow_upward, color: color, size: 16),
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
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
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
