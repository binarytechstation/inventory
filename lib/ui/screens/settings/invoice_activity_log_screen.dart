import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/invoice/invoice_settings_service.dart';

class InvoiceActivityLogScreen extends StatefulWidget {
  const InvoiceActivityLogScreen({super.key});

  @override
  State<InvoiceActivityLogScreen> createState() => _InvoiceActivityLogScreenState();
}

class _InvoiceActivityLogScreenState extends State<InvoiceActivityLogScreen> {
  final InvoiceSettingsService _service = InvoiceSettingsService();

  List<Map<String, dynamic>> _activityLogs = [];
  bool _isLoading = true;

  // Filters
  String? _selectedInvoiceType;
  String? _selectedAction;
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _actionTypes = [
    'CREATED',
    'EDITED',
    'VIEWED',
    'PRINTED',
    'SHARED',
    'DELETED',
    'APPROVED',
    'REJECTED',
  ];

  @override
  void initState() {
    super.initState();
    _loadActivityLogs();
  }

  Future<void> _loadActivityLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await _service.getActivityLogs(
        invoiceType: _selectedInvoiceType,
        action: _selectedAction,
        startDate: _startDate,
        endDate: _endDate,
        limit: 200,
      );

      setState(() {
        _activityLogs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading activity logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadActivityLogs();
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadActivityLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Activity Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActivityLogs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Invoice Type Filter
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedInvoiceType,
                          decoration: const InputDecoration(
                            labelText: 'Invoice Type',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('All Types')),
                            DropdownMenuItem(value: 'SALE', child: Text('Sales')),
                            DropdownMenuItem(value: 'PURCHASE', child: Text('Purchase')),
                            DropdownMenuItem(value: 'QUOTATION', child: Text('Quotation')),
                            DropdownMenuItem(value: 'RETURN_SALE', child: Text('Sales Return')),
                            DropdownMenuItem(value: 'RETURN_PURCHASE', child: Text('Purchase Return')),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedInvoiceType = value);
                            _loadActivityLogs();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Action Filter
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedAction,
                          decoration: const InputDecoration(
                            labelText: 'Action',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Actions')),
                            ..._actionTypes.map((action) => DropdownMenuItem(
                              value: action,
                              child: Text(action),
                            )),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedAction = value);
                            _loadActivityLogs();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Date Range
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            _startDate != null && _endDate != null
                                ? '${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}'
                                : 'Select Date Range',
                          ),
                          onPressed: _selectDateRange,
                        ),
                      ),
                      if (_startDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearDateRange,
                          tooltip: 'Clear date range',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Activity Logs List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _activityLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No activity logs found',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _activityLogs.length,
                        itemBuilder: (context, index) {
                          final log = _activityLogs[index];
                          return _buildActivityLogCard(log);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLogCard(Map<String, dynamic> log) {
    final action = log['action'] as String;
    final invoiceNumber = log['invoice_number'] as String;
    final invoiceType = log['invoice_type'] as String;
    final username = log['username'] as String?;
    final createdAt = log['created_at'] as String;
    final changesSummary = log['changes_summary'] as String?;

    final date = DateTime.parse(createdAt);
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(date);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getActionColor(action),
          child: Icon(_getActionIcon(action), color: Colors.white, size: 20),
        ),
        title: Row(
          children: [
            Text(action, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getTypeColor(invoiceType).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _getTypeColor(invoiceType)),
              ),
              child: Text(
                invoiceType,
                style: TextStyle(
                  fontSize: 10,
                  color: _getTypeColor(invoiceType),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Invoice: $invoiceNumber'),
            if (username != null) Text('By: $username'),
            Text(formattedDate, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (changesSummary != null && changesSummary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                changesSummary,
                style: TextStyle(fontSize: 12, color: Colors.grey[700], fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: () {
          _showLogDetails(log);
        },
      ),
    );
  }

  void _showLogDetails(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${log['action']} - ${log['invoice_number']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Invoice Type', log['invoice_type']),
              _buildDetailRow('Action', log['action']),
              if (log['username'] != null) _buildDetailRow('User', log['username']),
              if (log['ip_address'] != null) _buildDetailRow('IP Address', log['ip_address']),
              _buildDetailRow('Date', DateFormat('dd MMM yyyy, HH:mm:ss').format(DateTime.parse(log['created_at']))),
              if (log['changes_summary'] != null) ...[
                const Divider(),
                const Text('Changes Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(log['changes_summary']),
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

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value?.toString() ?? 'N/A')),
        ],
      ),
    );
  }

  Color _getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'CREATED':
        return Colors.green;
      case 'EDITED':
        return Colors.blue;
      case 'DELETED':
        return Colors.red;
      case 'VIEWED':
        return Colors.grey;
      case 'PRINTED':
        return Colors.purple;
      case 'SHARED':
        return Colors.orange;
      case 'APPROVED':
        return Colors.teal;
      case 'REJECTED':
        return Colors.deepOrange;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action.toUpperCase()) {
      case 'CREATED':
        return Icons.add_circle;
      case 'EDITED':
        return Icons.edit;
      case 'DELETED':
        return Icons.delete;
      case 'VIEWED':
        return Icons.visibility;
      case 'PRINTED':
        return Icons.print;
      case 'SHARED':
        return Icons.share;
      case 'APPROVED':
        return Icons.check_circle;
      case 'REJECTED':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'SALE':
        return Colors.green;
      case 'PURCHASE':
        return Colors.blue;
      case 'QUOTATION':
        return Colors.orange;
      case 'RETURN_SALE':
        return Colors.red;
      case 'RETURN_PURCHASE':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }
}
