import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/customer_model.dart';
import '../../../services/transaction/transaction_service.dart';
import '../../../services/currency/currency_service.dart';

/// Screen for processing customer product returns (normal or defective).
/// Normal returns → stock restored.
/// Defective returns → added to defective_stock for supplier return workflow.
class CustomerReturnScreen extends StatefulWidget {
  final CustomerModel customer;

  const CustomerReturnScreen({super.key, required this.customer});

  @override
  State<CustomerReturnScreen> createState() => _CustomerReturnScreenState();
}

class _CustomerReturnScreenState extends State<CustomerReturnScreen> {
  final TransactionService _txService = TransactionService();
  final CurrencyService _currencyService = CurrencyService();

  List<Map<String, dynamic>> _pastSales = [];
  Map<String, dynamic>? _selectedTx;

  // Each entry: {product_id, lot_id, product_name, unit_price, max_qty, qty, return_type, reason, selected}
  final List<Map<String, dynamic>> _returnItems = [];

  String _refundMethod = 'cash'; // 'cash' | 'credit'
  String _currencySymbol = '৳';
  bool _isLoadingTxns = true;
  bool _isLoadingLines = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final [txns, symbol] = await Future.wait([
        _txService.getTransactions(partyId: widget.customer.id!, type: 'SELL'),
        _currencyService.getCurrencySymbol(),
      ]);
      if (mounted) {
        setState(() {
          _pastSales = txns as List<Map<String, dynamic>>;
          _currencySymbol = symbol as String;
          _isLoadingTxns = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTxns = false);
    }
  }

