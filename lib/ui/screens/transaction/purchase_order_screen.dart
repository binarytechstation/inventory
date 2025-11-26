import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/supplier_model.dart';
import '../../../services/supplier/supplier_service.dart';
import '../../../services/transaction/transaction_service.dart';
import '../../../services/currency/currency_service.dart';

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
    final dateStr = _transactionDate.toString().split(' ')[0];
    setState(() {
      _lotName = _lotNumberController.text.isEmpty
          ? 'LOT-$dateStr'
          : 'LOT${_lotNumberController.text}-$dateStr';
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

    final selected = await showDialog<SupplierModel>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Supplier'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: suppliers.isEmpty
              ? const Center(child: Text('No suppliers available'))
              : ListView.builder(
                  itemCount: suppliers.length,
                  itemBuilder: (context, index) {
                    final supplier = suppliers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(supplier.name.substring(0, 1).toUpperCase()),
                      ),
                      title: Text(supplier.name),
                      subtitle: supplier.companyName != null
                          ? Text(supplier.companyName!)
                          : null,
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
      ),
    );

    if (selected != null) {
      setState(() => _selectedSupplier = selected);
    }
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

    if (_lotNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a lot number')),
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
        'lot_name': _lotName,
        'received_date': _transactionDate.toIso8601String(),
        'description': 'Purchase from ${_selectedSupplier!.name}',
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
                              labelText: 'Lot Number *',
                              border: OutlineInputBorder(),
                              hintText: 'e.g., 001, A1, 2025-01',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a lot number';
                              }
                              return null;
                            },
                            onChanged: (_) => _updateLotName(),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.label, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Lot Name: $_lotName',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.w600,
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
                color: Colors.grey.shade100,
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
  final _reorderLevelController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _unit = 'piece';

  @override
  void initState() {
    super.initState();

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
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
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
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _reorderLevelController,
                        decoration: const InputDecoration(
                          labelText: 'Reorder Level',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
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
