import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'purchase_order_screen.dart';
import '../pos/pos_screen.dart';
import '../../../services/transaction/transaction_service.dart';
import '../../../services/currency/currency_service.dart';
import '../../../services/invoice/invoice_service.dart';
import '../../providers/auth_provider.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TransactionService _transactionService = TransactionService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToNewTransaction(String type) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          // Use new Purchase Order screen for BUY transactions
          if (type == 'BUY') {
            return const PurchaseOrderScreen();
          }
          // Use POS screen for SELL transactions (same interface as Point of Sale)
          return const POSScreen();
        },
      ),
    );

    // Refresh the list if a transaction was created
    if (result == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt_long, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Transactions'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Buy / Purchase', icon: Icon(Icons.shopping_cart)),
            Tab(text: 'Sell / Sales', icon: Icon(Icons.point_of_sale)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TransactionTypeView(
            type: 'BUY',
            onNewTransaction: () => _navigateToNewTransaction('BUY'),
            transactionService: _transactionService,
          ),
          _TransactionTypeView(
            type: 'SELL',
            onNewTransaction: () => _navigateToNewTransaction('SELL'),
            transactionService: _transactionService,
          ),
        ],
      ),
    );
  }
}

class _TransactionTypeView extends StatefulWidget {
  final String type;
  final VoidCallback onNewTransaction;
  final TransactionService transactionService;

  const _TransactionTypeView({
    required this.type,
    required this.onNewTransaction,
    required this.transactionService,
  });

  @override
  State<_TransactionTypeView> createState() => _TransactionTypeViewState();
}

