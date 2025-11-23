import 'package:flutter/material.dart';
import 'transaction_form_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionFormScreen(transactionType: type),
      ),
    );
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
          ),
          _TransactionTypeView(
            type: 'SELL',
            onNewTransaction: () => _navigateToNewTransaction('SELL'),
          ),
        ],
      ),
    );
  }
}

class _TransactionTypeView extends StatelessWidget {
  final String type;
  final VoidCallback onNewTransaction;

  const _TransactionTypeView({
    required this.type,
    required this.onNewTransaction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            type == 'BUY' ? Icons.shopping_cart : Icons.point_of_sale,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            type == 'BUY' ? 'Purchase Orders' : 'Sales Invoices',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Transaction history will appear here',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onNewTransaction,
            icon: const Icon(Icons.add),
            label: Text('New ${type == 'BUY' ? 'Purchase' : 'Sale'}'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
