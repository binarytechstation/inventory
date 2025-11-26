import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../data/models/product_model.dart';
import '../../../services/product/product_service.dart';
import '../../../data/database/database_helper.dart';

class ProductFormScreen extends StatefulWidget {
  final ProductModel? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _productService = ProductService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _lotNumberController;
  late TextEditingController _descriptionController;
  late TextEditingController _itemController; // Pieces per lot
  late TextEditingController _reorderLevelController;

  bool _isLoading = false;
  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _lotNumberController = TextEditingController();
    _descriptionController = TextEditingController(text: widget.product?.description ?? '');
    _itemController = TextEditingController(); // Pieces per lot
    _reorderLevelController = TextEditingController(
      text: widget.product?.reorderLevel.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lotNumberController.dispose();
    _descriptionController.dispose();
    _itemController.dispose();
    _reorderLevelController.dispose();
    super.dispose();
  }

  String _generateProductName() {
    final baseName = _nameController.text.trim();
    final currentDate = DateFormat('dd-MMM-yyyy').format(DateTime.now());
    final lotNumber = _lotNumberController.text.trim();

    if (lotNumber.isEmpty) {
      return '$baseName $currentDate';
    } else {
      return '$baseName $currentDate $lotNumber';
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final item = int.parse(_itemController.text.trim());

      // Generate full product name with date and lot number
      final fullProductName = _generateProductName();

      final product = ProductModel(
        id: widget.product?.id,
        name: fullProductName,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        unit: 'piece per lot', // Fixed unit
        defaultPurchasePrice: 0, // Initially empty
        defaultSellingPrice: 0, // Initially empty
        taxRate: 0,
        reorderLevel: _reorderLevelController.text.trim().isEmpty
            ? 0
            : int.parse(_reorderLevelController.text.trim()),
        category: null,
        isActive: widget.product?.isActive ?? true,
        createdAt: widget.product?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEditing) {
        await _productService.updateProduct(product);
      } else {
        await _productService.createProduct(product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Product updated successfully'
                : 'Product created successfully\n'
                  'Item: $item piece per lot\n'
                  'Stock: 0 (will be added during purchase transaction)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving product: $e'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
        actions: [
          if (_isLoading)
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
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Product Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Product Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Product Base Name (Required)
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name of Product *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2),
                        hintText: 'Base product name',
                        helperText: 'Full name will include date and lot number',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Product name is required';
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.words,
                      onChanged: (value) => setState(() {}), // Trigger rebuild for preview
                    ),
                    const SizedBox(height: 16),

                    // Lot Number (Optional)
                    TextFormField(
                      controller: _lotNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Lot Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                        hintText: 'Optional - e.g., BATCH-A',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (value) => setState(() {}), // Trigger rebuild for preview
                    ),
                    const SizedBox(height: 16),

                    // Product Name Preview
                    if (_nameController.text.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.label, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Full Product Name:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _generateProductName(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Description (Optional)
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                        hintText: 'Product description (optional)',
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Item Definition Card
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Item Definition',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Define how many pieces are in one lot',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Item (Pieces per Lot) - Required
                    TextFormField(
                      controller: _itemController,
                      decoration: const InputDecoration(
                        labelText: 'Item (Total Product in a Lot) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory),
                        hintText: 'e.g., 50',
                        suffixText: 'piece per lot',
                        filled: true,
                        fillColor: Colors.white,
                        helperText: 'How many pieces in one lot/carton/box?',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Item quantity is required';
                        }
                        final item = int.tryParse(value.trim());
                        if (item == null || item <= 0) {
                          return 'Enter valid number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Stock & Price Information Card
            Card(
              color: Colors.amber[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.amber, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Stock & Price Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Initial Values (will be updated during purchase transaction):',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '• Stock: 0 pieces',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                '• Price: Empty (৳0)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'When you make a purchase transaction, you will enter the lot quantity, and the stock will be calculated as: Lot Quantity × Item',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
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
            ),

            const SizedBox(height: 16),

            // Additional Settings Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Additional Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Reorder Level (Optional)
                    TextFormField(
                      controller: _reorderLevelController,
                      decoration: const InputDecoration(
                        labelText: 'Reorder Level',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.warning_amber),
                        hintText: 'Low stock alert threshold (optional)',
                        suffixText: 'pieces',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProduct,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(_isEditing ? 'Update Product' : 'Create Product'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
