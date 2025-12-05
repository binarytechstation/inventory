import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Purchase Order'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
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
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.local_shipping, color: Colors.blue),
                      title: Text(_selectedSupplier == null
                          ? 'Select Supplier'
                          : _selectedSupplier!.name),
                      subtitle: _selectedSupplier?.companyName != null
                          ? Text(_selectedSupplier!.companyName!)
                          : null,
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _selectSupplier,
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
                          child: ListTile(
                            leading: const Icon(Icons.payment),
                            title: const Text('Payment'),
                            subtitle: DropdownButton<String>(
                              value: _paymentMode,
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                                DropdownMenuItem(value: 'credit', child: Text('Credit')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _paymentMode = value);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Lot Number
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lot Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _lotNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Lot Name *',
                              border: OutlineInputBorder(),
                              hintText: 'e.g., Summer Stock, Batch A',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Lot name is required';
                              }
                              return null;
                            },
                            onChanged: (_) => _updateLotName(),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.blue.shade900.withValues(alpha: 0.3)
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.blue.shade700
                                    : Colors.blue.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.label,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Generated Lot: $_lotName',
                                    style: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.blue.shade200
                                          : Colors.blue.shade900,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Products Section
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.inventory_2),
                          title: const Text('Products in this Lot'),
                          subtitle: Text('${_products.length} product(s)'),
                          trailing: ElevatedButton.icon(
                            onPressed: _addProduct,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Product'),
                          ),
                        ),
                        if (_products.isNotEmpty) ...[
                          const Divider(height: 1),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final product = _products[index];
                              final name = product['product_name'] as String;
                              final quantity = product['quantity'] as double;
                              final buyingPrice = product['buying_price'] as double;
                              final sellingPrice = product['selling_price'] as double;
                              final unit = product['unit'] as String;
                              final lineTotal = quantity * buyingPrice;

                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(name.substring(0, 1).toUpperCase()),
                                ),
                                title: Text(name),
                                subtitle: Text(
                                  '$quantity $unit × $_currencySymbol${buyingPrice.toStringAsFixed(2)} = $_currencySymbol${lineTotal.toStringAsFixed(2)}\n'
                                  'Selling: $_currencySymbol${sellingPrice.toStringAsFixed(2)}/$unit',
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () => _editProduct(index),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                      onPressed: () => _deleteProduct(index),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          border: OutlineInputBorder(),
                          hintText: 'Any additional notes...',
                        ),
                        maxLines: 3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Summary Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E293B)
                    : Colors.grey.shade100,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:'),
                      Text(
                        '$_currencySymbol${_subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:', style: TextStyle(fontSize: 18)),
                      Text(
                        '$_currencySymbol${_total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _savePurchaseOrder,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Create Purchase Order',
                              style: TextStyle(fontSize: 16),
                            ),
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
  bool _isLoadingProducts = true;
  bool _isExistingProduct = false;

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
      _unit = p['unit'] ?? 'piece';
    }
  }

  Future<void> _loadExistingProducts() async {
    try {
      final names = await _productService.getAllProductNames();
      if (mounted) {
        setState(() {
          _existingProductNames = names;
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
          _unit = productDetails['unit'] ?? 'piece';

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
                // Product Name Autocomplete (allows both new and existing)
                RawAutocomplete<String>(
                  textEditingController: _nameController,
                  focusNode: FocusNode(),
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return _existingProductNames.where((name) {
                      return name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    _nameController.text = selection;
                    _onProductNameSelected(selection);
                  },
                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                    // Listen to changes to detect existing vs new
                    textEditingController.addListener(() {
                      final text = textEditingController.text;
                      final isExisting = _existingProductNames.contains(text);
                      if (isExisting != _isExistingProduct) {
                        setState(() {
                          _isExistingProduct = isExisting;
                        });
                        if (isExisting) {
                          _onProductNameSelected(text);
                        }
                      }
                    });

                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Product Name *',
                        border: const OutlineInputBorder(),
                        hintText: 'Type to search existing or enter new',
                        helperText: _isExistingProduct
                            ? 'Existing product - category and unit auto-filled'
                            : 'New product - enter all details',
                        helperStyle: TextStyle(
                          color: _isExistingProduct ? Colors.blue : Colors.grey,
                          fontSize: 11,
                        ),
                        suffixIcon: _isLoadingProducts
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                dense: true,
                                title: Text(option),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
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
                        value: _unit,
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
                      child: TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(
                          labelText: 'Category *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter category';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.words,
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
