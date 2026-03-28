import 'package:flutter/material.dart';
import '../../../data/models/supplier_model.dart';
import '../../../services/supplier/supplier_service.dart';
import '../../../services/transaction/transaction_service.dart';
import '../../../services/currency/currency_service.dart';
import '../../../services/product/product_service.dart';

/// New Purchase Order Screen - Lot-based product entry
/// Creates a new lot and adds products to it in one transaction
class PurchaseOrderScreen extends StatefulWidget {
  const PurchaseOrderScreen({super.key});

  @override
  State<PurchaseOrderScreen> createState() => _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends State<PurchaseOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final SupplierService _supplierService = SupplierService();
  final TransactionService _transactionService = TransactionService();
  final CurrencyService _currencyService = CurrencyService();

  // Transaction data
  DateTime _transactionDate = DateTime.now();
  String _paymentMode = 'cash';
  SupplierModel? _selectedSupplier;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _lotNumberController = TextEditingController();
  final TextEditingController _cashPaidController = TextEditingController();

  // Products in this lot
  final List<Map<String, dynamic>> _products = [];

  // Calculations
  double _subtotal = 0;
  double _discount = 0;
  double _tax = 0;
  double _total = 0;

  bool _isSaving = false;
  String _currencySymbol = '৳';
  String _lotName = '';

