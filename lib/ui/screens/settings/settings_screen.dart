import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../data/models/user_model.dart';
import '../../../services/auth/auth_service.dart';
import '../../../services/backup/backup_service.dart';
import '../../../data/database/database_helper.dart';
import '../../providers/auth_provider.dart';
import '../user/change_password_screen.dart';
import 'profile_edit_screen.dart';
import 'business_info_screen.dart';
import 'activity_log_screen.dart';
import 'invoice_settings_main_screen.dart';
import 'invoice_activity_log_screen.dart';
import 'currency_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final BackupService _backupService = BackupService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

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
                    backgroundImage: user?.profilePicturePath != null && File(user!.profilePicturePath!).existsSync()
                        ? FileImage(File(user.profilePicturePath!))
                        : null,
                    child: user?.profilePicturePath == null || !File(user!.profilePicturePath!).existsSync()
                        ? Text(
                            user?.name.substring(0, 1).toUpperCase() ?? 'U',
                            style: const TextStyle(fontSize: 32, color: Colors.white),
                          )
                        : null,
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BusinessInfoScreen()),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.currency_exchange,
            title: 'Currency Settings',
            subtitle: 'Change currency symbol and code',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CurrencySettingsScreen()),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.receipt,
            title: 'Invoice Settings',
            subtitle: 'Customize invoice format, header, footer, body and print settings',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InvoiceSettingsMainScreen()),
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
          _buildSettingsTile(
            icon: Icons.refresh,
            title: 'Reset Database',
            subtitle: 'Delete and recreate database with fresh schema',
            onTap: () => _showResetDatabaseDialog(),
            trailing: const Icon(Icons.warning, color: Colors.orange),
          ),

          // Security
          _buildSectionTitle('Security'),
          _buildSettingsTile(
            icon: Icons.history,
            title: 'Activity Log',
            subtitle: 'View system activity and audit logs',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ActivityLogScreen()),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.receipt_long,
            title: 'Invoice Activity Log',
            subtitle: 'View invoice-specific activity history',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InvoiceActivityLogScreen()),
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
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Database'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will create a backup of your entire database.'),
            SizedBox(height: 8),
            Text('The backup file will be saved to your Documents folder.'),
            SizedBox(height: 16),
            Text(
              'Backup includes:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text('• All products and inventory'),
            Text('• All transactions'),
            Text('• All customers and suppliers'),
            Text('• All users and settings'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'backup'),
            child: const Text('Create Backup'),
          ),
        ],
      ),
    );

    if (result == 'backup') {
      await _performBackup();
    }
  }

  Future<void> _performBackup() async {
    try {
      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Creating backup...'),
            ],
          ),
        ),
      );

      // Create timestamped backup in temporary directory first
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'inventory_backup_$timestamp.db';

      // Create backup in temp directory
      final tempDir = await getTemporaryDirectory();
      final tempBackupPath = path.join(tempDir.path, fileName);
      await _backupService.createBackup(tempBackupPath);

      // On macOS/Linux, show save dialog; on Windows, save directly to Documents
      String? finalBackupPath;

      if (Platform.isMacOS || Platform.isLinux) {
        // Use native save dialog for macOS/Linux
        finalBackupPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Backup File',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['db'],
        );

        if (finalBackupPath != null) {
          // Copy from temp to user-selected location
          final tempFile = File(tempBackupPath);
          await tempFile.copy(finalBackupPath);
          await tempFile.delete(); // Clean up temp file
        } else {
          // User cancelled - clean up temp file
          final tempFile = File(tempBackupPath);
          await tempFile.delete();
        }
      } else {
        // Windows: Save directly to Documents folder
        final backupDir = '${Platform.environment['USERPROFILE']}\\Documents\\InventoryBackups';
        final dir = Directory(backupDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        finalBackupPath = path.join(backupDir, fileName);
        final tempFile = File(tempBackupPath);
        await tempFile.copy(finalBackupPath);
        await tempFile.delete();
      }

      if (finalBackupPath == null) {
        // User cancelled on macOS/Linux
        if (!mounted) return;
        Navigator.pop(context);
        return;
      }

      final backupPath = finalBackupPath;

      // Close loading dialog
      if (!mounted) return;
      Navigator.pop(context);

      // Show success message
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Backup Successful'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Database backup created successfully!'),
              const SizedBox(height: 16),
              const Text(
                'Location:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              SelectableText(
                backupPath,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close loading dialog if open
      if (!mounted) return;
      Navigator.pop(context);

      // Show error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showRestoreDialog() async {
    final confirmed = await showDialog<bool>(
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
              'WARNING: This will replace ALL current data!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Select a backup file to restore from.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Select Backup File'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performRestore();
    }
  }

  Future<void> _performRestore() async {
    try {
      // Pick backup file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
        dialogTitle: 'Select Backup File',
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final pickedFile = result.files.first;
      if (pickedFile.path == null) {
        throw Exception('Invalid file path');
      }

      // On macOS, copy the selected file to a safe location first
      String backupFilePath;
      if (Platform.isMacOS || Platform.isLinux) {
        final tempDir = await getTemporaryDirectory();
        final tempBackupPath = path.join(tempDir.path, 'restore_backup.db');

        // Copy selected file to temp location
        final sourceFile = File(pickedFile.path!);
        await sourceFile.copy(tempBackupPath);
        backupFilePath = tempBackupPath;
      } else {
        backupFilePath = pickedFile.path!;
      }

      // Verify it's a valid backup
      final isValid = await _backupService.verifyBackupIntegrity(backupFilePath);
      if (!isValid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid backup file. Please select a valid database backup.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Final confirmation
      if (!mounted) return;
      final finalConfirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Restore'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you absolutely sure?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('This will:'),
              const Text('• Delete ALL current data'),
              const Text('• Replace it with backup data'),
              const Text('• Restart the application'),
              const SizedBox(height: 16),
              Text(
                'File: ${backupFilePath.split(Platform.pathSeparator).last}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
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
              child: const Text('RESTORE NOW'),
            ),
          ],
        ),
      );

      if (finalConfirm != true) return;

      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Restoring database...'),
              SizedBox(height: 8),
              Text(
                'Please do not close the application',
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
          ),
        ),
      );

      // Perform restore
      await _backupService.restoreBackup(backupFilePath);

      // Close loading
      if (!mounted) return;
      Navigator.pop(context);

      // Show success and exit app
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Restore Complete'),
          content: const Text(
            'Database restored successfully!\n\nThe application will now restart.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                // Exit the app - user needs to restart manually
                exit(0);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Try to close loading dialog
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
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
      await _performClearData();
    }
  }

  Future<void> _performClearData() async {
    try {
      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Clearing all data...'),
            ],
          ),
        ),
      );

      final db = await _dbHelper.database;

      // Delete data from all tables (except users table - we'll keep admin)
      await db.transaction((txn) async {
        // Delete all held bills and their items
        await txn.delete('held_bill_items');
        await txn.delete('held_bills');

        // Delete all transactions and related data
        await txn.delete('transaction_lines');
        await txn.delete('transactions');

        // Delete product batches
        await txn.delete('product_batches');

        // Delete all products, suppliers, customers
        await txn.delete('products');
        await txn.delete('suppliers');
        await txn.delete('customers');

        // Delete all users except admin
        await txn.delete('users', where: 'username != ?', whereArgs: ['admin']);

        // Clear recovery codes
        await txn.delete('recovery_codes');

        // Clear audit logs
        await txn.delete('audit_logs');

        // Reset profile to default
        await txn.delete('profile');

        // Clear settings
        await txn.delete('settings');
      });

      // Close loading
      if (!mounted) return;
      Navigator.pop(context);

      // Show success
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Data Cleared'),
          content: const Text(
            'All data has been deleted successfully.\n\nOnly the admin account remains.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close loading
      if (!mounted) return;
      Navigator.pop(context);

      // Show error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showResetDatabaseDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Database'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WARNING: This will DELETE the entire database and recreate it!',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            SizedBox(height: 16),
            Text('This will:'),
            Text('• Delete ALL data permanently'),
            Text('• Recreate database with latest schema'),
            Text('• Reset to default admin account'),
            Text('• Fix any schema issues'),
            SizedBox(height: 16),
            Text(
              'The app will restart after reset.',
              style: TextStyle(fontStyle: FontStyle.italic),
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
            child: const Text('RESET DATABASE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performDatabaseReset();
    }
  }

  Future<void> _performDatabaseReset() async {
    try {
      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Resetting database...'),
            ],
          ),
        ),
      );

      // Delete the database
      await _dbHelper.deleteDatabase();

      // Close loading
      if (!mounted) return;
      Navigator.pop(context);

      // Show success and exit
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Database Reset Complete'),
          content: const Text(
            'Database has been reset successfully!\n\nThe application will now restart.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                // Exit the app
                exit(0);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close loading
      if (!mounted) return;
      Navigator.pop(context);

      // Show error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reset database: $e'),
          backgroundColor: Colors.red,
        ),
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
