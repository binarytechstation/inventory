import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'transaction_form_screen.dart';
import '../../../services/transaction/transaction_service.dart';

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
        builder: (context) => TransactionFormScreen(transactionType: type),
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
        title: const Text('Transactions'),
        bottom: TabBar(
          controller: _tabController,
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
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
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
            ElevatedButton.icon(
              onPressed: widget.onNewTransaction,
              icon: const Icon(Icons.add),
              label: Text('New ${widget.type == 'BUY' ? 'Purchase' : 'Sale'}'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                '${_transactions.length} ${widget.type == 'BUY' ? 'Purchases' : 'Sales'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: widget.onNewTransaction,
                icon: const Icon(Icons.add),
                label: Text('New ${widget.type == 'BUY' ? 'Purchase' : 'Sale'}'),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadTransactions,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadTransactions,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                final transaction = _transactions[index];
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
                  '\$${total.toStringAsFixed(2)}',
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

  void _viewTransactionDetails(Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invoice ${transaction['invoice_number']}'),
        content: SingleChildScrollView(
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
              const Divider(),
              _buildDetailRow('Subtotal', '\$${(transaction['subtotal'] as num).toStringAsFixed(2)}'),
              _buildDetailRow('Discount', '\$${(transaction['discount_amount'] as num).toStringAsFixed(2)}'),
              _buildDetailRow('Tax', '\$${(transaction['tax_amount'] as num).toStringAsFixed(2)}'),
              _buildDetailRow('Total', '\$${(transaction['total_amount'] as num).toStringAsFixed(2)}', bold: true),
              if (transaction['notes'] != null && (transaction['notes'] as String).isNotEmpty) ...[
                const Divider(),
                const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(transaction['notes'] as String),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
