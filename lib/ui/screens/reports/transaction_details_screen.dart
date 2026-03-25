import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/reports/transaction_details_service.dart';
import '../../../services/currency/currency_service.dart';

class TransactionDetailsScreen extends StatefulWidget {
  const TransactionDetailsScreen({super.key});

  @override
  State<TransactionDetailsScreen> createState() =>
      _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TransactionDetailsService _svc = TransactionDetailsService();
  final CurrencyService _currencyService = CurrencyService();
  String _sym = '৳';

  static const _tabs = [
    Tab(icon: Icon(Icons.shopping_cart_outlined, size: 16), text: 'Purchases'),
    Tab(icon: Icon(Icons.point_of_sale_outlined, size: 16), text: 'Sales'),
    Tab(icon: Icon(Icons.local_shipping_outlined, size: 16), text: 'Supplier Dues'),
    Tab(icon: Icon(Icons.person_outline, size: 16), text: 'Customer Dues'),
    Tab(icon: Icon(Icons.assignment_return_outlined, size: 16), text: 'Returns & Defects'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _currencyService.getCurrencySymbol().then((s) {
      if (mounted) setState(() => _sym = s);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: _tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LedgerTab(type: 'BUY', sym: _sym, svc: _svc),
          _LedgerTab(type: 'SELL', sym: _sym, svc: _svc),
          _DuesTab(partyType: 'supplier', sym: _sym, svc: _svc),
          _DuesTab(partyType: 'customer', sym: _sym, svc: _svc),
          _ReturnsDefectsTab(sym: _sym, svc: _svc),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// LEDGER TAB  (Purchases / Sales)
// ═══════════════════════════════════════════════════════════════════

class _LedgerTab extends StatefulWidget {
  final String type;
  final String sym;
  final TransactionDetailsService svc;

  const _LedgerTab({required this.type, required this.sym, required this.svc});

  @override
  State<_LedgerTab> createState() => _LedgerTabState();
}

class _LedgerTabState extends State<_LedgerTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DateTime? _start;
  DateTime? _end;
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = false;
  String _statusFilter = 'ALL'; // ALL | PAID | PARTIAL | CREDIT

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, 1);
    _end = DateTime(now.year, now.month + 1, 0);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await widget.svc.getTransactionsByDateRange(
        type: widget.type,
        startDate: _start!,
        endDate: _end!,
      );
      if (mounted) {
        setState(() {
          _all = data;
          _applyFilter();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    if (_statusFilter == 'ALL') {
      _filtered = List.of(_all);
    } else {
      _filtered = _all
          .where((t) =>
              (t['payment_status'] as String? ?? 'PAID') == _statusFilter)
          .toList();
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange:
          _start != null && _end != null ? DateTimeRange(start: _start!, end: _end!) : null,
    );
    if (picked != null) {
      setState(() {
        _start = picked.start;
        _end = picked.end;
      });
      _load();
    }
  }

  Future<void> _export() async {
    try {
      final path = await widget.svc.exportToExcel(
        transactions: _filtered,
        type: widget.type,
        reportType: 'date_range',
        startDate: _start,
        endDate: _end,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported: $path'), duration: const Duration(seconds: 5)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  // ── computed totals ──────────────────────────────────────────────
  double get _grandTotal =>
      _filtered.fold(0, (s, t) => s + (t['total_amount'] as num).toDouble());
  double get _totalCash =>
      _filtered.fold(0, (s, t) => s + ((t['paid_amount'] as num?)?.toDouble() ?? 0));
  double get _totalCredit =>
      _filtered.fold(0, (s, t) => s + ((t['credit_amount'] as num?)?.toDouble() ?? 0));
  int get _paidCount =>
      _filtered.where((t) => (t['payment_status'] ?? 'PAID') == 'PAID').length;
  int get _partialCount =>
      _filtered.where((t) => (t['payment_status'] ?? '') == 'PARTIAL').length;
  int get _creditCount =>
      _filtered.where((t) => (t['payment_status'] ?? '') == 'CREDIT').length;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBuy = widget.type == 'BUY';

    return Column(
      children: [
        // ── toolbar ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _start != null && _end != null
                              ? '${DateFormat('dd MMM yyyy').format(_start!)} – ${DateFormat('dd MMM yyyy').format(_end!)}'
                              : 'Select period',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          '${_filtered.length} transactions',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Period'),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: _filtered.isEmpty ? null : _export,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export'),
                  ),
                ],
              ),
              // status filter chips
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in ['ALL', 'PAID', 'PARTIAL', 'CREDIT'])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(f),
                          selected: _statusFilter == f,
                          onSelected: (_) {
                            setState(() {
                              _statusFilter = f;
                              _applyFilter();
                            });
                          },
                          selectedColor: _statusColor(f).withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: _statusFilter == f ? _statusColor(f) : null,
                            fontWeight: _statusFilter == f
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── summary bar ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: isBuy
              ? (isDark ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.shade50)
              : (isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50),
          child: Row(
            children: [
              _summaryPill('Total', widget.sym + _grandTotal.toStringAsFixed(2),
                  isBuy ? Colors.blue : Colors.green, isDark),
              const SizedBox(width: 8),
              _summaryPill('Cash', widget.sym + _totalCash.toStringAsFixed(2),
                  Colors.teal, isDark),
              const SizedBox(width: 8),
              _summaryPill('Credit', widget.sym + _totalCredit.toStringAsFixed(2),
                  Colors.orange, isDark),
              const Spacer(),
              if (_partialCount > 0) ...[
                _miniCount('$_partialCount Partial', Colors.orange),
                const SizedBox(width: 6),
              ],
              if (_creditCount > 0) ...[
                _miniCount('$_creditCount Unpaid', Colors.red),
                const SizedBox(width: 6),
              ],
              _miniCount('$_paidCount Paid', Colors.green),
            ],
          ),
        ),

        // ── data ─────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('No transactions found',
                              style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columnSpacing: 14,
                          headingRowHeight: 38,
                          dataRowMinHeight: 42,
                          dataRowMaxHeight: 60,
                          headingRowColor: WidgetStateProperty.all(
                            isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                          ),
                          columns: const [
                            DataColumn(label: Text('Invoice')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Time')),
                            DataColumn(label: Text('Party')),
                            DataColumn(label: Text('Products')),
                            DataColumn(label: Text('Qty'), numeric: true),
                            DataColumn(label: Text('Subtotal'), numeric: true),
                            DataColumn(label: Text('Discount'), numeric: true),
                            DataColumn(label: Text('Total'), numeric: true),
                            DataColumn(label: Text('Cash Paid'), numeric: true),
                            DataColumn(label: Text('Credit'), numeric: true),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Mode')),
                          ],
                          rows: _filtered.map((t) {
                            final date = DateTime.parse(t['transaction_date'] as String);
                            final status = t['payment_status'] as String? ?? 'PAID';
                            final cash = (t['paid_amount'] as num?)?.toDouble() ?? 0;
                            final credit = (t['credit_amount'] as num?)?.toDouble() ?? 0;
                            final lines = t['lines'] as List;
                            return DataRow(
                              color: WidgetStateProperty.resolveWith((_) =>
                                  _rowColor(status, isDark)),
                              cells: [
                                DataCell(Text(
                                  t['invoice_number'] as String,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 12),
                                )),
                                DataCell(Text(DateFormat('dd MMM yy').format(date),
                                    style: const TextStyle(fontSize: 12))),
                                DataCell(Text(DateFormat('HH:mm').format(date),
                                    style: const TextStyle(fontSize: 12))),
                                DataCell(Text(t['party_name'] as String? ?? 'N/A',
                                    style: const TextStyle(fontSize: 12))),
                                DataCell(Text(_productSummary(lines),
                                    style: const TextStyle(fontSize: 12))),
                                DataCell(Text(
                                    _totalQty(lines).toStringAsFixed(2),
                                    style: const TextStyle(fontSize: 12))),
                                DataCell(Text(
                                  '${widget.sym}${(t['subtotal'] as num?)?.toStringAsFixed(2) ?? (t['total_amount'] as num).toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12),
                                )),
                                DataCell(Text(
                                  '${widget.sym}${(t['discount_amount'] as num).toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12),
                                )),
                                DataCell(Text(
                                  '${widget.sym}${(t['total_amount'] as num).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 12),
                                )),
                                DataCell(Text(
                                  '${widget.sym}${cash.toStringAsFixed(2)}',
                                  style: TextStyle(
                                      color: Colors.teal.shade700, fontSize: 12),
                                )),
                                DataCell(Text(
                                  '${widget.sym}${credit.toStringAsFixed(2)}',
                                  style: TextStyle(
                                      color: credit > 0 ? Colors.orange.shade700 : null,
                                      fontSize: 12),
                                )),
                                DataCell(_statusBadge(status)),
                                DataCell(Text(
                                  (t['payment_mode'] as String? ?? 'cash')
                                      .toUpperCase(),
                                  style: const TextStyle(fontSize: 11),
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _summaryPill(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: isDark ? color.withValues(alpha: 0.8) : color.withValues(alpha: 0.9))),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? color.withValues(alpha: 0.9) : color)),
        ],
      ),
    );
  }

  Widget _miniCount(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      );

  Color _statusColor(String s) => switch (s) {
        'PAID' => Colors.green,
        'PARTIAL' => Colors.orange,
        'CREDIT' => Colors.red,
        _ => Colors.grey,
      };

  Color? _rowColor(String status, bool isDark) => switch (status) {
        'PARTIAL' => isDark
            ? Colors.orange.withValues(alpha: 0.08)
            : Colors.orange.shade50,
        'CREDIT' => isDark
            ? Colors.red.withValues(alpha: 0.08)
            : Colors.red.shade50,
        _ => null,
      };

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(status,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  String _productSummary(List lines) {
    if (lines.isEmpty) return 'N/A';
    final names =
        lines.map((l) => l['product_name'] as String).take(2).join(', ');
    return lines.length > 2 ? '$names +${lines.length - 2}' : names;
  }

  double _totalQty(List lines) =>
      lines.fold(0, (s, l) => s + (l['quantity'] as num).toDouble());
}

// ═══════════════════════════════════════════════════════════════════
// DUES TAB  (Supplier / Customer)
// ═══════════════════════════════════════════════════════════════════

class _DuesTab extends StatefulWidget {
  final String partyType; // 'supplier' | 'customer'
  final String sym;
  final TransactionDetailsService svc;

  const _DuesTab(
      {required this.partyType, required this.sym, required this.svc});

  @override
  State<_DuesTab> createState() => _DuesTabState();
}

class _DuesTabState extends State<_DuesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _parties = [];
  bool _loading = false;
  String _search = '';
  final _searchCtrl = TextEditingController();
  final Set<int> _expanded = {};

  bool get _isSupplier => widget.partyType == 'supplier';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await widget.svc.getPartyDues(partyType: widget.partyType);
      if (mounted) {
        setState(() {
          _parties = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _parties;
    final q = _search.toLowerCase();
    return _parties
        .where((p) =>
            (p['name'] as String).toLowerCase().contains(q) ||
            ((p['company_name'] as String?) ?? '').toLowerCase().contains(q))
        .toList();
  }

  double get _totalOutstanding =>
      _parties.fold(0, (s, p) => s + (p['current_balance'] as num).toDouble());

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _isSupplier ? Colors.blue : Colors.purple;
    final fmt = DateFormat('dd MMM yyyy');

    return Column(
      children: [
        // ── header ─────────────────────────────────────────────────
        Container(
          color: color.withValues(alpha: isDark ? 0.2 : 0.08),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    _isSupplier ? Icons.local_shipping_outlined : Icons.person_outline,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isSupplier ? 'Supplier Outstanding Dues' : 'Customer Outstanding Dues',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Total Due: ${widget.sym}${_totalOutstanding.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search ${_isSupplier ? 'supplier' : 'customer'}…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ],
          ),
        ),

        // ── list ───────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 48, color: Colors.green.shade400),
                          const SizedBox(height: 8),
                          Text(
                            _search.isEmpty
                                ? 'No outstanding dues!'
                                : 'No match found',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final p = _filtered[i];
                          final id = p['id'] as int;
                          final balance = (p['current_balance'] as num).toDouble();
                          final totalBusiness = (p['total_business'] as num?)?.toDouble() ?? 0;
                          final totalPaid = (p['total_paid_ever'] as num?)?.toDouble() ?? 0;
                          final isExpanded = _expanded.contains(id);
                          final unpaid = p['unpaid_transactions'] as List;
                          final payments = p['recent_payments'] as List;
                          final oldestUnpaid = p['oldest_unpaid_date'] as String?;
                          final daysDue = oldestUnpaid != null
                              ? DateTime.now()
                                  .difference(DateTime.parse(oldestUnpaid))
                                  .inDays
                              : 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: balance > 0
                                    ? Colors.red.withValues(alpha: 0.25)
                                    : Colors.grey.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                // card header
                                InkWell(
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12)),
                                  onTap: () => setState(() {
                                    if (isExpanded) {
                                      _expanded.remove(id);
                                    } else {
                                      _expanded.add(id);
                                    }
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor:
                                                  color.withValues(alpha: 0.2),
                                              child: Text(
                                                (p['name'] as String)
                                                    .substring(0, 1)
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                    color: color,
                                                    fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    p['name'] as String,
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15),
                                                  ),
                                                  if ((p['company_name'] as String?)?.isNotEmpty == true)
                                                    Text(
                                                      p['company_name'] as String,
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey.shade600),
                                                    ),
                                                  if ((p['phone'] as String?)?.isNotEmpty == true)
                                                    Text(
                                                      p['phone'] as String,
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey.shade600),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.withValues(alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    '${widget.sym}${balance.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                        color: Colors.red,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16),
                                                  ),
                                                ),
                                                if (daysDue > 0)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 2),
                                                    child: Text(
                                                      '${daysDue}d overdue',
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          color: daysDue > 30
                                                              ? Colors.red
                                                              : Colors.orange),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              isExpanded
                                                  ? Icons.expand_less
                                                  : Icons.expand_more,
                                              color: Colors.grey,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        // stat row
                                        Row(
                                          children: [
                                            _dueStatChip('Business',
                                                '${widget.sym}${totalBusiness.toStringAsFixed(0)}',
                                                Colors.blue, isDark),
                                            const SizedBox(width: 6),
                                            _dueStatChip('Paid',
                                                '${widget.sym}${totalPaid.toStringAsFixed(0)}',
                                                Colors.teal, isDark),
                                            const SizedBox(width: 6),
                                            _dueStatChip('${unpaid.length} Unpaid bill${unpaid.length == 1 ? '' : 's'}', '',
                                                Colors.orange, isDark),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // expanded section
                                if (isExpanded) ...[
                                  const Divider(height: 1),
                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // ── unpaid transactions ──────────────
                                        if (unpaid.isNotEmpty) ...[
                                          _sectionLabel(
                                              'Unpaid / Partial Transactions',
                                              Icons.receipt_long_outlined,
                                              Colors.red),
                                          const SizedBox(height: 8),
                                          ...unpaid.map((txn) {
                                            final txDate = DateTime.parse(
                                                txn['transaction_date'] as String);
                                            final txCredit = ((txn['credit_amount'] as num?)?.toDouble() ?? 0);
                                            final status = txn['payment_status'] as String? ?? 'PAID';
                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 6),
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.red.withValues(alpha: 0.08)
                                                    : Colors.red.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: Colors.red.withValues(alpha: 0.2)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          txn['invoice_number']
                                                              as String,
                                                          style: const TextStyle(
                                                              fontWeight: FontWeight.w600,
                                                              fontSize: 12),
                                                        ),
                                                        Text(
                                                          fmt.format(txDate),
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors.grey.shade600),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        'Total: ${widget.sym}${(txn['total_amount'] as num).toStringAsFixed(2)}',
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w500),
                                                      ),
                                                      Text(
                                                        'Due: ${widget.sym}${txCredit.toStringAsFixed(2)}',
                                                        style: const TextStyle(
                                                            color: Colors.red,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange.withValues(alpha: 0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      status,
                                                      style: const TextStyle(
                                                          color: Colors.orange,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],

                                        // ── payment history ──────────────────
                                        if (payments.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          _sectionLabel(
                                              'Recent Payments (last 5)',
                                              Icons.payments_outlined,
                                              Colors.teal),
                                          const SizedBox(height: 8),
                                          ...payments.map((pay) {
                                            final payDate = DateTime.parse(
                                                pay['payment_date'] as String);
                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 4),
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.teal.withValues(alpha: 0.08)
                                                    : Colors.teal.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.check_circle,
                                                      color: Colors.teal, size: 14),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    fmt.format(payDate),
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                  if ((pay['reference_number'] as String?)?.isNotEmpty == true) ...[
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Ref: ${pay['reference_number']}',
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.grey.shade600),
                                                    ),
                                                  ],
                                                  const Spacer(),
                                                  Text(
                                                    '${widget.sym}${(pay['amount'] as num).toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                        color: Colors.teal,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    (pay['payment_method'] as String? ?? 'cash').toUpperCase(),
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.grey.shade500),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _dueStatChip(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value.isEmpty ? label : '$label: $value',
        style: TextStyle(
            fontSize: 11,
            color: isDark ? color.withValues(alpha: 0.9) : color,
            fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _sectionLabel(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: color)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// RETURNS & DEFECTS TAB
// ═══════════════════════════════════════════════════════════════════

class _ReturnsDefectsTab extends StatefulWidget {
  final String sym;
  final TransactionDetailsService svc;

  const _ReturnsDefectsTab({required this.sym, required this.svc});

  @override
  State<_ReturnsDefectsTab> createState() => _ReturnsDefectsTabState();
}

class _ReturnsDefectsTabState extends State<_ReturnsDefectsTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  late TabController _inner;
  DateTime? _start;
  DateTime? _end;
  Map<String, dynamic>? _data;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _inner = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, 1);
    _end = DateTime(now.year, now.month + 1, 0);
    _load();
  }

  @override
  void dispose() {
    _inner.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await widget.svc
          .getReturnsAndDefectives(startDate: _start, endDate: _end);
      if (mounted) {
        setState(() {
          _data = d;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange:
          _start != null && _end != null ? DateTimeRange(start: _start!, end: _end!) : null,
    );
    if (picked != null) {
      setState(() {
        _start = picked.start;
        _end = picked.end;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = DateFormat('dd MMM yy');

    final returns = (_data?['returns'] as List?) ?? [];
    final defectives = (_data?['defectives'] as List?) ?? [];
    final totalReturnVal = (_data?['total_return_value'] as num?)?.toDouble() ?? 0;
    final cashRefunded = (_data?['cash_refunded'] as num?)?.toDouble() ?? 0;
    final creditRefunded = (_data?['credit_refunded'] as num?)?.toDouble() ?? 0;
    final defQty = (_data?['total_defective_qty'] as num?)?.toDouble() ?? 0;
    final defRefund = (_data?['total_defective_refund'] as num?)?.toDouble() ?? 0;

    return Column(
      children: [
        // ── toolbar ───────────────────────────────────────────────
        Container(
          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _start != null && _end != null
                      ? '${DateFormat('dd MMM yyyy').format(_start!)} – ${DateFormat('dd MMM yyyy').format(_end!)}'
                      : 'Select period',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Period'),
              ),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),

        // ── summary cards ─────────────────────────────────────────
        if (_data != null)
          Container(
            color: isDark
                ? Colors.red.shade900.withValues(alpha: 0.2)
                : Colors.red.shade50,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _summCard('Returns', '${returns.length}', Colors.red, isDark),
                  const SizedBox(width: 8),
                  _summCard('Return Value', '${widget.sym}${totalReturnVal.toStringAsFixed(2)}',
                      Colors.orange, isDark),
                  const SizedBox(width: 8),
                  _summCard('Cash Refunded', '${widget.sym}${cashRefunded.toStringAsFixed(2)}',
                      Colors.teal, isDark),
                  const SizedBox(width: 8),
                  _summCard('Credit Reversed', '${widget.sym}${creditRefunded.toStringAsFixed(2)}',
                      Colors.blue, isDark),
                  const SizedBox(width: 8),
                  _summCard('Defective Items', defectives.length.toString(),
                      Colors.purple, isDark),
                  const SizedBox(width: 8),
                  _summCard('Defective Qty', defQty.toStringAsFixed(2), Colors.deepPurple, isDark),
                  const SizedBox(width: 8),
                  _summCard('Defect Refund', '${widget.sym}${defRefund.toStringAsFixed(2)}',
                      Colors.indigo, isDark),
                ],
              ),
            ),
          ),

        // ── inner tabs ────────────────────────────────────────────
        TabBar(
          controller: _inner,
          labelColor: isDark ? Colors.white : Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.red,
          tabs: [
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.assignment_return, size: 14),
                const SizedBox(width: 4),
                Text('Returns (${returns.length})'),
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.warning_amber, size: 14),
                const SizedBox(width: 4),
                Text('Defectives (${defectives.length})'),
              ]),
            ),
          ],
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _inner,
                  children: [
                    // ── Returns ──────────────────────────────────────
                    returns.isEmpty
                        ? _emptyState('No returns in this period',
                            Icons.assignment_return_outlined)
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: DataTable(
                                columnSpacing: 14,
                                headingRowHeight: 36,
                                dataRowMinHeight: 42,
                                dataRowMaxHeight: 60,
                                headingRowColor: WidgetStateProperty.all(
                                  isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                                ),
                                columns: const [
                                  DataColumn(label: Text('Invoice')),
                                  DataColumn(label: Text('Date')),
                                  DataColumn(label: Text('Party')),
                                  DataColumn(label: Text('Type')),
                                  DataColumn(label: Text('Products')),
                                  DataColumn(label: Text('Qty'), numeric: true),
                                  DataColumn(label: Text('Return Value'), numeric: true),
                                  DataColumn(label: Text('Cash Refund'), numeric: true),
                                  DataColumn(label: Text('Credit Reversed'), numeric: true),
                                  DataColumn(label: Text('Mode')),
                                  DataColumn(label: Text('Status')),
                                ],
                                rows: returns.map((r) {
                                  final date = DateTime.parse(r['transaction_date'] as String);
                                  final lines = r['lines'] as List;
                                  final cash = ((r['paid_amount'] as num?)?.toDouble() ?? 0);
                                  final credit = ((r['credit_amount'] as num?)?.toDouble() ?? 0);
                                  final partyType = r['party_type'] as String? ?? '';
                                  return DataRow(
                                    color: WidgetStateProperty.all(
                                      isDark
                                          ? Colors.red.withValues(alpha: 0.06)
                                          : Colors.red.shade50,
                                    ),
                                    cells: [
                                      DataCell(Text(r['invoice_number'] as String,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                                      DataCell(Text(fmt.format(date),
                                          style: const TextStyle(fontSize: 12))),
                                      DataCell(Text(r['party_name'] as String? ?? 'N/A',
                                          style: const TextStyle(fontSize: 12))),
                                      DataCell(Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: partyType == 'customer'
                                              ? Colors.purple.withValues(alpha: 0.15)
                                              : Colors.blue.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          partyType == 'customer' ? 'CUSTOMER' : 'SUPPLIER',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: partyType == 'customer'
                                                ? Colors.purple
                                                : Colors.blue,
                                          ),
                                        ),
                                      )),
                                      DataCell(Text(_productSummary(lines),
                                          style: const TextStyle(fontSize: 12))),
                                      DataCell(Text(_totalQty(lines).toStringAsFixed(2),
                                          style: const TextStyle(fontSize: 12))),
                                      DataCell(Text(
                                        '${widget.sym}${(r['total_amount'] as num).toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      )),
                                      DataCell(Text(
                                        '${widget.sym}${cash.toStringAsFixed(2)}',
                                        style: TextStyle(color: Colors.teal.shade700, fontSize: 12),
                                      )),
                                      DataCell(Text(
                                        '${widget.sym}${credit.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: credit > 0 ? Colors.blue.shade700 : null,
                                          fontSize: 12,
                                        ),
                                      )),
                                      DataCell(Text(
                                        (r['payment_mode'] as String? ?? 'cash').toUpperCase(),
                                        style: const TextStyle(fontSize: 11),
                                      )),
                                      DataCell(_statusChip(r['status'] as String? ?? 'COMPLETED')),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),

                    // ── Defectives ───────────────────────────────────
                    defectives.isEmpty
                        ? _emptyState('No defective items in this period',
                            Icons.warning_amber_outlined)
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: DataTable(
                                columnSpacing: 14,
                                headingRowHeight: 36,
                                dataRowMinHeight: 42,
                                dataRowMaxHeight: 60,
                                headingRowColor: WidgetStateProperty.all(
                                  isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                                ),
                                columns: const [
                                  DataColumn(label: Text('Product')),
                                  DataColumn(label: Text('Reported')),
                                  DataColumn(label: Text('Qty'), numeric: true),
                                  DataColumn(label: Text('Source')),
                                  DataColumn(label: Text('Party')),
                                  DataColumn(label: Text('Reason')),
                                  DataColumn(label: Text('Refund'), numeric: true),
                                  DataColumn(label: Text('Return Status')),
                                ],
                                rows: defectives.map((d) {
                                  final date = DateTime.parse(d['reported_at'] as String);
                                  final returnStatus = d['supplier_return_status'] as String? ?? 'PENDING';
                                  final source = d['source'] as String? ?? '';
                                  return DataRow(
                                    color: WidgetStateProperty.all(
                                      isDark
                                          ? Colors.orange.withValues(alpha: 0.06)
                                          : Colors.orange.shade50,
                                    ),
                                    cells: [
                                      DataCell(Text(d['product_name'] as String,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                                      DataCell(Text(fmt.format(date),
                                          style: const TextStyle(fontSize: 12))),
                                      DataCell(Text(
                                        (d['quantity'] as num).toStringAsFixed(2),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      )),
                                      DataCell(_sourceBadge(source, isDark)),
                                      DataCell(Text(d['party_name'] as String? ?? '—',
                                          style: const TextStyle(fontSize: 12))),
                                      DataCell(SizedBox(
                                        width: 140,
                                        child: Text(
                                          d['reason'] as String? ?? '—',
                                          style: const TextStyle(fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      )),
                                      DataCell(Text(
                                        '${widget.sym}${((d['refund_amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: Colors.teal.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      )),
                                      DataCell(_returnStatusBadge(returnStatus)),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _summCard(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: isDark ? color.withValues(alpha: 0.8) : color.withValues(alpha: 0.85))),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? color.withValues(alpha: 0.9) : color)),
        ],
      ),
    );
  }

  Widget _emptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color =
        status == 'COMPLETED' ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _returnStatusBadge(String status) {
    final color = switch (status) {
      'ACCEPTED' => Colors.green,
      'REJECTED' => Colors.red,
      _ => Colors.orange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(status,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _sourceBadge(String source, bool isDark) {
    final isCustomer = source.contains('CUSTOMER');
    final color = isCustomer ? Colors.purple : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isCustomer ? 'CUSTOMER' : 'INTERNAL',
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _productSummary(List lines) {
    if (lines.isEmpty) return 'N/A';
    final names =
        lines.map((l) => l['product_name'] as String).take(2).join(', ');
    return lines.length > 2 ? '$names +${lines.length - 2}' : names;
  }

  double _totalQty(List lines) =>
      lines.fold(0, (s, l) => s + (l['quantity'] as num).toDouble());
}
