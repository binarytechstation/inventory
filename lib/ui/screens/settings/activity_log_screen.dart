import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/audit/audit_service.dart';
import '../../../services/user/user_service.dart';
import '../../../data/models/user_model.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final AuditService _auditService = AuditService();
  final UserService _userService = UserService();

  List<Map<String, dynamic>> _logs = [];
  List<UserModel> _users = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;

  // Filters
  int? _selectedUserId;
  String? _selectedAction;
  DateTimeRange? _dateRange;
  int _currentLimit = 50;
  final int _loadMoreIncrement = 50;

  // Action types
  final List<String> _actionTypes = [
    'CREATE',
    'UPDATE',
    'DELETE',
    'LOGIN',
    'LOGOUT',
    'VIEW',
    'PRINT',
    'EXPORT',
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadLogs();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _userService.getAllUsers();
      setState(() => _users = users);
    } catch (e) {
      // Silently fail if users can't be loaded
    }
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);

    try {
      final logs = await _auditService.getAuditLogs(
        userId: _selectedUserId,
        action: _selectedAction,
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
        limit: _currentLimit,
      );

      setState(() => _logs = logs);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreLogs() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
      _currentLimit += _loadMoreIncrement;
    });

    await _loadLogs();

    setState(() => _isLoadingMore = false);
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _currentLimit = 50;
      });
      await _loadLogs();
    }
  }

  Future<void> _clearFilters() async {
    setState(() {
      _selectedUserId = null;
      _selectedAction = null;
      _dateRange = null;
      _currentLimit = 50;
    });
    await _loadLogs();
  }

  Future<void> _clearOldLogs() async {
    final daysToKeep = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Old Logs'),
        content: const Text(
          'How many days of logs would you like to keep?\n\n'
          'Logs older than the specified number of days will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 30),
            child: const Text('Keep 30 days'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 90),
            child: const Text('Keep 90 days'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 180),
            child: const Text('Keep 180 days'),
          ),
        ],
      ),
    );

    if (daysToKeep != null) {
      try {
        final deletedCount = await _auditService.clearOldLogs(daysToKeep);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted $deletedCount old log entries'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadLogs();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing logs: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE':
        return Colors.green;
      case 'UPDATE':
        return Colors.blue;
      case 'DELETE':
        return Colors.red;
      case 'LOGIN':
        return Colors.purple;
      case 'LOGOUT':
        return Colors.orange;
      case 'VIEW':
        return Colors.grey;
      case 'PRINT':
        return Colors.indigo;
      case 'EXPORT':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE':
        return Icons.add_circle;
      case 'UPDATE':
        return Icons.edit;
      case 'DELETE':
        return Icons.delete;
      case 'LOGIN':
        return Icons.login;
      case 'LOGOUT':
        return Icons.logout;
      case 'VIEW':
        return Icons.visibility;
      case 'PRINT':
        return Icons.print;
      case 'EXPORT':
        return Icons.file_download;
      default:
        return Icons.circle;
    }
  }

  String _getUserName(int? userId) {
    if (userId == null) return 'System';
    final user = _users.firstWhere(
      (u) => u.id == userId,
      orElse: () => UserModel(
        username: 'unknown',
        passwordHash: '',
        role: '',
        name: 'Unknown User',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return user.name;
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd, yyyy HH:mm:ss').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filters',
            onPressed: () => _showFiltersDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear Old Logs',
            onPressed: _clearOldLogs,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          if (_selectedUserId != null || _selectedAction != null || _dateRange != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              color: Colors.blue.shade50,
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  if (_selectedUserId != null)
                    Chip(
                      label: Text('User: ${_getUserName(_selectedUserId)}'),
                      onDeleted: () {
                        setState(() => _selectedUserId = null);
                        _loadLogs();
                      },
                    ),
                  if (_selectedAction != null)
                    Chip(
                      label: Text('Action: $_selectedAction'),
                      onDeleted: () {
                        setState(() => _selectedAction = null);
                        _loadLogs();
                      },
                    ),
                  if (_dateRange != null)
                    Chip(
                      label: Text(
                        'Date: ${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}',
                      ),
                      onDeleted: () {
                        setState(() => _dateRange = null);
                        _loadLogs();
                      },
                    ),
                  ActionChip(
                    label: const Text('Clear All'),
                    onPressed: _clearFilters,
                  ),
                ],
              ),
            ),

          // Logs count
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            color: Colors.grey.shade100,
            child: Text(
              'Showing ${_logs.length} entries',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),

          // Logs list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No activity logs found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: _logs.length + 1, // +1 for "Load More" button
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          if (index == _logs.length) {
                            // Load More button
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: _isLoadingMore
                                    ? const CircularProgressIndicator()
                                    : OutlinedButton.icon(
                                        icon: const Icon(Icons.expand_more),
                                        label: const Text('Load More'),
                                        onPressed: _loadMoreLogs,
                                      ),
                              ),
                            );
                          }

                          final log = _logs[index];
                          final action = log['action'] as String? ?? 'UNKNOWN';
                          final actionColor = _getActionColor(action);
                          final actionIcon = _getActionIcon(action);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: actionColor.withValues(alpha: 0.2),
                                child: Icon(
                                  actionIcon,
                                  color: actionColor,
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _getUserName(log['user_id'] as int?),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                      vertical: 4.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: actionColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      action,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
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
                                  if (log['entity_type'] != null)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.category,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${log['entity_type']}${log['entity_id'] != null ? ' #${log['entity_id']}' : ''}',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (log['details'] != null &&
                                      (log['details'] as String).isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              log['details'] as String,
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDateTime(log['created_at'] as String?),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showFiltersDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Activity Logs'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter by User',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    initialValue: _selectedUserId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                      hintText: 'All Users',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All Users'),
                      ),
                      ..._users.map((user) => DropdownMenuItem<int?>(
                            value: user.id,
                            child: Text(user.name),
                          )),
                    ],
                    onChanged: (value) {
                      setDialogState(() => _selectedUserId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Filter by Action Type',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedAction,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.filter_alt),
                      hintText: 'All Actions',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Actions'),
                      ),
                      ..._actionTypes.map((action) => DropdownMenuItem<String?>(
                            value: action,
                            child: Row(
                              children: [
                                Icon(
                                  _getActionIcon(action),
                                  size: 18,
                                  color: _getActionColor(action),
                                ),
                                const SizedBox(width: 8),
                                Text(action),
                              ],
                            ),
                          )),
                    ],
                    onChanged: (value) {
                      setDialogState(() => _selectedAction = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Filter by Date Range',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _dateRange == null
                          ? 'Select Date Range'
                          : '${DateFormat('MMM dd, yyyy').format(_dateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_dateRange!.end)}',
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _selectDateRange();
                    },
                  ),
                  if (_dateRange != null)
                    TextButton.icon(
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear Date Range'),
                      onPressed: () {
                        setDialogState(() => _dateRange = null);
                      },
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedUserId = null;
                  _selectedAction = null;
                  _dateRange = null;
                  _currentLimit = 50;
                });
                Navigator.pop(context);
                _loadLogs();
              },
              child: const Text('Clear All'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _currentLimit = 50);
                Navigator.pop(context);
                _loadLogs();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}
