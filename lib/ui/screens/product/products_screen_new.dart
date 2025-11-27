import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/product/product_service.dart';
import '../../../services/currency/currency_service.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductService _productService = ProductService();
  final CurrencyService _currencyService = CurrencyService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];
  List<String> _categories = [];
  Map<String, List<dynamic>> _productsByCategory = {};

  bool _isLoading = true;
  bool _viewByCategory = false; // Toggle between product view and category view
  String _currencySymbol = '৳';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrency() async {
    try {
      final symbol = await _currencyService.getCurrencySymbol();
      if (mounted) {
        setState(() => _currencySymbol = symbol);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _currencySymbol = '৳');
      }
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productService.getAllProducts();
      final categories = await _productService.getAllCategories();

      // Group products by category
      final Map<String, List<dynamic>> byCategory = {};
      for (final product in products) {
        final category = (product['category'] as String?) ?? 'Uncategorized';
        if (!byCategory.containsKey(category)) {
          byCategory[category] = [];
        }
        byCategory[category]!.add(product);
      }

      if (mounted) {
        setState(() {
          _products = products;
          _filteredProducts = products;
          _categories = categories;
          _productsByCategory = byCategory;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _products;
      } else {
        _filteredProducts = _products.where((product) {
          final productMap = product as Map<String, dynamic>;
          final name = (productMap['name'] as String?)?.toLowerCase() ?? '';
          final category = (productMap['category'] as String?)?.toLowerCase() ?? '';
          final searchLower = query.toLowerCase();
          return name.contains(searchLower) || category.contains(searchLower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        elevation: 2,
        actions: [
          // View toggle buttons
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildViewToggleButton(
                  icon: Icons.grid_view,
                  label: 'By Product',
                  isSelected: !_viewByCategory,
                  onTap: () => setState(() => _viewByCategory = false),
                ),
                _buildViewToggleButton(
                  icon: Icons.category,
                  label: 'By Category',
                  isSelected: _viewByCategory,
                  onTap: () => setState(() => _viewByCategory = true),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
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
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: _filterProducts,
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _viewByCategory
                    ? _buildCategoryView()
                    : _buildProductView(),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Theme.of(context).primaryColor : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Theme.of(context).primaryColor : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryView() {
    if (_productsByCategory.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _productsByCategory.keys.length,
      itemBuilder: (context, index) {
        final category = _productsByCategory.keys.elementAt(index);
        final products = _productsByCategory[category]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.category,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${products.length} product(s)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            children: [
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: products.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return _buildProductListTile(products[index]);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductView() {
    if (_filteredProducts.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final productMap = _filteredProducts[index] as Map<String, dynamic>;
        return _buildProductCard(productMap);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> productMap) {
    final productName = (productMap['name'] as String?) ?? 'Unknown';
    final category = productMap['category'] as String?;
    final currentStock = ((productMap['current_stock'] as num?)?.toDouble() ?? 0.0);
    final reorderLevel = ((productMap['reorder_level'] as num?)?.toDouble() ?? 0.0);
    final lotsCount = ((productMap['lots_count'] as num?)?.toInt() ?? 0);
    final minPrice = ((productMap['min_price'] as num?)?.toDouble());
    final maxPrice = ((productMap['max_price'] as num?)?.toDouble());
    final unit = productMap['unit'] as String? ?? 'piece';
    final imagePath = productMap['image_path'] as String?;

    final isLowStock = currentStock <= reorderLevel && reorderLevel > 0;
    final stockColor = isLowStock ? Colors.red : Colors.green;
    final hasPriceRange = minPrice != null && maxPrice != null && minPrice != maxPrice;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showProductLotDetails(productMap),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Product image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  image: imagePath != null && File(imagePath).existsSync()
                      ? DecorationImage(
                          image: FileImage(File(imagePath)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: imagePath == null || !File(imagePath).existsSync()
                    ? Icon(Icons.inventory_2, size: 40, color: Colors.grey[400])
                    : null,
              ),
              const SizedBox(width: 16),

              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            productName.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (lotsCount > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      ],
                    ),
                    if (category != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.inventory_2, size: 14, color: stockColor),
                        const SizedBox(width: 4),
                        Text(
                          '${currentStock.toStringAsFixed(2)} $unit',
                          style: TextStyle(
                            color: stockColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.attach_money, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        if (hasPriceRange)
                          Text(
                            '$_currencySymbol${minPrice!.toStringAsFixed(2)} - $_currencySymbol${maxPrice!.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13),
                          )
                        else if (minPrice != null)
                          Text(
                            '$_currencySymbol${minPrice!.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 20),
                    onPressed: () => _showProductLotDetails(productMap),
                    tooltip: 'View lots',
                    color: Colors.blue,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _editProduct(productName, productMap),
                    tooltip: 'Edit product',
                    color: Colors.orange,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _deleteProduct(productName),
                    tooltip: 'Delete product',
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductListTile(Map<String, dynamic> productMap) {
    final productName = (productMap['name'] as String?) ?? 'Unknown';
    final currentStock = ((productMap['current_stock'] as num?)?.toDouble() ?? 0.0);
    final unit = productMap['unit'] as String? ?? 'piece';
    final lotsCount = ((productMap['lots_count'] as num?)?.toInt() ?? 0);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Text(
        productName.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('Stock: ${currentStock.toStringAsFixed(2)} $unit'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lotsCount > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$lotsCount lots',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _editProduct(productName, productMap),
            color: Colors.orange,
          ),
        ],
      ),
      onTap: () => _showProductLotDetails(productMap),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? 'No products yet.\nCreate a Purchase Order to add products.'
                : 'No products found',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Continue with existing methods for showing lot details, editing, and deleting...
  // (I'll add these in the next edit)

  Future<void> _showProductLotDetails(Map<String, dynamic> product) async {
    // Implementation will follow
  }

  Future<void> _editProduct(String productName, Map<String, dynamic> productMap) async {
    // Implementation will follow
  }

  Future<void> _deleteProduct(String productName) async {
    // Implementation will follow
  }
}
