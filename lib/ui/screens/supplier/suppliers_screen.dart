import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/supplier_model.dart';
import '../../../services/supplier/supplier_service.dart';
import '../../providers/auth_provider.dart';
import 'supplier_form_screen.dart';
import 'supplier_detail_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final SupplierService _supplierService = SupplierService();
  List<SupplierModel> _suppliers = [];
  List<SupplierModel> _filteredSuppliers = [];
  Map<String, List<SupplierModel>> _byCompany = {};
  bool _isLoading = true;
  bool _viewByCompany = false;
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
      final byCompany = await _supplierService.getSuppliersByCompany();
      setState(() {
        _suppliers = suppliers;
        _filteredSuppliers = suppliers;
        _byCompany = byCompany;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading suppliers: $e')));
      }
    }
  }

  void _filterSuppliers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSuppliers = _suppliers;
        _byCompany = _groupByCompany(_suppliers);
      } else {
        final q = query.toLowerCase();
        _filteredSuppliers = _suppliers.where((s) {
          return s.name.toLowerCase().contains(q) ||
              (s.companyName?.toLowerCase().contains(q) ?? false) ||
              (s.phone?.contains(q) ?? false) ||
              (s.email?.toLowerCase().contains(q) ?? false);
        }).toList();
        _byCompany = _groupByCompany(_filteredSuppliers);
      }
    });
  }

  Map<String, List<SupplierModel>> _groupByCompany(List<SupplierModel> suppliers) {
    final Map<String, List<SupplierModel>> grouped = {};
    for (final s in suppliers) {
      final company = s.companyName?.trim().isNotEmpty == true ? s.companyName! : '(No Company)';
      grouped.putIfAbsent(company, () => []).add(s);
    }
    return Map.fromEntries(grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  Future<void> _deleteSupplier(SupplierModel supplier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Dealer'),
        content: Text('Remove ${supplier.name}${supplier.currentBalance > 0 ? '\n\nWarning: This dealer has an outstanding balance of ৳${supplier.currentBalance.toStringAsFixed(2)}.' : ''}'),
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
      await _supplierService.deactivateSupplier(supplier.id!);
      _loadSuppliers();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dealer removed')));
    }
  }

  void _openDetail(SupplierModel supplier) async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => SupplierDetailScreen(supplier: supplier)));
    if (result == true) _loadSuppliers();
  }

  void _navigateToAddSupplier() async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => const SupplierFormScreen()));
    if (result == true) _loadSuppliers();
  }

  void _navigateToEditSupplier(SupplierModel supplier) async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => SupplierFormScreen(supplier: supplier)));
    if (result == true) _loadSuppliers();
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
            child: const Icon(Icons.local_shipping, size: 24),
          ),
          const SizedBox(width: 12),
          const Text('Suppliers'),
        ]),
        actions: [
          // View toggle
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
                ButtonSegment(value: false, label: Text('By Dealer'), icon: Icon(Icons.person, size: 16)),
                ButtonSegment(value: true, label: Text('By Company'), icon: Icon(Icons.business, size: 16)),
              ],
              selected: {_viewByCompany},
              onSelectionChanged: (v) => setState(() => _viewByCompany = v.first),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) { setState(() => _sortBy = value); _loadSuppliers(); },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
              const PopupMenuItem(value: 'company_name', child: Text('Sort by Company')),
              const PopupMenuItem(value: 'current_balance DESC', child: Text('Sort by Balance')),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSuppliers),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search dealers or companies...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _filterSuppliers(''); })
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: _filterSuppliers,
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredSuppliers.isEmpty
                  ? _buildEmptyState()
                  : _viewByCompany
                      ? _buildCompanyView(theme)
                      : _buildDealerView(theme),
        ),
      ]),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final canCreate = authProvider.currentUser?.hasPermission('create_supplier') ?? false;
          if (!canCreate) {
            return Tooltip(
              message: 'Admin access only',
              child: Opacity(opacity: 0.5,
                child: FloatingActionButton.extended(
                  onPressed: null, icon: const Icon(Icons.add),
                  label: const Text('Add Dealer'), backgroundColor: Colors.grey)),
            );
          }
          return FloatingActionButton.extended(
            onPressed: _navigateToAddSupplier,
            icon: const Icon(Icons.add),
            label: const Text('Add Dealer'),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.local_shipping, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(_searchController.text.isEmpty ? 'No dealers yet' : 'No dealers found',
            style: const TextStyle(fontSize: 18, color: Colors.grey)),
        const SizedBox(height: 8),
        if (_searchController.text.isEmpty)
          ElevatedButton.icon(onPressed: _navigateToAddSupplier,
              icon: const Icon(Icons.add), label: const Text('Add First Dealer')),
      ]),
    );
  }

  Widget _buildDealerView(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: _filteredSuppliers.length,
      itemBuilder: (context, index) => _buildDealerCard(_filteredSuppliers[index], theme),
    );
  }

  Widget _buildCompanyView(ThemeData theme) {
    final entries = _byCompany.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final company = entries[index].key;
        final dealers = entries[index].value;
        final totalBalance = dealers.fold(0.0, (s, d) => s + d.currentBalance);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.business, color: theme.colorScheme.primary),
            ),
            title: Text(company, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${dealers.length} dealer${dealers.length != 1 ? 's' : ''}'),
            trailing: totalBalance > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text('Due ৳${totalBalance.toStringAsFixed(0)}',
                        style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                  )
                : null,
            children: dealers.map((dealer) => Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _buildDealerCard(dealer, theme),
            )).toList(),
          ),
        );
      },
    );
  }

  Widget _buildDealerCard(SupplierModel supplier, ThemeData theme) {
    final hasDue = supplier.currentBalance > 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: hasDue ? Colors.red.shade50 : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: hasDue ? Colors.red : theme.colorScheme.primary,
          child: Text(supplier.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (supplier.companyName != null && supplier.companyName!.isNotEmpty)
            Text(supplier.companyName!, style: TextStyle(color: Colors.grey[600])),
          if (supplier.phone != null)
            Row(children: [
              Icon(Icons.phone, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(supplier.phone!, style: TextStyle(color: Colors.grey[600])),
            ]),
          if (hasDue)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red.shade600),
                const SizedBox(width: 4),
                Text('Due: ৳${supplier.currentBalance.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
        trailing: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            final canEdit = authProvider.currentUser?.hasPermission('edit_supplier') ?? false;
            return Row(mainAxisSize: MainAxisSize.min, children: [
              if (hasDue)
                TextButton.icon(
                  onPressed: () => _openDetail(supplier),
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('Pay'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
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
                      _openDetail(supplier);
                    } else if (value == 'edit') _navigateToEditSupplier(supplier);
                    else if (value == 'delete') _deleteSupplier(supplier);
                  },
                )
              else
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _openDetail(supplier)),
            ]);
          },
        ),
        onTap: () => _openDetail(supplier),
      ),
    );
  }
}
