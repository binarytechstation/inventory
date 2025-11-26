import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/customer_model.dart';
import '../../../services/customer/customer_service.dart';
import '../../providers/auth_provider.dart';
import 'customer_form_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final CustomerService _customerService = CustomerService();
  List<CustomerModel> _customers = [];
  List<CustomerModel> _filteredCustomers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'name';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final customers = await _customerService.getAllCustomers(sortBy: _sortBy);
      setState(() {
        _customers = customers;
        _filteredCustomers = customers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading customers: $e')),
        );
      }
    }
  }

  void _filterCustomers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = _customers;
      } else {
        _filteredCustomers = _customers.where((customer) {
          final nameLower = customer.name.toLowerCase();
          final companyLower = customer.companyName?.toLowerCase() ?? '';
          final phoneLower = customer.phone?.toLowerCase() ?? '';
          final emailLower = customer.email?.toLowerCase() ?? '';
          final searchLower = query.toLowerCase();

          return nameLower.contains(searchLower) ||
              companyLower.contains(searchLower) ||
              phoneLower.contains(searchLower) ||
              emailLower.contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _deleteCustomer(CustomerModel customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete ${customer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _customerService.deactivateCustomer(customer.id!);
        _loadCustomers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting customer: $e')),
          );
        }
      }
    }
  }

  void _navigateToAddCustomer() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomerFormScreen(),
      ),
    );
    if (result == true) {
      _loadCustomers();
    }
  }

  void _navigateToEditCustomer(CustomerModel customer) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerFormScreen(customer: customer),
      ),
    );
    if (result == true) {
      _loadCustomers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() => _sortBy = value);
              _loadCustomers();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
              const PopupMenuItem(value: 'company_name', child: Text('Sort by Company')),
              const PopupMenuItem(value: 'current_balance', child: Text('Sort by Balance')),
              const PopupMenuItem(value: 'created_at', child: Text('Sort by Date Added')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCustomers,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterCustomers('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _filterCustomers,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCustomers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No customers yet'
                                  : 'No customers found',
                              style: const TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            if (_searchController.text.isEmpty)
                              ElevatedButton.icon(
                                onPressed: _navigateToAddCustomer,
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Customer'),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredCustomers.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final customer = _filteredCustomers[index];
                          final hasOutstanding = customer.currentBalance > 0;
                          final nearLimit = customer.creditLimit > 0 &&
                              customer.currentBalance >= (customer.creditLimit * 0.8);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: hasOutstanding ? Colors.orange : Colors.green,
                                child: Text(
                                  customer.name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      customer.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (nearLimit)
                                    const Tooltip(
                                      message: 'Near credit limit',
                                      child: Icon(Icons.warning_amber, color: Colors.red, size: 20),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (customer.companyName != null)
                                    Text(customer.companyName!),
                                  if (customer.phone != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.phone, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(customer.phone!),
                                      ],
                                    ),
                                  if (hasOutstanding)
                                    Row(
                                      children: [
                                        const Icon(Icons.account_balance_wallet, size: 14, color: Colors.orange),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Balance: \$${customer.currentBalance.toStringAsFixed(2)}',
                                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  if (customer.creditLimit > 0)
                                    Row(
                                      children: [
                                        const Icon(Icons.credit_card, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text('Credit Limit: \$${customer.creditLimit.toStringAsFixed(2)}'),
                                      ],
                                    ),
                                ],
                              ),
                              trailing: Consumer<AuthProvider>(
                                builder: (context, authProvider, child) {
                                  final canEdit = authProvider.currentUser?.hasPermission('edit_customer') ?? false;

                                  if (!canEdit) {
                                    return const SizedBox.shrink();
                                  }

                                  return PopupMenuButton(
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, size: 20, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _navigateToEditCustomer(customer);
                                      } else if (value == 'delete') {
                                        _deleteCustomer(customer);
                                      }
                                    },
                                  );
                                },
                              ),
                              onTap: () {
                                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                final canEdit = authProvider.currentUser?.hasPermission('edit_customer') ?? false;
                                if (canEdit) {
                                  _navigateToEditCustomer(customer);
                                }
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final canCreate = authProvider.currentUser?.hasPermission('create_customer') ?? false;

          if (!canCreate) {
            return Tooltip(
              message: 'Admin access only',
              child: Opacity(
                opacity: 0.5,
                child: FloatingActionButton.extended(
                  onPressed: null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Customer'),
                  backgroundColor: Colors.grey,
                ),
              ),
            );
          }

          return FloatingActionButton.extended(
            onPressed: _navigateToAddCustomer,
            icon: const Icon(Icons.add),
            label: const Text('Add Customer'),
          );
        },
      ),
    );
  }
}
