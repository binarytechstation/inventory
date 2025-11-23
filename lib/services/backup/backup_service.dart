import 'dart:io';
import 'package:path/path.dart' as path;
import '../../core/utils/path_helper.dart';

class BackupService {
  final PathHelper _pathHelper = PathHelper();

  /// Create backup of database
  Future<bool> createBackup(String backupPath) async {
    try {
      // Get database file path
      final dbPath = _pathHelper.getDbPath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        throw Exception('Database file not found at $dbPath');
      }

      // Create backup directory if it doesn't exist
      final backupDir = Directory(path.dirname(backupPath));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // Copy database file to backup location
      await dbFile.copy(backupPath);

      return true;
    } catch (e) {
      throw Exception('Failed to create backup: $e');
    }
  }

  /// Create backup with timestamp
  Future<String> createTimestampedBackup(String backupDir) async {
    try {
      // Create backup directory if it doesn't exist
      final dir = Directory(backupDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Generate backup filename with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final backupFilePath = path.join(backupDir, 'inventory_backup_$timestamp.db');

      // Create backup
      await createBackup(backupFilePath);

      return backupFilePath;
    } catch (e) {
      throw Exception('Failed to create timestamped backup: $e');
    }
  }

  /// Restore database from backup file
  Future<bool> restoreBackup(String backupFilePath) async {
    try {
      final backupFile = File(backupFilePath);

      if (!await backupFile.exists()) {
        throw Exception('Backup file not found at $backupFilePath');
      }

      // Get database file path
      final dbPath = _pathHelper.getDbPath();
      final dbFile = File(dbPath);

      // Delete current database
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      // Copy backup file to database location
      await backupFile.copy(dbPath);

      return true;
    } catch (e) {
      throw Exception('Failed to restore backup: $e');
    }
  }

  /// Get list of available backups in directory
  Future<List<Map<String, dynamic>>> getBackupList(String backupDir) async {
    try {
      final dir = Directory(backupDir);

      if (!await dir.exists()) {
        return [];
      }

      final backupFiles = await dir.list().toList();
      final backups = <Map<String, dynamic>>[];

      for (var file in backupFiles) {
        if (file is File && file.path.endsWith('.db')) {
          final stat = await file.stat();
          backups.add({
            'filename': path.basename(file.path),
            'path': file.path,
            'size': stat.size,
            'modified': stat.modified,
          });
        }
      }

      // Sort by modification date (newest first)
      backups.sort((a, b) => (b['modified'] as DateTime).compareTo(a['modified'] as DateTime));

      return backups;
    } catch (e) {
      throw Exception('Failed to get backup list: $e');
    }
  }

  /// Delete backup file
  Future<bool> deleteBackup(String backupPath) async {
    try {
      final file = File(backupPath);

      if (!await file.exists()) {
        throw Exception('Backup file not found at $backupPath');
      }

      await file.delete();
      return true;
    } catch (e) {
      throw Exception('Failed to delete backup: $e');
    }
  }

  /// Delete old backups, keeping only recent ones
  Future<int> deleteOldBackups(String backupDir, int keepCount) async {
    try {
      final backups = await getBackupList(backupDir);

      if (backups.length <= keepCount) {
        return 0;
      }

      int deleted = 0;
      for (int i = keepCount; i < backups.length; i++) {
        await deleteBackup(backups[i]['path'] as String);
        deleted++;
      }

      return deleted;
    } catch (e) {
      throw Exception('Failed to delete old backups: $e');
    }
  }

  /// Get backup file size
  Future<int> getBackupSize(String backupPath) async {
    try {
      final file = File(backupPath);

      if (!await file.exists()) {
        throw Exception('Backup file not found at $backupPath');
      }

      final stat = await file.stat();
      return stat.size;
    } catch (e) {
      throw Exception('Failed to get backup size: $e');
    }
  }

  /// Get total size of all backups in directory
  Future<int> getTotalBackupSize(String backupDir) async {
    try {
      final backups = await getBackupList(backupDir);
      int totalSize = 0;

      for (var backup in backups) {
        totalSize += backup['size'] as int;
      }

      return totalSize;
    } catch (e) {
      throw Exception('Failed to get total backup size: $e');
    }
  }

  /// Schedule automatic backup (placeholder for scheduling logic)
  Future<void> scheduleAutoBackup({
    required String backupDir,
    Duration interval = const Duration(days: 1),
    int keepCount = 7,
  }) async {
    try {
      // This is a placeholder for scheduling backup logic
      // In a real implementation, this would use a scheduling package like
      // 'workmanager' or 'background_fetch' to schedule periodic backups

      // Example implementation would look like:
      // Workmanager().registerPeriodicTask(
      //   'auto_backup',
      //   'autoBackup',
      //   frequency: interval,
      //   constraints: Constraints(
      //     requiresBatteryNotLow: false,
      //     requiresCharging: false,
      //     requiresDeviceIdle: false,
      //     requiresStorageNotLow: false,
      //   ),
      // );

      // Auto backup scheduled successfully
      // interval: $interval, backupDir: $backupDir, keepCount: $keepCount
    } catch (e) {
      throw Exception('Failed to schedule auto backup: $e');
    }
  }

  /// Cancel automatic backup
  Future<void> cancelAutoBackup() async {
    try {
      // This is a placeholder for canceling scheduled backups
      // In a real implementation, this would use the same scheduling package
      // Workmanager().cancelByTag('auto_backup');
    } catch (e) {
      throw Exception('Failed to cancel auto backup: $e');
    }
  }

  /// Verify backup integrity
  Future<bool> verifyBackupIntegrity(String backupPath) async {
    try {
      final file = File(backupPath);

      if (!await file.exists()) {
        throw Exception('Backup file not found at $backupPath');
      }

      // Check if file is readable and not empty
      final stat = await file.stat();
      if (stat.size == 0) {
        return false;
      }

      // Try to open and verify it's a valid database file
      // This is a basic check - a more thorough check would attempt to query the database
      final bytes = await file.readAsBytes();
      final header = String.fromCharCodes(bytes.take(16));

      // SQLite database files start with "SQLite format 3"
      return header.startsWith('SQLite format 3');
    } catch (e) {
      return false;
    }
  }

  /// Get database file path
  String getDatabasePath() {
    return _pathHelper.getDbPath();
  }

  /// Export backup information
  Future<Map<String, dynamic>> getBackupInfo(String backupPath) async {
    try {
      final file = File(backupPath);

      if (!await file.exists()) {
        throw Exception('Backup file not found at $backupPath');
      }

      final stat = await file.stat();
      final isValid = await verifyBackupIntegrity(backupPath);

      return {
        'filename': path.basename(backupPath),
        'path': backupPath,
        'size': stat.size,
        'modified': stat.modified,
        'created': stat.accessed,
        'isValid': isValid,
      };
    } catch (e) {
      throw Exception('Failed to get backup info: $e');
    }
  }
}
