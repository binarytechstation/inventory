class DatabaseSchema {
  // Users table
  static const String createUsersTable = '''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL,
      name TEXT NOT NULL,
      email TEXT,
      phone TEXT,
      is_active INTEGER DEFAULT 1,
      must_change_password INTEGER DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      last_login TEXT
    )
  ''';

  // Profile table (company/business info)
  static const String createProfileTable = '''
    CREATE TABLE profile (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      company_name TEXT NOT NULL,
      owner_name TEXT,
      phone TEXT,
      email TEXT,
      address TEXT,
      tax_id TEXT,
      logo_path TEXT,
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  // Suppliers table
  static const String createSuppliersTable = '''
    CREATE TABLE suppliers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      company_name TEXT,
      phone TEXT,
      email TEXT,
      address TEXT,
      tax_id TEXT,
      notes TEXT,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  // Customers table
  static const String createCustomersTable = '''
    CREATE TABLE customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      company_name TEXT,
      phone TEXT,
      email TEXT,
      address TEXT,
      credit_limit REAL DEFAULT 0,
      current_balance REAL DEFAULT 0,
      notes TEXT,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  // Products table
  static const String createProductsTable = '''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      sku TEXT UNIQUE,
      barcode TEXT,
      description TEXT,
      unit TEXT DEFAULT 'piece',
      default_purchase_price REAL DEFAULT 0,
      default_selling_price REAL DEFAULT 0,
      tax_rate REAL DEFAULT 0,
      reorder_level INTEGER DEFAULT 0,
      category TEXT,
      image_path TEXT,
      supplier_id INTEGER,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
    )
  ''';

  // Product batches table (for tracking different purchase prices)
  static const String createProductBatchesTable = '''
    CREATE TABLE product_batches (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      batch_code TEXT,
      purchase_price REAL NOT NULL,
      quantity_added REAL NOT NULL,
      quantity_remaining REAL NOT NULL,
      supplier_id INTEGER,
      purchase_date TEXT NOT NULL,
      notes TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (product_id) REFERENCES products(id),
      FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
    )
  ''';

  // Transactions table (for both purchases and sales)
  static const String createTransactionsTable = '''
    CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_number TEXT UNIQUE NOT NULL,
      transaction_type TEXT NOT NULL,
      transaction_date TEXT NOT NULL,
      party_id INTEGER,
      party_type TEXT,
      party_name TEXT,
      subtotal REAL DEFAULT 0,
      discount_amount REAL DEFAULT 0,
      discount_percentage REAL DEFAULT 0,
      tax_amount REAL DEFAULT 0,
      total_amount REAL NOT NULL,
      payment_mode TEXT NOT NULL,
      status TEXT DEFAULT 'COMPLETED',
      notes TEXT,
      created_by INTEGER,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (created_by) REFERENCES users(id)
    )
  ''';

  // Transaction lines table
  static const String createTransactionLinesTable = '''
    CREATE TABLE transaction_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      batch_id INTEGER,
      quantity REAL NOT NULL,
      unit TEXT,
      unit_price REAL NOT NULL,
      discount_amount REAL DEFAULT 0,
      discount_percentage REAL DEFAULT 0,
      tax_amount REAL DEFAULT 0,
      tax_rate REAL DEFAULT 0,
      line_total REAL NOT NULL,
      notes TEXT,
      FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products(id),
      FOREIGN KEY (batch_id) REFERENCES product_batches(id)
    )
  ''';

  // Held bills table (for incomplete sales)
  static const String createHeldBillsTable = '''
    CREATE TABLE held_bills (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_name TEXT NOT NULL,
      customer_id INTEGER,
      customer_name TEXT,
      subtotal REAL DEFAULT 0,
      discount_amount REAL DEFAULT 0,
      discount_percentage REAL DEFAULT 0,
      tax_amount REAL DEFAULT 0,
      total_amount REAL DEFAULT 0,
      payment_mode TEXT,
      notes TEXT,
      created_by INTEGER,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (customer_id) REFERENCES customers(id),
      FOREIGN KEY (created_by) REFERENCES users(id)
    )
  ''';

  // Held bill lines table
  static const String createHeldBillLinesTable = '''
    CREATE TABLE held_bill_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      held_bill_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit TEXT,
      unit_price REAL NOT NULL,
      discount_amount REAL DEFAULT 0,
      discount_percentage REAL DEFAULT 0,
      tax_amount REAL DEFAULT 0,
      tax_rate REAL DEFAULT 0,
      line_total REAL NOT NULL,
      FOREIGN KEY (held_bill_id) REFERENCES held_bills(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products(id)
    )
  ''';

  // Audit logs table
  static const String createAuditLogsTable = '''
    CREATE TABLE audit_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      username TEXT,
      action TEXT NOT NULL,
      entity_type TEXT,
      entity_id INTEGER,
      details TEXT,
      ip_address TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  ''';

  // Settings table
  static const String createSettingsTable = '''
    CREATE TABLE settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      key TEXT UNIQUE NOT NULL,
      value TEXT,
      description TEXT,
      updated_at TEXT
    )
  ''';

  // Recovery codes table (for password recovery)
  static const String createRecoveryCodesTable = '''
    CREATE TABLE recovery_codes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      recovery_code TEXT NOT NULL,
      recovery_pin TEXT,
      security_question1 TEXT,
      security_answer1 TEXT,
      security_question2 TEXT,
      security_answer2 TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  ''';
}
