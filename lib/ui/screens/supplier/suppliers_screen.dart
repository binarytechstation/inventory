import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/supplier_model.dart';
import '../../../services/supplier/supplier_service.dart';
import '../../providers/auth_provider.dart';
import 'supplier_form_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final SupplierService _supplierService = SupplierService();
  List<SupplierModel> _suppliers = [];
  List<SupplierModel> _filteredSuppliers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'name';

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);
    try {
      final suppliers = await _supplierService.getAllSuppliers(sortBy: _sortBy);
      setState(() {
        _suppliers = suppliers;
        _filteredSuppliers = suppliers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading suppliers: $e')),
        );
      }
    }
  }

  void _filterSuppliers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSuppliers = _suppliers;
      } else {
        _filteredSuppliers = _suppliers.where((supplier) {
          final nameLower = supplier.name.toLowerCase();
          final companyLower = supplier.companyName?.toLowerCase() ?? '';
          final phoneLower = supplier.phone?.toLowerCase() ?? '';
          final emailLower = supplier.email?.toLowerCase() ?? '';
          final searchLower = query.toLowerCase();

          return nameLower.contains(searchLower) ||
              companyLower.contains(searchLower) ||
              phoneLower.contains(searchLower) ||
              emailLower.contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _deleteSupplier(SupplierModel supplier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: Text('Are you sure you want to delete ${supplier.name}?'),
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
        await _supplierService.deactivateSupplier(supplier.id!);
        _loadSuppliers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Supplier deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting supplier: $e')),
          );
        }
      }
    }
  }

  void _navigateToAddSupplier() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SupplierFormScreen(),
      ),
    );
    if (result == true) {
      _loadSuppliers();
    }
  }

  void _navigateToEditSupplier(SupplierModel supplier) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierFormScreen(supplier: supplier),
      ),
    );
    if (result == true) {
      _loadSuppliers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() => _sortBy = value);
              _loadSuppliers();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
              const PopupMenuItem(value: 'company_name', child: Text('Sort by Company')),
              const PopupMenuItem(value: 'created_at', child: Text('Sort by Date Added')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSuppliers,
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
                hintText: 'Search suppliers...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterSuppliers('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _filterSuppliers,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSuppliers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_shipping, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No suppliers yet'
                                  : 'No suppliers found',
                              style: const TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            if (_searchController.text.isEmpty)
                              ElevatedButton.icon(
                                onPressed: _navigateToAddSupplier,
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Supplier'),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredSuppliers.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final supplier = _filteredSuppliers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Text(
                                  supplier.name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                supplier.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (supplier.companyName != null)
                                    Text(supplier.companyName!),
                                  if (supplier.phone != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.phone, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(supplier.phone!),
                                      ],
                                    ),
                                  if (supplier.email != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.email, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(supplier.email!),
                                      ],
                                    ),
                                ],
                              ),
                              trailing: Consumer<AuthProvider>(
                                builder: (context, authProvider, child) {
                                  final canEdit = authProvider.currentUser?.hasPermission('edit_supplier') ?? false;

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
                                        _navigateToEditSupplier(supplier);
                                      } else if (value == 'delete') {
                                        _deleteSupplier(supplier);
                                      }
                                    },
                                  );
                                },
                              ),
                              onTap: () {
                                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                final canEdit = authProvider.currentUser?.hasPermission('edit_supplier') ?? false;
                                if (canEdit) {
                                  _navigateToEditSupplier(supplier);
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
          final canCreate = authProvider.currentUser?.hasPermission('create_supplier') ?? false;

          if (!canCreate) {
            return Tooltip(
              message: 'Admin access only',
              child: Opacity(
                opacity: 0.5,
                child: FloatingActionButton.extended(
                  onPressed: null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Supplier'),
                  backgroundColor: Colors.grey,
                ),
              ),
            );
          }

          return FloatingActionButton.extended(
            onPressed: _navigateToAddSupplier,
            icon: const Icon(Icons.add),
            label: const Text('Add Supplier'),
          );
        },
      ),
    );
  }
}
