import 'package:flutter/material.dart';
import '../../../services/transaction/held_bills_service.dart';
import '../../../services/transaction/transaction_service.dart';
import '../transaction/transaction_form_screen.dart';

class HeldBillsScreen extends StatefulWidget {
  const HeldBillsScreen({super.key});

  @override
  State<HeldBillsScreen> createState() => _HeldBillsScreenState();
}

class _HeldBillsScreenState extends State<HeldBillsScreen> {
  final HeldBillsService _heldBillsService = HeldBillsService();
  final TransactionService _transactionService = TransactionService();

  List<Map<String, dynamic>> _heldBills = [];
  bool _isLoading = true;
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _loadHeldBills();
  }

  Future<void> _loadHeldBills() async {
    setState(() => _isLoading = true);
    try {
      final heldBills = await _heldBillsService.getAllHeldBills(type: _selectedType);
      setState(() {
        _heldBills = heldBills;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading held bills: $e')),
        );
      }
    }
  }

  Future<void> _deleteHeldBill(int id, String billName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Held Bill'),
        content: Text('Are you sure you want to delete "$billName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _heldBillsService.deleteHeldBill(id);
        _loadHeldBills();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Held bill deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting held bill: $e')),
          );
        }
      }
    }
  }

  Future<void> _resumeHeldBill(Map<String, dynamic> heldBill) async {
    // Navigate to transaction form with held bill data
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionFormScreen(
          transactionType: heldBill['type'] as String,
        ),
      ),
    );

    if (result == true) {
      _loadHeldBills();
    }
  }

  Future<void> _convertToTransaction(Map<String, dynamic> heldBill) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Transaction'),
        content: Text(
          'Convert "${heldBill['bill_name'] ?? 'Held Bill'}" to a completed transaction?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Get full held bill details
        final fullHeldBill = await _heldBillsService.getHeldBillById(heldBill['id'] as int);
        if (fullHeldBill == null) throw Exception('Held bill not found');

        final items = (fullHeldBill['items'] as List).map((item) {
          return {
            'product_id': item['product_id'],
            'quantity': item['quantity'],
            'unit_price': item['unit_price'],
            'discount': item['discount'],
            'tax': item['tax'],
            'subtotal': item['subtotal'],
          };
        }).toList();

        // Create transaction
        await _transactionService.createTransaction(
          type: fullHeldBill['type'] as String,
          date: DateTime.now(),
          partyId: fullHeldBill['party_id'] as int,
          partyType: fullHeldBill['party_type'] as String,
          items: items,
          subtotal: (fullHeldBill['subtotal'] as num).toDouble(),
          discount: (fullHeldBill['discount'] as num).toDouble(),
          tax: (fullHeldBill['tax'] as num).toDouble(),
          total: (fullHeldBill['total'] as num).toDouble(),
          paymentMode: 'cash', // Default to cash
          notes: fullHeldBill['notes'] as String?,
        );

        // Delete held bill
        await _heldBillsService.deleteHeldBill(heldBill['id'] as int);

        _loadHeldBills();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction completed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error completing transaction: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Held Bills'),
        actions: [
          PopupMenuButton<String?>(
            icon: Icon(
              _selectedType != null ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _selectedType != null ? Colors.blue : null,
            ),
            onSelected: (value) {
              setState(() => _selectedType = value);
              _loadHeldBills();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('All Types')),
              const PopupMenuItem(value: 'SELL', child: Text('Sales')),
              const PopupMenuItem(value: 'BUY', child: Text('Purchases')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHeldBills,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _heldBills.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pause_circle_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'No held bills',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Held bills allow you to save incomplete transactions',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _heldBills.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final heldBill = _heldBills[index];
                    final billName = heldBill['bill_name'] as String? ?? 'Held Bill #${heldBill['id']}';
                    final type = heldBill['type'] as String;
                    final total = (heldBill['total'] as num).toDouble();
                    final itemCount = heldBill['item_count'] as int;
                    final party = heldBill['party'] as Map<String, dynamic>?;
                    final partyName = party?['name'] as String? ?? 'Unknown';
                    final createdAt = DateTime.parse(heldBill['created_at'] as String);
                    final typeColor = type == 'SELL' ? Colors.green : Colors.blue;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: typeColor,
                          child: Icon(
                            type == 'SELL' ? Icons.shopping_cart : Icons.add_shopping_cart,
                            color: Colors.white,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                billName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Chip(
                              label: Text(
                                type == 'SELL' ? 'Sale' : 'Purchase',
                                style: const TextStyle(fontSize: 10),
                              ),
                              backgroundColor: typeColor,
                              labelStyle: const TextStyle(color: Colors.white),
                              padding: const EdgeInsets.all(4),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  type == 'SELL' ? Icons.person : Icons.local_shipping,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(partyName),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.shopping_basket, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('$itemCount items'),
                                const SizedBox(width: 16),
                                const Icon(Icons.attach_money, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '\$${total.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.schedule, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(_formatDateTime(createdAt)),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'resume',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text('Resume'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'complete',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, size: 20, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Complete', style: TextStyle(color: Colors.green)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 20, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'resume') {
                              _resumeHeldBill(heldBill);
                            } else if (value == 'complete') {
                              _convertToTransaction(heldBill);
                            } else if (value == 'delete') {
                              _deleteHeldBill(heldBill['id'] as int, billName);
                            }
                          },
                        ),
                        onTap: () => _resumeHeldBill(heldBill),
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours} hr ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
