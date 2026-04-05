import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../services/expense/expense_service.dart';
import '../../../services/currency/currency_service.dart';
import '../../providers/auth_provider.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final ExpenseService _svc = ExpenseService();
  final CurrencyService _currencyService = CurrencyService();

  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _categoryBreakdown = [];
  bool _loading = false;
  String _sym = '৳';

  DateTime? _startDate;
  DateTime? _endDate;
  String _categoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _currencyService.getCurrencySymbol().then((s) {
      if (mounted) setState(() => _sym = s);
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _svc.getExpenses(startDate: _startDate, endDate: _endDate, category: _categoryFilter == 'All' ? null : _categoryFilter),
        _svc.getExpensesByCategory(startDate: _startDate, endDate: _endDate),
      ]);
      if (mounted) {
        setState(() {
          _expenses = results[0];
          _categoryBreakdown = results[1];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _grandTotal =>
      _expenses.fold(0, (s, e) => s + (e['amount'] as num).toDouble());

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _load();
    }
  }

  void _showAddEditDialog([Map<String, dynamic>? existing]) {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: isEdit ? existing['title'] as String : '');
    final amountCtrl = TextEditingController(
        text: isEdit ? (existing['amount'] as num).toStringAsFixed(2) : '');
    final notesCtrl = TextEditingController(text: isEdit ? (existing['notes'] as String? ?? '') : '');
    String category = isEdit ? (existing['category'] as String? ?? 'General') : 'General';
    String paymentMethod = isEdit ? (existing['payment_method'] as String? ?? 'cash') : 'cash';
    DateTime expenseDate = isEdit
        ? DateTime.tryParse(existing['expense_date'] as String) ?? DateTime.now()
        : DateTime.now();

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Row(children: [
            Icon(isEdit ? Icons.edit : Icons.add_circle_outline, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Text(isEdit ? 'Edit Expense' : 'Add Expense'),
          ]),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Title
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Title *',
                    hintText: 'e.g. Office Rent, Driver Salary',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.title),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 14),
                // Amount
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount *',
                    prefixText: '$_sym ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                // Category
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.category_outlined),
                  ),
                  items: ExpenseService.defaultCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDlg(() => category = v ?? 'General'),
                ),
                const SizedBox(height: 14),
                // Date
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: expenseDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (d != null) setDlg(() => expenseDate = d);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('dd MMM yyyy').format(expenseDate)),
                  ),
                ),
                const SizedBox(height: 14),
                // Payment Method
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  decoration: InputDecoration(
                    labelText: 'Payment Method',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                    DropdownMenuItem(value: 'mobile', child: Text('Mobile Banking')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setDlg(() => paymentMethod = v ?? 'cash'),
                ),
                const SizedBox(height: 14),
                // Notes
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.notes),
                  ),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final amount = double.tryParse(amountCtrl.text.trim());
                if (title.isEmpty || amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid title and amount.')));
                  return;
                }
                Navigator.pop(ctx);
                try {
                  if (isEdit) {
                    await _svc.updateExpense(
                      id: existing['id'] as int,
                      title: title,
                      amount: amount,
                      expenseDate: expenseDate,
                      category: category,
                      paymentMethod: paymentMethod,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    );
                  } else {
                    await _svc.addExpense(
                      title: title,
                      amount: amount,
                      expenseDate: expenseDate,
                      category: category,
                      paymentMethod: paymentMethod,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      createdBy: userId,
                    );
                  }
                  _load();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: Text(isEdit ? 'Save Changes' : 'Add Expense'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExpense(int id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _svc.deleteExpense(id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allCategories = ['All', ..._categoryBreakdown.map((c) => c['category'] as String)];

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.money_off_csred, size: 24),
          ),
          const SizedBox(width: 12),
          const Text('Expenses'),
        ]),
        actions: [
          TextButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.calendar_today, size: 16, color: Colors.white),
            label: Text(
              _startDate != null && _endDate != null
                  ? '${DateFormat('dd MMM').format(_startDate!)} – ${DateFormat('dd MMM yyyy').format(_endDate!)}'
                  : 'Select Period',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final canEdit = auth.currentUser?.hasPermission('create_sale') ?? false;
              return FilledButton.icon(
                onPressed: canEdit ? () => _showAddEditDialog() : null,
                icon: const Icon(Icons.add),
                label: const Text('Add Expense'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── LEFT: Category breakdown ──────────────────────────────
          SizedBox(
            width: 220,
            child: Card(
              margin: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                    child: Text('By Category', style: Theme.of(context).textTheme.titleSmall),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            children: [
                              // "All" chip
                              _catTile('All', _grandTotal, isDark),
                              ..._categoryBreakdown.map((c) => _catTile(
                                    c['category'] as String,
                                    (c['total'] as num).toDouble(),
                                    isDark,
                                  )),
                            ],
                          ),
                  ),
                  // Total
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.06),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '$_sym${_grandTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                            fontSize: 15),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          // ── RIGHT: Expense list ───────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Filter row
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: allCategories.map((cat) {
                        final isSelected = _categoryFilter == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: Colors.red.shade100,
                            checkmarkColor: Colors.red.shade700,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.red.shade700 : null,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            onSelected: (_) {
                              setState(() => _categoryFilter = cat);
                              _load();
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Row(children: [
                    Text('${_expenses.length} expense(s)',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const Spacer(),
                    Text('Total: $_sym${_grandTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                  ]),
                ),
                // List
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _expenses.isEmpty
                          ? Center(
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.receipt_long_outlined,
                                    size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                const Text('No expenses in this period',
                                    style: TextStyle(color: Colors.grey, fontSize: 16)),
                                const SizedBox(height: 6),
                                Text('Tap "Add Expense" to record one.',
                                    style:
                                        TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                              ]),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              itemCount: _expenses.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 6),
                              itemBuilder: (_, i) => _buildExpenseCard(_expenses[i], isDark),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _catTile(String name, double total, bool isDark) {
    final isSelected = _categoryFilter == name;
    return InkWell(
      onTap: () {
        setState(() => _categoryFilter = name);
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: isSelected
            ? Colors.red.withValues(alpha: isDark ? 0.18 : 0.08)
            : null,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Text(name,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.red.shade700 : null),
                overflow: TextOverflow.ellipsis),
          ),
          Text(total.toStringAsFixed(2),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.red.shade700 : Colors.grey.shade600)),
        ]),
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> exp, bool isDark) {
    final date = DateTime.tryParse(exp['expense_date'] as String) ?? DateTime.now();
    final amount = (exp['amount'] as num).toDouble();
    final category = exp['category'] as String? ?? 'General';
    final method = exp['payment_method'] as String? ?? 'cash';
    final notes = exp['notes'] as String?;

    final authProvider = context.read<AuthProvider>();
    final canEdit = authProvider.currentUser?.hasPermission('create_sale') ?? false;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.red.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          // Category icon circle
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_categoryIcon(category), color: Colors.red.shade600, size: 20),
          ),
          const SizedBox(width: 12),
          // Main content
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(exp['title'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 3),
              Wrap(spacing: 8, children: [
                _chip(category, Colors.red),
                _chip(DateFormat('dd MMM yyyy').format(date), Colors.grey),
                _chip(method.toUpperCase(), Colors.blue),
              ]),
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(notes,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
          const SizedBox(width: 12),
          // Amount
          Text('$_sym${amount.toStringAsFixed(2)}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.red.shade700)),
          const SizedBox(width: 8),
          if (canEdit) ...[
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 18, color: Colors.blue.shade400),
              onPressed: () => _showAddEditDialog(exp),
              tooltip: 'Edit',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade300),
              onPressed: () => _deleteExpense(exp['id'] as int, exp['title'] as String),
              tooltip: 'Delete',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
      );

  IconData _categoryIcon(String cat) => switch (cat.toLowerCase()) {
        'rent' => Icons.home_outlined,
        'salary' => Icons.people_outline,
        'utilities' => Icons.bolt_outlined,
        'transport' => Icons.directions_car_outlined,
        'marketing' => Icons.campaign_outlined,
        'maintenance' => Icons.build_outlined,
        'office supplies' => Icons.inventory_2_outlined,
        'food & entertainment' => Icons.restaurant_outlined,
        'tax & fees' => Icons.account_balance_outlined,
        'loan repayment' => Icons.money_outlined,
        _ => Icons.receipt_outlined,
      };
}
