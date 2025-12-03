import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/reports/transaction_details_service.dart';
import '../../../services/currency/currency_service.dart';

class TransactionDetailsScreen extends StatefulWidget {
  const TransactionDetailsScreen({super.key});

  @override
  State<TransactionDetailsScreen> createState() => _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TransactionDetailsService _detailsService = TransactionDetailsService();
  final CurrencyService _currencyService = CurrencyService();

  String _currencySymbol = '৳';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    try {
      final symbol = await _currencyService.getCurrencySymbol();
      setState(() {
        _currencySymbol = symbol;
      });
    } catch (e) {
      setState(() {
        _currencySymbol = '৳';
      });
    }
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
          tabs: const [
            Tab(text: 'Purchase (Date Range)'),
            Tab(text: 'Sales (Date Range)'),
            Tab(text: 'Purchase (Today Hourly)'),
            Tab(text: 'Sales (Today Hourly)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Purchase Date Range
          _DateRangeReport(
            type: 'BUY',
            currencySymbol: _currencySymbol,
            detailsService: _detailsService,
          ),
          // Sales Date Range
          _DateRangeReport(
            type: 'SELL',
            currencySymbol: _currencySymbol,
            detailsService: _detailsService,
          ),
          // Purchase Hourly
          _HourlyReport(
            type: 'BUY',
            currencySymbol: _currencySymbol,
            detailsService: _detailsService,
          ),
          // Sales Hourly
          _HourlyReport(
            type: 'SELL',
            currencySymbol: _currencySymbol,
            detailsService: _detailsService,
          ),
        ],
      ),
    );
  }
}

// Date Range Report Widget
class _DateRangeReport extends StatefulWidget {
  final String type; // 'BUY' or 'SELL'
  final String currencySymbol;
  final TransactionDetailsService detailsService;

  const _DateRangeReport({
    required this.type,
    required this.currencySymbol,
    required this.detailsService,
  });

  @override
  State<_DateRangeReport> createState() => _DateRangeReportState();
}

