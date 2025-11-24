import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/product/product_service.dart';
import '../../../services/customer/customer_service.dart';
import '../../../services/transaction/transaction_service.dart';
import '../../../services/invoice/invoice_service.dart';
import '../../../data/models/product_model.dart';
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

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  List<ProductModel> _products = [];
  List<ProductModel> _filteredProducts = [];
  List<CustomerModel> _customers = [];

  final Map<int, _CartItem> _cart = {};
  CustomerModel? _selectedCustomer;
  String _paymentMethod = 'cash';
  bool _isPercentageDiscount = true;
  bool _isLoading = false;

  final double _taxRate = 0; // Can be configured

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(_filterProducts);
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
          return product.name.toLowerCase().contains(query) ||
              (product.barcode?.toLowerCase().contains(query) ?? false) ||
              (product.sku?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  void _addToCart(ProductModel product) async {
    // Check stock
    final stock = await _productService.getProductStock(product.id!);
    final currentQty = _cart[product.id]?.quantity ?? 0;

    if (currentQty >= stock) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient stock')),
        );
      }
      return;
    }

    setState(() {
      if (_cart.containsKey(product.id)) {
        _cart[product.id]!.quantity++;
      } else {
        _cart[product.id!] = _CartItem(
          product: product,
          quantity: 1,
          unitPrice: product.defaultSellingPrice,
        );
      }
    });
  }

  void _removeFromCart(int productId) {
    setState(() {
      _cart.remove(productId);
    });
  }

  void _updateQuantity(int productId, double newQuantity) async {
    if (newQuantity <= 0) {
      _removeFromCart(productId);
      return;
    }

    // Check stock
    final stock = await _productService.getProductStock(productId);
    if (newQuantity > stock) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient stock')),
        );
      }
      return;
    }

    setState(() {
      _cart[productId]?.quantity = newQuantity;
    });
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
        return {
          'product_id': entry.key,
          'quantity': entry.value.quantity,
          'unit_price': entry.value.unitPrice,
          'discount': 0.0,
          'tax': 0.0,
          'subtotal': entry.value.quantity * entry.value.unitPrice,
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

  Widget _buildProductCard(ProductModel product) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _addToCart(product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image placeholder
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
              const SizedBox(height: 8),
              // Product name
              Text(
                product.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              // Price and SKU
              Text(
                '\$${product.defaultSellingPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (product.sku != null)
                Text(
                  'SKU: ${product.sku}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
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
              const Text(
                'Customer',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<CustomerModel>(
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
                  child: Text(
                    item.product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: () => _removeFromCart(item.product.id!),
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
                            item.product.id!,
                            item.quantity - 1,
                          );
                        },
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          item.quantity.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        onPressed: () {
                          _updateQuantity(
                            item.product.id!,
                            item.quantity + 1,
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
                    '\$${item.unitPrice.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                // Line total
                Text(
                  '\$${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
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
                segments: const [
                  ButtonSegment(value: true, label: Text('%')),
                  ButtonSegment(value: false, label: Text('\$')),
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
            '\$${amount.toStringAsFixed(2)}',
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
  final ProductModel product;
  double quantity;
  double unitPrice;

  _CartItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });
}
