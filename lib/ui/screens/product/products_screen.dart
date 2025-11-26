import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/product_model.dart';
import '../../../services/product/product_service.dart';
import '../../../services/currency/currency_service.dart';
import '../../providers/auth_provider.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductService _productService = ProductService();
  final CurrencyService _currencyService = CurrencyService();
  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'name';
  String? _selectedCategory;
  String _currencySymbol = '৳';

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    _loadProducts();
  }

  Future<void> _loadCurrency() async {
    try {
      final symbol = await _currencyService.getCurrencySymbol();
      setState(() {
        _currencySymbol = symbol;
      });
    } catch (e) {
      // Use default if error
      setState(() {
        _currencySymbol = '৳';
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productService.getAllProducts(sortBy: _sortBy);
      setState(() {
        _products = products;
        _filteredProducts = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty && _selectedCategory == null) {
        _filteredProducts = _products;
      } else {
        _filteredProducts = _products.where((product) {
          final productMap = product as Map<String, dynamic>;
          final nameLower = (productMap['name'] as String?)?.toLowerCase() ?? '';
          final skuLower = (productMap['sku'] as String?)?.toLowerCase() ?? '';
          final barcodeLower = (productMap['barcode'] as String?)?.toLowerCase() ?? '';
          final categoryLower = (productMap['category'] as String?)?.toLowerCase() ?? '';
          final searchLower = query.toLowerCase();

          final matchesSearch = query.isEmpty ||
              nameLower.contains(searchLower) ||
              skuLower.contains(searchLower) ||
              barcodeLower.contains(searchLower);

          final matchesCategory = _selectedCategory == null ||
              productMap['category'] == _selectedCategory;

          return matchesSearch && matchesCategory;
        }).toList();
      }
    });
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete ${product['name']}?'),
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
        await _productService.deactivateProduct(product['id'] as int);
        _loadProducts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting product: $e')),
          );
        }
      }
    }
  }

  void _navigateToAddProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProductFormScreen(),
      ),
    );
    if (result == true) {
      _loadProducts();
    }
  }

  void _navigateToEditProduct(Map<String, dynamic> product) async {
    // Convert map to ProductModel for the form screen
    final productModel = ProductModel.fromMap(product);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductFormScreen(product: productModel),
      ),
    );
    if (result == true) {
      _loadProducts();
    }
  }

  Future<void> _showCategoryFilter() async {
    final categories = await _productService.getAllCategories();
    if (!mounted) return;

    final selected = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Categories'),
              leading: Radio<String?>(
                value: null,
                groupValue: _selectedCategory,
                onChanged: (value) => Navigator.pop(context, value),
              ),
              onTap: () => Navigator.pop(context, null),
            ),
            ...categories.map((category) => ListTile(
              title: Text(category),
              leading: Radio<String?>(
                value: category,
                groupValue: _selectedCategory,
                onChanged: (value) => Navigator.pop(context, value),
              ),
              onTap: () => Navigator.pop(context, category),
            )),
          ],
        ),
      ),
    );

    if (selected != _selectedCategory) {
      setState(() => _selectedCategory = selected);
      _filterProducts(_searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: Icon(
              _selectedCategory != null ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _selectedCategory != null ? Colors.blue : null,
            ),
            onPressed: _showCategoryFilter,
            tooltip: 'Filter by Category',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() => _sortBy = value);
              _loadProducts();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
              const PopupMenuItem(value: 'sku', child: Text('Sort by SKU')),
              const PopupMenuItem(value: 'category', child: Text('Sort by Category')),
              const PopupMenuItem(value: 'selling_price', child: Text('Sort by Price')),
              const PopupMenuItem(value: 'created_at', child: Text('Sort by Date Added')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
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
                hintText: 'Search products by name, SKU, or barcode...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterProducts('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _filterProducts,
            ),
          ),
          if (_selectedCategory != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Chip(
                label: Text('Category: $_selectedCategory'),
                onDeleted: () {
                  setState(() => _selectedCategory = null);
                  _filterProducts(_searchController.text);
                },
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty && _selectedCategory == null
                                  ? 'No products yet'
                                  : 'No products found',
                              style: const TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            if (_searchController.text.isEmpty && _selectedCategory == null)
                              Consumer<AuthProvider>(
                                builder: (context, authProvider, child) {
                                  final canCreate = authProvider.currentUser?.hasPermission('create_product') ?? false;

                                  return Tooltip(
                                    message: canCreate ? '' : 'Admin access only',
                                    child: ElevatedButton.icon(
                                      onPressed: canCreate ? _navigateToAddProduct : null,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add First Product'),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredProducts.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final productMap = _filteredProducts[index] as Map<String, dynamic>;
                          final currentStock = ((productMap['current_stock'] as num?)?.toDouble() ?? 0.0);
                          final reorderLevel = ((productMap['reorder_level'] as num?)?.toDouble() ?? 0.0);
                          final isLowStock = currentStock <= reorderLevel && reorderLevel > 0;
                          final stockColor = isLowStock ? Colors.red : Colors.green;
                          final productName = (productMap['name'] as String?) ?? 'Unknown';
                          final productUnit = (productMap['unit'] as String?) ?? 'piece';
                          final productSku = productMap['sku'] as String?;
                          final productCategory = productMap['category'] as String?;
                          final sellingPrice = ((productMap['default_selling_price'] as num?)?.toDouble() ?? 0.0);

                          final lotsCount = ((productMap['lots_count'] as num?)?.toInt() ?? 0);
                          final minPrice = ((productMap['min_price'] as num?)?.toDouble());
                          final maxPrice = ((productMap['max_price'] as num?)?.toDouble());
                          final hasPriceRange = minPrice != null && maxPrice != null && minPrice != maxPrice;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: stockColor,
                                child: Text(
                                  productName.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      productName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (lotsCount > 1)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.blue.shade300),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.layers, size: 12, color: Colors.blue.shade700),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$lotsCount lots',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.blue.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (isLowStock)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Tooltip(
                                        message: 'Low stock',
                                        child: Icon(Icons.warning_amber, color: Colors.red, size: 20),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (productSku != null)
                                    Text('SKU: $productSku'),
                                  if (productCategory != null)
                                    Text('Category: $productCategory'),
                                  Row(
                                    children: [
                                      const Icon(Icons.inventory_2, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Stock: ${currentStock.toStringAsFixed(2)} $productUnit',
                                        style: TextStyle(
                                          color: stockColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.attach_money, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      if (hasPriceRange)
                                        Text('Price: $_currencySymbol${minPrice.toStringAsFixed(2)} - $_currencySymbol${maxPrice.toStringAsFixed(2)}')
                                      else
                                        Text('Price: $_currencySymbol${sellingPrice.toStringAsFixed(2)}'),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Consumer<AuthProvider>(
                                builder: (context, authProvider, child) {
                                  final canEdit = authProvider.currentUser?.hasPermission('edit_product') ?? false;

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
                                        _navigateToEditProduct(productMap);
                                      } else if (value == 'delete') {
                                        _deleteProduct(productMap);
                                      }
                                    },
                                  );
                                },
                              ),
                              onTap: () {
                                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                final canEdit = authProvider.currentUser?.hasPermission('edit_product') ?? false;
                                if (canEdit) {
                                  _navigateToEditProduct(productMap);
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
          final canCreate = authProvider.currentUser?.hasPermission('create_product') ?? false;

          if (!canCreate) {
            // Show disabled button with tooltip for viewers
            return Tooltip(
              message: 'Admin access only',
              child: Opacity(
                opacity: 0.5,
                child: FloatingActionButton.extended(
                  onPressed: null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product'),
                  backgroundColor: Colors.grey,
                ),
              ),
            );
          }

          return FloatingActionButton.extended(
            onPressed: _navigateToAddProduct,
            icon: const Icon(Icons.add),
            label: const Text('Add Product'),
          );
        },
      ),
    );
  }
}
