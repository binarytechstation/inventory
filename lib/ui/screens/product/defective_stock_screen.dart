import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/defective_stock_model.dart';
import '../../../services/stock/defective_stock_service.dart';
import '../../../services/transaction/transaction_service.dart';
import '../../../services/supplier/supplier_service.dart';
import '../../../services/product/product_service.dart';
import '../../../services/currency/currency_service.dart';
import '../../providers/auth_provider.dart';

/// Defective Stock Management
/// Tab 1 – Pending: items awaiting supplier return or write-off
/// Tab 2 – Returned: items successfully sent back to supplier
/// Tab 3 – Written Off: items that are non-refundable / written off
class DefectiveStockScreen extends StatefulWidget {
  const DefectiveStockScreen({super.key});

  @override
  State<DefectiveStockScreen> createState() => _DefectiveStockScreenState();
}

class _DefectiveStockScreenState extends State<DefectiveStockScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DefectiveStockService _service = DefectiveStockService();
  final TransactionService _txService = TransactionService();
  final SupplierService _supplierService = SupplierService();
  final ProductService _productService = ProductService();
  final CurrencyService _currencyService = CurrencyService();

  List<DefectiveStockModel> _pending = [];
  List<DefectiveStockModel> _returned = [];
  List<DefectiveStockModel> _writtenOff = [];
  String _currencySymbol = '৳';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final all = await _service.getAllDefectiveStock();
      final symbol = await _currencyService.getCurrencySymbol();
      setState(() {
        _pending = all.where((i) => i.supplierReturnStatus == 'PENDING').toList();
        _returned = all.where((i) => i.supplierReturnStatus == 'ACCEPTED').toList();
        _writtenOff = all.where((i) => i.supplierReturnStatus == 'REJECTED').toList();
        _currencySymbol = symbol;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Return to supplier ────────────────────────────────────────────────────

  Future<void> _sendToSupplier(DefectiveStockModel item) async {
    final suppliers = await _supplierService.getAllSuppliers();
    if (!mounted) return;

    final notesCtrl = TextEditingController();
    int? selectedSupplierId = suppliers.isNotEmpty ? suppliers.first.id : null;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Return to Supplier'),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Product summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Qty: ${item.quantity.toStringAsFixed(0)}  ·  '
                          'Refund: $_currencySymbol${(item.quantity * item.refundAmount).toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                    labelText: 'Select Supplier', border: OutlineInputBorder()),
                initialValue: selectedSupplierId,
                items: suppliers
                    .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                    .toList(),
                onChanged: (v) => setS(() => selectedSupplierId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Notes (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This will create a RETURN transaction to the supplier '
                      'and reduce the payable balance by the refund amount.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.local_shipping, size: 16),
              label: const Text('Send Return'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || selectedSupplierId == null || item.id == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final supplierId = selectedSupplierId!;
    try {
      final txId = await _txService.createTransaction(
        type: 'RETURN',
        date: DateTime.now(),
        partyId: supplierId,
        partyType: 'supplier',
        items: [{
          'product_id': item.productId,
          'lot_id': item.lotId,
          'quantity': item.quantity,
          'unit_price': item.refundAmount,
          'subtotal': item.quantity * item.refundAmount,
          'discount': 0.0,
          'tax': 0.0,
          'return_type': 'DEFECTIVE',
          'is_refundable': item.isRefundable,
        }],
        subtotal: item.quantity * item.refundAmount,
        discount: 0,
        tax: 0,
        total: item.quantity * item.refundAmount,
        paymentMode: 'credit', // supplier refund reduces our payable
        notes: notesCtrl.text.isEmpty ? 'Defective return' : notesCtrl.text,
        returnType: 'DEFECTIVE',
      );
      await _service.markSupplierAccepted(item.id!, txId);
      messenger.showSnackBar(SnackBar(
        content: Text('Return sent — $_currencySymbol${(item.quantity * item.refundAmount).toStringAsFixed(2)} credited'),
        backgroundColor: Colors.green,
      ));
      _loadData();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // ─── Write off ─────────────────────────────────────────────────────────────

  Future<void> _writeOff(DefectiveStockModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Write Off Item'),
        content: Text(
            'Mark ${item.productName} (qty: ${item.quantity.toStringAsFixed(0)}) as a write-off?\n\n'
            'This means the supplier will not accept a return for this item.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700),
            child: const Text('Write Off'),
          ),
        ],
      ),
    );
    if (confirm == true && item.id != null) {
      final messenger = ScaffoldMessenger.of(context);
      await _service.markSupplierRejected(item.id!);
      messenger.showSnackBar(const SnackBar(content: Text('Marked as write-off')));
      _loadData();
    }
  }

  // ─── Manually report defective ────────────────────────────────────────────

  Future<void> _showAddDefectiveDialog() async {
    final products = await _productService.getAllProducts();
    if (!mounted) return;

    // Capture context-dependent values before any further async gaps
    final messenger = ScaffoldMessenger.of(context);
    final reporterId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;

    dynamic selectedProduct;
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String source = 'INTERNAL';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Report Defective Item'),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<dynamic>(
                decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()),
                items: products.map((p) => DropdownMenuItem(
                  value: p,
                  child: Text('${p['product_name']} (Lot ${p['lot_id']})'),
                )).toList(),
                onChanged: (v) => setS(() {
                  selectedProduct = v;
                  if (v != null && priceCtrl.text.isEmpty) {
                    priceCtrl.text = (v['unit_price'] ?? '0').toString();
                  }
                }),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: 'Refund Price', prefixText: _currencySymbol,
                        border: const OutlineInputBorder()),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Source', border: OutlineInputBorder()),
                initialValue: source,
                items: const [
                  DropdownMenuItem(value: 'INTERNAL', child: Text('Internal Discovery')),
                  DropdownMenuItem(value: 'CUSTOMER_RETURN', child: Text('Customer Return')),
                ],
                onChanged: (v) => setS(() => source = v ?? 'INTERNAL'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason / Description', border: OutlineInputBorder()),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Report')),
          ],
        ),
      ),
    );

    if (confirm != true || selectedProduct == null) return;
    try {
      await _service.addDefectiveStock(DefectiveStockModel(
        productId: selectedProduct['product_id'] as int,
        lotId: selectedProduct['lot_id'] as int,
        productName: selectedProduct['product_name'] as String,
        quantity: double.tryParse(qtyCtrl.text) ?? 1,
        source: source,
        reason: reasonCtrl.text.isEmpty ? null : reasonCtrl.text,
        supplierReturnStatus: 'PENDING',
        isRefundable: true,
        refundAmount: double.tryParse(priceCtrl.text) ?? 0,
        reportedBy: reporterId,
        reportedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      messenger.showSnackBar(const SnackBar(content: Text('Defective item reported'), backgroundColor: Colors.green));
      _loadData();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final canManage = authProvider.currentUser?.hasPermission('edit_product') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.warning_amber_rounded, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('Defective Stock'),
        ]),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.pending_actions, size: 16),
                const SizedBox(width: 6),
                Text('Pending (${_pending.length})'),
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_outline, size: 16),
                const SizedBox(width: 6),
                Text('Returned (${_returned.length})'),
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cancel_outlined, size: 16),
                const SizedBox(width: 6),
                Text('Written Off (${_writtenOff.length})'),
              ]),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingTab(canManage),
                _buildList(_returned, emptyMsg: 'No returned items yet', emptyIcon: Icons.check_circle_outline),
                _buildList(_writtenOff, emptyMsg: 'No write-offs', emptyIcon: Icons.cancel_outlined),
              ],
            ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: _showAddDefectiveDialog,
              icon: const Icon(Icons.add),
              label: const Text('Report Defective'),
              backgroundColor: Colors.red.shade700,
            )
          : null,
    );
  }

  Widget _buildPendingTab(bool canManage) {
    if (_pending.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green[300]),
          const SizedBox(height: 12),
          const Text('No pending defective items', style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 6),
          const Text('All defective items have been processed.',
              style: TextStyle(color: Colors.grey)),
        ]),
      );
    }

    // Summary bar
    final totalRefundable = _pending
        .where((i) => i.isRefundable)
        .fold(0.0, (s, i) => s + i.quantity * i.refundAmount);

    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.orange.shade50,
        child: Row(children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Text('${_pending.length} items pending  ·  '
              'Potential recovery: $_currencySymbol${totalRefundable.toStringAsFixed(2)}',
              style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _pending.length,
          itemBuilder: (_, i) => _buildCard(_pending[i], showActions: canManage),
        ),
      ),
    ]);
  }

  Widget _buildList(List<DefectiveStockModel> items,
      {required String emptyMsg, required IconData emptyIcon}) {
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(emptyIcon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(emptyMsg, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildCard(items[i], showActions: false),
    );
  }

  Widget _buildCard(DefectiveStockModel item, {bool showActions = false}) {
    final statusColor = _statusColor(item.supplierReturnStatus);
    final sourceLabel = item.source == 'CUSTOMER_RETURN' ? 'Customer Return' : 'Internal';
    final sourceColor = item.source == 'CUSTOMER_RETURN' ? Colors.purple : Colors.grey;
    final refundValue = item.quantity * item.refundAmount;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Row(children: [
                  // Source badge
                  Container(
                    margin: const EdgeInsets.only(right: 6, top: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: sourceColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: sourceColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(sourceLabel,
                        style: TextStyle(fontSize: 10, color: sourceColor, fontWeight: FontWeight.w600)),
                  ),
                  if (item.partyName != null)
                    Text('· ${item.partyName}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ]),
              ]),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                item.supplierReturnStatus.replaceAll('_', ' '),
                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ]),

          const SizedBox(height: 10),

          // Info row
          Row(children: [
            _infoChip(Icons.inventory_2_outlined, 'Qty: ${item.quantity.toStringAsFixed(0)}', Colors.blue),
            const SizedBox(width: 8),
            if (item.isRefundable && refundValue > 0)
              _infoChip(Icons.payments_outlined,
                  '$_currencySymbol${refundValue.toStringAsFixed(2)}', Colors.green)
            else
              _infoChip(Icons.money_off, 'Non-refundable', Colors.grey),
            if (item.reason != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text('Reason: ${item.reason}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ]),

          // Action buttons (only for pending items)
          if (showActions && item.supplierReturnStatus == 'PENDING') ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(children: [
              if (!item.isRefundable)
                Text('Supplier rejected return',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic))
              else ...[
                OutlinedButton.icon(
                  onPressed: () => _writeOff(item),
                  icon: const Icon(Icons.cancel, size: 15),
                  label: const Text('Write Off'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _sendToSupplier(item),
                  icon: const Icon(Icons.local_shipping, size: 15),
                  label: const Text('Return to Supplier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ]),
      );

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING': return Colors.orange;
      case 'ACCEPTED': return Colors.green;
      case 'REJECTED': return Colors.red;
      default: return Colors.grey;
    }
  }
}
