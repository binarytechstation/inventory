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
  final ImagePicker _imagePicker = ImagePicker();

  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];
  Map<String, List<Map<String, dynamic>>> _groupedByCategory = {};
  final Set<String> _expandedCategories = {};

  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'name';
  String? _selectedCategory;
  String _currencySymbol = '৳';

  // View mode: 'product' or 'category'
  String _viewMode = 'product';

  @override
  void initState() {
    super.initState();
    _loadCurrency();

    // PERFORMANCE FIX: Defer loading to prevent blocking Dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadProducts();
      }
    });
  }

  Future<void> _loadCurrency() async {
    try {
      final symbol = await _currencyService.getCurrencySymbol();
      setState(() {
        _currencySymbol = symbol;
      });
    } catch (e) {
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
      final grouped = await _productService.getProductsGroupedByCategory();

      setState(() {
        _products = products;
        _filteredProducts = products;
        _groupedByCategory = grouped;
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

  Future<void> _pickImage(String productName) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        // Copy image to app directory
        final appDir = Directory.current.path;
        final fileName = 'product_${productName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final targetPath = '$appDir/assets/images/$fileName';

        // Ensure directory exists
        final dir = Directory('$appDir/assets/images');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        await File(image.path).copy(targetPath);

        // Update product with new image path
        await _productService.updateProductDetails(
          productName: productName,
          imagePath: 'assets/images/$fileName',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image updated successfully')),
          );
          _loadProducts();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _showProductLotDetails(Map<String, dynamic> product) async {
    final productName = product['name'] as String;

    try {
      final lots = await _productService.getAllLotsForProduct(productName);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 700,
            constraints: const BoxConstraints(maxHeight: 750),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade700, Colors.blue.shade500],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.layers, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ((product['name'] as String?) ?? 'Unknown').toUpperCase(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${lots.length} lot(s) available',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Lot list
                Expanded(
                  child: lots.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No lots available for this product',
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: lots.length,
                          itemBuilder: (context, index) {
                            final lot = lots[index];
                            final lotDescription = lot['lot_description'] as String?;
                            final receivedDate = lot['received_date'] as String?;
                            final stock = (lot['current_stock'] as num?)?.toDouble() ?? 0.0;
                            final buyingPrice = (lot['unit_price'] as num?)?.toDouble() ?? 0.0; // This is the buying/purchase price
                            final sellingPrice = (lot['selling_price'] as num?)?.toDouble() ?? 0.0; // Get selling price from each lot
                            final unit = lot['unit'] as String? ?? 'piece';
                            final serialNumber = index + 1;

                            // Calculate profit margin
                            final profitPerUnit = sellingPrice - buyingPrice;
                            final profitMargin = buyingPrice > 0 ? ((profitPerUnit / buyingPrice) * 100) : 0.0;

                            // Format date
                            String formattedDate = '';
                            if (receivedDate != null) {
                              formattedDate = DateTime.tryParse(receivedDate)
                                      ?.toLocal()
                                      .toString()
                                      .split(' ')[0] ??
                                  receivedDate;
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header with Lot number and description
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Colors.blue.shade100, Colors.blue.shade50],
                                            ),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.blue.shade300),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.inventory_2, size: 16, color: Colors.blue.shade700),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Lot #$serialNumber',
                                                style: TextStyle(
                                                  color: Colors.blue.shade900,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: (lotDescription != null && lotDescription.isNotEmpty)
                                                  ? Colors.green.shade50
                                                  : Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: (lotDescription != null && lotDescription.isNotEmpty)
                                                    ? Colors.green.shade200
                                                    : Colors.grey.shade300,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.label,
                                                  size: 14,
                                                  color: (lotDescription != null && lotDescription.isNotEmpty)
                                                      ? Colors.green.shade700
                                                      : Colors.grey.shade600,
                                                ),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    (lotDescription != null && lotDescription.isNotEmpty)
                                                        ? lotDescription
                                                        : 'N/A',
                                                    style: TextStyle(
                                                      color: (lotDescription != null && lotDescription.isNotEmpty)
                                                          ? Colors.green.shade900
                                                          : Colors.grey.shade600,
                                                      fontSize: 13,
                                                      fontWeight: (lotDescription != null && lotDescription.isNotEmpty)
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Date received
                                    if (formattedDate.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Received: $formattedDate',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const Divider(height: 24),
                                    // Stock and prices section
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildLotDetailRow(
                                            'Current Stock',
                                            '${stock.toStringAsFixed(2)} $unit',
                                            Icons.inventory_2,
                                            stock > 10 ? Colors.green : Colors.orange,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildLotDetailRow(
                                            'Lot Value',
                                            '$_currencySymbol${(stock * buyingPrice).toStringAsFixed(2)}',
                                            Icons.calculate,
                                            Colors.purple,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Buying and Selling Prices
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildLotDetailRow(
                                            'Buying Price',
                                            '$_currencySymbol${buyingPrice.toStringAsFixed(2)}/$unit',
                                            Icons.shopping_cart,
                                            Colors.red,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildLotDetailRow(
                                            'Selling Price',
                                            '$_currencySymbol${sellingPrice.toStringAsFixed(2)}/$unit',
                                            Icons.sell,
                                            Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Profit margin
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: profitPerUnit >= 0
                                              ? [Colors.green.shade50, Colors.green.shade100]
                                              : [Colors.red.shade50, Colors.red.shade100],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: profitPerUnit >= 0 ? Colors.green.shade300 : Colors.red.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                profitPerUnit >= 0 ? Icons.trending_up : Icons.trending_down,
                                                size: 18,
                                                color: profitPerUnit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Profit per Unit:',
                                                style: TextStyle(
                                                  color: profitPerUnit >= 0 ? Colors.green.shade900 : Colors.red.shade900,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '$_currencySymbol${profitPerUnit.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  color: profitPerUnit >= 0 ? Colors.green.shade900 : Colors.red.shade900,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              Text(
                                                '${profitMargin.toStringAsFixed(1)}% margin',
                                                style: TextStyle(
                                                  color: profitPerUnit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                                  fontSize: 11,
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
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading lot details: $e')),
        );
      }
    }
  }

  Widget _buildLotDetailRow(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color.lerp(color, Colors.black, 0.3)!,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editProduct(String productName) async {
    try {
      final productDetails = await _productService.getProductByName(productName);
      if (productDetails == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product not found')),
          );
        }
        return;
      }

      final nameController = TextEditingController(text: productName);
      final categoryController = TextEditingController(text: productDetails['category'] ?? '');
      final descriptionController = TextEditingController(text: productDetails['product_description'] ?? '');
      String? imagePath = productDetails['product_image'] as String?;

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.edit, color: Colors.blue.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Edit ${productName.toUpperCase()}',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final XFile? image = await _imagePicker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1024,
                                maxHeight: 1024,
                                imageQuality: 85,
                              );

                              if (image != null) {
                                setDialogState(() {
                                  imagePath = image.path;
                                });
                              }
                            },
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: imagePath != null
                                    ? Image.file(
                                        File(imagePath!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Icon(
                                          Icons.image_outlined,
                                          size: 60,
                                          color: Colors.grey.shade400,
                                        ),
                                      )
                                    : Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 60,
                                        color: Colors.grey.shade400,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to change image',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Product Name (editable)
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Product Name',
                        prefixIcon: const Icon(Icons.inventory),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category
                    TextField(
                      controller: categoryController,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        prefixIcon: const Icon(Icons.category),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // Edit Lot-wise Details Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _editLotWiseDetails(productName);
                        },
                        icon: const Icon(Icons.layers),
                        label: const Text('Edit Lot-wise Details'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'To change prices or quantities, use "Edit Lot-wise Details"',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      if (result == true && mounted) {
        // Save image first if changed
        if (imagePath != null && !imagePath!.startsWith('assets/')) {
          final appDir = Directory.current.path;
          final fileName = 'product_${productName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final targetPath = '$appDir/assets/images/$fileName';

          final dir = Directory('$appDir/assets/images');
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }

          await File(imagePath!).copy(targetPath);
          imagePath = 'assets/images/$fileName';
        }

        final newName = nameController.text.trim();
        await _productService.updateProductDetails(
          productName: productName,
          newName: newName.isEmpty ? null : newName,
          category: categoryController.text.trim().isEmpty ? null : categoryController.text.trim(),
          description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
          imagePath: imagePath,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${newName.isEmpty ? productName : newName} updated successfully')),
          );
          _loadProducts();
        }
      }

      nameController.dispose();
      categoryController.dispose();
      descriptionController.dispose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error editing product: $e')),
        );
      }
    }
  }

  Future<void> _editLotWiseDetails(String productName) async {
    try {
      final lots = await _productService.getAllLotsForProduct(productName);

      if (lots.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No lots found for this product')),
          );
        }
        return;
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 700,
            constraints: const BoxConstraints(maxHeight: 800),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade700, Colors.orange.shade500],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.edit_note, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Lot-wise Details',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              productName.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Lots list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: lots.length,
                    itemBuilder: (context, index) {
                      final lot = lots[index];
                      return _buildEditableLotCard(lot, index + 1);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading lots: $e')),
        );
      }
    }
  }

  Widget _buildEditableLotCard(Map<String, dynamic> lot, int serialNumber) {
    final lotId = lot['lot_id'] as int;
    final productId = lot['product_id'] as int;
    final unitPrice = (lot['unit_price'] as num?)?.toDouble() ?? 0.0;
    final sellingPrice = (lot['selling_price'] as num?)?.toDouble() ?? 0.0;
    final stock = (lot['current_stock'] as num?)?.toDouble() ?? 0.0;
    final receivedDate = lot['received_date'] as String?;
    final notes = lot['lot_description'] as String? ?? '';
    final unit = lot['unit'] as String? ?? 'piece';
    final productName = lot['product_name'] as String? ?? '';

    final lotNameController = TextEditingController(text: productName);
    final sellingPriceController = TextEditingController(text: sellingPrice.toStringAsFixed(2));
    final notesController = TextEditingController(text: notes);

    // Format date
    String formattedDate = '';
    if (receivedDate != null) {
      formattedDate = DateTime.tryParse(receivedDate)
              ?.toLocal()
              .toString()
              .split(' ')[0] ??
          receivedDate;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lot header with serial number
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade100, Colors.orange.shade50],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Lot #$serialNumber',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Always show lot name (N/A if empty)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: notes.isNotEmpty ? Colors.green.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: notes.isNotEmpty ? Colors.green.shade200 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.label,
                          size: 14,
                          color: notes.isNotEmpty ? Colors.green.shade700 : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            notes.isNotEmpty ? notes : 'N/A',
                            style: TextStyle(
                              color: notes.isNotEmpty ? Colors.green.shade900 : Colors.grey.shade600,
                              fontSize: 13,
                              fontWeight: notes.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Show date
            if (formattedDate.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Lot Name (editable)
            TextField(
              controller: lotNameController,
              decoration: InputDecoration(
                labelText: 'Lot Name',
                prefixIcon: const Icon(Icons.label),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Read-only and editable fields in a grid
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: unitPrice.toStringAsFixed(2)),
                    decoration: InputDecoration(
                      labelText: 'Buying Price ($_currencySymbol)',
                      prefixIcon: const Icon(Icons.shopping_cart),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    enabled: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: sellingPriceController,
                    decoration: InputDecoration(
                      labelText: 'Selling Price ($_currencySymbol)',
                      prefixIcon: const Icon(Icons.sell),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: stock.toStringAsFixed(2)),
                    decoration: InputDecoration(
                      labelText: 'Stock Quantity ($unit)',
                      prefixIcon: const Icon(Icons.inventory),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    enabled: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(
                      text: receivedDate != null
                          ? DateTime.tryParse(receivedDate)?.toLocal().toString().split(' ')[0] ?? receivedDate
                          : '',
                    ),
                    decoration: InputDecoration(
                      labelText: 'Received Date',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    enabled: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Lot Description (editable)
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'Lot Description',
                prefixIcon: const Icon(Icons.note),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Info message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You can edit: Lot Name, Selling Price, and Description. Buying price, stock, and date are read-only.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    // Parse and validate selling price
                    final newSellingPrice = double.tryParse(sellingPriceController.text.trim());
                    if (newSellingPrice == null || newSellingPrice < 0) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid selling price'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    await _productService.updateLotData(
                      productId: productId,
                      lotId: lotId,
                      lotName: lotNameController.text.trim().isEmpty ? null : lotNameController.text.trim(),
                      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                      sellingPrice: newSellingPrice,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lot #$lotId updated successfully')),
                      );
                      Navigator.pop(context);
                      _loadProducts();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating lot: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteProduct(String productName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 12),
            const Text('Delete Product'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$productName"?\n\n'
          'This will deactivate the product across all lots. '
          'The product will no longer appear in the product list, '
          'but historical transaction data will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _productService.deleteProductByName(productName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$productName deleted successfully')),
          );
          _loadProducts();
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

  Future<void> _showCategoryFilter() async {
    final categories = await _productService.getAllCategories();
    if (!mounted) return;

    final selected = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  Widget _buildProductCard(Map<String, dynamic> productMap) {
    final productName = (productMap['name'] as String?) ?? 'Unknown';
    final currentStock = ((productMap['current_stock'] as num?)?.toDouble() ?? 0.0);
    final reorderLevel = ((productMap['reorder_level'] as num?)?.toDouble() ?? 0.0);
    final lotsCount = ((productMap['lots_count'] as num?)?.toInt() ?? 0);
    final minPrice = ((productMap['min_price'] as num?)?.toDouble());
    final maxPrice = ((productMap['max_price'] as num?)?.toDouble());
    final unit = productMap['unit'] as String? ?? 'piece';
    final category = productMap['category'] as String?;
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
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showProductLotDetails(productMap),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Product image
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: stockColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: stockColor.withOpacity(0.3), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imagePath != null
                      ? Image.file(
                          File(imagePath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.inventory_2,
                            color: stockColor,
                            size: 32,
                          ),
                        )
                      : Icon(
                          Icons.inventory_2,
                          color: stockColor,
                          size: 32,
                        ),
                ),
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
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade100, Colors.blue.shade50],
                              ),
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
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Tooltip(
                              message: 'Low stock',
                              child: Icon(Icons.warning_amber, color: Colors.red.shade700, size: 20),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (category != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.category,
                              size: 16,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              category,
                              style: TextStyle(
                                fontSize: 15,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.grey.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Icon(Icons.inventory_2, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'Stock: ${currentStock.toStringAsFixed(2)} $unit',
                          style: TextStyle(
                            color: stockColor.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.attach_money, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        if (hasPriceRange)
                          Text(
                            'Price: $_currencySymbol${minPrice.toStringAsFixed(2)} - $_currencySymbol${maxPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13),
                          )
                        else if (minPrice != null)
                          Text(
                            'Price: $_currencySymbol${minPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.info_outline, color: Colors.blue.shade700),
                    tooltip: 'View lots',
                    onPressed: () => _showProductLotDetails(productMap),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: Colors.orange.shade700),
                    tooltip: 'Edit details',
                    onPressed: () => _editProduct(productName),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                    tooltip: 'Delete product',
                    onPressed: () => _deleteProduct(productName),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryView() {
    if (_groupedByCategory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No categories yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final categories = _groupedByCategory.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final products = _groupedByCategory[category]!;
        final isExpanded = _expandedCategories.contains(category);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedCategories.remove(category);
                    } else {
                      _expandedCategories.add(category);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade700,
                        Colors.blue.shade500,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          category == 'Uncategorized'
                              ? Icons.help_outline
                              : Icons.category,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${products.length} product(s)',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white,
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: products.map((product) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildProductCard(product),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
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
              child: const Icon(Icons.inventory_2, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Products'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced toolbar with view toggle and filters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search bar with filters
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search products by name, SKU, or barcode...',
                          hintStyle: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[400]
                                : Colors.grey[700],
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[400]
                                        : Colors.grey[700],
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _filterProducts('');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF334155)
                              : Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: _filterProducts,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Filter button
                    Tooltip(
                      message: 'Filter by Category',
                      child: OutlinedButton.icon(
                        onPressed: _showCategoryFilter,
                        icon: Icon(
                          _selectedCategory != null ? Icons.filter_alt : Icons.filter_alt_outlined,
                          color: _selectedCategory != null ? Colors.blue : Colors.grey[700],
                        ),
                        label: Text(
                          _selectedCategory != null ? 'Filtered' : 'Filter',
                          style: TextStyle(
                            color: _selectedCategory != null ? Colors.blue : Colors.grey[700],
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: _selectedCategory != null ? Colors.blue : Colors.grey[300]!,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sort button
                    Tooltip(
                      message: 'Sort',
                      child: PopupMenuButton<String>(
                        icon: Icon(Icons.sort, color: Colors.grey[700]),
                        onSelected: (value) {
                          setState(() => _sortBy = value);
                          _loadProducts();
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'name',
                            child: Row(
                              children: [
                                Icon(Icons.sort_by_alpha, size: 20),
                                SizedBox(width: 12),
                                Text('Sort by Name'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'sku',
                            child: Row(
                              children: [
                                Icon(Icons.qr_code, size: 20),
                                SizedBox(width: 12),
                                Text('Sort by SKU'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'category',
                            child: Row(
                              children: [
                                Icon(Icons.category, size: 20),
                                SizedBox(width: 12),
                                Text('Sort by Category'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'selling_price',
                            child: Row(
                              children: [
                                Icon(Icons.attach_money, size: 20),
                                SizedBox(width: 12),
                                Text('Sort by Price'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'created_at',
                            child: Row(
                              children: [
                                Icon(Icons.date_range, size: 20),
                                SizedBox(width: 12),
                                Text('Sort by Date Added'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // View toggle buttons - More prominent
                Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedViewToggleButton(
                        'View by Product',
                        Icons.view_list,
                        'product',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEnhancedViewToggleButton(
                        'View by Category',
                        Icons.category,
                        'category',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_selectedCategory != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Chip(
                label: Text('Category: $_selectedCategory'),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() => _selectedCategory = null);
                  _filterProducts(_searchController.text);
                },
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _viewMode == 'category'
                    ? _buildCategoryView()
                    : _filteredProducts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  _searchController.text.isEmpty && _selectedCategory == null
                                      ? 'No products yet. Create a Purchase Order to add products.'
                                      : 'No products found',
                                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredProducts.length,
                            padding: const EdgeInsets.all(16),
                            itemBuilder: (context, index) {
                              final productMap = _filteredProducts[index] as Map<String, dynamic>;
                              return _buildProductCard(productMap);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedViewToggleButton(String label, IconData icon, String mode) {
    final isActive = _viewMode == mode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _viewMode = mode;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Theme.of(context).primaryColor : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? Theme.of(context).primaryColor : Colors.grey[300]!,
              width: 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? Colors.white : Colors.grey[700],
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey[700],
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggleButton(String label, IconData icon, String mode) {
    final isActive = _viewMode == mode;

    return GestureDetector(
      onTap: () {
        setState(() {
          _viewMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.blue.shade700 : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.blue.shade700 : Colors.white,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
