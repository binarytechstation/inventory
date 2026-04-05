import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/payment_model.dart';
import '../../../services/customer/customer_service.dart';
import '../../../services/transaction/transaction_service.dart';
import '../../../services/payment/payment_service.dart';
import '../../providers/auth_provider.dart';
import 'customer_form_screen.dart';
import '../transaction/return_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final CustomerModel customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CustomerService _customerService = CustomerService();
  final TransactionService _txService = TransactionService();
  final PaymentService _paymentService = PaymentService();

  CustomerModel? _customer;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _creditTransactions = [];
  List<PaymentModel> _payments = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _customer = widget.customer;
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
      final customer = await _customerService.getCustomerById(widget.customer.id!);
      final txns = await _txService.getTransactions(partyId: widget.customer.id!, type: 'SELL');
      final creditTxns = await _txService.getCreditTransactions(
          partyId: widget.customer.id!, partyType: 'customer');
      final payments = await _paymentService.getCustomerPayments(widget.customer.id!);
      final stats = await _customerService.getCustomerStats(widget.customer.id!);
      setState(() {
        _customer = customer ?? widget.customer;
        _transactions = txns;
        _creditTransactions = creditTxns;
        _payments = payments;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showCollectPaymentDialog() {
    final balance = _customer?.currentBalance ?? 0;
    if (balance <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No outstanding balance to collect.')));
      return;
    }

    final amountController = TextEditingController(text: balance.toStringAsFixed(2));
    final refController = TextEditingController();
    final notesController = TextEditingController();
    String paymentMethod = 'cash';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Collect from ${_customer?.name}'),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.account_balance_wallet, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Outstanding Balance', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('৳${balance.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount Received (৳)',
                  prefixText: '৳ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
                  DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  DropdownMenuItem(value: 'mobile', child: Text('Mobile Banking')),
                ],
                onChanged: (v) => setDialogState(() => paymentMethod = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: refController,
                decoration: const InputDecoration(
                  labelText: 'Reference No. (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
                  return;
                }
                if (amount > balance) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Amount cannot exceed outstanding balance')));
                  return;
                }
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                try {
                  await _paymentService.recordCustomerPayment(
                    customerId: widget.customer.id!,
                    amount: amount,
                    paymentDate: DateTime.now(),
                    paymentMethod: paymentMethod,
                    referenceNumber: refController.text.isEmpty ? null : refController.text,
                    notes: notesController.text.isEmpty ? null : notesController.text,
                    createdBy: authProvider.currentUser?.id,
                  );
                  messenger.showSnackBar(
                      SnackBar(content: Text('৳${amount.toStringAsFixed(2)} collected')));
                  _loadData();
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              icon: const Icon(Icons.payment),
              label: const Text('Record Receipt'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customer = _customer ?? widget.customer;
    final hasDue = customer.currentBalance > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          // Return button — visible to anyone who can create transactions
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final canSell = auth.currentUser?.hasPermission('create_sale') ?? false;
              if (!canSell) return const SizedBox.shrink();
              return TextButton.icon(
                icon: const Icon(Icons.reply, size: 18, color: Colors.white),
                label: const Text('Return', style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  final result = await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => CustomerReturnScreen(customer: customer)));
                  if (result == true) _loadData();
                },
              );
            },
          ),
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final canEdit = auth.currentUser?.hasPermission('edit_customer') ?? false;
              if (!canEdit) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final result = await Navigator.push(context,
                      MaterialPageRoute(builder: (context) => CustomerFormScreen(customer: customer)));
                  if (result == true) _loadData();
                },
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Transactions'),
            Tab(text: 'Payments'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(customer, theme, hasDue),
                _buildTransactionsTab(theme),
                _buildPaymentsTab(theme),
              ],
            ),
      floatingActionButton: hasDue
          ? FloatingActionButton.extended(
              onPressed: _showCollectPaymentDialog,
              icon: const Icon(Icons.payment),
              label: const Text('Collect Payment'),
              backgroundColor: Colors.orange.shade700,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildOverviewTab(CustomerModel customer, ThemeData theme, bool hasDue) {
    final isDark = theme.brightness == Brightness.dark;
    final nearLimit = customer.creditLimit > 0 &&
        customer.currentBalance >= customer.creditLimit * 0.8;

    final grossAmount   = (_stats['gross_amount']    as num?)?.toDouble() ?? 0;
    final totalReturns  = (_stats['total_returns']   as num?)?.toDouble() ?? 0;
    final netAmount     = (_stats['total_amount']    as num?)?.toDouble() ?? 0;
    final collected     = (_stats['total_paid']      as num?)?.toDouble() ?? 0;
    final outstanding   = (_stats['total_credit']    as num?)?.toDouble() ?? 0;
    final totalSales    = (_stats['total_purchases'] as num?)?.toInt()    ?? 0;
    final lastPurchaseStr = _stats['last_purchase_date'] as String?;
    final lastPurchase  = lastPurchaseStr != null ? DateTime.tryParse(lastPurchaseStr) : null;
    final avgOrder      = totalSales > 0 ? grossAmount / totalSales : 0.0;
    final collectionRate = netAmount > 0 ? (collected / netAmount).clamp(0.0, 1.0) : (collected > 0 ? 1.0 : 0.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Financial Summary ───────────────────────────────────
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Card header
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.bar_chart_rounded, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Text('Financial Summary',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (lastPurchase != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Last: ${_formatDate(lastPurchase)}',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  ),
              ]),
              const SizedBox(height: 16),

              // Row 1: Gross Sales | Returns | Net Amount
              Row(children: [
                _financeMetric('Gross Sales', grossAmount, Icons.sell_outlined, Colors.blue.shade600, isDark),
                const SizedBox(width: 8),
                _financeMetric('Returns', totalReturns, Icons.keyboard_return, Colors.red.shade400, isDark),
                const SizedBox(width: 8),
                _financeMetric('Net Amount', netAmount, Icons.currency_exchange, Colors.green.shade600, isDark, highlighted: true),
              ]),
              const SizedBox(height: 8),

              // Row 2: Collected | Outstanding | # Orders
              Row(children: [
                _financeMetric('Collected', collected, Icons.check_circle_outline, Colors.teal.shade600, isDark),
                const SizedBox(width: 8),
                _financeMetric('Outstanding', outstanding, Icons.pending_outlined,
                    outstanding > 0 ? Colors.orange.shade700 : Colors.grey.shade400, isDark,
                    highlighted: outstanding > 0),
                const SizedBox(width: 8),
                _financeMetricCount('Orders', totalSales, Icons.shopping_bag_outlined,
                    theme.colorScheme.primary, isDark),
              ]),

              // Payment Completion bar
              if (netAmount > 0 || collected > 0) ...[
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Payment Completion',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                  Text('${(collectionRate * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold,
                        color: collectionRate >= 1.0 ? Colors.green.shade700 : Colors.orange.shade700,
                      )),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: collectionRate,
                    minHeight: 10,
                    backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      collectionRate >= 1.0 ? Colors.green.shade600 : Colors.orange.shade600),
                  ),
                ),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Collected: ৳${collected.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 11, color: Colors.teal.shade600)),
                  if (outstanding > 0)
                    Text('Due: ৳${outstanding.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
                ]),
              ],
            ]),
          ),
        ),

        const SizedBox(height: 12),

        // ── Customer Profile ────────────────────────────────────
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blueGrey.shade800 : Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.person_outline, color: Colors.blueGrey.shade600, size: 20),
                ),
                const SizedBox(width: 10),
                Text('Customer Profile',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 14),

              // Avg order + member since
              Row(children: [
                Expanded(child: _profileTile(
                  'Avg. Order Value',
                  avgOrder > 0 ? '৳${avgOrder.toStringAsFixed(2)}' : '—',
                  Icons.receipt_long, Colors.indigo, isDark,
                )),
                const SizedBox(width: 10),
                Expanded(child: _profileTile(
                  'Member Since',
                  _formatDate(customer.createdAt),
                  Icons.calendar_today, Colors.blueGrey, isDark,
                )),
              ]),

              // Credit limit row
              if (customer.creditLimit > 0) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _profileTile(
                    'Credit Limit',
                    '৳${customer.creditLimit.toStringAsFixed(2)}',
                    Icons.credit_score, Colors.teal, isDark,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _profileTile(
                    'Credit Used',
                    '৳${customer.currentBalance.toStringAsFixed(2)}',
                    Icons.credit_card, nearLimit ? Colors.red : Colors.orange, isDark,
                  )),
                ]),
                if (nearLimit) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (customer.currentBalance / customer.creditLimit).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation(Colors.red),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red.shade700),
                    const SizedBox(width: 4),
                    Text('Near credit limit — collect payment before new orders.',
                        style: TextStyle(fontSize: 11, color: Colors.red.shade700)),
                  ]),
                ],
              ],

              // Contact info
              if (customer.phone != null || customer.email != null ||
                  customer.address != null || (customer.companyName != null && customer.companyName!.isNotEmpty)) ...[
                const Divider(height: 24),
                Text('Contact', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                if (customer.companyName != null && customer.companyName!.isNotEmpty)
                  _infoRow(Icons.business, 'Company', customer.companyName!),
                if (customer.phone != null)
                  _infoRow(Icons.phone, 'Phone', customer.phone!),
                if (customer.email != null)
                  _infoRow(Icons.email, 'Email', customer.email!),
                if (customer.address != null)
                  _infoRow(Icons.location_on, 'Address', customer.address!),
                if (customer.notes != null && customer.notes!.isNotEmpty)
                  _infoRow(Icons.notes, 'Notes', customer.notes!),
              ],
            ]),
          ),
        ),

        // ── Outstanding Balance ─────────────────────────────────
        if (hasDue) ...[
          const SizedBox(height: 12),
          Card(
            color: isDark ? Colors.orange.shade900.withValues(alpha: 0.25) : Colors.orange.shade50,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.orange.shade300, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.account_balance_wallet, color: Colors.orange.shade800, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Outstanding Balance',
                      style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('৳${customer.currentBalance.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                  if (customer.creditLimit > 0)
                    Text('Limit: ৳${customer.creditLimit.toStringAsFixed(2)}',
                        style: TextStyle(color: nearLimit ? Colors.red : Colors.grey, fontSize: 12)),
                ])),
                ElevatedButton.icon(
                  onPressed: _showCollectPaymentDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  icon: const Icon(Icons.payments, color: Colors.white, size: 18),
                  label: const Text('Collect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
          ),
        ],

        // ── Unpaid Bills ────────────────────────────────────────
        if (_creditTransactions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(children: [
            Icon(Icons.pending_actions, size: 18, color: Colors.orange.shade700),
            const SizedBox(width: 6),
            Text('Unpaid Bills',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${_creditTransactions.length}',
                  style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 8),
          ..._creditTransactions.map((tx) => _buildCreditTxCard(tx, theme)),
        ],
      ]),
    );
  }

  Widget _financeMetric(String label, double value, IconData icon, Color color, bool isDark,
      {bool highlighted = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: highlighted
              ? color.withValues(alpha: isDark ? 0.18 : 0.08)
              : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: highlighted ? color.withValues(alpha: 0.35) : Colors.grey.withValues(alpha: 0.12)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 5),
          Text('৳${value.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: highlighted ? color : null,
              )),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _financeMetricCount(String label, int count, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 5),
          Text('$count',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }

  Widget _profileTile(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  Widget _buildTransactionsTab(ThemeData theme) {
    if (_transactions.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        const Text('No transactions yet', style: TextStyle(color: Colors.grey)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length,
      itemBuilder: (context, i) => _buildTxCard(_transactions[i], theme),
    );
  }

  Widget _buildPaymentsTab(ThemeData theme) {
    if (_payments.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.payment, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        const Text('No payment records', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        const Text('Record payments when this customer clears their dues.',
            style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      itemBuilder: (context, i) {
        final p = _payments[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.shade100,
              child: Icon(Icons.payment, color: Colors.teal.shade700),
            ),
            title: Text('৳${p.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.paymentMethod.toUpperCase()} · ${_formatDate(p.paymentDate)}'),
              if (p.referenceNumber != null) Text('Ref: ${p.referenceNumber}'),
              if (p.notes != null) Text(p.notes!),
            ]),
            trailing: const Icon(Icons.check_circle, color: Colors.teal),
          ),
        );
      },
    );
  }

  Widget _buildTxCard(Map<String, dynamic> tx, ThemeData theme) {
    final total = (tx['total_amount'] as num?)?.toDouble() ?? 0;
    final credit = (tx['credit_amount'] as num?)?.toDouble() ?? 0;
    final status = tx['payment_status'] as String? ?? 'PAID';
    final statusColor = status == 'PAID' ? Colors.green : (status == 'PARTIAL' ? Colors.orange : Colors.red);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showInvoiceDetailDialog(tx),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: Icon(Icons.receipt, color: theme.colorScheme.secondary, size: 20),
          ),
          title: Text(tx['invoice_number'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_formatDate(DateTime.tryParse(tx['transaction_date'] as String? ?? '') ?? DateTime.now())),
            if (credit > 0)
              Text('Credit: ৳${credit.toStringAsFixed(2)}', style: TextStyle(color: Colors.orange.shade700)),
          ]),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('৳${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildCreditTxCard(Map<String, dynamic> tx, ThemeData theme) {
    final credit = (tx['credit_amount'] as num?)?.toDouble() ?? 0;
    return Card(
      color: Colors.orange.shade50,
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showInvoiceDetailDialog(tx),
        child: ListTile(
          leading: const Icon(Icons.pending_actions, color: Colors.orange),
          title: Text(
            tx['invoice_number'] as String? ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(_formatDate(DateTime.tryParse(tx['transaction_date'] as String? ?? '') ?? DateTime.now())),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('৳${credit.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.orange.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showInvoiceDetailDialog(Map<String, dynamic> txSummary) async {
    // Show loading while fetching full details
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    Map<String, dynamic>? tx;
    try {
      tx = await _txService.getTransactionById(txSummary['id'] as int);
    } catch (_) {}

    if (!mounted) return;
    Navigator.pop(context); // dismiss loader

    if (tx == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not load invoice details')));
      return;
    }

    final lines = (tx['lines'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final invoiceNo = tx['invoice_number'] as String? ?? '';
    final date = DateTime.tryParse(tx['transaction_date'] as String? ?? '') ?? DateTime.now();
    final subtotal = (tx['subtotal'] as num?)?.toDouble() ?? 0.0;
    final discount = (tx['discount_amount'] as num?)?.toDouble() ?? 0.0;
    final tax = (tx['tax_amount'] as num?)?.toDouble() ?? 0.0;
    final total = (tx['total_amount'] as num?)?.toDouble() ?? 0.0;
    final paid = (tx['paid_amount'] as num?)?.toDouble() ?? 0.0;
    final outstanding = (tx['credit_amount'] as num?)?.toDouble() ?? 0.0;
    final status = tx['payment_status'] as String? ?? 'PAID';
    final notes = tx['notes'] as String?;
    final currency = tx['currency_symbol'] as String? ?? '৳';
    final paymentMode = (tx['payment_mode'] as String? ?? '').toUpperCase();

    final statusColor = status == 'PAID'
        ? Colors.green
        : (status == 'PARTIAL' ? Colors.orange : Colors.red);
    final statusLabel = status == 'CREDIT' ? 'UNPAID' : status;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 680,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Column(
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Colors.blue.shade700, Colors.blue.shade500]),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(invoiceNo,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17)),
                          Text(_formatDate(date),
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        statusLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // ── Body ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer + payment mode
                      Row(
                        children: [
                          Expanded(child: _infoChip(Icons.person_outline, 'Customer', _customer?.name ?? 'N/A')),
                          const SizedBox(width: 12),
                          Expanded(child: _infoChip(Icons.payment, 'Payment Mode', paymentMode)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Items table header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                                flex: 4,
                                child: Text('Product',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue))),
                            SizedBox(
                                width: 60,
                                child: Text('Qty',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue))),
                            SizedBox(width: 8),
                            SizedBox(
                                width: 90,
                                child: Text('Unit Price',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue))),
                            SizedBox(width: 8),
                            SizedBox(
                                width: 90,
                                child: Text('Amount',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue))),
                          ],
                        ),
                      ),

                      // Line items
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue.shade100),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: lines.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: Text('No items', style: TextStyle(color: Colors.grey)),
                                ),
                              )
                            : Column(
                                children: lines.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final line = entry.value;
                                  final name = line['product_name'] as String? ?? '';
                                  final qty = (line['quantity'] as num?)?.toDouble() ?? 0;
                                  final unit = line['unit'] as String? ?? '';
                                  final unitPrice = (line['unit_price'] as num?)?.toDouble() ?? 0;
                                  final lineTotal = (line['line_total'] as num?)?.toDouble() ?? 0;
                                  final isEven = i % 2 == 0;
                                  return Container(
                                    color: isEven ? Colors.grey.shade50 : Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(name,
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.w500, fontSize: 13)),
                                              if (unit.isNotEmpty)
                                                Text(unit,
                                                    style: const TextStyle(
                                                        color: Colors.grey, fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: 60,
                                          child: Text(
                                            qty % 1 == 0
                                                ? qty.toInt().toString()
                                                : qty.toStringAsFixed(2),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 90,
                                          child: Text(
                                            '$currency${unitPrice.toStringAsFixed(2)}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 90,
                                          child: Text(
                                            '$currency${lineTotal.toStringAsFixed(2)}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),

                      const SizedBox(height: 16),

                      // Totals summary
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            if (subtotal > 0 && subtotal != total)
                              _summaryRow('Subtotal', '$currency${subtotal.toStringAsFixed(2)}'),
                            if (discount > 0)
                              _summaryRow('Discount', '− $currency${discount.toStringAsFixed(2)}',
                                  color: Colors.green.shade700),
                            if (tax > 0)
                              _summaryRow('Tax', '+ $currency${tax.toStringAsFixed(2)}',
                                  color: Colors.orange.shade700),
                            _summaryRow('Total', '$currency${total.toStringAsFixed(2)}',
                                bold: true, large: true),
                            const Divider(height: 14),
                            _summaryRow('Paid', '$currency${paid.toStringAsFixed(2)}',
                                color: Colors.green.shade700),
                            if (outstanding > 0)
                              _summaryRow('Outstanding', '$currency${outstanding.toStringAsFixed(2)}',
                                  color: Colors.red.shade700, bold: true),
                          ],
                        ),
                      ),

                      // Notes
                      if (notes != null && notes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.notes, size: 15, color: Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(notes,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Footer actions ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                    if (outstanding > 0) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showCollectPaymentDialog();
                        },
                        icon: const Icon(Icons.payment, size: 16),
                        label: const Text('Collect Payment'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(value,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {Color? color, bool bold = false, bool large = false}) {
    final fontSize = large ? 15.0 : 13.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: fontSize, color: color ?? Colors.grey.shade700)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
