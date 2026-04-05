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
        _returned = all
            .where((i) =>
                i.supplierReturnStatus == 'ACCEPTED' ||
                i.supplierReturnStatus == 'RETURNED_TO_STOCK')
            .toList();
        _writtenOff = all.where((i) => i.supplierReturnStatus == 'REJECTED').toList();
        _currencySymbol = symbol;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Return to stock (after inspection) ───────────────────────────────────

  Future<void> _returnToStock(DefectiveStockModel item) async {
    final notesCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final userId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.inventory_2, color: Colors.green.shade700, size: 22),
          ),
          const SizedBox(width: 10),
          const Text('Return to Stock'),
        ]),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Product summary card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.teal.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(children: [
                Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Row(children: [
                      _dialogChip(Icons.inventory_2_outlined,
                          'Qty: ${item.quantity.toStringAsFixed(0)}', Colors.green),
                      const SizedBox(width: 8),
                      _dialogChip(Icons.label_outline,
                          item.source == 'CUSTOMER_RETURN' ? 'Customer Return' : 'Internal',
                          Colors.purple),
                    ]),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Inspection checklist
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.fact_check_outlined, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Text('Pre-restock checklist',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                          fontSize: 13)),
                ]),
                const SizedBox(height: 8),
                _checkItem('Item inspected and found to be in sellable condition'),
                _checkItem('Packaging is acceptable or replaced'),
                _checkItem('No functional defects confirmed'),
              ]),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Inspection Notes (optional)',
                hintText: 'e.g. Cleaned and repackaged, minor cosmetic scratch only…',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.notes_outlined),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 12),

            // Warning note
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${item.quantity.toStringAsFixed(0)} unit(s) will be added back to '
                    'Lot ${item.lotId} inventory immediately.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                ),
              ]),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.inventory_2, size: 16),
            label: const Text('Confirm & Restock'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600),
          ),
        ],
      ),
    );

    notesCtrl.dispose();
    if (confirm != true || item.id == null) return;

    try {
      await _service.returnToStock(
        defectiveId: item.id!,
        productId: item.productId,
        lotId: item.lotId,
        quantity: item.quantity,
        userId: userId,
        notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
      );
      messenger.showSnackBar(SnackBar(
        content: Text(
            '${item.quantity.toStringAsFixed(0)} × ${item.productName} added back to stock'),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ));
      _loadData();
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _checkItem(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.check, size: 14, color: Colors.green.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: Colors.blue.shade800)),
          ),
        ]),
      );

  Widget _dialogChip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ]),
      );

  // ─── Return to supplier ────────────────────────────────────────────────────

  Future<void> _sendToSupplier(DefectiveStockModel item) async {
    final suppliers = await _supplierService.getAllSuppliers();
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    final notesCtrl = TextEditingController();
    // Editable refund amount — pre-fill with stored value but user can correct it
    final refundCtrl = TextEditingController(
        text: item.refundAmount > 0
            ? item.refundAmount.toStringAsFixed(2)
            : '');
    // resolution: 'refund' = supplier credits us money, 'replacement' = supplier gives new item
    String resolution = 'refund';

    // Try to pre-select the supplier who was on the original source transaction,
    // otherwise fall back to first in list
    int? selectedSupplierId;
    if (item.partyType == 'supplier' && item.partyId != null) {
      selectedSupplierId = item.partyId;
    } else if (suppliers.isNotEmpty) {
      selectedSupplierId = suppliers.first.id;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          // Find selected supplier for balance preview
          final selSupplier = suppliers.firstWhere(
            (s) => s.id == selectedSupplierId,
            orElse: () => suppliers.isNotEmpty ? suppliers.first : suppliers.first,
          );
          final currentBalance = selectedSupplierId != null ? selSupplier.currentBalance : 0.0;
          final isReplacement = resolution == 'replacement';
          final refundAmt = double.tryParse(refundCtrl.text) ?? 0.0;
          final refundTotal = isReplacement ? 0.0 : item.quantity * refundAmt;
          final balanceAfter = (currentBalance - refundTotal).clamp(0.0, double.infinity);
          final overRefund = !isReplacement && refundTotal > currentBalance && currentBalance > 0;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.local_shipping, color: Colors.blue.shade700, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('Return to Supplier'),
            ]),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Product summary card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.productName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('Qty: ${item.quantity.toStringAsFixed(0)}  ·  '
                              'Lot: ${item.lotId}',
                              style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),

                  // Supplier dropdown
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                        labelText: 'Select Supplier',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.store_outlined)),
                    initialValue: selectedSupplierId,
                    items: suppliers
                        .map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Row(children: [
                                Expanded(child: Text(s.name)),
                                if (s.currentBalance > 0)
                                  Text('Due: $_currencySymbol${s.currentBalance.toStringAsFixed(0)}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red.shade600,
                                          fontWeight: FontWeight.w600)),
                              ]),
                            ))
                        .toList(),
                    onChanged: (v) => setS(() => selectedSupplierId = v),
                  ),
                  const SizedBox(height: 12),

                  // Resolution type — the key distinction
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(children: [
                      _resolutionTile(
                        icon: Icons.currency_exchange,
                        color: Colors.green.shade600,
                        title: 'Cash / Credit Note',
                        subtitle: 'Supplier refunds money or issues a credit note',
                        selected: resolution == 'refund',
                        onTap: () => setS(() => resolution = 'refund'),
                      ),
                      Divider(height: 1, color: Colors.grey.shade200),
                      _resolutionTile(
                        icon: Icons.swap_horiz,
                        color: Colors.blue.shade600,
                        title: 'Replacement Product',
                        subtitle: 'Supplier sends a new item — no money changes hands',
                        selected: resolution == 'replacement',
                        onTap: () => setS(() => resolution = 'replacement'),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // Editable refund amount — hidden for replacement
                  if (!isReplacement) ...[
                  // Editable refund amount per unit
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: refundCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Refund Price (per unit)',
                          prefixText: '$_currencySymbol ',
                          border: const OutlineInputBorder(),
                          helperText: 'Qty ${item.quantity.toStringAsFixed(0)} × price = total refund',
                        ),
                        onChanged: (_) => setS(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Computed total chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(children: [
                        Text('Total', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                        Text('$_currencySymbol${refundTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                                fontSize: 14)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // Balance impact preview (only for refund mode)
                  if (!isReplacement && selectedSupplierId != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: overRefund ? Colors.orange.shade50 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: overRefund ? Colors.orange.shade300 : Colors.blue.shade200),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(
                            overRefund ? Icons.warning_amber : Icons.account_balance_wallet_outlined,
                            size: 15,
                            color: overRefund ? Colors.orange.shade700 : Colors.blue.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text('Supplier Balance Impact',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: overRefund
                                      ? Colors.orange.shade800
                                      : Colors.blue.shade800)),
                        ]),
                        const SizedBox(height: 8),
                        _balanceRow('Current due', currentBalance, Colors.red.shade700),
                        _balanceRow('Refund deduction', refundTotal, Colors.green.shade700,
                            prefix: '−'),
                        const Divider(height: 12, thickness: 1),
                        _balanceRow('Balance after return', balanceAfter,
                            balanceAfter <= 0 ? Colors.green.shade700 : Colors.orange.shade700,
                            bold: true),
                        if (overRefund) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Refund exceeds current due. Please verify the refund price.',
                            style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                          ),
                        ],
                      ]),
                    ),
                  ], // end if (!isReplacement)

                  // Replacement info note
                  if (isReplacement)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(children: [
                        Icon(Icons.swap_horiz, color: Colors.blue.shade700, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Supplier balance will NOT change.\n'
                            'Ensure the replacement item is added as a new purchase.',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                          ),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes_outlined)),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton.icon(
                onPressed: (isReplacement || refundTotal > 0)
                    ? () => Navigator.pop(ctx, true)
                    : null,
                icon: Icon(isReplacement ? Icons.swap_horiz : Icons.local_shipping, size: 16),
                label: Text(isReplacement ? 'Confirm Replacement' : 'Send Return'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isReplacement ? Colors.blue.shade600 : Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirm != true || selectedSupplierId == null || item.id == null) {
      notesCtrl.dispose();
      refundCtrl.dispose();
      return;
    }

    final supplierId = selectedSupplierId!;
    final isReplacement = resolution == 'replacement';
    final confirmedRefundPerUnit =
        isReplacement ? 0.0 : (double.tryParse(refundCtrl.text) ?? item.refundAmount);
    final confirmedTotal = item.quantity * confirmedRefundPerUnit;
    final confirmedNotes = notesCtrl.text.isEmpty
        ? (isReplacement ? 'Defective return — replacement received' : 'Defective return')
        : notesCtrl.text;
    notesCtrl.dispose();
    refundCtrl.dispose();

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
          'unit_price': confirmedRefundPerUnit,
          'subtotal': confirmedTotal,
          'discount': 0.0,
          'tax': 0.0,
          'return_type': 'DEFECTIVE',
          'is_refundable': !isReplacement,
        }],
        subtotal: confirmedTotal,
        discount: 0,
        tax: 0,
        total: confirmedTotal,
        paymentMode: 'cash',
        notes: confirmedNotes,
        returnType: 'DEFECTIVE',
        skipBalanceAdjustment: isReplacement, // replacement = no money, don't touch balance
      );
      await _service.markSupplierAccepted(item.id!, txId);
      messenger.showSnackBar(SnackBar(
        content: Text(isReplacement
            ? 'Replacement recorded — supplier balance unchanged'
            : 'Return sent — $_currencySymbol${confirmedTotal.toStringAsFixed(2)} deducted from supplier balance'),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ));
      _loadData();
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _balanceRow(String label, double amount, Color color,
      {String prefix = '', bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
          ),
          Text('$prefix$_currencySymbol${amount.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
        ]),
      );

  Widget _resolutionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.12) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 18, color: selected ? color : Colors.grey.shade500),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: selected ? color : Colors.grey.shade700)),
                Text(subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ]),
            ),
            if (selected)
              Icon(Icons.check_circle, color: color, size: 20)
            else
              Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400, size: 20),
          ]),
        ),
      );

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
    // searchProducts('') returns per-lot rows with product_name, lot_id, unit_price
    final products = await _productService.searchProducts('');
    if (!mounted) return;

    // Capture context-dependent values before any further async gaps
    final messenger = ScaffoldMessenger.of(context);
    final reporterId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;

    // Build a key→product map so the dropdown value is a plain String (avoids Map equality issues)
    final productMap = <String, Map<String, dynamic>>{};
    for (final p in products) {
      final key = '${p['product_id']}_${p['lot_id']}';
      productMap[key] = p;
    }

    String? selectedKey;
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
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()),
                  initialValue: selectedKey,
                  items: productMap.entries.map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text('${e.value['product_name']} (Lot ${e.value['lot_id']})'),
                  )).toList(),
                  onChanged: (key) => setS(() {
                    selectedKey = key;
                    final p = productMap[key];
                    if (p != null && priceCtrl.text.isEmpty) {
                      priceCtrl.text = (p['unit_price'] ?? '0').toString();
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
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Report')),
          ],
        ),
      ),
    );

    final selectedProduct = productMap[selectedKey];
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_statusIcon(item.supplierReturnStatus), size: 12, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  _statusLabel(item.supplierReturnStatus),
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ]),
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
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (!item.isRefundable)
                Text('Supplier rejected return',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic))
              else ...[
                // Return to Stock — primary action for customer returns after inspection
                FilledButton.icon(
                  onPressed: () => _returnToStock(item),
                  icon: const Icon(Icons.inventory_2, size: 15),
                  label: const Text('Return to Stock'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _sendToSupplier(item),
                  icon: const Icon(Icons.local_shipping, size: 15),
                  label: const Text('Send to Supplier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
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
      case 'ACCEPTED': return Colors.blue;
      case 'RETURNED_TO_STOCK': return Colors.green;
      case 'REJECTED': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'PENDING': return 'PENDING';
      case 'ACCEPTED': return 'SUPPLIER RETURN';
      case 'RETURNED_TO_STOCK': return 'RESTOCKED';
      case 'REJECTED': return 'WRITTEN OFF';
      default: return status.replaceAll('_', ' ');
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'PENDING': return Icons.pending_actions;
      case 'ACCEPTED': return Icons.local_shipping;
      case 'RETURNED_TO_STOCK': return Icons.inventory_2;
      case 'REJECTED': return Icons.cancel;
      default: return Icons.help_outline;
    }
  }
}
