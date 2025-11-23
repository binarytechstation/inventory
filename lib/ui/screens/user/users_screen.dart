import 'package:flutter/material.dart';
import '../../../data/models/user_model.dart';
import '../../../services/auth/auth_service.dart';
import 'user_form_screen.dart';
import 'change_password_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final AuthService _authService = AuthService();
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedRole;

  final List<String> _roles = ['admin', 'manager', 'cashier', 'viewer'];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _authService.getAllUsers();
      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty && _selectedRole == null) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users.where((user) {
          final nameLower = user.name.toLowerCase();
          final usernameLower = user.username.toLowerCase();
          final emailLower = user.email?.toLowerCase() ?? '';
          final searchLower = query.toLowerCase();

          final matchesSearch = query.isEmpty ||
              nameLower.contains(searchLower) ||
              usernameLower.contains(searchLower) ||
              emailLower.contains(searchLower);

          final matchesRole = _selectedRole == null || user.role == _selectedRole;

          return matchesSearch && matchesRole;
        }).toList();
      }
    });
  }

  Future<void> _toggleUserStatus(UserModel user) async {
    try {
      final updatedUser = user.copyWith(isActive: !user.isActive);
      await _authService.updateUser(updatedUser);
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(user.isActive ? 'User deactivated' : 'User activated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating user: $e')),
        );
      }
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    // Prevent deleting yourself or the last admin
    final currentUser = _authService.getCurrentUser();
    if (currentUser?.id == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete your own account')),
      );
      return;
    }

    if (user.role == 'admin') {
      final adminCount = _users.where((u) => u.role == 'admin' && u.isActive).length;
      if (adminCount <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot delete the last admin user')),
        );
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.name}?'),
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
        await _authService.deleteUser(user.id!);
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting user: $e')),
          );
        }
      }
    }
  }

  void _navigateToAddUser() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UserFormScreen(),
      ),
    );
    if (result == true) {
      _loadUsers();
    }
  }

  void _navigateToEditUser(UserModel user) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserFormScreen(user: user),
      ),
    );
    if (result == true) {
      _loadUsers();
    }
  }

  void _navigateToChangePassword(UserModel user) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangePasswordScreen(user: user),
      ),
    );
  }

  Future<void> _showRoleFilter() async {
    final selected = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Roles'),
              leading: Radio<String?>(
                value: null,
                groupValue: _selectedRole,
                onChanged: (value) => Navigator.pop(context, value),
              ),
              onTap: () => Navigator.pop(context, null),
            ),
            ..._roles.map((role) => ListTile(
              title: Text(role[0].toUpperCase() + role.substring(1)),
              leading: Radio<String?>(
                value: role,
                groupValue: _selectedRole,
                onChanged: (value) => Navigator.pop(context, value),
              ),
              onTap: () => Navigator.pop(context, role),
            )),
          ],
        ),
      ),
    );

    if (selected != _selectedRole) {
      setState(() => _selectedRole = selected);
      _filterUsers(_searchController.text);
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'manager':
        return Colors.blue;
      case 'cashier':
        return Colors.green;
      case 'viewer':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'manager':
        return Icons.manage_accounts;
      case 'cashier':
        return Icons.point_of_sale;
      case 'viewer':
        return Icons.visibility;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: Icon(
              _selectedRole != null ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _selectedRole != null ? Colors.blue : null,
            ),
            onPressed: _showRoleFilter,
            tooltip: 'Filter by Role',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users by name, username, or email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterUsers('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _filterUsers,
            ),
          ),
          if (_selectedRole != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Chip(
                label: Text('Role: ${_selectedRole![0].toUpperCase()}${_selectedRole!.substring(1)}'),
                onDeleted: () {
                  setState(() => _selectedRole = null);
                  _filterUsers(_searchController.text);
                },
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty && _selectedRole == null
                                  ? 'No users yet'
                                  : 'No users found',
                              style: const TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            if (_searchController.text.isEmpty && _selectedRole == null)
                              ElevatedButton.icon(
                                onPressed: _navigateToAddUser,
                                icon: const Icon(Icons.add),
                                label: const Text('Add First User'),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          final roleColor = _getRoleColor(user.role);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: user.isActive ? roleColor : Colors.grey,
                                child: Icon(
                                  _getRoleIcon(user.role),
                                  color: Colors.white,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      user.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        decoration: user.isActive ? null : TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ),
                                  if (!user.isActive)
                                    const Chip(
                                      label: Text('Inactive', style: TextStyle(fontSize: 10)),
                                      padding: EdgeInsets.all(4),
                                      backgroundColor: Colors.grey,
                                    ),
                                  if (user.mustChangePassword)
                                    const Tooltip(
                                      message: 'Must change password',
                                      child: Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.account_circle, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text('Username: ${user.username}'),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Icon(_getRoleIcon(user.role), size: 14, color: roleColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Role: ${user.role[0].toUpperCase()}${user.role.substring(1)}',
                                        style: TextStyle(
                                          color: roleColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (user.email != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.email, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(user.email!),
                                      ],
                                    ),
                                  if (user.lastLogin != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.schedule, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text('Last login: ${_formatDateTime(user.lastLogin!)}'),
                                      ],
                                    ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 20),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'password',
                                    child: Row(
                                      children: [
                                        Icon(Icons.lock_reset, size: 20),
                                        SizedBox(width: 8),
                                        Text('Change Password'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Row(
                                      children: [
                                        Icon(
                                          user.isActive ? Icons.block : Icons.check_circle,
                                          size: 20,
                                          color: user.isActive ? Colors.orange : Colors.green,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          user.isActive ? 'Deactivate' : 'Activate',
                                          style: TextStyle(
                                            color: user.isActive ? Colors.orange : Colors.green,
                                          ),
                                        ),
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
                                  if (value == 'edit') {
                                    _navigateToEditUser(user);
                                  } else if (value == 'password') {
                                    _navigateToChangePassword(user);
                                  } else if (value == 'toggle') {
                                    _toggleUserStatus(user);
                                  } else if (value == 'delete') {
                                    _deleteUser(user);
                                  }
                                },
                              ),
                              onTap: () => _navigateToEditUser(user),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddUser,
        icon: const Icon(Icons.add),
        label: const Text('Add User'),
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
