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
      version: 6,
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

    // Lot-based inventory tables (NEW)
    await db.execute(DatabaseSchema.createLotsTable);
    await db.execute(DatabaseSchema.createProductsTable);
    await db.execute(DatabaseSchema.createStockTable);
    await db.execute(DatabaseSchema.createLotHistoryTable);
    await db.execute(DatabaseSchema.createProductMasterTable);

    // Legacy tables (for backward compatibility)
    await db.execute(DatabaseSchema.createProductBatchesTable);

    // Transaction tables
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
    // Lot-based inventory indexes
    await db.execute('CREATE INDEX idx_lots_received_date ON lots(received_date)');
    await db.execute('CREATE INDEX idx_lots_supplier ON lots(supplier_id)');
    await db.execute('CREATE INDEX idx_lots_active ON lots(is_active)');
    await db.execute('CREATE INDEX idx_products_lot ON products(lot_id)');
    await db.execute('CREATE INDEX idx_products_composite ON products(product_id, lot_id)');
    await db.execute('CREATE INDEX idx_products_name ON products(product_name)');
    await db.execute('CREATE INDEX idx_products_active ON products(is_active)');
    await db.execute('CREATE INDEX idx_stock_lot ON stock(lot_id)');
    await db.execute('CREATE INDEX idx_stock_product ON stock(product_id)');
    await db.execute('CREATE INDEX idx_stock_composite ON stock(product_id, lot_id)');
    await db.execute('CREATE INDEX idx_stock_low ON stock(count, reorder_level) WHERE count <= reorder_level');
    await db.execute('CREATE INDEX idx_lot_history_lot ON lot_history(lot_id)');
    await db.execute('CREATE INDEX idx_lot_history_product ON lot_history(product_id)');
    await db.execute('CREATE INDEX idx_lot_history_date ON lot_history(created_at)');
    await db.execute('CREATE INDEX idx_product_master_name ON product_master(product_name)');
    await db.execute('CREATE INDEX idx_product_master_active ON product_master(is_active)');

    // Transaction indexes
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(transaction_date)');
    await db.execute('CREATE INDEX idx_transactions_type ON transactions(transaction_type)');
    await db.execute('CREATE INDEX idx_transactions_lot ON transactions(lot_id)');
    await db.execute('CREATE INDEX idx_transaction_lines_transaction ON transaction_lines(transaction_id)');
    await db.execute('CREATE INDEX idx_transaction_lines_lot ON transaction_lines(lot_id)');
    await db.execute('CREATE INDEX idx_transaction_lines_product ON transaction_lines(product_id)');
    await db.execute('CREATE INDEX idx_transaction_lines_composite ON transaction_lines(product_id, lot_id)');
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

    if (oldVersion < 4) {
      // Migration from version 3 to 4 - Update currency to Taka (BDT)
      await db.execute('''
        UPDATE invoice_settings
        SET currency_code = 'BDT', currency_symbol = '৳'
        WHERE currency_code = 'USD' OR currency_symbol = '\$'
      ''');
    }

    if (oldVersion < 5) {
      // Migration from version 4 to 5 - Add currency fields to transactions
      final transactionColumns = await db.rawQuery('PRAGMA table_info(transactions)');
      final hasCurrencyCode = transactionColumns.any((col) => col['name'] == 'currency_code');
      final hasCurrencySymbol = transactionColumns.any((col) => col['name'] == 'currency_symbol');

      if (!hasCurrencyCode) {
        await db.execute('ALTER TABLE transactions ADD COLUMN currency_code TEXT DEFAULT \'BDT\'');
      }

      if (!hasCurrencySymbol) {
        await db.execute('ALTER TABLE transactions ADD COLUMN currency_symbol TEXT DEFAULT \'৳\'');
      }

      // Update existing transactions to have the current currency from invoice_settings
      final currencyResult = await db.query(
        'invoice_settings',
        columns: ['currency_code', 'currency_symbol'],
        where: 'invoice_type = ?',
        whereArgs: ['SALE'],
        limit: 1,
      );

      if (currencyResult.isNotEmpty) {
        final currencyCode = currencyResult.first['currency_code'] ?? 'BDT';
        final currencySymbol = currencyResult.first['currency_symbol'] ?? '৳';

        await db.execute('''
          UPDATE transactions
          SET currency_code = ?, currency_symbol = ?
          WHERE currency_code IS NULL OR currency_symbol IS NULL
        ''', [currencyCode, currencySymbol]);
      }
    }

    if (oldVersion < 6) {
      // Migration from version 5 to 6 - LOT-BASED INVENTORY SYSTEM
      print('Migrating to lot-based inventory system (v6)...');

      // Step 1: Rename old products table
      await db.execute('ALTER TABLE products RENAME TO products_old');

      // Step 2: Rename old product_batches table
      final batchesExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='product_batches'"
      );
      if (batchesExists.isNotEmpty) {
        await db.execute('ALTER TABLE product_batches RENAME TO product_batches_old');
      }

      // Step 3: Create new lot-based tables
      await db.execute(DatabaseSchema.createLotsTable);
      await db.execute(DatabaseSchema.createProductsTable);
      await db.execute(DatabaseSchema.createStockTable);
      await db.execute(DatabaseSchema.createLotHistoryTable);
      await db.execute(DatabaseSchema.createProductMasterTable);
      await db.execute(DatabaseSchema.createProductBatchesTable); // Legacy table

      // Step 4: Create indexes for new tables
      await db.execute('CREATE INDEX idx_lots_received_date ON lots(received_date)');
      await db.execute('CREATE INDEX idx_lots_supplier ON lots(supplier_id)');
      await db.execute('CREATE INDEX idx_lots_active ON lots(is_active)');
      await db.execute('CREATE INDEX idx_products_lot ON products(lot_id)');
      await db.execute('CREATE INDEX idx_products_composite ON products(product_id, lot_id)');
      await db.execute('CREATE INDEX idx_products_name ON products(product_name)');
      await db.execute('CREATE INDEX idx_products_active ON products(is_active)');
      await db.execute('CREATE INDEX idx_stock_lot ON stock(lot_id)');
      await db.execute('CREATE INDEX idx_stock_product ON stock(product_id)');
      await db.execute('CREATE INDEX idx_stock_composite ON stock(product_id, lot_id)');
      await db.execute('CREATE INDEX idx_stock_low ON stock(count, reorder_level) WHERE count <= reorder_level');
      await db.execute('CREATE INDEX idx_lot_history_lot ON lot_history(lot_id)');
      await db.execute('CREATE INDEX idx_lot_history_product ON lot_history(product_id)');
      await db.execute('CREATE INDEX idx_lot_history_date ON lot_history(created_at)');
      await db.execute('CREATE INDEX idx_product_master_name ON product_master(product_name)');
      await db.execute('CREATE INDEX idx_product_master_active ON product_master(is_active)');

      // Step 5: Migrate data from old schema to new schema
      final now = DateTime.now().toIso8601String();

      // 5a: Migrate product_batches to lots
      final oldBatches = await db.query('product_batches_old');
      for (final batch in oldBatches) {
        await db.insert('lots', {
          'lot_id': batch['id'],
          'received_date': batch['purchase_date'] ?? now,
          'description': batch['notes'] ?? 'Migrated from old system',
          'supplier_id': batch['supplier_id'],
          'reference_number': batch['batch_code'],
          'is_active': 1,
          'created_at': batch['created_at'] ?? now,
          'updated_at': now,
        });
      }

      // 5b: Migrate products to product_master (catalog)
      final oldProducts = await db.query('products_old');
      for (final product in oldProducts) {
        try {
          await db.insert('product_master', {
            'product_id': product['id'],
            'product_name': product['name'],
            'default_unit': product['unit'] ?? 'piece',
            'default_category': product['category'],
            'default_sku_prefix': product['sku'],
            'default_image': product['image_path'],
            'default_description': product['description'],
            'is_active': product['is_active'] ?? 1,
            'created_at': product['created_at'] ?? now,
            'updated_at': now,
          });
        } catch (e) {
          print('Error migrating product ${product['id']}: $e');
        }
      }

      // 5c: Create products in lots from product_batches
      for (final batch in oldBatches) {
        final productId = batch['product_id'];
        final lotId = batch['id'];

        // Get product details from products_old
        final productList = await db.query(
          'products_old',
          where: 'id = ?',
          whereArgs: [productId],
          limit: 1,
        );

        if (productList.isNotEmpty) {
          final product = productList.first;

          await db.insert('products', {
            'product_id': productId,
            'lot_id': lotId,
            'product_name': product['name'],
            'unit_price': batch['purchase_price'] ?? 0,
            'product_image': product['image_path'],
            'product_description': product['description'],
            'unit': product['unit'] ?? 'piece',
            'sku': product['sku'],
            'barcode': product['barcode'],
            'category': product['category'],
            'tax_rate': product['tax_rate'] ?? 0,
            'is_active': product['is_active'] ?? 1,
            'created_at': batch['created_at'] ?? now,
            'updated_at': now,
          });

          // Create stock record
          await db.insert('stock', {
            'lot_id': lotId,
            'product_id': productId,
            'count': batch['quantity_remaining'] ?? 0,
            'reorder_level': product['reorder_level'] ?? 0,
            'reserved_quantity': 0,
            'last_stock_update': now,
            'created_at': batch['created_at'] ?? now,
            'updated_at': now,
          });

          // Create initial history record
          await db.insert('lot_history', {
            'lot_id': lotId,
            'product_id': productId,
            'action': 'MIGRATION',
            'quantity_change': batch['quantity_remaining'] ?? 0,
            'quantity_before': 0,
            'quantity_after': batch['quantity_remaining'] ?? 0,
            'reference_type': 'MIGRATION',
            'reference_id': null,
            'user_id': null,
            'notes': 'Migrated from old inventory system',
            'created_at': now,
          });
        }
      }

      // Step 6: Update transactions and transaction_lines to include lot_id
      // Add lot_id column to transactions
      await db.execute('ALTER TABLE transactions ADD COLUMN lot_id INTEGER');

      // Rename old transaction_lines table
      await db.execute('ALTER TABLE transaction_lines RENAME TO transaction_lines_old');

      // Create new transaction_lines table
      await db.execute(DatabaseSchema.createTransactionLinesTable);

      // Create indexes
      await db.execute('CREATE INDEX idx_transactions_lot ON transactions(lot_id)');
      await db.execute('CREATE INDEX idx_transaction_lines_lot ON transaction_lines(lot_id)');
      await db.execute('CREATE INDEX idx_transaction_lines_composite ON transaction_lines(product_id, lot_id)');

      // Migrate transaction_lines data
      final oldTxLines = await db.query('transaction_lines_old');
      for (final line in oldTxLines) {
        // Try to find the lot_id from batch_id if available
        int? lotId;
        if (line['batch_id'] != null) {
          lotId = line['batch_id'] as int?;
        } else {
          // Find first available lot for this product
          final stockList = await db.query(
            'stock',
            where: 'product_id = ?',
            whereArgs: [line['product_id']],
            limit: 1,
          );
          if (stockList.isNotEmpty) {
            lotId = stockList.first['lot_id'] as int?;
          }
        }

        if (lotId != null) {
          await db.insert('transaction_lines', {
            'id': line['id'],
            'transaction_id': line['transaction_id'],
            'lot_id': lotId,
            'product_id': line['product_id'],
            'product_name': line['product_name'],
            'quantity': line['quantity'],
            'unit': line['unit'],
            'unit_price': line['unit_price'],
            'total_price': (line['quantity'] as num) * (line['unit_price'] as num),
            'discount_amount': line['discount_amount'] ?? 0,
            'discount_percentage': line['discount_percentage'] ?? 0,
            'tax_amount': line['tax_amount'] ?? 0,
            'tax_rate': line['tax_rate'] ?? 0,
            'line_total': line['line_total'],
            'notes': line['notes'],
            'created_at': now,
          });
        }
      }

      // Step 7: Drop old tables (optional - keep for safety)
      // await db.execute('DROP TABLE IF EXISTS products_old');
      // await db.execute('DROP TABLE IF EXISTS product_batches_old');
      // await db.execute('DROP TABLE IF EXISTS transaction_lines_old');

      print('Migration to lot-based inventory system complete!');
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
