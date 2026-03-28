import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/models/customer_model.dart';
import '../../../services/currency/currency_service.dart';
import '../../../services/customer/customer_service.dart';
import '../../../services/invoice/invoice_service.dart';
import '../../../services/product/product_service.dart';
import '../../../services/transaction/transaction_service.dart';
import '../../providers/auth_provider.dart';

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
  final TextEditingController _cashPaidController = TextEditingController();

  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];
  List<CustomerModel> _customers = [];

  final Map<String, _CartItem> _cart =
      {}; // Changed from int to String key for (productId_lotId)
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
    _cashPaidController.dispose();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
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
          final barcode =
              (productMap['barcode'] as String?)?.toLowerCase() ?? '';
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

  void _updateQuantity(
    String cartKey,
    double newQuantity,
    double availableStock,
  ) async {
    if (newQuantity <= 0) {
      _removeFromCart(cartKey);
      return;
    }

    // Check stock
    if (newQuantity > availableStock) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Insufficient stock')));
      }
      return;
    }

    setState(() {
      _cart[cartKey]?.quantity = newQuantity;
    });
  }

  // Show lot selection dialog
  Future<void> _showLotSelectionDialog(
    String productName,
    List<Map<String, dynamic>> lots,
  ) async {
    // Track selected lots with quantities and prices
    final Map<int, TextEditingController> quantityControllers = {};
    final Map<int, TextEditingController> priceControllers = {};
    final Map<int, bool> selectedLots = {};

    // Get product image from first lot
    final productImage = lots.isNotEmpty
        ? (lots.first['product_image'] as String?)
        : null;

    // Calculate total available stock across all lots
    final double totalAvailableStock = lots.fold(0.0,
        (sum, lot) => sum + ((lot['available_stock'] as num?)?.toDouble() ?? 0.0));
    final String productUnit = lots.isNotEmpty ? (lots.first['unit'] as String? ?? 'piece') : 'piece';
    final String totalStockLabel = totalAvailableStock % 1 == 0
        ? '${totalAvailableStock.toInt()} $productUnit'
        : '${totalAvailableStock.toStringAsFixed(2)} $productUnit';

    // Initialize controllers with SELLING PRICE (not unit_price)
    for (final lot in lots) {
      final lotId = lot['lot_id'] as int;
      final unitPrice = ((lot['unit_price'] as num?)?.toDouble() ?? 0.0);
      final sellingPrice =
          ((lot['selling_price'] as num?)?.toDouble() ?? unitPrice * 1.2);
      quantityControllers[lotId] = TextEditingController();
      priceControllers[lotId] = TextEditingController(
        text: sellingPrice.toStringAsFixed(2),
      );
      selectedLots[lotId] = false;
    }

    // Only Admin can see purchase/cost prices
    final bool isAdmin = Provider.of<AuthProvider>(context, listen: false)
        .currentUser?.role == 'Admin';

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
                        onError: (_, _) => const SizedBox(),
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
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${lots.length} lot(s)',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: totalAvailableStock > 0
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2,
                                  size: 12,
                                  color: totalAvailableStock > 0
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Total: $totalStockLabel',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: totalAvailableStock > 0
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
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
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: lots.map((lot) {
                    final lotId = lot['lot_id'] as int;
                    final availableStock =
                        ((lot['available_stock'] as num?)?.toDouble() ?? 0.0);
                    final unitPrice =
                        ((lot['unit_price'] as num?)?.toDouble() ?? 0.0);
                    final sellingPrice =
                        ((lot['selling_price'] as num?)?.toDouble() ??
                        unitPrice * 1.2);
                    final unit = (lot['unit'] as String?) ?? 'piece';
                    final receivedDate = lot['received_date'] as String?;
                    final lotDescription = lot['lot_description'] as String?; // Generated lot name
                    final isSelected = selectedLots[lotId] ?? false;

                    // Format received date
                    String formattedDate = 'Unknown';
                    if (receivedDate != null) {
                      try {
                        final date = DateTime.parse(receivedDate);
                        formattedDate =
                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      } catch (e) {
                        formattedDate = receivedDate;
                      }
                    }

                    final isDark = Theme.of(context).brightness == Brightness.dark;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: isSelected ? 4 : 2,
                      color: isSelected
                          ? (isDark ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue[50])
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.blue
                              : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Show generated lot name prominently
                                      if (lotDescription != null && lotDescription.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: isDark
                                                  ? [Colors.green.shade900.withValues(alpha: 0.3), Colors.green.shade800.withValues(alpha: 0.3)]
                                                  : [Colors.green.shade100, Colors.green.shade50],
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isDark ? Colors.green.shade700 : Colors.green.shade300,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.label,
                                                size: 14,
                                                color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  lotDescription,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: isDark ? Colors.green.shade200 : Colors.green.shade900,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.blue.shade900.withValues(alpha: 0.3)
                                                    : Colors.blue.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Lot #$lotId',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: isDark ? Colors.blue.shade300 : Colors.blue.shade900,
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
                                          Icon(
                                            Icons.inventory_2,
                                            size: 14,
                                            color: availableStock > 0
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Stock: ${availableStock.toStringAsFixed(2)} $unit',
                                            style: TextStyle(
                                              color: availableStock > 0
                                                  ? Colors.green.shade700
                                                  : Colors.red.shade700,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (isAdmin) ...[
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.shopping_cart,
                                                    size: 14,
                                                    color: Colors.grey[600],
                                                  ),
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
                                          ],
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.sell,
                                                  size: 14,
                                                  color: Colors.green[700],
                                                ),
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
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                        suffixText:
                                            '/ ${availableStock.toStringAsFixed(2)}',
                                        prefixIcon: const Icon(
                                          Icons.shopping_basket,
                                          size: 20,
                                        ),
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      onChanged: (value) {
                                        // Validate quantity
                                        final qty = double.tryParse(value) ?? 0;
                                        if (qty > availableStock) {
                                          quantityControllers[lotId]?.text =
                                              availableStock.toString();
                                        }
                                      },
                                    ),
                                  ),
                                  if (isAdmin) ...[
                                    const SizedBox(width: 8),
                                    // Purchase Price (Read-only — Admin only)
                                    Expanded(
                                      child: TextField(
                                        controller: TextEditingController(
                                          text: unitPrice.toStringAsFixed(2),
                                        ),
                                        decoration: InputDecoration(
                                          labelText: 'Purchase Price',
                                          labelStyle: TextStyle(
                                            color: isDark ? Colors.grey[400] : null,
                                          ),
                                          border: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                          prefixText: _currencySymbol,
                                          filled: true,
                                          fillColor: isDark
                                              ? const Color(0xFF334155)
                                              : Colors.grey.shade100,
                                          prefixIcon: Icon(
                                            Icons.shopping_cart,
                                            size: 20,
                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                          ),
                                        ),
                                        enabled: false,
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  // Selling Price (Editable)
                                  Expanded(
                                    child: TextField(
                                      controller: priceControllers[lotId],
                                      decoration: InputDecoration(
                                        labelText: 'Selling Price',
                                        border: const OutlineInputBorder(),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                        prefixText: _currencySymbol,
                                        prefixIcon: Icon(
                                          Icons.sell,
                                          size: 20,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
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
                      final quantityText =
                          quantityControllers[lotId]?.text ?? '';
                      final quantity = double.tryParse(quantityText) ?? 0;

                      final priceText = priceControllers[lotId]?.text ?? '';
                      final editedPrice = double.tryParse(priceText) ?? 0;

                      if (quantity > 0 && editedPrice > 0) {
                        final availableStock =
                            ((lot['available_stock'] as num?)?.toDouble() ??
                            0.0);
                        final unit = (lot['unit'] as String?) ?? 'piece';
                        final receivedDate = lot['received_date'] as String?;

                        // Create cart key: productId_lotId
                        final cartKey = '${productId}_$lotId';

                        // Add to cart with edited price
                        // setState(() {
                        //   _cart[cartKey] = _CartItem(
                        //     productId: productId,
                        //     lotId: lotId,
                        //     productName: productName,
                        //     quantity: quantity,
                        //     unitPrice:
                        //         editedPrice, // Use edited price from controller
                        //     unit: unit,
                        //     lotNumber: lotId,
                        //     receivedDate: receivedDate,
                        //     availableStock: availableStock,
                        //   );
                        // });
                        setState(() {
                          _cart[cartKey] = _CartItem(
                            productId: productId,
                            lotId: lotId,
                            productName: productName,
                            quantity: quantity,
                            unitPrice:
                                editedPrice, // Use edited price from controller
                            unit: unit,
                            lotNumber: lotId,
                            receivedDate: receivedDate,
                            availableStock: availableStock,
                            productImage: productImage, // Add this line
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
                      const SnackBar(
                        content: Text(
                          'Please select lot(s) and enter quantity',
                        ),
                      ),
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
            email: emailController.text.trim().isEmpty
                ? null
                : emailController.text.trim(),
            address: addressController.text.trim().isEmpty
                ? null
                : addressController.text.trim(),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return;
    }

    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a customer')));
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

      final total = _calculateTotal();
      final transactionId = await _transactionService.createTransaction(
        type: 'SELL',
        date: DateTime.now(),
        partyId: _selectedCustomer!.id!,
        partyType: 'customer',
        items: items,
        subtotal: _calculateSubtotal(),
        discount: _calculateDiscount(),
        tax: _calculateTax(),
        total: total,
        paymentMode: _paymentMethod,
        paidAmount: _paymentMethod == 'partial'
            ? (double.tryParse(_cashPaidController.text) ?? 0).clamp(0, total)
            : null,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error completing sale: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating invoice: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating invoice: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening PDF: $e')));
      }
    }
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _selectedCustomer = null;
      _discountController.clear();
      _cashPaidController.clear();
      _paymentMethod = 'cash';
    });
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
              child: const Icon(Icons.point_of_sale, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Point of Sale', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_cart.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_cart_rounded, size: 13, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('${_cart.length}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadInitialData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading && _products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Left side - Product selection
                Expanded(flex: 2, child: _buildProductSelection()),
                const VerticalDivider(width: 1),
                // Right side - Cart and checkout
                Expanded(flex: 1, child: _buildCartAndCheckout()),
              ],
            ),
    );
  }

  Widget _buildProductSelection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, barcode, or SKU…',
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded,
                  color: Colors.blue.shade400, size: 22),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: _searchController.clear,
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF334155) : Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
              ),
            ),
          ),
        ),
        // Product count bar
        if (_filteredProducts.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: Row(
              children: [
                Text(
                  '${_filteredProducts.length} products',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_cart.length} in cart',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        // Product grid
        Expanded(
          child: _filteredProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No products found',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 15)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) =>
                      _buildProductCard(_filteredProducts[index]),
                ),
        ),
      ],
    );
  }

  // Widget _buildProductCard(Map<String, dynamic> productMap) {
  //   final productName = (productMap['name'] as String?) ?? 'Unknown';
  //   final sellingPrice =
  //       ((productMap['default_selling_price'] as num?)?.toDouble() ?? 0.0);
  //   final lotsCount = ((productMap['lots_count'] as num?)?.toInt() ?? 0);
  //   final minPrice = ((productMap['min_price'] as num?)?.toDouble());
  //   final maxPrice = ((productMap['max_price'] as num?)?.toDouble());

  //   // Show price range if there are multiple lots with different prices
  //   String priceDisplay;
  //   if (lotsCount > 1 &&
  //       minPrice != null &&
  //       maxPrice != null &&
  //       minPrice != maxPrice) {
  //     priceDisplay =
  //         '$_currencySymbol${minPrice.toStringAsFixed(2)} - $_currencySymbol${maxPrice.toStringAsFixed(2)}';
  //   } else {
  //     priceDisplay = '$_currencySymbol${sellingPrice.toStringAsFixed(2)}';
  //   }

  //   return Card(
  //     elevation: 2,
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //     child: InkWell(
  //       onTap: () => _addToCart(productMap),
  //       borderRadius: BorderRadius.circular(12),
  //       child: Padding(
  //         padding: const EdgeInsets.all(12),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             // Product image placeholder with lot badge
  //             Stack(
  //               children: [
  //                 Container(
  //                   height: 80,
  //                   decoration: BoxDecoration(
  //                     color: Colors.grey[200],
  //                     borderRadius: BorderRadius.circular(8),
  //                   ),
  //                   child: const Center(
  //                     child: Icon(
  //                       Icons.inventory_2,
  //                       size: 40,
  //                       color: Colors.grey,
  //                     ),
  //                   ),
  //                 ),
  //                 if (lotsCount > 1)
  //                   Positioned(
  //                     top: 4,
  //                     right: 4,
  //                     child: Container(
  //                       padding: const EdgeInsets.symmetric(
  //                         horizontal: 6,
  //                         vertical: 2,
  //                       ),
  //                       decoration: BoxDecoration(
  //                         color: Colors.blue,
  //                         borderRadius: BorderRadius.circular(10),
  //                       ),
  //                       child: Text(
  //                         '$lotsCount lots',
  //                         style: const TextStyle(
  //                           color: Colors.white,
  //                           fontSize: 10,
  //                           fontWeight: FontWeight.bold,
  //                         ),
  //                       ),
  //                     ),
  //                   ),
  //               ],
  //             ),
  //             const SizedBox(height: 8),
  //             // Product name
  //             Text(
  //               productName,
  //               style: const TextStyle(
  //                 fontWeight: FontWeight.bold,
  //                 fontSize: 14,
  //               ),
  //               maxLines: 2,
  //               overflow: TextOverflow.ellipsis,
  //             ),
  //             const Spacer(),
  //             // Price
  //             Text(
  //               priceDisplay,
  //               style: const TextStyle(
  //                 color: Colors.green,
  //                 fontWeight: FontWeight.bold,
  //                 fontSize: 14,
  //               ),
  //             ),
  //             if (lotsCount > 1)
  //               Text(
  //                 'Multiple lots',
  //                 style: TextStyle(
  //                   color: Colors.blue[700],
  //                   fontSize: 11,
  //                   fontStyle: FontStyle.italic,
  //                 ),
  //               ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }
  Widget _buildProductCard(Map<String, dynamic> productMap) {
    final productName = (productMap['name'] as String?) ?? 'Unknown';
    final sellingPrice =
        ((productMap['default_selling_price'] as num?)?.toDouble() ?? 0.0);
    final lotsCount = ((productMap['lots_count'] as num?)?.toInt() ?? 0);
    final minPrice = ((productMap['min_price'] as num?)?.toDouble());
    final maxPrice = ((productMap['max_price'] as num?)?.toDouble());
    final imagePath = (productMap['image_path'] as String?);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String priceDisplay;
    if (lotsCount > 1 &&
        minPrice != null &&
        maxPrice != null &&
        minPrice != maxPrice) {
      priceDisplay =
          '$_currencySymbol${minPrice.toStringAsFixed(2)} – $_currencySymbol${maxPrice.toStringAsFixed(2)}';
    } else {
      priceDisplay = '$_currencySymbol${sellingPrice.toStringAsFixed(2)}';
    }

    // check if already in cart
    final cartQty = _cart.entries
        .where((e) => e.value.productId == (productMap['product_id'] as int?))
        .fold<double>(0, (s, e) => s + e.value.quantity);
    final inCart = cartQty > 0;

    return Card(
      elevation: inCart ? 6 : 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: inCart
            ? BorderSide(color: Colors.blue.shade400, width: 2)
            : BorderSide(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
      ),
      shadowColor: inCart
          ? Colors.blue.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.1),
      child: InkWell(
        onTap: () => _addToCart(productMap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image (top 62% of card) ──────────────────────────
            Expanded(
              flex: 62,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Product image
                  imagePath != null && imagePath.isNotEmpty
                      ? Image.file(
                          File(imagePath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, s) =>
                              _buildPlaceholderImage(isDark),
                        )
                      : _buildPlaceholderImage(isDark),

                  // Bottom gradient for readability
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.35),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Cart quantity badge (top-left)
                  if (inCart)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_cart_rounded,
                                size: 11, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              cartQty % 1 == 0
                                  ? cartQty.toInt().toString()
                                  : cartQty.toStringAsFixed(1),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Lots badge (top-right)
                  if (lotsCount > 1)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade600,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.layers_rounded,
                                size: 11, color: Colors.white),
                            const SizedBox(width: 3),
                            Text('$lotsCount',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Product info (bottom 38%) ────────────────────────
            Expanded(
              flex: 38,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Product name
                    Tooltip(
                      message: productName,
                      child: Text(
                        productName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.25,
                          color: isDark ? Colors.white : Colors.grey.shade900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Price + add button row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            priceDisplay,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.green.shade300
                                  : Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2)),
                            ],
                          ),
                          child: const Icon(Icons.add_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF334155), const Color(0xFF1E293B)]
              : [Colors.grey.shade100, Colors.grey.shade200],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 44, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
          const SizedBox(height: 6),
          Text(
            'No Image',
            style: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildCartAndCheckout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Customer selection
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              // Customer selector
              Expanded(
                child: InkWell(
                  onTap: () => _showCustomerSelectionDialog(),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: _selectedCustomer != null
                          ? LinearGradient(colors: [Colors.green.shade50, Colors.green.shade100])
                          : null,
                      color: _selectedCustomer == null
                          ? (isDark ? const Color(0xFF334155) : Colors.grey.shade100)
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedCustomer != null
                            ? Colors.green.shade300
                            : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: _selectedCustomer != null
                              ? Colors.green.shade600
                              : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                          child: Text(
                            _selectedCustomer != null
                                ? _selectedCustomer!.name.substring(0, 1).toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedCustomer?.name ?? 'Walk-in Customer',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _selectedCustomer != null
                                      ? (isDark ? Colors.white : Colors.black)
                                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_selectedCustomer != null && _selectedCustomer!.phone != null)
                                Text(_selectedCustomer!.phone!,
                                    style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                            ],
                          ),
                        ),
                        Icon(Icons.expand_more, size: 18,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Add customer button
              InkWell(
                onTap: _showAddCustomerDialog,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_add_outlined, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
        // Cart items
        Expanded(
          child: _cart.isEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 120;
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!compact) ...[
                            Icon(Icons.shopping_cart_outlined,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                          ],
                          Text(
                            'Cart is empty',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  },
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

  // Show customer selection dialog with search
  Future<void> _showCustomerSelectionDialog() async {
    final TextEditingController searchController = TextEditingController();
    List<CustomerModel> filteredCustomers = List.from(_customers);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Customer'),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _showAddCustomerDialog();
                    // Reopen the selection dialog after adding customer
                    if (mounted) {
                      await _showCustomerSelectionDialog();
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              height: 500,
              child: Column(
                children: [
                  // Search bar
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Search by name',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (query) {
                      setDialogState(() {
                        filteredCustomers = _customers.where((customer) {
                          final nameLower = customer.name.toLowerCase();
                          final phoneLower = (customer.phone ?? '').toLowerCase();
                          final searchLower = query.toLowerCase();
                          return nameLower.contains(searchLower) ||
                              phoneLower.contains(searchLower);
                        }).toList();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Customer list
                  Expanded(
                    child: filteredCustomers.isEmpty
                        ? const Center(
                            child: Text('No customers found'),
                          )
                        : ListView.builder(
                            itemCount: filteredCustomers.length,
                            itemBuilder: (context, index) {
                              final customer = filteredCustomers[index];
                              final isSelected = _selectedCustomer?.id == customer.id;

                              return Card(
                                color: isSelected ? Colors.blue[50] : null,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isSelected
                                        ? Colors.blue
                                        : Colors.grey[300],
                                    child: Icon(
                                      Icons.person,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey[700],
                                    ),
                                  ),
                                  title: Text(
                                    customer.name,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: customer.phone != null
                                      ? Text(customer.phone!)
                                      : null,
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Colors.blue,
                                        )
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _selectedCustomer = customer;
                                    });
                                    searchController.dispose();
                                    Navigator.pop(context);
                                  },
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
                onPressed: () {
                  searchController.dispose();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Widget _buildCartItem(_CartItem item) {
  //   final cartKey = '${item.productId}_${item.lotId}';

  //   return Card(
  //     margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //     child: Padding(
  //       padding: const EdgeInsets.all(12),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             children: [
  //               Expanded(
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       item.productName,
  //                       style: const TextStyle(fontWeight: FontWeight.bold),
  //                       maxLines: 2,
  //                       overflow: TextOverflow.ellipsis,
  //                     ),
  //                     const SizedBox(height: 2),
  //                     Text(
  //                       'Lot #${item.lotNumber}',
  //                       style: TextStyle(
  //                         fontSize: 12,
  //                         color: Colors.blue[700],
  //                         fontWeight: FontWeight.w500,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //               IconButton(
  //                 icon: const Icon(Icons.delete, size: 20),
  //                 onPressed: () => _removeFromCart(cartKey),
  //                 padding: EdgeInsets.zero,
  //                 constraints: const BoxConstraints(),
  //               ),
  //             ],
  //           ),
  //           const SizedBox(height: 8),
  //           Row(
  //             children: [
  //               // Quantity controls
  //               Container(
  //                 decoration: BoxDecoration(
  //                   border: Border.all(color: Colors.grey[300]!),
  //                   borderRadius: BorderRadius.circular(8),
  //                 ),
  //                 child: Row(
  //                   children: [
  //                     IconButton(
  //                       icon: const Icon(Icons.remove, size: 16),
  //                       onPressed: () {
  //                         _updateQuantity(
  //                           cartKey,
  //                           item.quantity - 1,
  //                           item.availableStock,
  //                         );
  //                       },
  //                       padding: const EdgeInsets.all(4),
  //                       constraints: const BoxConstraints(),
  //                     ),
  //                     SizedBox(
  //                       width: 50,
  //                       child: Text(
  //                         '${item.quantity} ${item.unit}',
  //                         textAlign: TextAlign.center,
  //                         style: const TextStyle(
  //                           fontWeight: FontWeight.bold,
  //                           fontSize: 11,
  //                         ),
  //                       ),
  //                     ),
  //                     IconButton(
  //                       icon: const Icon(Icons.add, size: 16),
  //                       onPressed: () {
  //                         _updateQuantity(
  //                           cartKey,
  //                           item.quantity + 1,
  //                           item.availableStock,
  //                         );
  //                       },
  //                       padding: const EdgeInsets.all(4),
  //                       constraints: const BoxConstraints(),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //               const SizedBox(width: 8),
  //               const Text('x'),
  //               const SizedBox(width: 8),
  //               // Unit price
  //               Expanded(
  //                 child: Text(
  //                   '$_currencySymbol${item.unitPrice.toStringAsFixed(2)}',
  //                   style: TextStyle(color: Colors.grey[600], fontSize: 12),
  //                 ),
  //               ),
  //               // Line total
  //               Text(
  //                 '$_currencySymbol${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
  //                 style: const TextStyle(
  //                   fontWeight: FontWeight.bold,
  //                   fontSize: 16,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
  Widget _buildCartItem(_CartItem item) {
    final cartKey = '${item.productId}_${item.lotId}';
    final lineTotal = item.quantity * item.unitPrice;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: Theme.of(context).brightness == Brightness.dark
                ? [const Color(0xFF1E293B), const Color(0xFF334155)]
                : [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with product name and delete button
              Row(
                children: [
                  // Product image thumbnail (if available)
                  if (item.productImage != null &&
                      item.productImage!.isNotEmpty)
                    Container(
                      width: 50,
                      height: 50,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                        ),
                        image: DecorationImage(
                          image: FileImage(File(item.productImage!)),
                          fit: BoxFit.cover,
                          onError: (_, _) {},
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.blue.shade900.withValues(alpha: 0.3)
                                : Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.tag,
                                size: 12,
                                color: isDark ? Colors.blue.shade300 : Colors.blue.shade800,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Lot #${item.lotNumber}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.blue.shade300 : Colors.blue.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: isDark ? Colors.red.shade300 : Colors.red.shade400,
                    ),
                    onPressed: () => _removeFromCart(cartKey),
                    tooltip: 'Remove item',
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.red.shade900.withValues(alpha: 0.3)
                          : Colors.red.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(height: 20),

              // Quantity controls and pricing
              Row(
                children: [
                  // Quantity controls
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      color: isDark
                          ? Colors.blue.shade900.withValues(alpha: 0.3)
                          : Colors.blue.shade50,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: () {
                            _updateQuantity(
                              cartKey,
                              item.quantity - 1,
                              item.availableStock,
                            );
                          },
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          constraints: const BoxConstraints(minWidth: 60),
                          child: Column(
                            children: [
                              Text(
                                item.quantity.toStringAsFixed(2),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                item.unit,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: () {
                            _updateQuantity(
                              cartKey,
                              item.quantity + 1,
                              item.availableStock,
                            );
                          },
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Price info
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.green.shade900.withValues(alpha: 0.3)
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.green.shade700 : Colors.green.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.sell,
                                size: 14,
                                color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_currencySymbol${item.unitPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                ' / ${item.unit}',
                                style: TextStyle(
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total: $_currencySymbol${lineTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.green.shade200 : Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Stock availability indicator
              if (item.quantity > item.availableStock * 0.8)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber,
                          size: 14,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Available: ${item.availableStock.toStringAsFixed(2)} ${item.unit}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  //   Widget _buildCheckoutSection() {
  //     final subtotal = _calculateSubtotal();
  //     final discount = _calculateDiscount();
  //     final tax = _calculateTax();
  //     final total = _calculateTotal();

  //     return Container(
  //       padding: const EdgeInsets.all(16),
  //       decoration: BoxDecoration(
  //         color: Colors.white,
  //         boxShadow: [
  //           BoxShadow(
  //             color: Colors.black.withValues(alpha: 0.05),
  //             blurRadius: 10,
  //             offset: const Offset(0, -2),
  //           ),
  //         ],
  //       ),
  //       child: Column(
  //         children: [
  //           // Payment method
  //           Row(
  //             children: [
  //               const Text(
  //                 'Payment:',
  //                 style: TextStyle(fontWeight: FontWeight.bold),
  //               ),
  //               const SizedBox(width: 8),
  //               Expanded(
  //                 child: SegmentedButton<String>(
  //                   segments: const [
  //                     ButtonSegment(value: 'cash', label: Text('Cash')),
  //                     ButtonSegment(value: 'credit', label: Text('Card')),
  //                     ButtonSegment(value: 'bank', label: Text('Bank')),
  //                   ],
  //                   selected: {_paymentMethod},
  //                   onSelectionChanged: (Set<String> newSelection) {
  //                     setState(() {
  //                       _paymentMethod = newSelection.first;
  //                     });
  //                   },
  //                 ),
  //               ),
  //             ],
  //           ),
  //           const SizedBox(height: 12),
  //           // Discount
  //           Row(
  //             children: [
  //               Expanded(
  //                 child: TextField(
  //                   controller: _discountController,
  //                   decoration: InputDecoration(
  //                     labelText: 'Discount',
  //                     border: OutlineInputBorder(
  //                       borderRadius: BorderRadius.circular(8),
  //                     ),
  //                     contentPadding: const EdgeInsets.symmetric(
  //                       horizontal: 12,
  //                       vertical: 8,
  //                     ),
  //                   ),
  //                   keyboardType: TextInputType.number,
  //                   inputFormatters: [
  //                     FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
  //                   ],
  //                   onChanged: (_) => setState(() {}),
  //                 ),
  //               ),
  //               const SizedBox(width: 8),
  //               SegmentedButton<bool>(
  //                 segments: [
  //                   const ButtonSegment(value: true, label: Text('%')),
  //                   ButtonSegment(value: false, label: Text(_currencySymbol)),
  //                 ],
  //                 selected: {_isPercentageDiscount},
  //                 onSelectionChanged: (Set<bool> newSelection) {
  //                   setState(() {
  //                     _isPercentageDiscount = newSelection.first;
  //                   });
  //                 },
  //               ),
  //             ],
  //           ),
  //           const Divider(height: 24),
  //           // Totals
  //           _buildTotalRow('Subtotal', subtotal),
  //           _buildTotalRow('Discount', -discount, color: Colors.red),
  //           _buildTotalRow('Tax', tax),
  //           const Divider(height: 16),
  //           _buildTotalRow('Total', total, isTotal: true),
  //           const SizedBox(height: 16),
  //           // Action buttons
  //           Row(
  //             children: [
  //               Expanded(
  //                 child: OutlinedButton(
  //                   onPressed: _cart.isEmpty ? null : _clearCart,
  //                   style: OutlinedButton.styleFrom(
  //                     padding: const EdgeInsets.symmetric(vertical: 16),
  //                   ),
  //                   child: const Text('Clear'),
  //                 ),
  //               ),
  //               const SizedBox(width: 8),
  //               Expanded(
  //                 child: ElevatedButton(
  //                   onPressed: _cart.isEmpty || _isLoading ? null : _completeSale,
  //                   style: ElevatedButton.styleFrom(
  //                     backgroundColor: Colors.green,
  //                     foregroundColor: Colors.white,
  //                     padding: const EdgeInsets.symmetric(vertical: 16),
  //                   ),
  //                   child: _isLoading
  //                       ? const SizedBox(
  //                           height: 20,
  //                           width: 20,
  //                           child: CircularProgressIndicator(
  //                             strokeWidth: 2,
  //                             color: Colors.white,
  //                           ),
  //                         )
  //                       : const Text('Complete Sale'),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ],
  //       ),
  //     );
  //   }

  //   Widget _buildTotalRow(String label, double amount, {Color? color, bool isTotal = false}) {
  //     return Padding(
  //       padding: const EdgeInsets.symmetric(vertical: 4),
  //       child: Row(
  //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //         children: [
  //           Text(
  //             label,
  //             style: TextStyle(
  //               fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
  //               fontSize: isTotal ? 18 : 14,
  //             ),
  //           ),
  //           Text(
  //             '$_currencySymbol${amount.toStringAsFixed(2)}',
  //             style: TextStyle(
  //               fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
  //               fontSize: isTotal ? 20 : 14,
  //               color: color,
  //             ),
  //           ),
  //         ],
  //       ),
  //     );
  //   }
  Widget _buildCheckoutSection() {
    final subtotal = _calculateSubtotal();
    final discount = _calculateDiscount();
    final tax = _calculateTax();
    final total = _calculateTotal();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Payment method section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF334155), const Color(0xFF1E293B)]
                    : [Colors.grey.shade50, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.payment,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Payment Method',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: Colors.blue.shade600,
                    selectedForegroundColor: Colors.white,
                    side: BorderSide(color: Colors.blue.shade200),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: 'cash',
                      label: Text('Cash'),
                      icon: Icon(Icons.money, size: 18),
                    ),
                    ButtonSegment(
                      value: 'partial',
                      label: Text('Partial'),
                      icon: Icon(Icons.pie_chart, size: 18),
                    ),
                    ButtonSegment(
                      value: 'credit',
                      label: Text('Credit'),
                      icon: Icon(Icons.credit_card, size: 18),
                    ),
                  ],
                  selected: {_paymentMethod},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _paymentMethod = newSelection.first;
                      _cashPaidController.clear();
                    });
                  },
                ),
                if (_paymentMethod == 'partial') ...[
                  const SizedBox(height: 12),
                  Builder(builder: (context) {
                    final total = _calculateTotal();
                    final cashPaid =
                        (double.tryParse(_cashPaidController.text) ?? 0)
                            .clamp(0, total > 0 ? total : double.infinity);
                    final credit = total > 0 ? (total - cashPaid) : 0.0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _cashPaidController,
                          decoration: InputDecoration(
                            labelText: 'Cash Paid ($_currencySymbol)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            isDense: true,
                            prefixIcon: const Icon(Icons.money, size: 18),
                            suffixText: total > 0 &&
                                    _cashPaidController.text.isNotEmpty
                                ? 'Credit: $_currencySymbol${credit.toStringAsFixed(2)}'
                                : null,
                            suffixStyle: TextStyle(
                                color: Colors.orange.shade700, fontSize: 11),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    );
                  }),
                ],
              ],
            ),
          ),

          // Discount section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.discount,
                      color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Discount',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey.shade50,
                        ),
                        child: TextField(
                          controller: _discountController,
                          decoration: InputDecoration(
                            hintText: '0.00',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            prefixIcon: Icon(
                              Icons.local_offer,
                              color: Colors.orange.shade600,
                              size: 20,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'),
                            ),
                          ],
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SegmentedButton<bool>(
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: Colors.orange.shade100,
                          selectedForegroundColor: Colors.orange.shade800,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        segments: [
                          ButtonSegment(
                            value: true,
                            label: Text(
                              '%',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text(
                              _currencySymbol,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        selected: {_isPercentageDiscount},
                        onSelectionChanged: (Set<bool> newSelection) {
                          setState(() {
                            _isPercentageDiscount = newSelection.first;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // Totals section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTotalRowEnhanced(
                  'Subtotal',
                  subtotal,
                  Icons.receipt_long,
                ),
                const SizedBox(height: 8),
                _buildTotalRowEnhanced(
                  'Discount',
                  -discount,
                  Icons.discount,
                  color: Colors.red,
                ),
                const SizedBox(height: 8),
                _buildTotalRowEnhanced('Tax', tax, Icons.account_balance),
                const Divider(height: 24, thickness: 2),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [Colors.green.shade900.withValues(alpha: 0.4), Colors.green.shade800.withValues(alpha: 0.4)]
                          : [Colors.green.shade50, Colors.green.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.green.shade700 : Colors.green.shade300,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.green.shade700 : Colors.green.shade600,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.payments,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Grand Total',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$_currencySymbol${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: isDark ? Colors.green.shade200 : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_paymentMethod == 'partial') ...[
                  const SizedBox(height: 8),
                  Builder(builder: (_) {
                    final cashPaid =
                        (double.tryParse(_cashPaidController.text) ?? 0)
                            .clamp(0, total);
                    final credit = total - cashPaid;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.orange.shade900.withValues(alpha: 0.3)
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isDark
                                ? Colors.orange.shade700
                                : Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cash: $_currencySymbol${cashPaid.toStringAsFixed(2)}',
                            style: TextStyle(
                                color: isDark
                                    ? Colors.green.shade300
                                    : Colors.green.shade700,
                                fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Credit: $_currencySymbol${credit.toStringAsFixed(2)}',
                            style: TextStyle(
                                color: isDark
                                    ? Colors.orange.shade300
                                    : Colors.orange.shade700,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _cart.isEmpty ? null : _clearCart,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear Cart'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.red.shade300, width: 2),
                      foregroundColor: Colors.red.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: _cart.isEmpty || _isLoading
                        ? null
                        : _completeSale,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle, size: 22),
                    label: Text(
                      _isLoading ? 'Processing...' : 'Complete Sale',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 4,
                      shadowColor: Colors.green.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRowEnhanced(
    String label,
    double amount,
    IconData icon, {
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color ?? Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        Text(
          '$_currencySymbol${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color ?? Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}

// class _CartItem {
//   final int productId;
//   final int lotId;
//   final String productName;
//   double quantity;
//   final double unitPrice;
//   final String unit;
//   final int lotNumber;
//   final String? receivedDate;
//   final double availableStock;

//   _CartItem({
//     required this.productId,
//     required this.lotId,
//     required this.productName,
//     required this.quantity,
//     required this.unitPrice,
//     required this.unit,
//     required this.lotNumber,
//     this.receivedDate,
//     required this.availableStock,
//   });
// }
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
  final String? productImage; // Add this field

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
    this.productImage, // Add this parameter
  });
}
