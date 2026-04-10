import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../services/product/product_service.dart';
import '../../../services/currency/currency_service.dart';
import '../../../services/stock/defective_stock_service.dart';
import '../../providers/auth_provider.dart';
import 'defective_stock_screen.dart';
import 'product_form_screen.dart';
import '../transaction/purchase_order_screen.dart';

class ProductsScreen extends StatefulWidget {
  final bool showLowStockOnly;
  const ProductsScreen({super.key, this.showLowStockOnly = false});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with SingleTickerProviderStateMixin {
  final ProductService _productService = ProductService();
  final CurrencyService _currencyService = CurrencyService();
  final DefectiveStockService _defectiveService = DefectiveStockService();
  final ImagePicker _imagePicker = ImagePicker();

  late TabController _tabController;

  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];
  Map<String, List<Map<String, dynamic>>> _groupedByCategory = {};
  final Set<String> _expandedCategories = {};

  // defectiveCounts[productName][lotId] = {total, pending, accepted, writeOff}
  Map<String, Map<int, Map<String, double>>> _defectiveCounts = {};

  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'name';
  String? _selectedCategory;
  bool _lowStockFilterActive = false;
  String _currencySymbol = '৳';

  // View mode: 'product' or 'category'
  String _viewMode = 'product';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _lowStockFilterActive = widget.showLowStockOnly;
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
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDefectiveCounts() async {
    try {
      final rows = await _defectiveService.getDefectiveSummaryByProduct();
      final map = <String, Map<int, Map<String, double>>>{};
      for (final row in rows) {
        final name = (row['product_name'] as String?) ?? '';
        final lotId = (row['lot_id'] as num?)?.toInt() ?? 0;
        map.putIfAbsent(name, () => {})[lotId] = {
          'total': (row['total_defective'] as num?)?.toDouble() ?? 0,
          'pending': (row['pending_return'] as num?)?.toDouble() ?? 0,
          'accepted': (row['accepted_return'] as num?)?.toDouble() ?? 0,
          'writeOff': (row['write_off'] as num?)?.toDouble() ?? 0,
        };
      }
      if (mounted) setState(() => _defectiveCounts = map);
    } catch (_) {}
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
      // Apply any active filters (low stock, category) after load
      _filterProducts(_searchController.text);
      _loadDefectiveCounts();
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

        bool matchesLowStock = true;
        if (_lowStockFilterActive) {
          final stock = (productMap['current_stock'] as num?)?.toDouble() ?? 0.0;
          final reorder = (productMap['reorder_level'] as num?)?.toDouble() ?? 0.0;
          matchesLowStock = stock == 0 || (reorder > 0 && stock <= reorder);
        }

        return matchesSearch && matchesCategory && matchesLowStock;
      }).toList();
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

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.category, color: Colors.orange),
            SizedBox(width: 8),
            Text('Add Category'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g. Electronics, Clothing...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.label_outline),
          ),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) Navigator.pop(ctx, val.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.pop(ctx, name);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (result != null && mounted) {
      try {
        await _productService.addCategory(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Category "$result" added'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding category: $e')),
          );
        }
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
                                    // Defective items for this lot
                                    Builder(builder: (_) {
                                      final lotId = (lot['lot_id'] as num?)?.toInt() ?? 0;
                                      final defData = _defectiveCounts[productName]?[lotId];
                                      if (defData == null || (defData['total'] ?? 0) <= 0) {
                                        return const SizedBox.shrink();
                                      }
                                      final total = defData['total'] ?? 0;
                                      final pending = defData['pending'] ?? 0;
                                      final accepted = defData['accepted'] ?? 0;
                                      final writeOff = defData['writeOff'] ?? 0;
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.red.shade200),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.report_problem, size: 16, color: Colors.red.shade700),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Defective Items: ${total.toStringAsFixed(0)} $unit',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.red.shade800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  _defectivePill('Pending', pending, Colors.orange),
                                                  const SizedBox(width: 8),
                                                  _defectivePill('Accepted', accepted, Colors.green),
                                                  const SizedBox(width: 8),
                                                  _defectivePill('Written Off', writeOff, Colors.grey),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                    const SizedBox(height: 16),
                                    // Delete lot button
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.pop(context); // Close details dialog first
                                          _deleteLot(lot['product_id'] as int, lot['lot_id'] as int, serialNumber, closeDialog: false);
                                        },
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Delete This Lot'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red.shade700,
                                          side: BorderSide(color: Colors.red.shade300, width: 1.5),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
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
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                            color: Colors.white.withValues(alpha: 0.2),
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
                    child: Container(
                      color: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: lots.length,
                        itemBuilder: (context, index) {
                          final lot = lots[index];
                          return _buildEditableLotCard(lot, index + 1);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
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
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lot header with serial number and delete button
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [Colors.orange.shade800.withValues(alpha: 0.5), Colors.orange.shade900.withValues(alpha: 0.3)]
                              : [Colors.orange.shade100, Colors.orange.shade50],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.orange.shade700 : Colors.orange.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2, size: 16, color: isDark ? Colors.orange.shade300 : Colors.orange.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Lot #$serialNumber',
                            style: TextStyle(
                              color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
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
                          color: notes.isNotEmpty
                              ? (isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50)
                              : (isDark ? Colors.grey.shade800 : Colors.grey.shade50),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: notes.isNotEmpty
                                ? (isDark ? Colors.green.shade700 : Colors.green.shade200)
                                : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.label,
                              size: 14,
                              color: notes.isNotEmpty
                                  ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                notes.isNotEmpty ? notes : 'N/A',
                                style: TextStyle(
                                  color: notes.isNotEmpty
                                      ? (isDark ? Colors.green.shade200 : Colors.green.shade900)
                                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
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
                    const SizedBox(width: 12),
                    // Delete lot button
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: isDark ? Colors.red.shade300 : Colors.red.shade700),
                      tooltip: 'Delete this lot',
                      onPressed: () => _deleteLot(productId, lotId, serialNumber),
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
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
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
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Lot Name',
                    labelStyle: TextStyle(color: isDark ? Colors.grey[400] : null),
                    prefixIcon: Icon(Icons.label, color: isDark ? Colors.grey[400] : null),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[400]!),
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
                        style: TextStyle(color: isDark ? Colors.grey[500] : Colors.black54),
                        decoration: InputDecoration(
                          labelText: 'Buying Price ($_currencySymbol)',
                          labelStyle: TextStyle(color: isDark ? Colors.grey[500] : null),
                          prefixIcon: Icon(Icons.shopping_cart, color: isDark ? Colors.grey[500] : null),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.grey.shade900.withValues(alpha: 0.3) : Colors.grey.shade100,
                        ),
                        enabled: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: sellingPriceController,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Selling Price ($_currencySymbol)',
                          labelStyle: TextStyle(color: isDark ? Colors.grey[400] : null),
                          prefixIcon: Icon(Icons.sell, color: isDark ? Colors.grey[400] : null),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[400]!),
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
                        style: TextStyle(color: isDark ? Colors.grey[500] : Colors.black54),
                        decoration: InputDecoration(
                          labelText: 'Stock Quantity ($unit)',
                          labelStyle: TextStyle(color: isDark ? Colors.grey[500] : null),
                          prefixIcon: Icon(Icons.inventory, color: isDark ? Colors.grey[500] : null),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.grey.shade900.withValues(alpha: 0.3) : Colors.grey.shade100,
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
                        style: TextStyle(color: isDark ? Colors.grey[500] : Colors.black54),
                        decoration: InputDecoration(
                          labelText: 'Received Date',
                          labelStyle: TextStyle(color: isDark ? Colors.grey[500] : null),
                          prefixIcon: Icon(Icons.calendar_today, color: isDark ? Colors.grey[500] : null),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.grey.shade900.withValues(alpha: 0.3) : Colors.grey.shade100,
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
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Lot Description',
                    labelStyle: TextStyle(color: isDark ? Colors.grey[400] : null),
                    prefixIcon: Icon(Icons.note, color: isDark ? Colors.grey[400] : null),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[400]!),
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Info message
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.blue.shade700 : Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You can edit: Lot Name, Selling Price, and Description. Buying price, stock, and date are read-only.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
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
      },
    );
  }

  Future<void> _deleteLot(int productId, int lotId, int serialNumber, {bool closeDialog = true}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
              const SizedBox(width: 12),
              Text(
                'Delete Lot #$serialNumber',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete Lot #$serialNumber?\n\n'
            'This will deactivate only this specific lot. '
            'The lot will no longer appear in the product list, '
            'but historical transaction data will be preserved.',
            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.delete),
              label: const Text('Delete Lot'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      try {
        await _productService.deleteProduct(productId, lotId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lot #$serialNumber deleted successfully')),
          );
          if (closeDialog) Navigator.pop(context);
          _loadProducts();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting lot: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteCategory(String categoryName) async {
    final products = _groupedByCategory[categoryName] ?? [];
    final productCount = products.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 10),
            const Expanded(child: Text('Delete Category')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete category "${categoryName}"?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (productCount > 0) ...[
              Text(
                '$productCount product(s) in this category will be moved to "Uncategorized".',
                style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
              ),
            ] else
              const Text('This category is empty.'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _productService.deleteCategoryAndReassign(categoryName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Category "$categoryName" deleted'),
              backgroundColor: Colors.green,
            ),
          );
          _loadProducts();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting category: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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
                        // Defective badge
                        Builder(builder: (_) {
                          final defLots = _defectiveCounts[productName];
                          if (defLots == null || defLots.isEmpty) return const SizedBox.shrink();
                          final totalDef = defLots.values
                              .fold<double>(0, (s, m) => s + (m['total'] ?? 0));
                          if (totalDef <= 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Tooltip(
                              message: '${totalDef.toStringAsFixed(0)} defective item(s)',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.report_problem, size: 11, color: Colors.white),
                                    const SizedBox(width: 3),
                                    Text(
                                      totalDef.toStringAsFixed(0),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
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
                      if (category != 'Uncategorized')
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 22),
                          tooltip: 'Delete category',
                          onPressed: () => _deleteCategory(category),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2, size: 18), text: 'Stock'),
            Tab(icon: Icon(Icons.warning_amber_rounded, size: 18), text: 'Defective'),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 0: Products ────────────────────────────────
          Column(
            children: [
              // Toolbar: search, filter, sort, view-toggle
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search + filter + sort
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(
                                color: isDark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              hintText: 'Search by name, SKU, or barcode...',
                              hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600]),
                              prefixIcon: Icon(Icons.search,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[700]),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[700]),
                                      onPressed: () {
                                        _searchController.clear();
                                        _filterProducts('');
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF334155)
                                  : Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            onChanged: _filterProducts,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _showCategoryFilter,
                          icon: Icon(
                            _selectedCategory != null
                                ? Icons.filter_alt
                                : Icons.filter_alt_outlined,
                            color: _selectedCategory != null
                                ? Colors.blue
                                : Colors.grey[700],
                            size: 18,
                          ),
                          label: Text(
                            _selectedCategory != null ? 'Filtered' : 'Filter',
                            style: TextStyle(
                                color: _selectedCategory != null
                                    ? Colors.blue
                                    : Colors.grey[700]),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(
                                color: _selectedCategory != null
                                    ? Colors.blue
                                    : Colors.grey[300]!),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: _lowStockFilterActive
                              ? 'Showing low stock only — click to clear'
                              : 'Show low stock items only',
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() => _lowStockFilterActive = !_lowStockFilterActive);
                              _filterProducts(_searchController.text);
                            },
                            icon: Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: _lowStockFilterActive
                                  ? Colors.orange.shade700
                                  : Colors.grey[700],
                            ),
                            label: Text(
                              'Low Stock',
                              style: TextStyle(
                                color: _lowStockFilterActive
                                    ? Colors.orange.shade700
                                    : Colors.grey[700],
                                fontWeight: _lowStockFilterActive
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(
                                color: _lowStockFilterActive
                                    ? Colors.orange.shade400
                                    : Colors.grey[300]!,
                                width: _lowStockFilterActive ? 1.5 : 1.0,
                              ),
                              backgroundColor: _lowStockFilterActive
                                  ? Colors.orange.shade50
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        PopupMenuButton<String>(
                          tooltip: 'Sort',
                          icon: Icon(Icons.sort, color: Colors.grey[700]),
                          onSelected: (v) {
                            setState(() => _sortBy = v);
                            _loadProducts();
                          },
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'name', child: Row(children: [Icon(Icons.sort_by_alpha, size: 18), SizedBox(width: 10), Text('Name')])),
                            PopupMenuItem(value: 'sku', child: Row(children: [Icon(Icons.qr_code, size: 18), SizedBox(width: 10), Text('SKU')])),
                            PopupMenuItem(value: 'category', child: Row(children: [Icon(Icons.category, size: 18), SizedBox(width: 10), Text('Category')])),
                            PopupMenuItem(value: 'selling_price', child: Row(children: [Icon(Icons.attach_money, size: 18), SizedBox(width: 10), Text('Price')])),
                            PopupMenuItem(value: 'created_at', child: Row(children: [Icon(Icons.date_range, size: 18), SizedBox(width: 10), Text('Date Added')])),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── Action buttons row ──────────────────
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        final canProduct = auth.currentUser?.hasPermission('create_product') ?? false;
                        final canPurchase = auth.currentUser?.hasPermission('create_purchase') ?? false;
                        if (!canProduct && !canPurchase) return const SizedBox.shrink();
                        return Row(
                          children: [
                            if (canPurchase) ...[
                              _actionButton(
                                label: 'New Purchase',
                                icon: Icons.shopping_cart_outlined,
                                color: Colors.green.shade600,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const PurchaseOrderScreen())),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (canProduct) ...[
                              _actionButton(
                                label: 'Add Product',
                                icon: Icons.add_box_outlined,
                                color: Colors.blue.shade600,
                                onTap: () async {
                                  final r = await Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => const ProductFormScreen()));
                                  if (r == true) _loadProducts();
                                },
                              ),
                              const SizedBox(width: 8),
                              _actionButton(
                                label: 'Add Category',
                                icon: Icons.category_outlined,
                                color: Colors.orange.shade600,
                                onTap: _showAddCategoryDialog,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // ── View toggle ─────────────────────────
                    Row(
                      children: [
                        Expanded(child: _buildEnhancedViewToggleButton('View by Product', Icons.view_list, 'product')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildEnhancedViewToggleButton('View by Category', Icons.category, 'category')),
                      ],
                    ),
                  ],
                ),
              ),
              if (_selectedCategory != null || _lowStockFilterActive)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (_selectedCategory != null)
                        Chip(
                          avatar: const Icon(Icons.category, size: 14),
                          label: Text('Category: $_selectedCategory'),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(() => _selectedCategory = null);
                            _filterProducts(_searchController.text);
                          },
                        ),
                      if (_lowStockFilterActive)
                        Chip(
                          avatar: Icon(Icons.warning_amber_rounded,
                              size: 14, color: Colors.orange.shade700),
                          label: const Text('Low Stock Only'),
                          backgroundColor: Colors.orange.shade50,
                          side: BorderSide(color: Colors.orange.shade300),
                          labelStyle: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600),
                          deleteIcon: Icon(Icons.close,
                              size: 16, color: Colors.orange.shade700),
                          onDeleted: () {
                            setState(() => _lowStockFilterActive = false);
                            _filterProducts(_searchController.text);
                          },
                        ),
                    ],
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
                                          ? 'No products yet.\nCreate a Purchase Order to add products.'
                                          : 'No products found',
                                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredProducts.length,
                                padding: const EdgeInsets.all(16),
                                itemBuilder: (context, index) {
                                  final p = _filteredProducts[index] as Map<String, dynamic>;
                                  return _buildProductCard(p);
                                },
                              ),
              ),
            ],
          ),

          // ── Tab 1: Defective Stock ─────────────────────────
          _DefectiveStockTabView(onManagePressed: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DefectiveStockScreen()));
          }),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedViewToggleButton(String label, IconData icon, String mode) {
    final isActive = _viewMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final inactiveBg = isDark ? Colors.grey[800]! : Colors.grey[100]!;
    final inactiveBorder = isDark ? Colors.grey[600]! : Colors.grey[300]!;
    final inactiveContent = isDark ? Colors.grey[300]! : Colors.grey[700]!;

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
            color: isActive ? Theme.of(context).primaryColor : inactiveBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? Theme.of(context).primaryColor : inactiveBorder,
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
                color: isActive ? Colors.white : inactiveContent,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : inactiveContent,
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

  Widget _defectivePill(String label, double qty, MaterialColor color) {
    if (qty <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade300),
      ),
      child: Text(
        '$label: ${qty.toStringAsFixed(0)}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color.shade800,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Defective Stock Tab View (embedded, no Scaffold)
// ─────────────────────────────────────────────────────────────────────────────

class _DefectiveStockTabView extends StatefulWidget {
  final VoidCallback onManagePressed;
  const _DefectiveStockTabView({required this.onManagePressed});

  @override
  State<_DefectiveStockTabView> createState() => _DefectiveStockTabViewState();
}

class _DefectiveStockTabViewState extends State<_DefectiveStockTabView> {
  final DefectiveStockService _service = DefectiveStockService();
  List<Map<String, dynamic>> _rows = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final rows = await _service.getDefectiveSummaryByProduct();
      if (mounted) setState(() { _rows = rows; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Toolbar ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Defective Products',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                      ),
                    ),
                    Text(
                      '${_rows.length} product(s) with defective stock',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: widget.onManagePressed,
                    icon: const Icon(Icons.manage_search, size: 16),
                    label: const Text('Manage'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Body ─────────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 72, color: Colors.green.shade400),
                          const SizedBox(height: 16),
                          const Text('No defective stock recorded',
                              style: TextStyle(fontSize: 18, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Text('All inventory is in good condition.',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : _buildGroupedList(),
        ),
      ],
    );
  }

  Widget _buildGroupedList() {
    // Group rows by product name
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in _rows) {
      final name = (row['product_name'] as String?) ?? 'Unknown';
      grouped.putIfAbsent(name, () => []).add(row);
    }
    final products = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final productName = products[index];
        final lots = grouped[productName]!;
        final totalDef = lots.fold<double>(
            0, (s, r) => s + ((r['total_defective'] as num?)?.toDouble() ?? 0));

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Icon(Icons.report_problem, color: Colors.red.shade600, size: 22),
              ),
              title: Text(
                productName.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                '${lots.length} lot(s) · ${totalDef.toStringAsFixed(0)} total defective',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  totalDef.toStringAsFixed(0),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              children: lots.map((lot) {
                final lotId = (lot['lot_id'] as num?)?.toInt() ?? 0;
                final total = (lot['total_defective'] as num?)?.toDouble() ?? 0;
                final pending = (lot['pending_return'] as num?)?.toDouble() ?? 0;
                final accepted = (lot['accepted_return'] as num?)?.toDouble() ?? 0;
                final writeOff = (lot['write_off'] as num?)?.toDouble() ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Text(
                          'Lot #$lotId',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _statusChip('Total', total, Colors.red),
                            if (pending > 0) _statusChip('Pending', pending, Colors.orange),
                            if (accepted > 0) _statusChip('Accepted', accepted, Colors.green),
                            if (writeOff > 0) _statusChip('Written Off', writeOff, Colors.grey),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _statusChip(String label, double qty, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade300),
      ),
      child: Text(
        '$label: ${qty.toStringAsFixed(0)}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color.shade800,
        ),
      ),
    );
  }
}
