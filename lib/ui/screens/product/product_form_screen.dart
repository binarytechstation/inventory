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
  late TextEditingController _categoryController;
  late TextEditingController _descriptionController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _reorderLevelController;

  final FocusNode _categoryFocusNode = FocusNode();
  List<String> _existingCategories = [];
  bool _showCategorySuggestions = false;
  String _unit = 'piece';
  bool _isLoading = false;
  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _categoryController = TextEditingController(text: widget.product?.category ?? '');
    _descriptionController = TextEditingController(text: widget.product?.description ?? '');
    _purchasePriceController = TextEditingController(
      text: widget.product?.defaultPurchasePrice != null &&
              widget.product!.defaultPurchasePrice > 0
          ? widget.product!.defaultPurchasePrice.toStringAsFixed(2)
          : '',
    );
    _sellingPriceController = TextEditingController(
      text: widget.product?.defaultSellingPrice != null &&
              widget.product!.defaultSellingPrice > 0
          ? widget.product!.defaultSellingPrice.toStringAsFixed(2)
          : '',
    );
    _reorderLevelController = TextEditingController(
      text: widget.product?.reorderLevel != null && widget.product!.reorderLevel > 0
          ? widget.product!.reorderLevel.toString()
          : '',
    );
    _unit = widget.product?.unit ?? 'piece';
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _productService.getAllCategories();
      if (mounted) setState(() => _existingCategories = cats);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _reorderLevelController.dispose();
    _categoryFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final product = ProductModel(
        id: widget.product?.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        unit: _unit,
        defaultPurchasePrice:
            double.tryParse(_purchasePriceController.text.trim()) ?? 0,
        defaultSellingPrice:
            double.tryParse(_sellingPriceController.text.trim()) ?? 0,
        taxRate: 0,
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing
              ? 'Product updated successfully'
              : 'Product "${product.name}" created. Stock will be added via purchase orders.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving product: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Product Information ─────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Product Information',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // Product Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2),
                        hintText: 'e.g., Samsung S35',
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Product name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category + inline suggestions
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _categoryController,
                          focusNode: _categoryFocusNode,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                            hintText: 'e.g., Phone, Electronics',
                            suffixIcon:
                                Icon(Icons.arrow_drop_down, size: 20),
                          ),
                          textCapitalization: TextCapitalization.words,
                          onTap: () =>
                              setState(() => _showCategorySuggestions = true),
                          onChanged: (_) =>
                              setState(() => _showCategorySuggestions = true),
                        ),
                        Builder(builder: (_) {
                          if (!_showCategorySuggestions) {
                            return const SizedBox.shrink();
                          }
                          final q = _categoryController.text.toLowerCase();
                          final filtered = q.isEmpty
                              ? _existingCategories
                              : _existingCategories
                                  .where((c) => c.toLowerCase().contains(q))
                                  .toList();
                          if (filtered.isEmpty) return const SizedBox.shrink();
                          return Container(
                            margin: const EdgeInsets.only(top: 2),
                            constraints: const BoxConstraints(maxHeight: 150),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              border:
                                  Border.all(color: Colors.blue.shade200),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2))
                              ],
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: filtered.length,
                              itemBuilder: (_, i) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.category,
                                    size: 16, color: Colors.blue),
                                title: Text(filtered[i],
                                    style: const TextStyle(fontSize: 13)),
                                onTap: () => setState(() {
                                  _categoryController.text = filtered[i];
                                  _showCategorySuggestions = false;
                                }),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Unit dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.straighten),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'piece', child: Text('Piece')),
                        DropdownMenuItem(value: 'kg', child: Text('Kilogram')),
                        DropdownMenuItem(value: 'liter', child: Text('Liter')),
                        DropdownMenuItem(value: 'meter', child: Text('Meter')),
                        DropdownMenuItem(value: 'box', child: Text('Box')),
                        DropdownMenuItem(value: 'dozen', child: Text('Dozen')),
                      ],
                      onChanged: (v) => setState(() => _unit = v!),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                        hintText: 'Product description',
                      ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Price Information ───────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Price Information',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Default prices — can be overridden per transaction.',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _purchasePriceController,
                          decoration: const InputDecoration(
                            labelText: 'Purchase Price',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.shopping_cart),
                            hintText: '0.00',
                            prefixText: '৳ ',
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty) {
                              if (double.tryParse(v.trim()) == null) {
                                return 'Invalid price';
                              }
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _sellingPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Selling Price',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.sell),
                            hintText: '0.00',
                            prefixText: '৳ ',
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty) {
                              if (double.tryParse(v.trim()) == null) {
                                return 'Invalid price';
                              }
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ]),
                    // Live margin preview
                    Builder(builder: (_) {
                      final purchase =
                          double.tryParse(_purchasePriceController.text.trim()) ??
                              0;
                      final selling =
                          double.tryParse(_sellingPriceController.text.trim()) ??
                              0;
                      if (purchase <= 0 || selling <= 0) {
                        return const SizedBox.shrink();
                      }
                      final margin = selling - purchase;
                      final pct = margin / purchase * 100;
                      final isLoss = margin < 0;
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isLoss ? Colors.red[50] : Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: isLoss
                                    ? Colors.red[200]!
                                    : Colors.green[200]!),
                          ),
                          child: Row(children: [
                            Icon(
                                isLoss
                                    ? Icons.trending_down
                                    : Icons.trending_up,
                                color: isLoss ? Colors.red : Colors.green,
                                size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Margin: ৳${margin.toStringAsFixed(2)}  (${pct.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isLoss
                                    ? Colors.red[700]
                                    : Colors.green[700],
                              ),
                            ),
                          ]),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Additional Settings ─────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Additional Settings',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _reorderLevelController,
                      decoration: const InputDecoration(
                        labelText: 'Reorder Level',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.warning_amber),
                        hintText: 'Low stock alert threshold',
                        suffixText: 'pieces',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber[200]!),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline,
                            color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Stock starts at 0 and increases when you create a purchase order for this product.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[700]),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Action Buttons ──────────────────────────────────────
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Cancel'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProduct,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_isEditing ? 'Update Product' : 'Create Product'),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
