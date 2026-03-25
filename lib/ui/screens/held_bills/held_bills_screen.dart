import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/transaction/held_bills_service.dart';
import '../../../services/transaction/transaction_service.dart';
import '../../../services/payment/payment_service.dart';
import '../../../services/currency/currency_service.dart';
import '../../providers/auth_provider.dart';
import '../transaction/transaction_form_screen.dart';

class HeldBillsScreen extends StatefulWidget {
  const HeldBillsScreen({super.key});

  @override
  State<HeldBillsScreen> createState() => _HeldBillsScreenState();
}

class _HeldBillsScreenState extends State<HeldBillsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final HeldBillsService _heldBillsService = HeldBillsService();
  final TransactionService _txService = TransactionService();
  final PaymentService _paymentService = PaymentService();
  final CurrencyService _currencyService = CurrencyService();

  // Drafts
  List<Map<String, dynamic>> _drafts = [];
  String? _draftFilter; // 'SELL' | 'BUY' | null

  // Supplier credit bills
  List<Map<String, dynamic>> _supplierCreditTxns = [];
  Map<String, List<Map<String, dynamic>>> _supplierCreditByCompany = {};

  // Customer credit bills
  List<Map<String, dynamic>> _customerCreditTxns = [];
  Map<String, List<Map<String, dynamic>>> _customerCreditByCompany = {};

  bool _isLoadingDrafts = true;
  bool _isLoadingSupplier = true;
  bool _isLoadingCustomer = true;
  String _currencySymbol = '৳';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadCurrency();
    _loadAll();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    switch (_tabController.index) {
      case 0: _loadDrafts(); break;
      case 1: _loadSupplierCredit(); break;
      case 2: _loadCustomerCredit(); break;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrency() async {
    try {
      final s = await _currencyService.getCurrencySymbol();
      if (mounted) setState(() => _currencySymbol = s);
    } catch (_) {}
  }

  Future<void> _loadAll() async {
    // Reconcile stale transaction statuses before displaying
    try {
      await _paymentService.reconcileTransactionStatuses();
    } catch (_) {}
    await Future.wait([_loadDrafts(), _loadSupplierCredit(), _loadCustomerCredit()]);
  }

  Future<void> _loadDrafts() async {
    setState(() => _isLoadingDrafts = true);
    try {
      final drafts = await _heldBillsService.getAllHeldBills(type: _draftFilter);
      if (mounted) setState(() { _drafts = drafts; _isLoadingDrafts = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingDrafts = false);
    }
  }

  Future<void> _loadSupplierCredit() async {
    setState(() => _isLoadingSupplier = true);
    try {
      final txns = await _txService.getTransactions(
        type: 'BUY', paymentStatus: null,
      );
      final credit = txns.where((t) {
        final s = t['payment_status'] as String? ?? 'PAID';
        return s == 'CREDIT' || s == 'PARTIAL';
      }).toList();

      // Group by company
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final t in credit) {
        final partyName = t['party_name'] as String? ?? 'Unknown';
        grouped.putIfAbsent(partyName, () => []).add(t);
      }

      if (mounted) {
        setState(() {
        _supplierCreditTxns = credit;
        _supplierCreditByCompany = Map.fromEntries(
            grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
        _isLoadingSupplier = false;
      });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSupplier = false);
    }
  }

  Future<void> _loadCustomerCredit() async {
    setState(() => _isLoadingCustomer = true);
    try {
      final txns = await _txService.getTransactions(type: 'SELL');
      final credit = txns.where((t) {
        final s = t['payment_status'] as String? ?? 'PAID';
        return s == 'CREDIT' || s == 'PARTIAL';
      }).toList();

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final t in credit) {
        final partyName = t['party_name'] as String? ?? 'Unknown';
        grouped.putIfAbsent(partyName, () => []).add(t);
      }

      if (mounted) {
        setState(() {
        _customerCreditTxns = credit;
        _customerCreditByCompany = Map.fromEntries(
            grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
        _isLoadingCustomer = false;
      });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCustomer = false);
    }
  }

  // ─── DRAFT ACTIONS ───────────────────────────────────────────────────────────

  Future<void> _deleteDraft(int id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Draft'),
        content: Text('Delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final messenger = ScaffoldMessenger.of(context);
      await _heldBillsService.deleteHeldBill(id);
      messenger.showSnackBar(const SnackBar(content: Text('Draft deleted')));
      _loadDrafts();
    }
  }

  Future<void> _resumeDraft(Map<String, dynamic> draft) async {
    if (!mounted) return;
    final result = await Navigator.push(context, MaterialPageRoute(
        builder: (_) => TransactionFormScreen(transactionType: draft['type'] as String)));
    if (result == true) _loadDrafts();
  }

  Future<void> _completeDraft(Map<String, dynamic> draft) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Complete Transaction'),
        content: Text('Convert "${draft['bill_name'] ?? 'Draft'}" to a completed transaction?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Complete')),
        ],
      ),
    );
    if (ok != true) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final full = await _heldBillsService.getHeldBillById(draft['id'] as int);
      if (full == null) throw Exception('Draft not found');

      final items = (full['items'] as List).map((item) => {
        'product_id': item['product_id'],
        'lot_id': item['lot_id'] ?? 1,
        'quantity': (item['quantity'] as num).toDouble(),
        'unit_price': (item['unit_price'] as num).toDouble(),
        'discount': (item['discount_amount'] as num?)?.toDouble() ?? 0.0,
        'tax': (item['tax_amount'] as num?)?.toDouble() ?? 0.0,
        'subtotal': (item['line_total'] as num).toDouble(),
      }).toList();

      await _txService.createTransaction(
        type: full['type'] as String,
        date: DateTime.now(),
        partyId: full['party_id'] as int,
        partyType: full['party_type'] as String,
        items: items,
        subtotal: (full['subtotal'] as num).toDouble(),
        discount: (full['discount_amount'] as num?)?.toDouble() ?? 0,
        tax: (full['tax_amount'] as num?)?.toDouble() ?? 0,
        total: (full['total_amount'] as num).toDouble(),
        paymentMode: 'cash',
        notes: full['notes'] as String?,
      );

      await _heldBillsService.deleteHeldBill(draft['id'] as int);
      messenger.showSnackBar(const SnackBar(
          content: Text('Transaction completed'), backgroundColor: Colors.green));
      _loadDrafts();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // ─── CREDIT BILL PAYMENT DIALOG ──────────────────────────────────────────────

  void _showPayDialog({
    required String partyName,
    required int partyId,
    required String partyType, // 'supplier' | 'customer'
    required double totalDue,
  }) {
    final amountCtrl = TextEditingController(text: totalDue.toStringAsFixed(2));
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String method = 'cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(children: [
            Icon(partyType == 'supplier' ? Icons.local_shipping : Icons.person,
                color: partyType == 'supplier' ? Colors.blue : Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text(
              partyType == 'supplier' ? 'Pay $partyName' : 'Collect from $partyName',
              overflow: TextOverflow.ellipsis,
            )),
          ]),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Balance display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: partyType == 'supplier'
                      ? Colors.red.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: partyType == 'supplier'
                          ? Colors.red.shade200 : Colors.orange.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.account_balance_wallet,
                      color: partyType == 'supplier'
                          ? Colors.red.shade700 : Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total Outstanding',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('$_currencySymbol${totalDue.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: partyType == 'supplier'
                                ? Colors.red.shade700 : Colors.orange.shade800)),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: partyType == 'supplier'
                      ? 'Amount to Pay ($_currencySymbol)'
                      : 'Amount Received ($_currencySymbol)',
                  prefixText: '$_currencySymbol ',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(
                    labelText: 'Payment Method', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
                  DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  DropdownMenuItem(value: 'mobile', child: Text('Mobile Banking')),
                ],
                onChanged: (v) => setS(() => method = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: refCtrl,
                decoration: const InputDecoration(
                    labelText: 'Reference No. (optional)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Notes (optional)', border: OutlineInputBorder()),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: Icon(partyType == 'supplier' ? Icons.payment : Icons.payments_outlined),
              label: Text(partyType == 'supplier' ? 'Record Payment' : 'Record Receipt'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: partyType == 'supplier'
                      ? Colors.red.shade600 : Colors.orange.shade700),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0 || amount > totalDue) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(amount <= 0
                          ? 'Enter a valid amount'
                          : 'Amount exceeds outstanding balance')));
                  return;
                }
                final authProvider =
                    Provider.of<AuthProvider>(ctx, listen: false);
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                try {
                  if (partyType == 'supplier') {
                    await _paymentService.recordSupplierPayment(
                      supplierId: partyId,
                      amount: amount,
                      paymentDate: DateTime.now(),
                      paymentMethod: method,
                      referenceNumber:
                          refCtrl.text.isEmpty ? null : refCtrl.text,
                      notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                      createdBy: authProvider.currentUser?.id,
                    );
                  } else {
                    await _paymentService.recordCustomerPayment(
                      customerId: partyId,
                      amount: amount,
                      paymentDate: DateTime.now(),
                      paymentMethod: method,
                      referenceNumber:
                          refCtrl.text.isEmpty ? null : refCtrl.text,
                      notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                      createdBy: authProvider.currentUser?.id,
                    );
                  }
                  messenger.showSnackBar(SnackBar(
                      content: Text(
                          '$_currencySymbol${amount.toStringAsFixed(2)} recorded successfully'),
                      backgroundColor: Colors.green));
                  _loadAll();
                } catch (e) {
                  messenger.showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supplierTotal = _supplierCreditTxns.fold(
        0.0, (s, t) => s + ((t['credit_amount'] as num?)?.toDouble() ?? 0));
    final customerTotal = _customerCreditTxns.fold(
        0.0, (s, t) => s + ((t['credit_amount'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.pending_actions, size: 24),
          ),
          const SizedBox(width: 12),
          const Text('Held Bills'),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.pause_circle_outline, size: 18),
                const SizedBox(width: 6),
                const Text('Drafts'),
                if (_drafts.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  _badge(_drafts.length, Colors.grey),
                ],
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.local_shipping, size: 18),
                const SizedBox(width: 6),
                const Text('Supplier'),
                if (_supplierCreditTxns.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  _badge(_supplierCreditTxns.length, Colors.red),
                ],
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.people, size: 18),
                const SizedBox(width: 6),
                const Text('Customer'),
                if (_customerCreditTxns.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  _badge(_customerCreditTxns.length, Colors.orange),
                ],
              ]),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDraftsTab(theme),
          _buildCreditTab(
            isLoading: _isLoadingSupplier,
            grouped: _supplierCreditByCompany,
            allTxns: _supplierCreditTxns,
            partyType: 'supplier',
            totalDue: supplierTotal,
            theme: theme,
          ),
          _buildCreditTab(
            isLoading: _isLoadingCustomer,
            grouped: _customerCreditByCompany,
            allTxns: _customerCreditTxns,
            partyType: 'customer',
            totalDue: customerTotal,
            theme: theme,
          ),
        ],
      ),
    );
  }

  // ─── DRAFTS TAB ───────────────────────────────────────────────────────────────

  Widget _buildDraftsTab(ThemeData theme) {
    return Column(children: [
      // Filter bar
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          FilterChip(
            label: const Text('All'),
            selected: _draftFilter == null,
            onSelected: (_) { setState(() => _draftFilter = null); _loadDrafts(); },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Sales'),
            selected: _draftFilter == 'SELL',
            onSelected: (_) { setState(() => _draftFilter = _draftFilter == 'SELL' ? null : 'SELL'); _loadDrafts(); },
            selectedColor: Colors.green.shade100,
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Purchases'),
            selected: _draftFilter == 'BUY',
            onSelected: (_) { setState(() => _draftFilter = _draftFilter == 'BUY' ? null : 'BUY'); _loadDrafts(); },
            selectedColor: Colors.blue.shade100,
          ),
        ]),
      ),
      Expanded(
        child: _isLoadingDrafts
            ? const Center(child: CircularProgressIndicator())
            : _drafts.isEmpty
                ? _emptyState(
                    Icons.pause_circle_outline,
                    'No draft bills',
                    'Save incomplete transactions here to resume later')
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _drafts.length,
                    itemBuilder: (_, i) => _buildDraftCard(_drafts[i], theme),
                  ),
      ),
    ]);
  }

  Widget _buildDraftCard(Map<String, dynamic> draft, ThemeData theme) {
    final type = draft['type'] as String;
    final billName = draft['bill_name'] as String? ?? 'Draft #${draft['id']}';
    final total = (draft['total_amount'] as num?)?.toDouble() ?? 0;
    final itemCount = draft['item_count'] as int? ?? 0;
    final party = draft['party'] as Map<String, dynamic>?;
    final partyName = party?['name'] as String? ?? draft['party_name'] as String? ?? 'Unknown';
    final createdAt = DateTime.tryParse(draft['created_at'] as String? ?? '') ?? DateTime.now();
    final isSale = type == 'SELL';
    final typeColor = isSale ? Colors.green : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _resumeDraft(draft),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: typeColor.withValues(alpha: 0.15),
              child: Icon(isSale ? Icons.shopping_cart : Icons.add_shopping_cart,
                  color: typeColor),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(billName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(isSale ? 'Sale' : 'Purchase',
                      style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(isSale ? Icons.person : Icons.local_shipping,
                    size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text(partyName, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(width: 12),
                Icon(Icons.inventory_2, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text('$itemCount items',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.schedule, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text(_relativeTime(createdAt),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const Spacer(),
                Text('$_currencySymbol${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
            ])),
            PopupMenuButton<String>(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'resume',
                    child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Resume')])),
                const PopupMenuItem(value: 'complete',
                    child: Row(children: [
                      Icon(Icons.check_circle, size: 18, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Complete', style: TextStyle(color: Colors.green))
                    ])),
                const PopupMenuItem(value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red))
                    ])),
              ],
              onSelected: (v) {
                if (v == 'resume') {
                  _resumeDraft(draft);
                } else if (v == 'complete') _completeDraft(draft);
                else _deleteDraft(draft['id'] as int, billName);
              },
            ),
          ]),
        ),
      ),
    );
  }

  // ─── CREDIT TAB (shared for supplier & customer) ──────────────────────────────

  Widget _buildCreditTab({
    required bool isLoading,
    required Map<String, List<Map<String, dynamic>>> grouped,
    required List<Map<String, dynamic>> allTxns,
    required String partyType,
    required double totalDue,
    required ThemeData theme,
  }) {
    final isSupplier = partyType == 'supplier';
    final accentColor = isSupplier ? Colors.red : Colors.orange;

    return Column(children: [
      // Summary bar
      if (totalDue > 0)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: accentColor.shade50,
          child: Row(children: [
            Icon(Icons.account_balance_wallet, color: accentColor.shade700),
            const SizedBox(width: 8),
            Text(
              isSupplier
                  ? 'Total owed to suppliers: $_currencySymbol${totalDue.toStringAsFixed(2)}'
                  : 'Total owed by customers: $_currencySymbol${totalDue.toStringAsFixed(2)}',
              style: TextStyle(
                  color: accentColor.shade800, fontWeight: FontWeight.w600),
            ),
          ]),
        ),

      Expanded(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : allTxns.isEmpty
                ? _emptyState(
                    isSupplier ? Icons.local_shipping : Icons.people,
                    isSupplier ? 'No supplier credit bills' : 'No customer credit bills',
                    isSupplier
                        ? 'Purchases made on credit will appear here'
                        : 'Sales made on credit will appear here')
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: grouped.length,
                    itemBuilder: (_, i) {
                      final entry = grouped.entries.elementAt(i);
                      final partyName = entry.key;
                      final txns = entry.value;
                      final partyTotal = txns.fold(
                          0.0, (s, t) => s + ((t['credit_amount'] as num?)?.toDouble() ?? 0));
                      final partyId = txns.first['party_id'] as int? ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: accentColor.withValues(alpha: 0.15),
                            child: Icon(
                              isSupplier ? Icons.local_shipping : Icons.person,
                              color: accentColor,
                            ),
                          ),
                          title: Text(partyName,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${txns.length} unpaid bill${txns.length != 1 ? 's' : ''}'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: accentColor.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: accentColor.shade200),
                              ),
                              child: Text(
                                '$_currencySymbol${partyTotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                    color: accentColor.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(
                                isSupplier ? Icons.payment : Icons.payments_outlined,
                                color: accentColor,
                              ),
                              tooltip: isSupplier ? 'Pay' : 'Collect',
                              onPressed: () => _showPayDialog(
                                partyName: partyName,
                                partyId: partyId,
                                partyType: partyType,
                                totalDue: partyTotal,
                              ),
                            ),
                          ]),
                          children: txns.map((tx) => _buildCreditTxTile(tx, accentColor, partyType)).toList(),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }

  void _showSingleBillPayDialog({
    required Map<String, dynamic> tx,
    required int partyId,
    required String partyType,
    required double credit,
  }) {
    final invoice = tx['invoice_number'] as String? ?? '';
    final txId = tx['id'] as int;
    final amountCtrl = TextEditingController(text: credit.toStringAsFixed(2));
    final refCtrl = TextEditingController();
    String method = 'cash';
    final isSupplier = partyType == 'supplier';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(children: [
            Icon(isSupplier ? Icons.receipt : Icons.receipt_long,
                color: isSupplier ? Colors.red : Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Pay Bill: $invoice',
                  style: const TextStyle(fontSize: 15),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.account_balance_wallet, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Outstanding on this bill',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('$_currencySymbol${credit.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700)),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount ($_currencySymbol)',
                  prefixText: '$_currencySymbol ',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(
                    labelText: 'Payment Method', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
                  DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  DropdownMenuItem(value: 'mobile', child: Text('Mobile Banking')),
                ],
                onChanged: (v) => setS(() => method = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: refCtrl,
                decoration: const InputDecoration(
                    labelText: 'Reference No. (optional)',
                    border: OutlineInputBorder()),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Confirm Payment'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Enter a valid amount')));
                  return;
                }
                if (amount > credit + 0.001) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(
                          'Amount exceeds bill due ($_currencySymbol${credit.toStringAsFixed(2)})')));
                  return;
                }
                final authProvider = Provider.of<AuthProvider>(ctx, listen: false);
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                try {
                  if (isSupplier) {
                    await _paymentService.recordSupplierPayment(
                      supplierId: partyId,
                      amount: amount,
                      paymentDate: DateTime.now(),
                      paymentMethod: method,
                      referenceNumber: refCtrl.text.isEmpty ? null : refCtrl.text,
                      createdBy: authProvider.currentUser?.id,
                      targetTransactionId: txId,
                    );
                  } else {
                    await _paymentService.recordCustomerPayment(
                      customerId: partyId,
                      amount: amount,
                      paymentDate: DateTime.now(),
                      paymentMethod: method,
                      referenceNumber: refCtrl.text.isEmpty ? null : refCtrl.text,
                      createdBy: authProvider.currentUser?.id,
                      targetTransactionId: txId,
                    );
                  }
                  messenger.showSnackBar(SnackBar(
                      content: Text('$_currencySymbol${amount.toStringAsFixed(2)} recorded for $invoice'),
                      backgroundColor: Colors.green));
                  _loadAll();
                } catch (e) {
                  messenger.showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditTxTile(
      Map<String, dynamic> tx, Color accentColor, String partyType) {
    final invoice = tx['invoice_number'] as String? ?? '';
    final credit = (tx['credit_amount'] as num?)?.toDouble() ?? 0;
    final paid = (tx['paid_amount'] as num?)?.toDouble() ?? 0;
    final total = (tx['total_amount'] as num?)?.toDouble() ?? 0;
    final status = tx['payment_status'] as String? ?? 'CREDIT';
    final partyId = tx['party_id'] as int? ?? 0;
    final date = DateTime.tryParse(tx['transaction_date'] as String? ?? '') ?? DateTime.now();
    final statusColor = status == 'PARTIAL' ? Colors.orange : Colors.red;
    final daysOld = DateTime.now().difference(date).inDays;
    final paidRatio = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: accentColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(invoice,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                // Overdue badge
                if (daysOld > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: daysOld > 30
                          ? Colors.red.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${daysOld}d',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: daysOld > 30 ? Colors.red : Colors.orange),
                    ),
                  ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Progress bar
            if (status == 'PARTIAL') ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: paidRatio,
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.teal.shade400),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Text(_formatDate(date),
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 11)),
                const Spacer(),
                if (status == 'PARTIAL') ...[
                  Text(
                    'Paid: $_currencySymbol${paid.toStringAsFixed(2)} / $_currencySymbol${total.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: Colors.teal.shade700, fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '$_currencySymbol${credit.toStringAsFixed(2)} due',
                  style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                const SizedBox(width: 8),
                // Per-bill Pay button
                SizedBox(
                  height: 28,
                  child: OutlinedButton.icon(
                    onPressed: () => _showSingleBillPayDialog(
                      tx: tx,
                      partyId: partyId,
                      partyType: partyType,
                      credit: credit,
                    ),
                    icon: const Icon(Icons.payment, size: 13),
                    label: const Text('Pay', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 0),
                      side: BorderSide(color: statusColor),
                      foregroundColor: statusColor,
                      minimumSize: Size.zero,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────────

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 17, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center),
        ),
      ]),
    );
  }

  Widget _badge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10)),
      child: Text('$count',
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _formatDate(dt);
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}
