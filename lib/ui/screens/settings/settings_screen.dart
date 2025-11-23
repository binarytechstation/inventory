import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/user_model.dart';
import '../../../services/auth/auth_service.dart';
import '../../providers/auth_provider.dart';
import '../user/change_password_screen.dart';
import 'profile_edit_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // User Profile Section
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue,
                    child: Text(
                      user?.name.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(fontSize: 32, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.name ?? 'User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${user?.username ?? 'username'}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(user?.role.toUpperCase() ?? 'USER'),
                    backgroundColor: _getRoleColor(user?.role ?? ''),
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _navigateToEditProfile(user),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Profile'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => _navigateToChangePassword(user),
                        icon: const Icon(Icons.lock),
                        label: const Text('Change Password'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Account Settings
          _buildSectionTitle('Account Settings'),
          _buildSettingsTile(
            icon: Icons.person,
            title: 'Full Name',
            subtitle: user?.name ?? 'Not set',
            onTap: () => _navigateToEditProfile(user),
          ),
          _buildSettingsTile(
            icon: Icons.email,
            title: 'Email',
            subtitle: user?.email ?? 'Not set',
            onTap: () => _navigateToEditProfile(user),
          ),
          _buildSettingsTile(
            icon: Icons.phone,
            title: 'Phone',
            subtitle: user?.phone ?? 'Not set',
            onTap: () => _navigateToEditProfile(user),
          ),

          // Application Settings
          _buildSectionTitle('Application Settings'),
          _buildSettingsTile(
            icon: Icons.business,
            title: 'Business Information',
            subtitle: 'Company name, address, tax details',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Feature coming soon')),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.receipt,
            title: 'Invoice Settings',
            subtitle: 'Customize invoice format and numbering',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Feature coming soon')),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.print,
            title: 'Print Settings',
            subtitle: 'Configure receipt and report printing',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Feature coming soon')),
              );
            },
          ),

          // Data Management
          _buildSectionTitle('Data Management'),
          _buildSettingsTile(
            icon: Icons.backup,
            title: 'Backup Data',
            subtitle: 'Create a backup of your database',
            onTap: () => _showBackupDialog(),
          ),
          _buildSettingsTile(
            icon: Icons.restore,
            title: 'Restore Data',
            subtitle: 'Restore from a previous backup',
            onTap: () => _showRestoreDialog(),
          ),
          _buildSettingsTile(
            icon: Icons.delete_forever,
            title: 'Clear All Data',
            subtitle: 'Delete all data (cannot be undone)',
            onTap: () => _showClearDataDialog(),
            trailing: const Icon(Icons.warning, color: Colors.red),
          ),

          // Security
          _buildSectionTitle('Security'),
          _buildSettingsTile(
            icon: Icons.history,
            title: 'Activity Log',
            subtitle: 'View system activity and audit logs',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Feature coming soon')),
              );
            },
          ),

          // About
          _buildSectionTitle('About'),
          _buildSettingsTile(
            icon: Icons.info,
            title: 'App Version',
            subtitle: '1.0.0',
            onTap: null,
          ),
          _buildSettingsTile(
            icon: Icons.description,
            title: 'License Information',
            subtitle: 'View license details',
            onTap: () => _showLicenseDialog(),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
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

  void _navigateToEditProfile(UserModel? user) {
    if (user == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileEditScreen(user: user),
      ),
    );
  }

  void _navigateToChangePassword(UserModel? user) {
    if (user == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangePasswordScreen(user: user),
      ),
    );
  }

  Future<void> _showBackupDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Database'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will create a backup of your entire database.'),
            SizedBox(height: 16),
            Text(
              'Note: This feature is under development.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup feature coming soon')),
              );
            },
            child: const Text('Create Backup'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRestoreDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Database'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will restore your database from a backup file.'),
            SizedBox(height: 8),
            Text(
              'Warning: This will replace all current data!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Note: This feature is under development.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Restore feature coming soon')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  Future<void> _showClearDataDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WARNING: This will permanently delete ALL data including:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            SizedBox(height: 8),
            Text('• All products and inventory'),
            Text('• All transactions (sales & purchases)'),
            Text('• All suppliers and customers'),
            Text('• All user accounts (except admin)'),
            SizedBox(height: 16),
            Text(
              'This action CANNOT be undone!',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE ALL DATA'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clear data feature coming soon')),
      );
    }
  }

  Future<void> _showLicenseDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('License Information'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventory Management System',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('Version: 1.0.0'),
              SizedBox(height: 16),
              Text(
                'Device-based licensing with offline capabilities.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 16),
              Text(
                'License Details',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('License Type: Single Device'),
              Text('Status: Active'),
              SizedBox(height: 16),
              Text(
                'This software uses device-based licensing and does not require internet connectivity for operation.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
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
}
