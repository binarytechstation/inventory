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
      version: 3,
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

    // Invoice settings tables
    await db.execute(DatabaseSchema.createInvoiceSettingsTable);
    await db.execute(DatabaseSchema.createInvoiceHeaderSettingsTable);
    await db.execute(DatabaseSchema.createInvoiceFooterSettingsTable);
    await db.execute(DatabaseSchema.createInvoiceBodySettingsTable);
    await db.execute(DatabaseSchema.createInvoiceTypeSettingsTable);
    await db.execute(DatabaseSchema.createInvoicePrintSettingsTable);
    await db.execute(DatabaseSchema.createInvoiceActivityLogsTable);

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(transaction_date)');
    await db.execute('CREATE INDEX idx_transactions_type ON transactions(transaction_type)');
    await db.execute('CREATE INDEX idx_transaction_lines_transaction ON transaction_lines(transaction_id)');
    await db.execute('CREATE INDEX idx_transaction_lines_product ON transaction_lines(product_id)');
    await db.execute('CREATE INDEX idx_product_batches_product ON product_batches(product_id)');
    await db.execute('CREATE INDEX idx_invoice_activity_logs_invoice ON invoice_activity_logs(invoice_id)');
    await db.execute('CREATE INDEX idx_invoice_activity_logs_date ON invoice_activity_logs(created_at)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < 2) {
      // Migration from version 1 to 2

      // Check if profile_picture_path column exists
      final userColumns = await db.rawQuery('PRAGMA table_info(users)');
      final hasProfilePicture = userColumns.any((col) => col['name'] == 'profile_picture_path');

      if (!hasProfilePicture) {
        await db.execute('ALTER TABLE users ADD COLUMN profile_picture_path TEXT');
      }

      // Check if held_bills table exists
      final heldBillsExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='held_bills'"
      );

      if (heldBillsExists.isEmpty) {
        await db.execute(DatabaseSchema.createHeldBillsTable);
      }

      // Check if held_bill_items table exists
      final heldBillItemsExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='held_bill_items'"
      );

      if (heldBillItemsExists.isEmpty) {
        await db.execute(DatabaseSchema.createHeldBillLinesTable);
      }
    }

    if (oldVersion < 3) {
      // Migration from version 2 to 3 - Add invoice settings tables

      // Check if invoice_settings table exists
      final invoiceSettingsExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='invoice_settings'"
      );

      if (invoiceSettingsExists.isEmpty) {
        await db.execute(DatabaseSchema.createInvoiceSettingsTable);
        await db.execute(DatabaseSchema.createInvoiceHeaderSettingsTable);
        await db.execute(DatabaseSchema.createInvoiceFooterSettingsTable);
        await db.execute(DatabaseSchema.createInvoiceBodySettingsTable);
        await db.execute(DatabaseSchema.createInvoiceTypeSettingsTable);
        await db.execute(DatabaseSchema.createInvoicePrintSettingsTable);
        await db.execute(DatabaseSchema.createInvoiceActivityLogsTable);

        // Create indexes
        await db.execute('CREATE INDEX idx_invoice_activity_logs_invoice ON invoice_activity_logs(invoice_id)');
        await db.execute('CREATE INDEX idx_invoice_activity_logs_date ON invoice_activity_logs(created_at)');

        // Seed default invoice type settings
        await _seedInvoiceTypeSettings(db);
      }
    }
  }

  Future<void> _seedInvoiceTypeSettings(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Default invoice types
    final invoiceTypes = [
      {
        'type_code': 'SALE',
        'type_name': 'Sales Invoice',
        'description': 'Invoice for product sales',
        'prefix': 'INV',
        'title': 'SALES INVOICE',
        'enable_party_selection': 1,
        'party_label': 'Customer',
        'enable_items': 1,
        'enable_tax_calculation': 1,
        'enable_discount': 1,
        'enable_payment_mode': 1,
        'enable_notes': 1,
        'default_status': 'COMPLETED',
        'requires_approval': 0,
        'affects_inventory': 1,
        'inventory_effect': 'DECREASE',
        'show_in_dashboard': 1,
        'icon_name': 'receipt',
        'color_code': '#4CAF50',
        'is_active': 1,
        'display_order': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'type_code': 'PURCHASE',
        'type_name': 'Purchase Invoice',
        'description': 'Invoice for product purchases',
        'prefix': 'PUR',
        'title': 'PURCHASE INVOICE',
        'enable_party_selection': 1,
        'party_label': 'Supplier',
        'enable_items': 1,
        'enable_tax_calculation': 1,
        'enable_discount': 1,
        'enable_payment_mode': 1,
        'enable_notes': 1,
        'default_status': 'COMPLETED',
        'requires_approval': 0,
        'affects_inventory': 1,
        'inventory_effect': 'INCREASE',
        'show_in_dashboard': 1,
        'icon_name': 'shopping_cart',
        'color_code': '#2196F3',
        'is_active': 1,
        'display_order': 2,
        'created_at': now,
        'updated_at': now,
      },
      {
        'type_code': 'QUOTATION',
        'type_name': 'Quotation',
        'description': 'Price quotation for customers',
        'prefix': 'QUO',
        'title': 'QUOTATION',
        'enable_party_selection': 1,
        'party_label': 'Customer',
        'enable_items': 1,
        'enable_tax_calculation': 1,
        'enable_discount': 1,
        'enable_payment_mode': 0,
        'enable_notes': 1,
        'default_status': 'DRAFT',
        'requires_approval': 0,
        'affects_inventory': 0,
        'inventory_effect': 'NONE',
        'show_in_dashboard': 1,
        'icon_name': 'description',
        'color_code': '#FF9800',
        'is_active': 1,
        'display_order': 3,
        'created_at': now,
        'updated_at': now,
      },
      {
        'type_code': 'RETURN_SALE',
        'type_name': 'Sales Return',
        'description': 'Return invoice for sold products',
        'prefix': 'SRT',
        'title': 'SALES RETURN',
        'enable_party_selection': 1,
        'party_label': 'Customer',
        'enable_items': 1,
        'enable_tax_calculation': 1,
        'enable_discount': 0,
        'enable_payment_mode': 1,
        'enable_notes': 1,
        'default_status': 'COMPLETED',
        'requires_approval': 1,
        'affects_inventory': 1,
        'inventory_effect': 'INCREASE',
        'show_in_dashboard': 1,
        'icon_name': 'undo',
        'color_code': '#F44336',
        'is_active': 1,
        'display_order': 4,
        'created_at': now,
        'updated_at': now,
      },
      {
        'type_code': 'RETURN_PURCHASE',
        'type_name': 'Purchase Return',
        'description': 'Return invoice for purchased products',
        'prefix': 'PRT',
        'title': 'PURCHASE RETURN',
        'enable_party_selection': 1,
        'party_label': 'Supplier',
        'enable_items': 1,
        'enable_tax_calculation': 1,
        'enable_discount': 0,
        'enable_payment_mode': 1,
        'enable_notes': 1,
        'default_status': 'COMPLETED',
        'requires_approval': 1,
        'affects_inventory': 1,
        'inventory_effect': 'DECREASE',
        'show_in_dashboard': 1,
        'icon_name': 'reply',
        'color_code': '#E91E63',
        'is_active': 1,
        'display_order': 5,
        'created_at': now,
        'updated_at': now,
      },
      {
        'type_code': 'DELIVERY_CHALLAN',
        'type_name': 'Delivery Challan',
        'description': 'Delivery note for products',
        'prefix': 'DC',
        'title': 'DELIVERY CHALLAN',
        'enable_party_selection': 1,
        'party_label': 'Customer',
        'enable_items': 1,
        'enable_tax_calculation': 0,
        'enable_discount': 0,
        'enable_payment_mode': 0,
        'enable_notes': 1,
        'default_status': 'DRAFT',
        'requires_approval': 0,
        'affects_inventory': 0,
        'inventory_effect': 'NONE',
        'show_in_dashboard': 0,
        'icon_name': 'local_shipping',
        'color_code': '#9C27B0',
        'is_active': 1,
        'display_order': 6,
        'created_at': now,
        'updated_at': now,
      },
    ];

    for (final type in invoiceTypes) {
      await db.insert('invoice_type_settings', type);
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