  @override
  void initState() {
    super.initState();
    _loadCurrencySymbol();
    _updateLotName();
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

  void _updateLotName() {
    final now = _transactionDate;
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final dateTimeStr = '$dateStr $timeStr';

    setState(() {
      _lotName = _lotNumberController.text.trim().isEmpty
          ? 'LOT-$dateTimeStr'
          : '${_lotNumberController.text.trim()} ($dateTimeStr)';
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _lotNumberController.dispose();
    _cashPaidController.dispose();
    super.dispose();
  }

  void _calculateTotals() {
    _subtotal = 0;
    _tax = 0;
    _discount = 0;

    for (final product in _products) {
      final quantity = product['quantity'] as double;
      final buyingPrice = product['buying_price'] as double;

      final itemSubtotal = quantity * buyingPrice;
      _subtotal += itemSubtotal;
    }

    // For now, no tax or discount on purchase orders
    _total = _subtotal - _discount + _tax;
    setState(() {});
  }

  Future<void> _selectSupplier() async {
    final suppliers = await _supplierService.getAllSuppliers();
    if (!mounted) return;

    final searchController = TextEditingController();
    List<SupplierModel> filteredSuppliers = List.from(suppliers);

    final selected = await showDialog<SupplierModel>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Select Supplier'),
              ElevatedButton.icon(
                onPressed: () async {
                  // Capture context before async operation
                  final dialogContext = context;
                  // Show add supplier dialog
                  final newSupplier = await _showAddSupplierDialog();
                  if (newSupplier != null) {
                    // Refresh suppliers list
                    final updatedSuppliers = await _supplierService.getAllSuppliers();
                    setDialogState(() {
                      suppliers.clear();
                      suppliers.addAll(updatedSuppliers);
                      filteredSuppliers = List.from(suppliers);
                    });
                    // Auto-select the new supplier
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, newSupplier);
                    }
                  }
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            height: 450,
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Search by name',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (query) {
                    setDialogState(() {
                      filteredSuppliers = suppliers.where((supplier) {
                        final nameLower = supplier.name.toLowerCase();
                        final companyLower = (supplier.companyName ?? '').toLowerCase();
                        final searchLower = query.toLowerCase();
                        return nameLower.contains(searchLower) || companyLower.contains(searchLower);
                      }).toList();
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Suppliers list
                Expanded(
                  child: filteredSuppliers.isEmpty
                      ? Center(
                          child: Text(
                            searchController.text.isEmpty
                                ? 'No suppliers available'
                                : 'No suppliers found',
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredSuppliers.length,
                          itemBuilder: (context, index) {
                            final supplier = filteredSuppliers[index];
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(supplier.name.substring(0, 1).toUpperCase()),
                              ),
                              title: Text(supplier.name),
                              subtitle: supplier.companyName != null
                                  ? Text(supplier.companyName!)
                                  : null,
                              onTap: () {
                                searchController.dispose();
                                Navigator.pop(context, supplier);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                searchController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      setState(() => _selectedSupplier = selected);
    }
  }

  Future<SupplierModel?> _showAddSupplierDialog() async {
    final nameController = TextEditingController();
    final companyController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.green.shade900.withValues(alpha: 0.3)
                    : Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.business,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.green.shade300
                    : Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Add New Supplier'),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Supplier Name *',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: companyController,
                  decoration: InputDecoration(
                    labelText: 'Company Name (Optional)',
                    prefixIcon: const Icon(Icons.business),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number *',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email (Optional)',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(
                    labelText: 'Address (Optional)',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              nameController.dispose();
              companyController.dispose();
              phoneController.dispose();
              emailController.dispose();
              addressController.dispose();
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final name = nameController.text.trim();
      final phone = phoneController.text.trim();

      if (name.isEmpty || phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name and phone are required')),
        );
        nameController.dispose();
        companyController.dispose();
        phoneController.dispose();
        emailController.dispose();
        addressController.dispose();
        return null;
      }

      try {
        // Create supplier model
        final supplier = SupplierModel(
          name: name,
          companyName: companyController.text.trim().isEmpty ? null : companyController.text.trim(),
          phone: phone,
          email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
          address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Save supplier
        final supplierId = await _supplierService.createSupplier(supplier);

        // Get the created supplier with ID
        final suppliers = await _supplierService.getAllSuppliers();
        final newSupplier = suppliers.firstWhere(
          (s) => s.id == supplierId,
          orElse: () => suppliers.first,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Supplier "$name" added successfully')),
          );
        }

        nameController.dispose();
        companyController.dispose();
        phoneController.dispose();
        emailController.dispose();
        addressController.dispose();

        return newSupplier;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding supplier: $e')),
          );
        }
        nameController.dispose();
        companyController.dispose();
        phoneController.dispose();
        emailController.dispose();
        addressController.dispose();
        return null;
      }
    }

    nameController.dispose();
    companyController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    return null;
  }

  Future<void> _addProduct() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddProductDialog(currencySymbol: _currencySymbol),
    );

    if (result != null) {
      setState(() {
        _products.add(result);
      });
      _calculateTotals();
    }
  }

  void _editProduct(int index) async {
    final product = _products[index];
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddProductDialog(
        currencySymbol: _currencySymbol,
        existingProduct: product,
      ),
    );

    if (result != null) {
      setState(() {
        _products[index] = result;
      });
      _calculateTotals();
    }
  }

  void _deleteProduct(int index) {
    setState(() {
      _products.removeAt(index);
    });
    _calculateTotals();
  }

  Future<void> _savePurchaseOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a supplier')),
      );
      return;
    }

    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // This will be handled by an updated TransactionService
      // that creates the lot and products together
      final lotData = {
        'lot_number': _lotNumberController.text.trim(),
        'lot_name': _lotName, // This is the generated lot name with date and time
        'received_date': _transactionDate.toIso8601String(),
      };

      // Format products for transaction service
      final formattedProducts = _products.map((p) {
        return {
          ...p,
          'lot_data': lotData,
        };
      }).toList();

      await _transactionService.createPurchaseOrderWithLot(
        supplierId: _selectedSupplier!.id!,
        date: _transactionDate,
        lotData: lotData,
        products: formattedProducts,
        paymentMode: _paymentMode,
        paidAmount: _paymentMode == 'partial'
            ? double.tryParse(_cashPaidController.text) ?? 0
            : null,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        subtotal: _subtotal,
        discount: _discount,
        tax: _tax,
        total: _total,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase Order created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: iconColor)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _priceChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shopping_cart_outlined, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('New Purchase Order', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          if (_products.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text('${_products.length} item${_products.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Supplier Selection
                  _sectionCard(
                    icon: Icons.local_shipping_outlined,
                    iconColor: Colors.indigo,
                    label: 'Supplier',
                    child: InkWell(
                      onTap: _selectSupplier,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _selectedSupplier == null
                                ? [Colors.grey.shade50, Colors.grey.shade100]
                                : [Colors.indigo.shade50, Colors.indigo.shade100],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedSupplier == null
                                ? Colors.grey.shade300
                                : Colors.indigo.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _selectedSupplier == null
                                    ? Colors.grey.shade200
                                    : Colors.indigo.shade600,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.storefront_outlined,
                                  color: _selectedSupplier == null
                                      ? Colors.grey.shade600
                                      : Colors.white,
                                  size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedSupplier == null ? 'Tap to select supplier' : _selectedSupplier!.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: _selectedSupplier == null
                                          ? Colors.grey.shade600
                                          : Colors.indigo.shade900,
                                    ),
                                  ),
                                  if (_selectedSupplier?.companyName != null) ...[
                                    const SizedBox(height: 2),
                                    Text(_selectedSupplier!.companyName!,
                                        style: TextStyle(fontSize: 12, color: Colors.indigo.shade700)),
                                  ] else if (_selectedSupplier == null)
                                    Text('Required for purchase order',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: _selectedSupplier == null ? Colors.grey : Colors.indigo),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date and Payment Mode
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.calendar_today),
                            title: const Text('Date'),
                            subtitle: Text(
                              _transactionDate.toString().split(' ')[0],
                            ),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _transactionDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() {
                                  _transactionDate = date;
                                  _updateLotName();
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.payment, size: 20),
                                    const SizedBox(width: 8),
                                    const Text('Payment Mode',
                                        style: TextStyle(fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                        value: 'cash',
                                        label: Text('Cash'),
                                        icon: Icon(Icons.money, size: 16)),
                                    ButtonSegment(
                                        value: 'partial',
                                        label: Text('Partial'),
                                        icon: Icon(Icons.pie_chart, size: 16)),
                                    ButtonSegment(
                                        value: 'credit',
                                        label: Text('Credit'),
                                        icon: Icon(Icons.credit_card, size: 16)),
                                  ],
                                  selected: {_paymentMode},
                                  onSelectionChanged: (s) => setState(() {
                                    _paymentMode = s.first;
                                    _cashPaidController.clear();
                                  }),
                                  style: const ButtonStyle(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                if (_paymentMode == 'partial') ...[
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _cashPaidController,
                                    decoration: InputDecoration(
                                      labelText: 'Cash Paid ($_currencySymbol)',
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      suffixText: _total > 0 &&
                                              _cashPaidController.text.isNotEmpty
                                          ? 'Credit: $_currencySymbol${(_total - (double.tryParse(_cashPaidController.text) ?? 0)).clamp(0, _total).toStringAsFixed(2)}'
                                          : null,
                                      suffixStyle:
                                          const TextStyle(color: Colors.orange, fontSize: 11),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                    validator: (v) {
                                      if (_paymentMode != 'partial') return null;
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Enter cash amount';
                                      }
                                      final n = double.tryParse(v);
                                      if (n == null || n < 0) return 'Invalid amount';
                                      if (n > _total) {
                                        return 'Cannot exceed total';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Lot Number
                  _sectionCard(
                    icon: Icons.inventory_2_outlined,
                    iconColor: Colors.teal,
                    label: 'Lot Information',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _lotNumberController,
                          decoration: InputDecoration(
                            labelText: 'Lot Name *',
                            hintText: 'e.g., Summer Stock, Batch A',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            prefixIcon: const Icon(Icons.label_outline, color: Colors.teal),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Lot name is required';
                            return null;
                          },
                          onChanged: (_) => _updateLotName(),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.teal.shade50, Colors.teal.shade100],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.teal.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade600,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Auto ID: $_lotName',
                                  style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Products Section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: [
                        // Section header
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade700, Colors.blue.shade500],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.inventory_2, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Products in this Lot',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                    Text('${_products.length} item${_products.length == 1 ? '' : 's'} · $_currencySymbol${_subtotal.toStringAsFixed(2)} total',
                                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: _addProduct,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blue.shade700,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        if (_products.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(Icons.add_box_outlined, size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 8),
                                Text('No products added yet', style: TextStyle(color: Colors.grey.shade500)),
                                const SizedBox(height: 4),
                                Text('Tap "Add" to add products to this lot',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _products.length,
                            separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                            itemBuilder: (context, index) {
                              final product = _products[index];
                              final name = product['product_name'] as String;
                              final quantity = product['quantity'] as double;
                              final buyingPrice = product['buying_price'] as double;
                              final sellingPrice = product['selling_price'] as double;
                              final unit = product['unit'] as String;
                              final lineTotal = quantity * buyingPrice;
                              final margin = buyingPrice > 0 ? ((sellingPrice - buyingPrice) / buyingPrice * 100) : 0.0;
                              final isMarginPositive = margin >= 0;

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    // Number badge
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue.shade100),
                                      ),
                                      child: Center(
                                        child: Text('${index + 1}',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade700)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Product details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              _priceChip(Icons.shopping_cart_outlined, '$_currencySymbol${buyingPrice.toStringAsFixed(2)}', Colors.blue),
                                              const SizedBox(width: 6),
                                              _priceChip(Icons.sell_outlined, '$_currencySymbol${sellingPrice.toStringAsFixed(2)}', Colors.green),
                                              const SizedBox(width: 6),
                                              _priceChip(
                                                isMarginPositive ? Icons.trending_up : Icons.trending_down,
                                                '${margin.toStringAsFixed(0)}%',
                                                isMarginPositive ? Colors.teal : Colors.red,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Qty × total
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('$_currencySymbol${lineTotal.toStringAsFixed(2)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        Text('${quantity % 1 == 0 ? quantity.toInt() : quantity.toStringAsFixed(2)} $unit',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    // Actions
                                    Column(
                                      children: [
                                        InkWell(
                                          onTap: () => _editProduct(index),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(Icons.edit_outlined, size: 16, color: Colors.blue.shade600),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        InkWell(
                                          onTap: () => _deleteProduct(index),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  _sectionCard(
                    icon: Icons.notes_outlined,
                    iconColor: Colors.grey.shade600,
                    label: 'Notes (Optional)',
                    child: TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        hintText: 'Any additional notes about this purchase...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.edit_note, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
            ),

            // Summary Section
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF0F172A)
                    : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Pull handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      children: [
                        // Summary rows
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              Icon(Icons.receipt_outlined, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 6),
                              Text('Subtotal', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            ]),
                            Text('$_currencySymbol${_subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Total row — prominent
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade700, Colors.blue.shade500],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                const Icon(Icons.payments, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                const Text('Total', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ]),
                              Text('$_currencySymbol${_total.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        if (_paymentMode == 'partial') ...[
                          const SizedBox(height: 8),
                          Builder(builder: (_) {
                            final cashPaid = (double.tryParse(_cashPaidController.text) ?? 0).clamp(0.0, _total);
                            final credit = _total - cashPaid;
                            return Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green.shade200),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.money, size: 14, color: Colors.green.shade700),
                                        const SizedBox(width: 4),
                                        Text('Cash: $_currencySymbol${cashPaid.toStringAsFixed(2)}',
                                            style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.shade200),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.credit_card, size: 14, color: Colors.orange.shade700),
                                        const SizedBox(width: 4),
                                        Text('Credit: $_currencySymbol${credit.toStringAsFixed(2)}',
                                            style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                        const SizedBox(height: 16),
                        // Save button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _savePurchaseOrder,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: _isSaving
                                ? const SizedBox(width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_circle_outline, size: 20),
                            label: Text(
                              _isSaving ? 'Creating...' : 'Create Purchase Order',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for adding/editing a product in the lot
class _AddProductDialog extends StatefulWidget {
  final String currencySymbol;
  final Map<String, dynamic>? existingProduct;

  const _AddProductDialog({
    required this.currencySymbol,
    this.existingProduct,
  });

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _buyingPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _reorderLevelController = TextEditingController(text: '2');
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();

  final ProductService _productService = ProductService();
  List<String> _existingProductNames = [];
  List<String> _existingCategories = [];
  bool _isLoadingProducts = true;
  bool _isExistingProduct = false;

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _categoryFocusNode = FocusNode();
  bool _showNameSuggestions = false;
  bool _showCategorySuggestions = false;

  String _unit = 'piece';

  @override
  void initState() {
    super.initState();
    _loadExistingProducts();

    if (widget.existingProduct != null) {
      final p = widget.existingProduct!;
      _nameController.text = p['product_name'] ?? '';
      _quantityController.text = (p['quantity'] as double).toString();
      _buyingPriceController.text = (p['buying_price'] as double).toString();
      _sellingPriceController.text = (p['selling_price'] as double).toString();
      _reorderLevelController.text = (p['reorder_level'] as double?)?.toString() ?? '0';
      _skuController.text = p['sku'] ?? '';
      _barcodeController.text = p['barcode'] ?? '';
      _categoryController.text = p['category'] ?? '';
      _descriptionController.text = p['description'] ?? '';
      const validUnits = {'piece', 'kg', 'liter', 'meter', 'box'};
      final loaded = p['unit'] as String? ?? 'piece';
      _unit = validUnits.contains(loaded) ? loaded : 'piece';
    }
  }

  Future<void> _loadExistingProducts() async {
    try {
      final results = await Future.wait([
        _productService.getAllProductNames(),
        _productService.getAllCategories(),
      ]);
      if (mounted) {
        setState(() {
          _existingProductNames = results[0];
          _existingCategories = results[1];
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }
  }

  Future<void> _onProductNameSelected(String productName) async {
    try {
      final productDetails = await _productService.getProductByName(productName);
      if (productDetails != null && mounted) {
        setState(() {
          _isExistingProduct = true;
          _categoryController.text = productDetails['category'] ?? '';
          _descriptionController.text = productDetails['product_description'] ?? '';
          const validUnits = {'piece', 'kg', 'liter', 'meter', 'box'};
          final loaded = productDetails['unit'] as String? ?? 'piece';
          _unit = validUnits.contains(loaded) ? loaded : 'piece';

          // Auto-fill selling price from product (can be edited)
          final sellingPrice = productDetails['selling_price'];
          if (sellingPrice != null) {
            _sellingPriceController.text = sellingPrice.toString();
          }

          // Note: SKU, barcode, and buying price are NOT auto-filled
          // because each lot can have different values
        });
      }
    } catch (e) {
      // Error loading product details
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _buyingPriceController.dispose();
    _sellingPriceController.dispose();
    _reorderLevelController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _nameFocusNode.dispose();
    _categoryFocusNode.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final productData = {
      'product_name': _nameController.text.trim(),
      'quantity': double.parse(_quantityController.text),
      'buying_price': double.parse(_buyingPriceController.text),
      'selling_price': double.parse(_sellingPriceController.text),
      'unit': _unit,
      'reorder_level': double.tryParse(_reorderLevelController.text) ?? 0.0,
      'sku': _skuController.text.trim(),
      'barcode': _barcodeController.text.trim(),
      'category': _categoryController.text.trim(),
      'description': _descriptionController.text.trim(),
    };

    Navigator.pop(context, productData);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingProduct == null ? 'Add Product' : 'Edit Product'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Product Name — inline suggestion list (works inside dialogs)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Product Name *',
                        border: const OutlineInputBorder(),
                        hintText: 'Type to search existing or enter new',
                        helperText: _isExistingProduct
                            ? 'Existing product — category & unit auto-filled'
                            : 'New product — enter all details',
                        helperStyle: TextStyle(
                          color: _isExistingProduct ? Colors.blue : Colors.grey,
                          fontSize: 11,
                        ),
                        suffixIcon: _isLoadingProducts
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ))
                            : _nameController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => setState(() {
                                      _nameController.clear();
                                      _isExistingProduct = false;
                                      _showNameSuggestions = false;
                                    }))
                                : null,
                      ),
                      onTap: () => setState(
                          () => _showNameSuggestions = _nameController.text.isNotEmpty),
                      onChanged: (v) {
                        final isExisting = _existingProductNames
                            .any((n) => n.toLowerCase() == v.trim().toLowerCase());
                        setState(() {
                          _showNameSuggestions = v.isNotEmpty;
                          _isExistingProduct = isExisting;
                        });
                        if (isExisting) _onProductNameSelected(v.trim());
                      },
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        return null;
                      },
                    ),
                    // Inline suggestions
                    Builder(builder: (_) {
                      if (!_showNameSuggestions) return const SizedBox.shrink();
                      final q = _nameController.text.toLowerCase();
                      final filtered = _existingProductNames
                          .where((n) => n.toLowerCase().contains(q))
                          .toList();
                      if (filtered.isEmpty) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(top: 2),
                        constraints: const BoxConstraints(maxHeight: 160),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Colors.blue.shade200),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.inventory_2, size: 16, color: Colors.blue),
                            title: Text(filtered[i], style: const TextStyle(fontSize: 13)),
                            onTap: () {
                              setState(() {
                                _nameController.text = filtered[i];
                                _showNameSuggestions = false;
                                _isExistingProduct = true;
                              });
                              _onProductNameSelected(filtered[i]);
                            },
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (double.tryParse(v) == null || double.parse(v) <= 0) {
                            return 'Invalid quantity';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _unit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'piece', child: Text('Piece')),
                          DropdownMenuItem(value: 'kg', child: Text('Kilogram')),
                          DropdownMenuItem(value: 'liter', child: Text('Liter')),
                          DropdownMenuItem(value: 'meter', child: Text('Meter')),
                          DropdownMenuItem(value: 'box', child: Text('Box')),
                        ],
                        onChanged: (v) => setState(() => _unit = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _buyingPriceController,
                        decoration: InputDecoration(
                          labelText: 'Buying Price * (${widget.currencySymbol})',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (double.tryParse(v) == null || double.parse(v) < 0) {
                            return 'Invalid price';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _sellingPriceController,
                        decoration: InputDecoration(
                          labelText: 'Selling Price * (${widget.currencySymbol})',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (double.tryParse(v) == null || double.parse(v) < 0) {
                            return 'Invalid price';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _skuController,
                        decoration: const InputDecoration(
                          labelText: 'SKU',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _barcodeController,
                        decoration: const InputDecoration(
                          labelText: 'Barcode',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _categoryController,
                            focusNode: _categoryFocusNode,
                            decoration: const InputDecoration(
                              labelText: 'Category *',
                              border: OutlineInputBorder(),
                              hintText: 'Type or select existing category',
                              suffixIcon: Icon(Icons.arrow_drop_down, size: 20),
                            ),
                            textCapitalization: TextCapitalization.words,
                            onTap: () => setState(() => _showCategorySuggestions = true),
                            onChanged: (v) => setState(() => _showCategorySuggestions = true),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Please enter category';
                              return null;
                            },
                          ),
                          // Inline category suggestions
                          Builder(builder: (_) {
                            if (!_showCategorySuggestions) return const SizedBox.shrink();
                            final q = _categoryController.text.toLowerCase();
                            final filtered = q.isEmpty
                                ? _existingCategories
                                : _existingCategories
                                    .where((c) => c.toLowerCase().contains(q))
                                    .toList();
                            if (filtered.isEmpty) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(top: 2),
                              constraints: const BoxConstraints(maxHeight: 130),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                border: Border.all(color: Colors.blue.shade200),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: filtered.length,
                                itemBuilder: (_, i) => ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.category, size: 16, color: Colors.blue),
                                  title: Text(filtered[i], style: const TextStyle(fontSize: 13)),
                                  onTap: () => setState(() {
                                    _categoryController.text = filtered[i];
                                    _showCategorySuggestions = false;
                                  }),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _reorderLevelController,
                        decoration: const InputDecoration(
                          labelText: 'Reorder Level *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter reorder level';
                          }
                          final level = int.tryParse(value.trim());
                          if (level == null || level < 0) {
                            return 'Enter valid number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