class _TransactionTypeViewState extends State<_TransactionTypeView> with AutomaticKeepAliveClientMixin {
  final CurrencyService _currencyService = CurrencyService();
  final InvoiceService _invoiceService = InvoiceService();
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String _currencySymbol = '৳';
  bool _isPrinting = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    _loadTransactions();
  }

  Future<void> _loadCurrency() async {
    try {
      final symbol = await _currencyService.getCurrencySymbol();
      if (mounted) {
        setState(() {
          _currencySymbol = symbol;
        });
      }
    } catch (e) {
      // Use default if error
      if (mounted) {
        setState(() {
          _currencySymbol = '৳';
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final transactions = await widget.transactionService.getTransactions(
        type: widget.type,
      );
      if (mounted) {
        setState(() {
          _transactions = transactions;
          _filteredTransactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

  void _filterTransactions(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredTransactions = _transactions;
      } else {
        _filteredTransactions = _transactions.where((transaction) {
          final invoiceNumber = (transaction['invoice_number'] as String? ?? '').toLowerCase();
          final partyName = (transaction['party_name'] as String? ?? '').toLowerCase();
          final paymentMode = (transaction['payment_mode'] as String? ?? '').toLowerCase();
          final productNames = (transaction['product_names'] as String? ?? '').toLowerCase();
          final searchQuery = query.toLowerCase();

          return invoiceNumber.contains(searchQuery) ||
                 partyName.contains(searchQuery) ||
                 paymentMode.contains(searchQuery) ||
                 productNames.contains(searchQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.type == 'BUY' ? Icons.shopping_cart : Icons.point_of_sale,
              size: 100,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              widget.type == 'BUY' ? 'Purchase Orders' : 'Sales Invoices',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No transactions yet',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                final permission = widget.type == 'BUY' ? 'create_purchase' : 'create_sale';
                final canCreate = authProvider.currentUser?.hasPermission(permission) ?? false;

                return Tooltip(
                  message: canCreate ? '' : 'Admin access only',
                  child: ElevatedButton.icon(
                    onPressed: canCreate ? widget.onNewTransaction : null,
                    icon: const Icon(Icons.add),
                    label: Text('New ${widget.type == 'BUY' ? 'Purchase' : 'Sale'}'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    '${_filteredTransactions.length} ${widget.type == 'BUY' ? 'Purchases' : 'Sales'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      final permission = widget.type == 'BUY' ? 'create_purchase' : 'create_sale';
                      final canCreate = authProvider.currentUser?.hasPermission(permission) ?? false;

                      return Tooltip(
                        message: canCreate ? '' : 'Admin access only',
                        child: ElevatedButton.icon(
                          onPressed: canCreate ? widget.onNewTransaction : null,
                          icon: const Icon(Icons.add),
                          label: Text('New ${widget.type == 'BUY' ? 'Purchase' : 'Sale'}'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadTransactions,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by invoice number, party name, payment mode...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[700],
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[400]
                                : Colors.grey[700],
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _filterTransactions('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF334155)
                      : Colors.grey[100],
                ),
                onChanged: _filterTransactions,
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadTransactions,
            child: _filteredTransactions.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.isEmpty
                          ? 'No transactions found'
                          : 'No results for "${_searchController.text}"',
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _filteredTransactions[index];
                      return _buildTransactionCard(transaction);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final invoiceNumber = transaction['invoice_number'] as String;
    final date = DateTime.parse(transaction['transaction_date'] as String);
    final partyName = transaction['party_name'] as String? ?? 'N/A';
    final total = (transaction['total_amount'] as num).toDouble();
    final paymentMode = transaction['payment_mode'] as String;
    final status = transaction['status'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: widget.type == 'BUY' ? Colors.blue : Colors.green,
          child: Icon(
            widget.type == 'BUY' ? Icons.shopping_cart : Icons.point_of_sale,
            color: Colors.white,
          ),
        ),
        title: Row(
          children: [
            Text(
              invoiceNumber,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            if (status != 'COMPLETED')
              Chip(
                label: Text(
                  status,
                  style: const TextStyle(fontSize: 10),
                ),
                backgroundColor: status == 'CANCELLED' ? Colors.red : Colors.orange,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Party: $partyName'),
            Text('Date: ${DateFormat('dd MMM yyyy, HH:mm').format(date)}'),
            Row(
              children: [
                Text('Payment: ${paymentMode.toUpperCase()}'),
                const SizedBox(width: 8),
                Text(
                  '$_currencySymbol${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _viewTransactionDetails(transaction),
      ),
    );
  }

  Future<void> _viewTransactionDetails(Map<String, dynamic> transaction) async {
    // Fetch full transaction details with line items
    final transactionId = transaction['id'] as int;
    final fullTransaction = await widget.transactionService.getTransactionById(transactionId);

    if (!mounted || fullTransaction == null) return;

    final lines = fullTransaction['lines'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invoice ${transaction['invoice_number']}'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Party', transaction['party_name'] ?? 'N/A'),
                _buildDetailRow('Date', DateFormat('dd MMM yyyy, HH:mm').format(
                  DateTime.parse(transaction['transaction_date'] as String),
                )),
                _buildDetailRow('Type', transaction['transaction_type']),
                _buildDetailRow('Payment Mode', transaction['payment_mode']),
                _buildDetailRow('Status', transaction['status']),
                const Divider(thickness: 2),
                const SizedBox(height: 8),
                const Text(
                  'Items:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                if (lines.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No items found', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ...lines.map((line) {
                    final productName = line['product_name'] as String? ?? 'N/A';
                    final quantity = (line['quantity'] as num).toDouble();
                    final unit = line['unit'] as String? ?? 'piece';
                    final unitPrice = (line['unit_price'] as num).toDouble();
                    final lineTotal = (line['line_total'] as num).toDouble();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    productName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${quantity.toStringAsFixed(2)} $unit × $_currencySymbol${unitPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '$_currencySymbol${lineTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const Divider(thickness: 2),
                const SizedBox(height: 8),
                _buildDetailRow('Subtotal', '$_currencySymbol${(transaction['subtotal'] as num).toStringAsFixed(2)}'),
                _buildDetailRow('Discount', '$_currencySymbol${(transaction['discount_amount'] as num).toStringAsFixed(2)}'),
                _buildDetailRow('Tax', '$_currencySymbol${(transaction['tax_amount'] as num).toStringAsFixed(2)}'),
                _buildDetailRow('Total', '$_currencySymbol${(transaction['total_amount'] as num).toStringAsFixed(2)}', bold: true),
                if (transaction['notes'] != null && (transaction['notes'] as String).isNotEmpty) ...[
                  const Divider(),
                  const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(transaction['notes'] as String),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              final canPrint = authProvider.currentUser?.hasPermission('print_invoice') ?? false;

              return Tooltip(
                message: canPrint ? '' : 'Admin access only',
                child: ElevatedButton.icon(
                  onPressed: (!canPrint || _isPrinting)
                      ? null
                      : () async {
                          setState(() => _isPrinting = true);
                          await _printInvoice(transaction['id'] as int);
                          setState(() => _isPrinting = false);
                        },
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print),
                  label: Text(_isPrinting ? 'Printing...' : 'Print'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _printInvoice(int transactionId) async {
    try {
      // Generate PDF with invoice settings
      final pdfPath = await _invoiceService.generateInvoicePDF(
        transactionId: transactionId,
        saveToFile: true,
      );

      if (mounted) {
        // Close the transaction details dialog
        Navigator.pop(context);

        // Show success dialog with options
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Invoice Saved'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Invoice has been saved to:'),
                const SizedBox(height: 8),
                SelectableText(
                  pdfPath,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _openPDFFile(pdfPath);
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open PDF'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openPDFFile(String path) async {
    try {
      // Open the PDF file with the default PDF viewer
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }
}
