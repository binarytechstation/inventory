import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/path_helper.dart';
import 'database_schema.dart';

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;
  final PathHelper _pathHelper = PathHelper();

  DatabaseHelper._();

  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dbPath = _pathHelper.getDbPath();
    final dbFile = File(dbPath);
    final isNewDatabase = !await dbFile.exists();

    final db = await openDatabase(
      dbPath,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // If new database, seed with initial admin user
    if (isNewDatabase) {
      await _seedInitialData(db);
    }

    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create all tables
    await db.execute(DatabaseSchema.createUsersTable);
    await db.execute(DatabaseSchema.createProfileTable);
    await db.execute(DatabaseSchema.createSuppliersTable);
    await db.execute(DatabaseSchema.createCustomersTable);
    await db.execute(DatabaseSchema.createProductsTable);
    await db.execute(DatabaseSchema.createProductBatchesTable);
    await db.execute(DatabaseSchema.createTransactionsTable);
    await db.execute(DatabaseSchema.createTransactionLinesTable);
    await db.execute(DatabaseSchema.createHeldBillsTable);
    await db.execute(DatabaseSchema.createHeldBillLinesTable);
    await db.execute(DatabaseSchema.createAuditLogsTable);
    await db.execute(DatabaseSchema.createSettingsTable);
    await db.execute(DatabaseSchema.createRecoveryCodesTable);

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(transaction_date)');
    await db.execute('CREATE INDEX idx_transactions_type ON transactions(transaction_type)');
    await db.execute('CREATE INDEX idx_transaction_lines_transaction ON transaction_lines(transaction_id)');
    await db.execute('CREATE INDEX idx_transaction_lines_product ON transaction_lines(product_id)');
    await db.execute('CREATE INDEX idx_product_batches_product ON product_batches(product_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < 2) {
      // Migration from version 1 to 2
      // Add profile_picture_path column to users table
      await db.execute('ALTER TABLE users ADD COLUMN profile_picture_path TEXT');

      // Check if held_bill_items table exists, if not create it
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='held_bill_items'"
      );

      if (tables.isEmpty) {
        await db.execute(DatabaseSchema.createHeldBillsTable);
        await db.execute(DatabaseSchema.createHeldBillLinesTable);
      }
    }
  }

  Future<void> _seedInitialData(Database db) async {
    // Create default admin user
    // Password will be hashed by auth service, but we need a placeholder here
    // The actual hashing will happen in the auth service
    await db.insert('users', {
      'username': AppConstants.defaultAdminUsername,
      'password_hash': 'TEMP_WILL_BE_SET_BY_AUTH_SERVICE',
      'role': AppConstants.roleAdmin,
      'name': 'Administrator',
      'email': '',
      'phone': '',
      'is_active': 1,
      'must_change_password': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Create default profile
    await db.insert('profile', {
      'company_name': 'My Company',
      'owner_name': 'Administrator',
      'phone': '',
      'email': '',
      'address': '',
      'tax_id': '',
      'logo_path': '',
      'notes': '',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Create default settings
    await db.insert('settings', {
      'key': 'invoice_prefix',
      'value': AppConstants.defaultInvoicePrefix,
    });

    await db.insert('settings', {
      'key': 'invoice_start_number',
      'value': AppConstants.defaultInvoiceStartNumber.toString(),
    });

    await db.insert('settings', {
      'key': 'current_invoice_number',
      'value': AppConstants.defaultInvoiceStartNumber.toString(),
    });
  }

  /// Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Delete database (for testing or reset)
  Future<void> deleteDatabase() async {
    await close();
    final dbPath = _pathHelper.getDbPath();
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
  }

  /// Get database size
  Future<int> getDatabaseSize() async {
    final dbPath = _pathHelper.getDbPath();
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      return await dbFile.length();
    }
    return 0;
  }

  /// Execute raw query
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  /// Execute raw insert/update/delete
  Future<int> rawExecute(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawUpdate(sql, arguments);
  }
}
