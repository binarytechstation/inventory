import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/supplier_model.dart';
import '../../../services/product/product_service.dart';
import '../../../services/customer/customer_service.dart';
import '../../../services/supplier/supplier_service.dart';
import '../../../services/transaction/transaction_service.dart';
import '../../../services/currency/currency_service.dart';

class TransactionFormScreen extends StatefulWidget {
  final String transactionType; // 'BUY' or 'SELL'

  const TransactionFormScreen({
    super.key,
    required this.transactionType,
  });

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _productService = ProductService();
  final CustomerService _customerService = CustomerService();
  final SupplierService _supplierService = SupplierService();
  final TransactionService _transactionService = TransactionService();
  final CurrencyService _currencyService = CurrencyService();

  // Transaction data
  DateTime _transactionDate = DateTime.now();
  String _paymentMode = 'cash';
  dynamic _selectedParty; // CustomerModel or SupplierModel
  final TextEditingController _notesController = TextEditingController();

  // Line items
  final List<Map<String, dynamic>> _lineItems = [];

  // Calculations
  double _subtotal = 0;
  double _discount = 0;
  double _tax = 0;
  double _total = 0;

  bool _isSaving = false;
  String _currencySymbol = '৳';

  @override
  void initState() {
    super.initState();
    _loadCurrencySymbol();
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
    _notesController.dispose();
    super.dispose();
  }

  String get _partyLabel => widget.transactionType == 'BUY' ? 'Supplier' : 'Customer';
  String get _transactionLabel => widget.transactionType == 'BUY' ? 'Purchase Order' : 'Sales Invoice';

  void _calculateTotals() {
    _subtotal = 0;
    _tax = 0;
    _discount = 0;

    for (final item in _lineItems) {
      final quantity = item['quantity'] as double;
      final unitPrice = item['unit_price'] as double;
      final itemDiscount = item['discount'] as double;
      final itemTax = item['tax'] as double;

      final itemSubtotal = quantity * unitPrice;
      final discountAmount = (itemSubtotal * itemDiscount) / 100;
      final afterDiscount = itemSubtotal - discountAmount;
      final taxAmount = (afterDiscount * itemTax) / 100;

      _subtotal += itemSubtotal;
      _discount += discountAmount;
      _tax += taxAmount;
    }

    _total = _subtotal - _discount + _tax;
    setState(() {});
  }

  Future<void> _addProduct() async {
    final products = await _productService.getAllProducts();
    if (!mounted) return;

    final selectedProducts = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => _ProductSelectionDialog(
        products: products,
        transactionType: widget.transactionType,
        existingLineItems: _lineItems,
      ),
    );