class _DateRangeReportState extends State<_DateRangeReport> {
  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default to current month
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _loadData();
  }

  Future<void> _loadData() async {
    if (_startDate == null || _endDate == null) return;

    setState(() => _isLoading = true);
    try {
      final data = await widget.detailsService.getTransactionsByDateRange(
        type: widget.type,
        startDate: _startDate!,
        endDate: _endDate!,
      );
      setState(() {
        _transactions = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
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
      _loadData();
    }
  }

  Future<void> _exportToExcel() async {
    try {
      final path = await widget.detailsService.exportToExcel(
        transactions: _transactions,
        type: widget.type,
        reportType: 'date_range',
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: $path'),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grandTotal = _transactions.fold<double>(
      0,
      (sum, t) => sum + (t['total_amount'] as num).toDouble(),
    );

    return Column(
      children: [
        // Date Range Selector
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date Range',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _startDate != null && _endDate != null
                          ? '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}'
                          : 'Select date range',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _selectDateRange,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: const Text('Select'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _transactions.isEmpty ? null : _exportToExcel,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export'),
              ),
            ],
          ),
        ),

        // Summary
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Transactions: ${_transactions.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Grand Total: ${widget.currencySymbol}${grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),

        // Data Table
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _transactions.isEmpty
                  ? const Center(
                      child: Text('No transactions found for selected date range'),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columnSpacing: 16,
                          headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                          columns: const [
                            DataColumn(label: Text('Invoice')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Time')),
                            DataColumn(label: Text('Party')),
                            DataColumn(label: Text('Products')),
                            DataColumn(label: Text('Quantity')),
                            DataColumn(label: Text('Lot Details')),
                            DataColumn(label: Text('Discount')),
                            DataColumn(label: Text('Unit Price')),
                            DataColumn(label: Text('Total')),
                          ],
                          rows: _transactions.map((t) {
                            final date = DateTime.parse(t['transaction_date'] as String);
                            return DataRow(cells: [
                              DataCell(Text(t['invoice_number'] as String)),
                              DataCell(Text(DateFormat('dd MMM yyyy').format(date))),
                              DataCell(Text(DateFormat('HH:mm').format(date))),
                              DataCell(Text(t['party_name'] as String? ?? 'N/A')),
                              DataCell(Text(_getProductNames(t['lines'] as List))),
                              DataCell(Text(_getTotalQuantity(t['lines'] as List))),
                              DataCell(Text(_getLotDetails(t['lines'] as List))),
                              DataCell(Text('${widget.currencySymbol}${(t['discount_amount'] as num).toStringAsFixed(2)}')),
                              DataCell(Text(_getAverageUnitPrice(t['lines'] as List))),
                              DataCell(Text(
                                '${widget.currencySymbol}${(t['total_amount'] as num).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  String _getProductNames(List lines) {
    if (lines.isEmpty) return 'N/A';
    final names = lines.map((l) => l['product_name'] as String).take(2).join(', ');
    return lines.length > 2 ? '$names +${lines.length - 2}' : names;
  }

  String _getTotalQuantity(List lines) {
    final total = lines.fold<double>(
      0,
      (sum, l) => sum + (l['quantity'] as num).toDouble(),
    );
    return total.toStringAsFixed(2);
  }

  String _getAverageUnitPrice(List lines) {
    if (lines.isEmpty) return 'N/A';
    final total = lines.fold<double>(
      0,
      (sum, l) => sum + (l['unit_price'] as num).toDouble(),
    );
    final average = total / lines.length;
    return '${widget.currencySymbol}${average.toStringAsFixed(2)}';
  }

  String _getLotDetails(List lines) {
    if (lines.isEmpty) return 'N/A';
    final lotNames = lines
        .map((l) {
          final lotDesc = l['lot_description'] as String?;
          return (lotDesc != null && lotDesc.isNotEmpty) ? lotDesc : 'Lot #${l['lot_id']}';
        })
        .take(2)
        .join(', ');
    return lines.length > 2 ? '$lotNames +${lines.length - 2}' : lotNames;
  }
}

// Hourly Report Widget
class _HourlyReport extends StatefulWidget {
  final String type; // 'BUY' or 'SELL'
  final String currencySymbol;
  final TransactionDetailsService detailsService;

  const _HourlyReport({
    required this.type,
    required this.currencySymbol,
    required this.detailsService,
  });

  @override
  State<_HourlyReport> createState() => _HourlyReportState();
}

class _HourlyReportState extends State<_HourlyReport> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  int? _startHour;
  int? _endHour;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.detailsService.getHourlyTransactions(
        type: widget.type,
        date: _selectedDate,
        startHour: _startHour,
        endHour: _endHour,
      );
      setState(() {
        _transactions = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  Future<void> _selectHourRange() async {
    int? selectedStart = _startHour;
    int? selectedEnd = _endHour;

    final result = await showDialog<Map<String, int?>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Hour Range'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Start Hour: '),
                  const SizedBox(width: 16),
                  DropdownButton<int?>(
                    value: selectedStart,
                    hint: const Text('All'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Hours')),
                      ...List.generate(24, (i) => i).map((hour) => DropdownMenuItem(
                        value: hour,
                        child: Text('${hour.toString().padLeft(2, '0')}:00'),
                      )),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedStart = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('End Hour:   '),
                  const SizedBox(width: 16),
                  DropdownButton<int?>(
                    value: selectedEnd,
                    hint: const Text('All'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Hours')),
                      ...List.generate(24, (i) => i).map((hour) => DropdownMenuItem(
                        value: hour,
                        child: Text('${hour.toString().padLeft(2, '0')}:00'),
                      )),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedEnd = value;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, {'start': selectedStart, 'end': selectedEnd});
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _startHour = result['start'];
        _endHour = result['end'];
      });
      _loadData();
    }
  }

  Future<void> _exportToExcel() async {
    try {
      final path = await widget.detailsService.exportToExcel(
        transactions: _transactions,
        type: widget.type,
        reportType: 'hourly',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: $path'),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grandTotal = _transactions.fold<double>(
      0,
      (sum, t) => sum + (t['total_amount'] as num).toDouble(),
    );

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hourly Transactions',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMM yyyy').format(_selectedDate),
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (_startHour != null || _endHour != null)
                          Text(
                            'Hours: ${_startHour?.toString().padLeft(2, '0') ?? '00'}:00 - ${_endHour?.toString().padLeft(2, '0') ?? '23'}:59',
                            style: const TextStyle(fontSize: 10, color: Colors.blue),
                          ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: const Text('Date'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _selectHourRange,
                    icon: const Icon(Icons.access_time, size: 18),
                    label: const Text('Hours'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _transactions.isEmpty ? null : _exportToExcel,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Export'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Summary
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Transactions: ${_transactions.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Grand Total: ${widget.currencySymbol}${grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),

        // Data Table
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _transactions.isEmpty
                  ? const Center(
                      child: Text('No transactions today'),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columnSpacing: 16,
                          headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                          columns: const [
                            DataColumn(label: Text('Invoice')),
                            DataColumn(label: Text('Hour')),
                            DataColumn(label: Text('Exact Time')),
                            DataColumn(label: Text('Party')),
                            DataColumn(label: Text('Products')),
                            DataColumn(label: Text('Quantity')),
                            DataColumn(label: Text('Lot Details')),
                            DataColumn(label: Text('Discount')),
                            DataColumn(label: Text('Unit Price')),
                            DataColumn(label: Text('Total')),
                          ],
                          rows: _transactions.map((t) {
                            final date = DateTime.parse(t['transaction_date'] as String);
                            return DataRow(cells: [
                              DataCell(Text(t['invoice_number'] as String)),
                              DataCell(Text(_getHourRange(date))),
                              DataCell(Text(DateFormat('HH:mm:ss').format(date))),
                              DataCell(Text(t['party_name'] as String? ?? 'N/A')),
                              DataCell(Text(_getProductNames(t['lines'] as List))),
                              DataCell(Text(_getTotalQuantity(t['lines'] as List))),
                              DataCell(Text(_getLotDetails(t['lines'] as List))),
                              DataCell(Text('${widget.currencySymbol}${(t['discount_amount'] as num).toStringAsFixed(2)}')),
                              DataCell(Text(_getAverageUnitPrice(t['lines'] as List))),
                              DataCell(Text(
                                '${widget.currencySymbol}${(t['total_amount'] as num).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  String _getHourRange(DateTime date) {
    final hour = date.hour;
    final nextHour = (hour + 1) % 24;
    return '${hour.toString().padLeft(2, '0')}:00 - ${nextHour.toString().padLeft(2, '0')}:00';
  }

  String _getProductNames(List lines) {
    if (lines.isEmpty) return 'N/A';
    final names = lines.map((l) => l['product_name'] as String).take(2).join(', ');
    return lines.length > 2 ? '$names +${lines.length - 2}' : names;
  }

  String _getTotalQuantity(List lines) {
    final total = lines.fold<double>(
      0,
      (sum, l) => sum + (l['quantity'] as num).toDouble(),
    );
    return total.toStringAsFixed(2);
  }

  String _getAverageUnitPrice(List lines) {
    if (lines.isEmpty) return 'N/A';
    final total = lines.fold<double>(
      0,
      (sum, l) => sum + (l['unit_price'] as num).toDouble(),
    );
    final average = total / lines.length;
    return '${widget.currencySymbol}${average.toStringAsFixed(2)}';
  }

  String _getLotDetails(List lines) {
    if (lines.isEmpty) return 'N/A';
    final lotNames = lines
        .map((l) {
          final lotDesc = l['lot_description'] as String?;
          return (lotDesc != null && lotDesc.isNotEmpty) ? lotDesc : 'Lot #${l['lot_id']}';
        })
        .take(2)
        .join(', ');
    return lines.length > 2 ? '$lotNames +${lines.length - 2}' : lotNames;
  }
}

