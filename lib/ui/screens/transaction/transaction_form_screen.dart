import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/supplier_model.dart';
import '../../../services/product/product_service.dart';
import '../../../services/customer/customer_service.dart';
import '../../../services/supplier/supplier_service.dart';
import '../../../services/transaction/transaction_service.dart';

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

  final bool _isLoading = false;
  bool _isSaving = false;

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

    final selected = await showDialog<ProductModel>(
      context: context,
      builder: (context) => _ProductSelectionDialog(products: products),
    );

    if (selected != null) {
      // Check if product already in list
      final existing = _lineItems.indexWhere((item) => item['product_id'] == selected.id);

      if (existing >= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product already added. Edit quantity in the list.')),
        );
        return;
      }

      setState(() {
        _lineItems.add({
          'product_id': selected.id!,
          'product_name': selected.name,
          'product_unit': selected.unit,
          'quantity': 1.0,
          'unit_price': widget.transactionType == 'BUY'
              ? selected.defaultPurchasePrice
              : selected.defaultSellingPrice,
          'discount': 0.0,
          'tax': selected.taxRate,
          'subtotal': widget.transactionType == 'BUY'
              ? selected.defaultPurchasePrice
              : selected.defaultSellingPrice,
        });
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
                                  '${item['quantity']} ${item['product_unit']} × \$${item['unit_price'].toStringAsFixed(2)}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '\$${item['subtotal'].toStringAsFixed(2)}',
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
            '\$${amount.toStringAsFixed(2)}',
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
  final List<ProductModel> products;

  const _ProductSelectionDialog({required this.products});

  @override
  State<_ProductSelectionDialog> createState() => _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends State<_ProductSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<ProductModel> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _filteredProducts = widget.products;
  }

  void _filterProducts(String query) {
    setState(() {
      _filteredProducts = widget.products.where((product) {
        return product.name.toLowerCase().contains(query.toLowerCase()) ||
            (product.sku?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
            (product.barcode?.toLowerCase().contains(query.toLowerCase()) ?? false);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Product'),
      content: SizedBox(
        width: 500,
        height: 500,
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
              child: ListView.builder(
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = _filteredProducts[index];
                  return ListTile(
                    title: Text(product.name),
                    subtitle: Text('SKU: ${product.sku ?? 'N/A'} | Stock: ${product.currentStock?.toStringAsFixed(2) ?? '0'} ${product.unit}'),
                    trailing: Text('\$${product.defaultSellingPrice.toStringAsFixed(2)}'),
                    onTap: () => Navigator.pop(context, product),
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
      ],
    );
  }
}

// Supplier Selection Dialog
class _SupplierSelectionDialog extends StatelessWidget {
  final List<SupplierModel> suppliers;

  const _SupplierSelectionDialog({required this.suppliers});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Supplier'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: ListView.builder(
          itemCount: suppliers.length,
          itemBuilder: (context, index) {
            final supplier = suppliers[index];
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
class _CustomerSelectionDialog extends StatelessWidget {
  final List<CustomerModel> customers;

  const _CustomerSelectionDialog({required this.customers});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Customer'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: ListView.builder(
          itemCount: customers.length,
          itemBuilder: (context, index) {
            final customer = customers[index];
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
  final Function(Map<String, dynamic>) onSave;

  const _LineItemEditDialog({required this.item, required this.onSave});

  @override
  State<_LineItemEditDialog> createState() => _LineItemEditDialogState();
}

class _LineItemEditDialogState extends State<_LineItemEditDialog> {
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late TextEditingController _discountController;
  late TextEditingController _taxController;

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
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  void _save() {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    final discount = double.tryParse(_discountController.text) ?? 0;
    final tax = double.tryParse(_taxController.text) ?? 0;

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

    Navigator.pop(context);
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
            decoration: const InputDecoration(
              labelText: 'Unit Price',
              border: OutlineInputBorder(),
              prefixText: '\$ ',
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