  Future<void> _selectTransaction(Map<String, dynamic> tx) async {
    setState(() {
      _selectedTx = tx;
      _isLoadingLines = true;
      _returnItems.clear();
    });
    try {
      final originalTxId = tx['id'] as int;
      final [lines, returnedQtysRaw] = await Future.wait([
        _txService.getTransactionLines(originalTxId),
        _txService.getReturnedQuantities(originalTxId),
      ]);

      final returnedQtys = returnedQtysRaw as Map<int, Map<int, double>>;

      setState(() {
        for (final line in lines as List<Map<String, dynamic>>) {
          final productId = line['product_id'] as int;
          final lotId = (line['lot_id'] ?? 1) as int;
          final originalQty = (line['quantity'] as num).toDouble();
          final alreadyReturned = returnedQtys[productId]?[lotId] ?? 0.0;
          final maxQty = (originalQty - alreadyReturned).clamp(0.0, originalQty);

          // Skip items that have already been fully returned
          if (maxQty <= 0) continue;

          _returnItems.add({
            'product_id': productId,
            'lot_id': lotId,
            'product_name': line['product_name'] as String? ?? 'Product',
            'unit_price': (line['unit_price'] as num).toDouble(),
            'original_qty': originalQty,
            'already_returned': alreadyReturned,
            'max_qty': maxQty,
            'qty': 0.0,
            'return_type': 'NORMAL',
            'reason': '',
            'selected': false,
          });
        }
        _isLoadingLines = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingLines = false);
    }
  }

  double get _totalRefund {
    double t = 0;
    for (final item in _returnItems) {
      if (item['selected'] == true) {
        t += (item['qty'] as double) * (item['unit_price'] as double);
      }
    }
    return t;
  }

  List<Map<String, dynamic>> get _selectedItems =>
      _returnItems.where((i) => i['selected'] == true && (i['qty'] as double) > 0).toList();

  Future<void> _submit() async {
    if (_selectedTx == null) {
      _snack('Please select a transaction to return from.');
      return;
    }
    if (_selectedItems.isEmpty) {
      _snack('Select at least one item with quantity > 0.');
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final items = _selectedItems.map((item) => {
        'product_id': item['product_id'],
        'lot_id': item['lot_id'],
        'quantity': item['qty'],
        'unit_price': item['unit_price'],
        'subtotal': (item['qty'] as double) * (item['unit_price'] as double),
        'discount': 0.0,
        'tax': 0.0,
        'return_type': item['return_type'],
        'reason': item['reason'] ?? '',
        'is_refundable': true,
      }).toList();

      await _txService.createTransaction(
        type: 'RETURN',
        date: DateTime.now(),
        partyId: widget.customer.id!,
        partyType: 'customer',
        items: items,
        subtotal: _totalRefund,
        discount: 0,
        tax: 0,
        total: _totalRefund,
        paymentMode: _refundMethod, // 'cash' → physical refund, 'credit' → reduce balance
        notes: 'Return from ${widget.customer.name} | Ref: ${_selectedTx!['invoice_number']}',
        referenceTransactionId: _selectedTx!['id'] as int,
      );

      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Return processed — $_currencySymbol${_totalRefund.toStringAsFixed(2)} '
              '${_refundMethod == 'cash' ? 'cash refunded' : 'credited to account'}'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Process Return', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(widget.customer.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
        ]),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: Row(children: [
        // LEFT: Transaction list
        SizedBox(
          width: 320,
          child: Card(
            margin: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Select a past sale to return from',
                    style: theme.textTheme.titleSmall),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isLoadingTxns
                    ? const Center(child: CircularProgressIndicator())
                    : _pastSales.isEmpty
                        ? const Center(child: Text('No sales found for this customer'))
                        : ListView.builder(
                            itemCount: _pastSales.length,
                            itemBuilder: (_, i) {
                              final tx = _pastSales[i];
                              final isSelected = _selectedTx?['id'] == tx['id'];
                              final total = (tx['total_amount'] as num).toDouble();
                              final status = tx['payment_status'] as String? ?? 'PAID';
                              final date = DateTime.tryParse(tx['transaction_date'] as String? ?? '');
                              return InkWell(
                                onTap: () => _selectTransaction(tx),
                                child: Container(
                                  color: isSelected
                                      ? Colors.orange.withValues(alpha: 0.15)
                                      : null,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(children: [
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(tx['invoice_number'] as String? ?? '—',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        if (date != null)
                                          Text(DateFormat('dd MMM yyyy').format(date),
                                              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                      ]),
                                    ),
                                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                      Text('$_currencySymbol${total.toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: status == 'PAID'
                                              ? Colors.green.shade100
                                              : Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(status,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: status == 'PAID'
                                                    ? Colors.green.shade700
                                                    : Colors.orange.shade700)),
                                      ),
                                    ]),
                                  ]),
                                ),
                              );
                            },
                          ),
              ),
            ]),
          ),
        ),

        // RIGHT: Items + controls
        Expanded(
          child: _selectedTx == null
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.reply_all, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text('Select a sale on the left to start processing a return',
                        style: TextStyle(color: Colors.grey[500])),
                  ]),
                )
              : Column(children: [
                  // Items list
                  Expanded(
                    child: _isLoadingLines
                        ? const Center(child: CircularProgressIndicator())
                        : _returnItems.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline,
                                        size: 56, color: Colors.green.shade400),
                                    const SizedBox(height: 12),
                                    const Text('All items have already been returned',
                                        style: TextStyle(fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Text('Nothing left to return from this invoice.',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _returnItems.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (_, i) => _buildReturnItemCard(i, isDark, theme),
                              ),
                  ),

                  // Bottom summary + controls
                  if (_returnItems.isNotEmpty)
                    _buildBottomBar(theme),
                ]),
        ),
      ]),
    );
  }

  Widget _buildReturnItemCard(int i, bool isDark, ThemeData theme) {
    final item = _returnItems[i];
    final isSelected = item['selected'] == true;
    final maxQty = item['max_qty'] as double;
    final qty = item['qty'] as double;
    final isDefective = item['return_type'] == 'DEFECTIVE';

    return Card(
      elevation: isSelected ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isSelected
            ? BorderSide(color: Colors.orange.shade400, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Checkbox(
              value: isSelected,
              activeColor: Colors.orange,
              onChanged: (_) => setState(() {
                _returnItems[i]['selected'] = !isSelected;
                if (!isSelected && qty == 0) _returnItems[i]['qty'] = 1.0;
              }),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['product_name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(children: [
                  Text('Max: ${maxQty.toStringAsFixed(0)} units · '
                      '$_currencySymbol${(item['unit_price'] as double).toStringAsFixed(2)} each',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  if ((item['already_returned'] as double? ?? 0) > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text(
                        '${(item['already_returned'] as double).toStringAsFixed(0)} already returned',
                        style: TextStyle(fontSize: 10, color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ]),
              ]),
            ),
            if (isSelected)
              Text('$_currencySymbol${(qty * (item['unit_price'] as double)).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),

          if (isSelected) ...[
            const SizedBox(height: 10),
            Row(children: [
              // Quantity control
              const SizedBox(width: 40),
              Text('Qty:', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              const SizedBox(width: 8),
              _qtyButton(Icons.remove, () {
                if (qty > 1) setState(() => _returnItems[i]['qty'] = qty - 1);
              }),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${qty.toInt()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              _qtyButton(Icons.add, () {
                if (qty < maxQty) setState(() => _returnItems[i]['qty'] = qty + 1);
              }),
              const SizedBox(width: 24),

              // Return type
              Text('Type:', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Normal'),
                selected: !isDefective,
                selectedColor: Colors.green.shade100,
                onSelected: (_) => setState(() => _returnItems[i]['return_type'] = 'NORMAL'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Defective'),
                selected: isDefective,
                selectedColor: Colors.red.shade100,
                onSelected: (_) => setState(() => _returnItems[i]['return_type'] = 'DEFECTIVE'),
              ),
            ]),

            if (isDefective) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Reason for defective (optional)',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (v) => _returnItems[i]['reason'] = v,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 40, top: 6),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text('Defective items go to defective stock — not back to regular stock.',
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
                ]),
              ),
            ],
          ],
        ]),
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18),
        ),
      );

  Widget _buildBottomBar(ThemeData theme) {
    final hasSelection = _selectedItems.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(children: [
        // Refund method
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Refund Method', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(children: [
              _refundChip('cash', Icons.payments_outlined, 'Cash Refund',
                  'Give cash back to customer'),
              const SizedBox(width: 10),
              _refundChip('credit', Icons.account_balance_wallet_outlined, 'Credit Note',
                  'Reduce outstanding balance'),
            ]),
          ]),
        ),
        const SizedBox(width: 24),

        // Total + submit
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Return Total', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          Text('$_currencySymbol${_totalRefund.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: hasSelection && !_isSaving ? _submit : null,
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline),
            label: Text(_isSaving ? 'Processing…' : 'Process Return'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _refundChip(String value, IconData icon, String label, String sub) {
    final selected = _refundMethod == value;
    return InkWell(
      onTap: () => setState(() => _refundMethod = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
              color: selected ? Colors.orange.shade600 : Colors.grey.shade400, width: 1.5),
          borderRadius: BorderRadius.circular(10),
          color: selected ? Colors.orange.withValues(alpha: 0.08) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: selected ? Colors.orange.shade700 : Colors.grey),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: selected ? Colors.orange.shade700 : null)),
            Text(sub,
                style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ]),
        ]),
      ),
    );
  }
}
