import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';

class PathHelper {
  static PathHelper? _instance;
  bool _initialized = false;

  PathHelper._();

  factory PathHelper() {
    _instance ??= PathHelper._();
    return _instance!;
  }

  /// Initialize application paths
  /// On Windows: uses %PROGRAMDATA%\InventoryManagementSystem or %LOCALAPPDATA%\InventoryManagementSystem
  Future<void> initialize() async {
    if (_initialized) return;

    String baseDir;

    if (Platform.isWindows) {
      // Try to use PROGRAMDATA first (for all users), fallback to LOCALAPPDATA (current user)
      final programData = Platform.environment['PROGRAMDATA'];
      if (programData != null) {
        baseDir = path.join(programData, 'InventoryManagementSystem');
      } else {
        final localAppData = Platform.environment['LOCALAPPDATA'];
        if (localAppData != null) {
          baseDir = path.join(localAppData, 'InventoryManagementSystem');
        } else {
          // Fallback to documents directory
          final documentsDir = await getApplicationDocumentsDirectory();
          baseDir = path.join(documentsDir.path, 'InventoryManagementSystem');
        }
      }
    } else if (Platform.isLinux) {
      final homeDir = Platform.environment['HOME'];
      if (homeDir != null) {
        baseDir = path.join(homeDir, '.inventory_management');
      } else {
        final documentsDir = await getApplicationDocumentsDirectory();
        baseDir = path.join(documentsDir.path, 'InventoryManagementSystem');
      }
    } else if (Platform.isMacOS) {
      final appSupport = await getApplicationSupportDirectory();
      baseDir = path.join(appSupport.path, 'InventoryManagementSystem');
    } else {
      throw UnsupportedError('Platform not supported');
    }

    // Create directories if they don't exist
    final baseDirectory = Directory(baseDir);
    if (!await baseDirectory.exists()) {
      await baseDirectory.create(recursive: true);
    }

    final backupDirectory = Directory(path.join(baseDir, AppConstants.backupFolderName));
    if (!await backupDirectory.exists()) {
      await backupDirectory.create(recursive: true);
    }

    // Set paths in AppConstants
    AppConstants.appDataPath = baseDir;
    AppConstants.dbPath = path.join(baseDir, AppConstants.dbFileName);
    AppConstants.licensePath = path.join(baseDir, AppConstants.licenseFileName);
    AppConstants.backupPath = path.join(baseDir, AppConstants.backupFolderName);

    _initialized = true;
  }

  /// Get application data directory path
  String getAppDataPath() {
    if (!_initialized) {
      throw StateError('PathHelper not initialized. Call initialize() first.');
    }
    return AppConstants.appDataPath!;
  }

  /// Get database file path
  String getDbPath() {
    if (!_initialized) {
      throw StateError('PathHelper not initialized. Call initialize() first.');
    }
    return AppConstants.dbPath!;
  }

  /// Get license file path
  String getLicensePath() {
    if (!_initialized) {
      throw StateError('PathHelper not initialized. Call initialize() first.');
    }
    return AppConstants.licensePath!;
  }

  /// Get backup directory path
  String getBackupPath() {
    if (!_initialized) {
      throw StateError('PathHelper not initialized. Call initialize() first.');
    }
    return AppConstants.backupPath!;
  }

  /// Check if database exists
  Future<bool> databaseExists() async {
    final file = File(getDbPath());
    return await file.exists();
  }

  /// Check if license exists
  Future<bool> licenseExists() async {
    final file = File(getLicensePath());
    return await file.exists();
  }
}