    if (selectedProducts != null && selectedProducts.isNotEmpty) {
      setState(() {
        for (final productData in selectedProducts) {
          // Check if product already exists
          final existing = _lineItems.indexWhere(
            (item) => item['product_id'] == productData['product_id'],
          );

          if (existing >= 0) {
            // Update existing quantity
            _lineItems[existing]['quantity'] =
                (_lineItems[existing]['quantity'] as double) + (productData['quantity'] as double);

            final quantity = _lineItems[existing]['quantity'] as double;
            final unitPrice = _lineItems[existing]['unit_price'] as double;
            final discount = _lineItems[existing]['discount'] as double;
            final tax = _lineItems[existing]['tax'] as double;

            final itemSubtotal = quantity * unitPrice;
            final discountAmount = (itemSubtotal * discount) / 100;
            final afterDiscount = itemSubtotal - discountAmount;
            final taxAmount = (afterDiscount * tax) / 100;

            _lineItems[existing]['subtotal'] = afterDiscount + taxAmount;
          } else {
            // Add new product
            _lineItems.add(productData);
          }
        }
      });
      _calculateTotals();
    }
  }

  Future<void> _selectParty() async {
    if (widget.transactionType == 'BUY') {
      final suppliers = await _supplierService.getAllSuppliers();
      if (!mounted) return;

      final selected = await showDialog<SupplierModel>(
        context: context,
        builder: (context) => _SupplierSelectionDialog(suppliers: suppliers),
      );

      if (selected != null) {
        setState(() => _selectedParty = selected);
      }
    } else {
      final customers = await _customerService.getAllCustomers();
      if (!mounted) return;

      final selected = await showDialog<CustomerModel>(
        context: context,
        builder: (context) => _CustomerSelectionDialog(customers: customers),
      );

      if (selected != null) {
        setState(() => _selectedParty = selected);
      }
    }
  }

  void _editLineItem(int index) {
    final item = _lineItems[index];
    showDialog(
      context: context,
      builder: (context) => _LineItemEditDialog(
        item: item,
        transactionType: widget.transactionType,
        onSave: (updatedItem) {
          setState(() {
            _lineItems[index] = updatedItem;
          });
          _calculateTotals();
        },
      ),
    );
  }

  void _removeLineItem(int index) {
    setState(() {
      _lineItems.removeAt(index);
    });
    _calculateTotals();
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a $_partyLabel')),
      );
      return;
    }

    if (_lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _transactionService.createTransaction(
        type: widget.transactionType,
        date: _transactionDate,
        partyId: _selectedParty.id!,
        partyType: widget.transactionType == 'BUY' ? 'supplier' : 'customer',
        items: _lineItems,
        subtotal: _subtotal,
        discount: _discount,
        tax: _tax,
        total: _total,
        paymentMode: _paymentMode,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_transactionLabel created successfully'),
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
        title: Text('New $_transactionLabel'),
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
                  // Party Selection
                  Card(
                    child: ListTile(
                      leading: Icon(
                        widget.transactionType == 'BUY'
                            ? Icons.local_shipping
                            : Icons.person,
                        color: Colors.blue,
                      ),
                      title: Text(_selectedParty == null
                          ? 'Select $_partyLabel'
                          : _selectedParty.name),
                      subtitle: _selectedParty != null
                          ? Text(_selectedParty.companyName ?? _selectedParty.phone ?? '')
                          : Text('Tap to select $_partyLabel'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _selectParty,
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
                              '${_transactionDate.day}/${_transactionDate.month}/${_transactionDate.year}',
                            ),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _transactionDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => _transactionDate = date);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Payment Mode', style: TextStyle(fontSize: 12)),
                                const SizedBox(height: 8),
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(value: 'cash', label: Text('Cash')),
                                    ButtonSegment(value: 'credit', label: Text('Credit')),
                                  ],
                                  selected: {_paymentMode},
                                  onSelectionChanged: (Set<String> selection) {
                                    setState(() => _paymentMode = selection.first);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Products Section
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text(
                            'Products',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: ElevatedButton.icon(
                            onPressed: _addProduct,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Product'),
                          ),
                        ),
                        if (_lineItems.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                              'No products added yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _lineItems.length,
                            itemBuilder: (context, index) {
                              final item = _lineItems[index];
                              return ListTile(
                                title: Text(item['product_name']),
                                subtitle: Text(
                                  '${item['quantity']} ${item['product_unit']} × $_currencySymbol${item['unit_price'].toStringAsFixed(2)}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$_currencySymbol${item['subtotal'].toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () => _editLineItem(index),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                      onPressed: () => _removeLineItem(index),
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
              decoration: BoxDecoration(
                color: Colors.grey[100],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSummaryRow('Subtotal', _subtotal),
                  _buildSummaryRow('Discount', -_discount, color: Colors.red),
                  _buildSummaryRow('Tax', _tax),
                  const Divider(thickness: 2),
                  _buildSummaryRow('Total', _total, isTotal: true),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : () => Navigator.pop(context),
                          child: const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Cancel'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveTransaction,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text('Save $_transactionLabel'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {Color? color, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '$_currencySymbol${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 20 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Product Selection Dialog
class _ProductSelectionDialog extends StatefulWidget {
  final List<dynamic> products;
  final String transactionType;
  final List<Map<String, dynamic>> existingLineItems;

  const _ProductSelectionDialog({
    required this.products,
    required this.transactionType,
    required this.existingLineItems,
  });

  @override
  State<_ProductSelectionDialog> createState() => _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends State<_ProductSelectionDialog> {
  final ProductService _productService = ProductService();
  final CurrencyService _currencyService = CurrencyService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredProducts = [];
  List<dynamic> _allProducts = [];
  String _currencySymbol = '৳';

  // Track selected products with quantities
  final Map<int, double> _selectedProducts = {};

  @override
  void initState() {
    super.initState();
    _allProducts = widget.products;
    _filteredProducts = widget.products;
    _loadCurrencySymbol();
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
    _searchController.dispose();
    super.dispose();
  }

  void _filterProducts(String query) {
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        final productMap = product as Map<String, dynamic>;
        final name = (productMap['name'] as String?)?.toLowerCase() ?? '';
        final sku = (productMap['sku'] as String?)?.toLowerCase() ?? '';
        final barcode = (productMap['barcode'] as String?)?.toLowerCase() ?? '';
        return name.contains(query.toLowerCase()) ||
            sku.contains(query.toLowerCase()) ||
            barcode.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _addNewProduct() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const _InlineProductFormDialog(),
    );

    if (result == true) {
      // Refresh product list
      final products = await _productService.getAllProducts();
      setState(() {
        _allProducts = products;
        _filteredProducts = products;
        _searchController.clear();
      });
    }
  }

  void _toggleProduct(Map<String, dynamic> productMap) {
    final productId = productMap['id'] as int;
    setState(() {
      if (_selectedProducts.containsKey(productId)) {
        _selectedProducts.remove(productId);
      } else {
        _selectedProducts[productId] = 1.0;
      }
    });
  }

  void _incrementQuantity(int productId) {
    // For SELL transactions, check if quantity exceeds available stock
    if (widget.transactionType == 'SELL') {
      final productMap = _allProducts.firstWhere(
        (p) => (p as Map<String, dynamic>)['id'] == productId
      ) as Map<String, dynamic>;
      final currentQty = _selectedProducts[productId] ?? 1.0;
      final newQty = currentQty + 1.0;
      final availableStock = ((productMap['current_stock'] as num?)?.toDouble() ?? 0.0);
      final productUnit = (productMap['unit'] as String?) ?? 'piece';

      // Check existing quantity in line items
      final existingItem = widget.existingLineItems.firstWhere(
        (item) => item['product_id'] == productId,
        orElse: () => {},
      );
      final existingQty = existingItem.isNotEmpty ? (existingItem['quantity'] as double?) ?? 0.0 : 0.0;

      if (newQty + existingQty > availableStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot exceed available stock (${availableStock.toStringAsFixed(2)} $productUnit)',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() {
      _selectedProducts[productId] = (_selectedProducts[productId] ?? 1.0) + 1.0;
    });
  }

  void _decrementQuantity(int productId) {
    setState(() {
      final currentQty = _selectedProducts[productId] ?? 1.0;
      if (currentQty > 1.0) {
        _selectedProducts[productId] = currentQty - 1.0;
      } else {
        _selectedProducts.remove(productId);
      }
    });
  }

  void _proceedWithSelection() {
    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one product')),
      );
      return;
    }

    final selectedProductData = <Map<String, dynamic>>[];

    for (final entry in _selectedProducts.entries) {
      final productId = entry.key;
      final quantity = entry.value;

      final productMap = _allProducts.firstWhere(
        (p) => (p as Map<String, dynamic>)['id'] == productId
      ) as Map<String, dynamic>;

      final unitPrice = widget.transactionType == 'BUY'
          ? ((productMap['default_purchase_price'] as num?)?.toDouble() ?? 0.0)
          : ((productMap['default_selling_price'] as num?)?.toDouble() ?? 0.0);

      selectedProductData.add({
        'product_id': productMap['id'] as int,
        'lot_id': 1, // Default to lot 1 for compatibility
        'product_name': (productMap['name'] as String?) ?? 'Unknown',
        'product_unit': (productMap['unit'] as String?) ?? 'piece',
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount': 0.0,
        'tax': ((productMap['tax_rate'] as num?)?.toDouble() ?? 0.0),
        'subtotal': quantity * unitPrice,
      });
    }

    Navigator.pop(context, selectedProductData);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Select Products (${_selectedProducts.length})'),
          TextButton.icon(
            onPressed: _addNewProduct,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add New'),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 600,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by name, SKU, or barcode...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterProducts,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredProducts.isEmpty
                  ? const Center(
                      child: Text(
                        'No products found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final productMap = _filteredProducts[index] as Map<String, dynamic>;
                        final productId = productMap['id'] as int;
                        final productName = (productMap['name'] as String?) ?? 'Unknown';
                        final productSku = (productMap['sku'] as String?) ?? 'N/A';
                        final productStock = ((productMap['current_stock'] as num?)?.toDouble() ?? 0.0);
                        final productUnit = (productMap['unit'] as String?) ?? 'piece';
                        final productPrice = widget.transactionType == 'BUY'
                            ? ((productMap['default_purchase_price'] as num?)?.toDouble() ?? 0.0)
                            : ((productMap['default_selling_price'] as num?)?.toDouble() ?? 0.0);

                        final isSelected = _selectedProducts.containsKey(productId);
                        final quantity = _selectedProducts[productId] ?? 1.0;

                        return Card(
                          color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                          child: ListTile(
                            leading: Checkbox(
                              value: isSelected,
                              onChanged: (value) => _toggleProduct(productMap),
                            ),
                            title: Text(productName),
                            subtitle: Text(
                              'SKU: $productSku | Stock: ${productStock.toStringAsFixed(2)} $productUnit\n'
                              'Price: $_currencySymbol${productPrice.toStringAsFixed(2)}',
                            ),
                            trailing: isSelected
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        onPressed: () => _decrementQuantity(productId),
                                        color: Colors.red,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          quantity.toStringAsFixed(0),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        onPressed: () => _incrementQuantity(productId),
                                        color: Colors.green,
                                      ),
                                    ],
                                  )
                                : null,
                            onTap: () => _toggleProduct(productMap),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _selectedProducts.isEmpty ? null : _proceedWithSelection,
          icon: const Icon(Icons.check),
          label: Text('Proceed (${_selectedProducts.length})'),
        ),
      ],
    );
  }
}

// Supplier Selection Dialog
class _SupplierSelectionDialog extends StatefulWidget {
  final List<SupplierModel> suppliers;

  const _SupplierSelectionDialog({required this.suppliers});

  @override
  State<_SupplierSelectionDialog> createState() => _SupplierSelectionDialogState();
}

class _SupplierSelectionDialogState extends State<_SupplierSelectionDialog> {
  final SupplierService _supplierService = SupplierService();
  List<SupplierModel> _suppliers = [];

  @override
  void initState() {
    super.initState();
    _suppliers = widget.suppliers;
  }

  Future<void> _addNewSupplier() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const _InlineSupplierFormDialog(),
    );

    if (result == true) {
      // Refresh supplier list
      final suppliers = await _supplierService.getAllSuppliers();
      setState(() {
        _suppliers = suppliers;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Select Supplier'),
          TextButton.icon(
            onPressed: _addNewSupplier,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add New'),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 400,
        child: _suppliers.isEmpty
            ? const Center(
                child: Text(
                  'No suppliers found',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : ListView.builder(
                itemCount: _suppliers.length,
                itemBuilder: (context, index) {
                  final supplier = _suppliers[index];
                  return ListTile(
                    title: Text(supplier.name),
                    subtitle: Text(supplier.companyName ?? supplier.phone ?? ''),
                    onTap: () => Navigator.pop(context, supplier),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// Customer Selection Dialog
class _CustomerSelectionDialog extends StatefulWidget {
  final List<CustomerModel> customers;

  const _CustomerSelectionDialog({required this.customers});

  @override
  State<_CustomerSelectionDialog> createState() => _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends State<_CustomerSelectionDialog> {
  final CustomerService _customerService = CustomerService();
  List<CustomerModel> _customers = [];

  @override
  void initState() {
    super.initState();
    _customers = widget.customers;
  }

  Future<void> _addNewCustomer() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const _InlineCustomerFormDialog(),
    );

    if (result == true) {
      // Refresh customer list
      final customers = await _customerService.getAllCustomers();
      setState(() {
        _customers = customers;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Select Customer'),
          TextButton.icon(
            onPressed: _addNewCustomer,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add New'),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 400,
        child: _customers.isEmpty
            ? const Center(
                child: Text(
                  'No customers found',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : ListView.builder(
                itemCount: _customers.length,
                itemBuilder: (context, index) {
                  final customer = _customers[index];
                  return ListTile(
                    title: Text(customer.name),
                    subtitle: Text(customer.companyName ?? customer.phone ?? ''),
                    onTap: () => Navigator.pop(context, customer),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// Line Item Edit Dialog
class _LineItemEditDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final String transactionType;
  final Function(Map<String, dynamic>) onSave;

  const _LineItemEditDialog({
    required this.item,
    required this.transactionType,
    required this.onSave,
  });

  @override
  State<_LineItemEditDialog> createState() => _LineItemEditDialogState();
}

class _LineItemEditDialogState extends State<_LineItemEditDialog> {
  final CurrencyService _currencyService = CurrencyService();
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late TextEditingController _discountController;
  late TextEditingController _taxController;
  String _currencySymbol = '৳';

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.item['quantity'].toString(),
    );
    _priceController = TextEditingController(
      text: widget.item['unit_price'].toString(),
    );
    _discountController = TextEditingController(
      text: widget.item['discount'].toString(),
    );
    _taxController = TextEditingController(
      text: widget.item['tax'].toString(),
    );
    _loadCurrencySymbol();
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
    _quantityController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  void _save() async {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    final discount = double.tryParse(_discountController.text) ?? 0;
    final tax = double.tryParse(_taxController.text) ?? 0;

    // For SELL transactions, validate stock
    if (widget.transactionType == 'SELL') {
      final productId = widget.item['product_id'] as int;
      final productService = ProductService();

      try {
        final product = await productService.getProductById(productId);
        if (product != null) {
          final availableStock = product.currentStock ?? 0.0;

          if (quantity > availableStock) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Cannot exceed available stock (${availableStock.toStringAsFixed(2)} ${product.unit})',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
        }
      } catch (e) {
        // Continue if product fetch fails
      }
    }

    final subtotal = quantity * price;
    final discountAmount = (subtotal * discount) / 100;
    final afterDiscount = subtotal - discountAmount;
    final taxAmount = (afterDiscount * tax) / 100;
    final total = afterDiscount + taxAmount;

    widget.onSave({
      ...widget.item,
      'quantity': quantity,
      'unit_price': price,
      'discount': discount,
      'tax': tax,
      'subtotal': total,
    });

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.item['product_name']}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _quantityController,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceController,
            decoration: InputDecoration(
              labelText: 'Unit Price',
              border: const OutlineInputBorder(),
              prefixText: '$_currencySymbol ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _discountController,
                  decoration: const InputDecoration(
                    labelText: 'Discount %',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _taxController,
                  decoration: const InputDecoration(
                    labelText: 'Tax %',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                ),
              ),
            ],
          ),
        ],
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

// Inline Customer Form Dialog
class _InlineCustomerFormDialog extends StatefulWidget {
  const _InlineCustomerFormDialog();

  @override
  State<_InlineCustomerFormDialog> createState() => _InlineCustomerFormDialogState();
}

class _InlineCustomerFormDialogState extends State<_InlineCustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final CustomerService _customerService = CustomerService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _companyNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final customer = CustomerModel(
        name: _nameController.text.trim(),
        companyName: _companyNameController.text.trim().isEmpty
            ? null
            : _companyNameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        creditLimit: 0,
        currentBalance: 0,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _customerService.createCustomer(customer);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer created successfully'),
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Customer'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter customer name';
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _companyNameController,
                  decoration: const InputDecoration(
                    labelText: 'Company Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveCustomer,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

// Inline Supplier Form Dialog
class _InlineSupplierFormDialog extends StatefulWidget {
  const _InlineSupplierFormDialog();

  @override
  State<_InlineSupplierFormDialog> createState() => _InlineSupplierFormDialogState();
}

class _InlineSupplierFormDialogState extends State<_InlineSupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final SupplierService _supplierService = SupplierService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _companyNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supplier = SupplierModel(
        name: _nameController.text.trim(),
        companyName: _companyNameController.text.trim().isEmpty
            ? null
            : _companyNameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _supplierService.createSupplier(supplier);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supplier created successfully'),
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Supplier'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Supplier Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter supplier name';
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _companyNameController,
                  decoration: const InputDecoration(
                    labelText: 'Company Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveSupplier,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

// Inline Product Form Dialog
class _InlineProductFormDialog extends StatefulWidget {
  const _InlineProductFormDialog();

  @override
  State<_InlineProductFormDialog> createState() => _InlineProductFormDialogState();
}

class _InlineProductFormDialogState extends State<_InlineProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _productService = ProductService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _unitController = TextEditingController(text: 'piece');
  final TextEditingController _purchasePriceController = TextEditingController(text: '0');
  final TextEditingController _sellingPriceController = TextEditingController(text: '0');
  final TextEditingController _taxRateController = TextEditingController(text: '0');

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _unitController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final product = ProductModel(
        name: _nameController.text.trim(),
        sku: _skuController.text.trim().isEmpty
            ? null
            : _skuController.text.trim(),
        unit: _unitController.text.trim(),
        defaultPurchasePrice: double.tryParse(_purchasePriceController.text.trim()) ?? 0,
        defaultSellingPrice: double.tryParse(_sellingPriceController.text.trim()) ?? 0,
        taxRate: double.tryParse(_taxRateController.text.trim()) ?? 0,
        reorderLevel: 0,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _productService.createProduct(product);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product created successfully'),
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Product'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory_2),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter product name';
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _skuController,
                  decoration: const InputDecoration(
                    labelText: 'SKU',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _unitController,
                  decoration: const InputDecoration(
                    labelText: 'Unit *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.straighten),
                    hintText: 'e.g., piece, kg, box',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter unit';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _purchasePriceController,
                        decoration: const InputDecoration(
                          labelText: 'Purchase Price *',
                          border: OutlineInputBorder(),
                          prefixText: '\$ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          final amount = double.tryParse(value.trim());
                          if (amount == null || amount < 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _sellingPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Selling Price *',
                          border: OutlineInputBorder(),
                          prefixText: '\$ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          final amount = double.tryParse(value.trim());
                          if (amount == null || amount < 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _taxRateController,
                  decoration: const InputDecoration(
                    labelText: 'Tax Rate (%)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.percent),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final rate = double.tryParse(value.trim());
                      if (rate == null || rate < 0 || rate > 100) {
                        return 'Enter valid rate (0-100)';
                      }
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveProduct,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
