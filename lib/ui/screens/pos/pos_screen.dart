import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/product/product_service.dart';
import '../../../services/customer/customer_service.dart';
import '../../../services/transaction/transaction_service.dart';
import '../../../services/invoice/invoice_service.dart';
import '../../../services/currency/currency_service.dart';
import '../../../data/models/customer_model.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final ProductService _productService = ProductService();
  final CustomerService _customerService = CustomerService();
  final TransactionService _transactionService = TransactionService();
  final InvoiceService _invoiceService = InvoiceService();
  final CurrencyService _currencyService = CurrencyService();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];
  List<CustomerModel> _customers = [];

  final Map<String, _CartItem> _cart = {}; // Changed from int to String key for (productId_lotId)
  CustomerModel? _selectedCustomer;
  String _paymentMethod = 'cash';
  bool _isPercentageDiscount = true;
  bool _isLoading = false;
  String _currencySymbol = '৳';

  final double _taxRate = 0; // Can be configured

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadCurrencySymbol();
    _searchController.addListener(_filterProducts);
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
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productService.getAllProducts();
      final customers = await _customerService.getAllCustomers();

      setState(() {
        _products = products;
        _filteredProducts = products;
        _customers = customers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _products;
      } else {
        _filteredProducts = _products.where((product) {
          final productMap = product as Map<String, dynamic>;
          final name = (productMap['name'] as String?)?.toLowerCase() ?? '';
          final barcode = (productMap['barcode'] as String?)?.toLowerCase() ?? '';
          final sku = (productMap['sku'] as String?)?.toLowerCase() ?? '';
          return name.contains(query) ||
              barcode.contains(query) ||
              sku.contains(query);
        }).toList();
      }
    });
  }

  void _addToCart(Map<String, dynamic> productMap) async {
    // Get product name and fetch all lots
    final productName = (productMap['name'] as String?) ?? 'Unknown';
    final lots = await _productService.getAllLotsForProduct(productName);

    if (!mounted) return;

    if (lots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No lots available for this product')),
      );
      return;
    }

    // Show lot selection dialog
    await _showLotSelectionDialog(productName, lots);
  }

  void _removeFromCart(String cartKey) {
    setState(() {
      _cart.remove(cartKey);
    });
  }

  void _updateQuantity(String cartKey, double newQuantity, double availableStock) async {
    if (newQuantity <= 0) {
      _removeFromCart(cartKey);
      return;
    }

    // Check stock
    if (newQuantity > availableStock) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient stock')),
        );
      }
      return;
    }

    setState(() {
      _cart[cartKey]?.quantity = newQuantity;
    });
  }

  // Show lot selection dialog
  Future<void> _showLotSelectionDialog(String productName, List<Map<String, dynamic>> lots) async {
    // Track selected lots with quantities and prices
    final Map<int, TextEditingController> quantityControllers = {};
    final Map<int, TextEditingController> priceControllers = {};
    final Map<int, bool> selectedLots = {};

    // Get product image from first lot
    final productImage = lots.isNotEmpty ? (lots.first['product_image'] as String?) : null;

    // Initialize controllers with SELLING PRICE (not unit_price)
    for (final lot in lots) {
      final lotId = lot['lot_id'] as int;
      final unitPrice = ((lot['unit_price'] as num?)?.toDouble() ?? 0.0);
      final sellingPrice = ((lot['selling_price'] as num?)?.toDouble() ?? unitPrice * 1.2);
      quantityControllers[lotId] = TextEditingController();
      priceControllers[lotId] = TextEditingController(text: sellingPrice.toStringAsFixed(2));
      selectedLots[lotId] = false;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                // Product Image
                if (productImage != null)
                  Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                      image: DecorationImage(
                        image: FileImage(File(productImage)),
                        fit: BoxFit.cover,
                        onError: (_, __) => const SizedBox(),
                      ),
                    ),
                  ),
                // Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Lot(s) for $productName',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${lots.length} lot(s) available',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: lots.map((lot) {
                    final lotId = lot['lot_id'] as int;
                    final availableStock = ((lot['available_stock'] as num?)?.toDouble() ?? 0.0);
                    final unitPrice = ((lot['unit_price'] as num?)?.toDouble() ?? 0.0);
                    final sellingPrice = ((lot['selling_price'] as num?)?.toDouble() ?? unitPrice * 1.2);
                    final unit = (lot['unit'] as String?) ?? 'piece';
                    final receivedDate = lot['received_date'] as String?;
                    final isSelected = selectedLots[lotId] ?? false;

                    // Format received date
                    String formattedDate = 'Unknown';
                    if (receivedDate != null) {
                      try {
                        final date = DateTime.parse(receivedDate);
                        formattedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      } catch (e) {
                        formattedDate = receivedDate;
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: isSelected ? 4 : 2,
                      color: isSelected ? Colors.blue[50] : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? Colors.blue : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedLots[lotId] = value ?? false;
                                      if (!value!) {
                                        quantityControllers[lotId]?.clear();
                                      }
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Lot #$lotId',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Colors.blue.shade900,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            formattedDate,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.inventory_2, size: 14, color: availableStock > 0 ? Colors.green : Colors.red),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Stock: ${availableStock.toStringAsFixed(2)} $unit',
                                            style: TextStyle(
                                              color: availableStock > 0 ? Colors.green.shade700 : Colors.red.shade700,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Icon(Icons.shopping_cart, size: 14, color: Colors.grey[600]),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Purchase: $_currencySymbol${unitPrice.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    color: Colors.grey[700],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Icon(Icons.sell, size: 14, color: Colors.green[700]),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Selling: $_currencySymbol${sellingPrice.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    color: Colors.green[700],
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (isSelected) ...[
                              const Divider(height: 16),
                              Row(
                                children: [
                                  // Quantity Field
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: quantityControllers[lotId],
                                      decoration: InputDecoration(
                                        labelText: 'Quantity ($unit)',
                                        border: const OutlineInputBorder(),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        suffixText: '/ ${availableStock.toStringAsFixed(2)}',
                                        prefixIcon: const Icon(Icons.shopping_basket, size: 20),
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (value) {
                                        // Validate quantity
                                        final qty = double.tryParse(value) ?? 0;
                                        if (qty > availableStock) {
                                          quantityControllers[lotId]?.text = availableStock.toString();
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Purchase Price (Read-only)
                                  Expanded(
                                    child: TextField(
                                      controller: TextEditingController(text: unitPrice.toStringAsFixed(2)),
                                      decoration: InputDecoration(
                                        labelText: 'Purchase Price',
                                        border: const OutlineInputBorder(),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        prefixText: _currencySymbol,
                                        filled: true,
                                        fillColor: Colors.grey.shade100,
                                        prefixIcon: const Icon(Icons.shopping_cart, size: 20),
                                      ),
                                      enabled: false,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Selling Price (Editable)
                                  Expanded(
                                    child: TextField(
                                      controller: priceControllers[lotId],
                                      decoration: InputDecoration(
                                        labelText: 'Selling Price',
                                        border: const OutlineInputBorder(),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        prefixText: _currencySymbol,
                                        prefixIcon: Icon(Icons.sell, size: 20, color: Colors.green.shade700),
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Dispose controllers
                  for (final controller in quantityControllers.values) {
                    controller.dispose();
                  }
                  for (final controller in priceControllers.values) {
                    controller.dispose();
                  }
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Validate and add selected lots to cart
                  bool hasValidSelection = false;

                  for (final lot in lots) {
                    final lotId = lot['lot_id'] as int;
                    final productId = lot['product_id'] as int;
                    final isSelected = selectedLots[lotId] ?? false;

                    if (isSelected) {
                      final quantityText = quantityControllers[lotId]?.text ?? '';
                      final quantity = double.tryParse(quantityText) ?? 0;

                      final priceText = priceControllers[lotId]?.text ?? '';
                      final editedPrice = double.tryParse(priceText) ?? 0;

                      if (quantity > 0 && editedPrice > 0) {
                        final availableStock = ((lot['available_stock'] as num?)?.toDouble() ?? 0.0);
                        final unit = (lot['unit'] as String?) ?? 'piece';
                        final receivedDate = lot['received_date'] as String?;

                        // Create cart key: productId_lotId
                        final cartKey = '${productId}_$lotId';

                        // Add to cart with edited price
                        setState(() {
                          _cart[cartKey] = _CartItem(
                            productId: productId,
                            lotId: lotId,
                            productName: productName,
                            quantity: quantity,
                            unitPrice: editedPrice,  // Use edited price from controller
                            unit: unit,
                            lotNumber: lotId,
                            receivedDate: receivedDate,
                            availableStock: availableStock,
                          );
                        });

                        hasValidSelection = true;
                      }
                    }
                  }

                  // Dispose controllers
                  for (final controller in quantityControllers.values) {
                    controller.dispose();
                  }
                  for (final controller in priceControllers.values) {
                    controller.dispose();
                  }

                  Navigator.pop(context);

                  if (hasValidSelection) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lot(s) added to cart')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select lot(s) and enter quantity')),
                    );
                  }
                },
                child: const Text('Add to Cart'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Show add customer dialog
  Future<void> _showAddCustomerDialog() async {
    final nameController = TextEditingController();
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
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person_add, color: Colors.green.shade700),
            ),
            const SizedBox(width: 12),
            const Text('Add New Customer'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Customer Name *',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  autofocus: true,
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
      } else {
        try {
          // Create customer model
          final customer = CustomerModel(
            name: name,
            phone: phone,
            email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
            address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // Save customer
          final customerId = await _customerService.createCustomer(customer);

          // Reload customers
          final customers = await _customerService.getAllCustomers();

          // Select the newly created customer
          final newCustomer = customers.firstWhere(
            (c) => c.id == customerId,
            orElse: () => customers.first,
          );

          setState(() {
            _customers = customers;
            _selectedCustomer = newCustomer;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Customer "$name" added successfully')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error adding customer: $e')),
            );
          }
        }
      }
    }

    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
  }

  double _calculateSubtotal() {
    return _cart.values.fold(
      0,
      (sum, item) => sum + (item.quantity * item.unitPrice),
    );
  }

  double _calculateDiscount() {
    final subtotal = _calculateSubtotal();
    final discountValue = double.tryParse(_discountController.text) ?? 0;

    if (_isPercentageDiscount) {
      return subtotal * (discountValue / 100);
    } else {
      return discountValue;
    }
  }

  double _calculateTax() {
    final subtotal = _calculateSubtotal();
    final discount = _calculateDiscount();
    return (subtotal - discount) * (_taxRate / 100);
  }

  double _calculateTotal() {
    return _calculateSubtotal() - _calculateDiscount() + _calculateTax();
  }

  Future<void> _completeSale() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }

    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final items = _cart.entries.map((entry) {
        final item = entry.value;
        return {
          'product_id': item.productId,
          'lot_id': item.lotId,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'discount': 0.0,
          'tax': 0.0,
          'subtotal': item.quantity * item.unitPrice,
        };
      }).toList();

      final transactionId = await _transactionService.createTransaction(
        type: 'SELL',
        date: DateTime.now(),
        partyId: _selectedCustomer!.id!,
        partyType: 'customer',
        items: items,
        subtotal: _calculateSubtotal(),
        discount: _calculateDiscount(),
        tax: _calculateTax(),
        total: _calculateTotal(),
        paymentMode: _paymentMethod,
        status: 'COMPLETED',
      );

      if (mounted) {
        setState(() => _isLoading = false);

        // Show success dialog with invoice options
        await _showInvoiceOptionsDialog(transactionId);

        _clearCart();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing sale: $e')),
        );
      }
    }
  }

  Future<void> _showInvoiceOptionsDialog(int transactionId) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            const Text('Sale Completed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The sale has been completed successfully.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Would you like to generate an invoice?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _downloadInvoice(transactionId);
            },
            icon: const Icon(Icons.download),
            label: const Text('Download PDF'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _generateAndOpenInvoice(transactionId);
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('View Invoice'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadInvoice(int transactionId) async {
    try {
      final pdfPath = await _invoiceService.generateInvoicePDF(
        transactionId: transactionId,
        saveToFile: true,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Invoice Saved'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Invoice has been saved to:'),
                const SizedBox(height: 8),
                SelectableText(
                  pdfPath,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _openPDFFile(pdfPath);
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating invoice: $e')),
        );
      }
    }
  }

  Future<void> _generateAndOpenInvoice(int transactionId) async {
    try {
      final pdfPath = await _invoiceService.generateInvoicePDF(
        transactionId: transactionId,
        saveToFile: true,
      );

      await _openPDFFile(pdfPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating invoice: $e')),
        );
      }
    }
  }

  Future<void> _openPDFFile(String path) async {
    try {
      // Open the PDF file with the default PDF viewer
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening PDF: $e')),
        );
      }
    }
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _selectedCustomer = null;
      _discountController.clear();
      _paymentMethod = 'cash';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Point of Sale'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
          ),
        ],
      ),
      body: _isLoading && _products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Left side - Product selection
                Expanded(
                  flex: 2,
                  child: _buildProductSelection(),
                ),
                const VerticalDivider(width: 1),
                // Right side - Cart and checkout
                Expanded(
                  flex: 1,
                  child: _buildCartAndCheckout(),
                ),
              ],
            ),
    );
  }

  Widget _buildProductSelection() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, barcode, or SKU...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        // Product grid
        Expanded(
          child: _filteredProducts.isEmpty
              ? const Center(
                  child: Text('No products found'),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    return _buildProductCard(product);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> productMap) {
    final productName = (productMap['name'] as String?) ?? 'Unknown';
    final sellingPrice = ((productMap['default_selling_price'] as num?)?.toDouble() ?? 0.0);
    final lotsCount = ((productMap['lots_count'] as num?)?.toInt() ?? 0);
    final minPrice = ((productMap['min_price'] as num?)?.toDouble());
    final maxPrice = ((productMap['max_price'] as num?)?.toDouble());

    // Show price range if there are multiple lots with different prices
    String priceDisplay;
    if (lotsCount > 1 && minPrice != null && maxPrice != null && minPrice != maxPrice) {
      priceDisplay = '$_currencySymbol${minPrice.toStringAsFixed(2)} - $_currencySymbol${maxPrice.toStringAsFixed(2)}';
    } else {
      priceDisplay = '$_currencySymbol${sellingPrice.toStringAsFixed(2)}';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _addToCart(productMap),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image placeholder with lot badge
              Stack(
                children: [
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.inventory_2, size: 40, color: Colors.grey),
                    ),
                  ),
                  if (lotsCount > 1)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$lotsCount lots',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Product name
              Text(
                productName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              // Price
              Text(
                priceDisplay,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (lotsCount > 1)
                Text(
                  'Multiple lots',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartAndCheckout() {
    return Column(
      children: [
        // Customer selection
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Customer',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddCustomerDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Customer'),
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
              const SizedBox(height: 8),
              DropdownButtonFormField<CustomerModel>(
                value: _selectedCustomer,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  prefixIcon: const Icon(Icons.person),
                ),
                hint: const Text('Select customer'),
                items: _customers.map((customer) {
                  return DropdownMenuItem(
                    value: customer,
                    child: Text(
                      customer.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCustomer = value;
                  });
                },
              ),
            ],
          ),
        ),
        // Cart items
        Expanded(
          child: _cart.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Cart is empty',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _cart.length,
                  itemBuilder: (context, index) {
                    final cartItem = _cart.values.elementAt(index);
                    return _buildCartItem(cartItem);
                  },
                ),
        ),
        // Checkout section
        _buildCheckoutSection(),
      ],
    );
  }

  Widget _buildCartItem(_CartItem item) {
    final cartKey = '${item.productId}_${item.lotId}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Lot #${item.lotNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: () => _removeFromCart(cartKey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Quantity controls
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16),
                        onPressed: () {
                          _updateQuantity(
                            cartKey,
                            item.quantity - 1,
                            item.availableStock,
                          );
                        },
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text(
                          '${item.quantity} ${item.unit}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        onPressed: () {
                          _updateQuantity(
                            cartKey,
                            item.quantity + 1,
                            item.availableStock,
                          );
                        },
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text('x'),
                const SizedBox(width: 8),
                // Unit price
                Expanded(
                  child: Text(
                    '$_currencySymbol${item.unitPrice.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
                // Line total
                Text(
                  '$_currencySymbol${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutSection() {
    final subtotal = _calculateSubtotal();
    final discount = _calculateDiscount();
    final tax = _calculateTax();
    final total = _calculateTotal();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Payment method
          Row(
            children: [
              const Text(
                'Payment:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'cash', label: Text('Cash')),
                    ButtonSegment(value: 'credit', label: Text('Card')),
                    ButtonSegment(value: 'bank', label: Text('Bank')),
                  ],
                  selected: {_paymentMethod},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _paymentMethod = newSelection.first;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Discount
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _discountController,
                  decoration: InputDecoration(
                    labelText: 'Discount',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              SegmentedButton<bool>(
                segments: [
                  const ButtonSegment(value: true, label: Text('%')),
                  ButtonSegment(value: false, label: Text(_currencySymbol)),
                ],
                selected: {_isPercentageDiscount},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _isPercentageDiscount = newSelection.first;
                  });
                },
              ),
            ],
          ),
          const Divider(height: 24),
          // Totals
          _buildTotalRow('Subtotal', subtotal),
          _buildTotalRow('Discount', -discount, color: Colors.red),
          _buildTotalRow('Tax', tax),
          const Divider(height: 16),
          _buildTotalRow('Total', total, isTotal: true),
          const SizedBox(height: 16),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cart.isEmpty ? null : _clearCart,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _cart.isEmpty || _isLoading ? null : _completeSale,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Complete Sale'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {Color? color, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
          Text(
            '$_currencySymbol${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 20 : 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItem {
  final int productId;
  final int lotId;
  final String productName;
  double quantity;
  final double unitPrice;
  final String unit;
  final int lotNumber;
  final String? receivedDate;
  final double availableStock;

  _CartItem({
    required this.productId,
    required this.lotId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.unit,
    required this.lotNumber,
    this.receivedDate,
    required this.availableStock,
  });
}
