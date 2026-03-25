import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/customer_model.dart';
import '../../../services/customer/customer_service.dart';
import '../../providers/auth_provider.dart';
import 'customer_form_screen.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final CustomerService _customerService = CustomerService();
  List<CustomerModel> _customers = [];
  List<CustomerModel> _filteredCustomers = [];
  Map<String, List<CustomerModel>> _byCompany = {};
  bool _isLoading = true;
  bool _viewByCompany = false;
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
        _byCompany = _groupByCompany(customers);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading customers: $e')));
      }
    }
  }

  void _filterCustomers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = _customers;
        _byCompany = _groupByCompany(_customers);
      } else {
        final q = query.toLowerCase();
        _filteredCustomers = _customers.where((c) {
          return c.name.toLowerCase().contains(q) ||
              (c.companyName?.toLowerCase().contains(q) ?? false) ||
              (c.phone?.contains(q) ?? false) ||
              (c.email?.toLowerCase().contains(q) ?? false);
        }).toList();
        _byCompany = _groupByCompany(_filteredCustomers);
      }
    });
  }

  Map<String, List<CustomerModel>> _groupByCompany(List<CustomerModel> customers) {
    final Map<String, List<CustomerModel>> grouped = {};
    for (final c in customers) {
      final company = c.companyName?.trim().isNotEmpty == true ? c.companyName! : '(Individual)';
      grouped.putIfAbsent(company, () => []).add(c);
    }
    return Map.fromEntries(grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  Future<void> _deleteCustomer(CustomerModel customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Customer'),
        content: Text('Remove ${customer.name}?'
            '${customer.currentBalance > 0 ? '\n\nWarning: This customer has an outstanding balance of ৳${customer.currentBalance.toStringAsFixed(2)}.' : ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _customerService.deactivateCustomer(customer.id!);
      _loadCustomers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer removed')));
      }
    }
  }

  void _openDetail(CustomerModel customer) async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => CustomerDetailScreen(customer: customer)));
    if (result == true) _loadCustomers();
  }

  void _navigateToAddCustomer() async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => const CustomerFormScreen()));
    if (result == true) _loadCustomers();
  }

  void _navigateToEditCustomer(CustomerModel customer) async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => CustomerFormScreen(customer: customer)));
    if (result == true) _loadCustomers();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.people, size: 24),
          ),
          const SizedBox(width: 12),
          const Text('Customers'),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: SegmentedButton<bool>(
              style: SegmentedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                selectedBackgroundColor: Colors.white.withValues(alpha: 0.3),
                foregroundColor: Colors.white,
                selectedForegroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
              ),
              segments: const [
                ButtonSegment(value: false, label: Text('By Customer'), icon: Icon(Icons.person, size: 16)),
                ButtonSegment(value: true, label: Text('By Company'), icon: Icon(Icons.business, size: 16)),
              ],
              selected: {_viewByCompany},
              onSelectionChanged: (v) => setState(() => _viewByCompany = v.first),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() => _sortBy = value);
              _loadCustomers();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
              const PopupMenuItem(value: 'company_name', child: Text('Sort by Company')),
              const PopupMenuItem(value: 'current_balance DESC', child: Text('Sort by Balance')),
              const PopupMenuItem(value: 'created_at DESC', child: Text('Sort by Date Added')),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCustomers),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search customers or companies...',
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: _filterCustomers,
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredCustomers.isEmpty
                  ? _buildEmptyState()
                  : _viewByCompany
                      ? _buildCompanyView(theme)
                      : _buildCustomerView(theme),
        ),
      ]),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.people, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(_searchController.text.isEmpty ? 'No customers yet' : 'No customers found',
            style: const TextStyle(fontSize: 18, color: Colors.grey)),
        const SizedBox(height: 8),
        if (_searchController.text.isEmpty)
          ElevatedButton.icon(
            onPressed: _navigateToAddCustomer,
            icon: const Icon(Icons.add),
            label: const Text('Add First Customer'),
          ),
      ]),
    );
  }

  Widget _buildCustomerView(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: _filteredCustomers.length,
      itemBuilder: (context, index) => _buildCustomerCard(_filteredCustomers[index], theme),
    );
  }

  Widget _buildCompanyView(ThemeData theme) {
    final entries = _byCompany.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final company = entries[index].key;
        final customers = entries[index].value;
        final totalBalance = customers.fold(0.0, (s, c) => s + c.currentBalance);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(Icons.business, color: theme.colorScheme.secondary),
            ),
            title: Text(company, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${customers.length} customer${customers.length != 1 ? 's' : ''}'),
            trailing: totalBalance > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text('৳${totalBalance.toStringAsFixed(0)} due',
                        style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                  )
                : null,
            children: customers.map((c) => Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _buildCustomerCard(c, theme),
            )).toList(),
          ),
        );
      },
    );
  }

  Widget _buildCustomerCard(CustomerModel customer, ThemeData theme) {
    final hasDue = customer.currentBalance > 0;
    final nearLimit = customer.creditLimit > 0 &&
        customer.currentBalance >= customer.creditLimit * 0.8;

    Color avatarColor = theme.colorScheme.secondary;
    if (hasDue && nearLimit) {
      avatarColor = Colors.red;
    } else if (hasDue) {
      avatarColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: hasDue ? Colors.orange.shade50 : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: avatarColor,
          child: Text(customer.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (customer.companyName != null && customer.companyName!.isNotEmpty)
            Text(customer.companyName!, style: TextStyle(color: Colors.grey[600])),
          if (customer.phone != null)
            Row(children: [
              Icon(Icons.phone, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(customer.phone!, style: TextStyle(color: Colors.grey[600])),
            ]),
          if (hasDue)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Icon(Icons.account_balance_wallet, size: 14, color: Colors.orange.shade700),
                const SizedBox(width: 4),
                Text('Due: ৳${customer.currentBalance.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
                if (customer.creditLimit > 0) ...[
                  const SizedBox(width: 8),
                  Text('/ ৳${customer.creditLimit.toStringAsFixed(0)} limit',
                      style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                ],
              ]),
            ),
          if (nearLimit)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Near credit limit!',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
        ]),
        trailing: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            final canEdit = authProvider.currentUser?.hasPermission('edit_customer') ?? false;
            return Row(mainAxisSize: MainAxisSize.min, children: [
              if (hasDue)
                TextButton.icon(
                  onPressed: () => _openDetail(customer),
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('Collect'),
                  style: TextButton.styleFrom(foregroundColor: Colors.orange.shade800),
                ),
              if (canEdit)
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility, size: 20), SizedBox(width: 8), Text('View Details')])),
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Edit')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Remove', style: TextStyle(color: Colors.red))])),
                  ],
                  onSelected: (value) {
                    if (value == 'view') {
                      _openDetail(customer);
                    } else if (value == 'edit') {
                      _navigateToEditCustomer(customer);
                    } else if (value == 'delete') {
                      _deleteCustomer(customer);
                    }
                  },
                )
              else
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _openDetail(customer)),
            ]);
          },
        ),
        onTap: () => _openDetail(customer),
      ),
    );
  }
}
