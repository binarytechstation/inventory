import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/product_model.dart';
import '../../../services/product/product_service.dart';

class ProductFormScreen extends StatefulWidget {
  final ProductModel? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _productService = ProductService();

  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _barcodeController;
  late TextEditingController _descriptionController;
  late TextEditingController _unitController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _taxRateController;
  late TextEditingController _reorderLevelController;
  late TextEditingController _categoryController;

  bool _isLoading = false;
  bool get _isEditing => widget.product != null;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _skuController = TextEditingController(text: widget.product?.sku ?? '');
    _barcodeController = TextEditingController(text: widget.product?.barcode ?? '');
    _descriptionController = TextEditingController(text: widget.product?.description ?? '');
    _unitController = TextEditingController(text: widget.product?.unit ?? 'piece');
    _purchasePriceController = TextEditingController(
      text: widget.product?.defaultPurchasePrice.toString() ?? '0',
    );
    _sellingPriceController = TextEditingController(
      text: widget.product?.defaultSellingPrice.toString() ?? '0',
    );
    _taxRateController = TextEditingController(
      text: widget.product?.taxRate.toString() ?? '0',
    );
    _reorderLevelController = TextEditingController(
      text: widget.product?.reorderLevel.toString() ?? '0',
    );
    _categoryController = TextEditingController(text: widget.product?.category ?? '');
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _descriptionController.dispose();
    _unitController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _taxRateController.dispose();
    _reorderLevelController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _productService.getAllCategories();
      setState(() => _categories = categories);
    } catch (e) {
      // Ignore error
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final product = ProductModel(
        id: widget.product?.id,
        name: _nameController.text.trim(),
        sku: _skuController.text.trim().isEmpty
            ? null
            : _skuController.text.trim(),
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        unit: _unitController.text.trim(),
        defaultPurchasePrice: double.tryParse(_purchasePriceController.text.trim()) ?? 0,
        defaultSellingPrice: double.tryParse(_sellingPriceController.text.trim()) ?? 0,
        taxRate: double.tryParse(_taxRateController.text.trim()) ?? 0,
        reorderLevel: int.tryParse(_reorderLevelController.text.trim()) ?? 0,
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
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
                : 'Product created successfully'),
            backgroundColor: Colors.green,
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Basic Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter product name';
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _skuController,
                            decoration: const InputDecoration(
                              labelText: 'SKU',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.qr_code),
                              hintText: 'Stock Keeping Unit',
                            ),
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _barcodeController,
                            decoration: const InputDecoration(
                              labelText: 'Barcode',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.barcode_reader),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pricing & Unit',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit of Measurement *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.straighten),
                        hintText: 'e.g., piece, kg, box, liter',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter unit';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _purchasePriceController,
                            decoration: const InputDecoration(
                              labelText: 'Purchase Price *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.shopping_cart),
                              prefixText: '\$ ',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              final amount = double.tryParse(value.trim());
                              if (amount == null || amount < 0) {
                                return 'Invalid amount';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _sellingPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Selling Price *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.point_of_sale),
                              prefixText: '\$ ',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              final amount = double.tryParse(value.trim());
                              if (amount == null || amount < 0) {
                                return 'Invalid amount';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _taxRateController,
                      decoration: const InputDecoration(
                        labelText: 'Tax Rate (%)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.percent),
                        hintText: 'e.g., 5 for 5%',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final rate = double.tryParse(value.trim());
                          if (rate == null || rate < 0 || rate > 100) {
                            return 'Enter valid rate (0-100)';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inventory Management',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _categoryController,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.category),
                        suffixIcon: _categories.isNotEmpty
                            ? PopupMenuButton<String>(
                                icon: const Icon(Icons.arrow_drop_down),
                                onSelected: (value) {
                                  _categoryController.text = value;
                                },
                                itemBuilder: (context) => _categories
                                    .map((cat) => PopupMenuItem(
                                          value: cat,
                                          child: Text(cat),
                                        ))
                                    .toList(),
                              )
                            : null,
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _reorderLevelController,
                      decoration: const InputDecoration(
                        labelText: 'Reorder Level',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.warning_amber),
                        hintText: 'Low stock alert threshold',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final level = int.tryParse(value.trim());
                          if (level == null || level < 0) {
                            return 'Enter valid number';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
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
                      child: Text(_isEditing ? 'Update' : 'Create'),
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
