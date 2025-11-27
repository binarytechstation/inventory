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
      profile_picture_path TEXT,
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

  // ============================================================
  // LOT-BASED INVENTORY SYSTEM - NEW SCHEMA
  // ============================================================

  // Lots table - Master table for all incoming inventory lots
  static const String createLotsTable = '''
    CREATE TABLE lots (
      lot_id INTEGER PRIMARY KEY AUTOINCREMENT,
      received_date TEXT NOT NULL,
      description TEXT,
      supplier_id INTEGER,
      reference_number TEXT,
      notes TEXT,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
    )
  ''';

  // Products table - Redesigned with composite primary key
  static const String createProductsTable = '''
    CREATE TABLE products (
      product_id INTEGER NOT NULL,
      lot_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      unit_price REAL NOT NULL,
      selling_price REAL,
      product_image TEXT,
      product_description TEXT,
      unit TEXT DEFAULT 'piece',
      sku TEXT,
      barcode TEXT,
      category TEXT,
      tax_rate REAL DEFAULT 0,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      PRIMARY KEY (product_id, lot_id),
      FOREIGN KEY (lot_id) REFERENCES lots(lot_id) ON DELETE CASCADE
    )
  ''';

  // Stock table - Tracks inventory levels per product per lot
  static const String createStockTable = '''
    CREATE TABLE stock (
      stock_id INTEGER PRIMARY KEY AUTOINCREMENT,
      lot_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      count REAL NOT NULL DEFAULT 0,
      reorder_level REAL DEFAULT 0,
      reserved_quantity REAL DEFAULT 0,
      last_stock_update TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (lot_id) REFERENCES lots(lot_id) ON DELETE CASCADE,
      FOREIGN KEY (product_id, lot_id) REFERENCES products(product_id, lot_id) ON DELETE CASCADE,
      UNIQUE (lot_id, product_id),
      CHECK (count >= 0),
      CHECK (reorder_level >= 0)
    )
  ''';

  // Lot history table - Audit trail for stock movements
  static const String createLotHistoryTable = '''
    CREATE TABLE lot_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      lot_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      action TEXT NOT NULL,
      quantity_change REAL NOT NULL,
      quantity_before REAL NOT NULL,
      quantity_after REAL NOT NULL,
      reference_type TEXT,
      reference_id INTEGER,
      user_id INTEGER,
      notes TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (lot_id) REFERENCES lots(lot_id) ON DELETE CASCADE,
      FOREIGN KEY (product_id, lot_id) REFERENCES products(product_id, lot_id),
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  ''';

  // Product master table (optional) - Catalog of products independent of lots
  static const String createProductMasterTable = '''
    CREATE TABLE product_master (
      product_id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_name TEXT UNIQUE NOT NULL,
      default_unit TEXT DEFAULT 'piece',
      default_category TEXT,
      default_sku_prefix TEXT,
      default_image TEXT,
      default_description TEXT,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  // ============================================================
  // LEGACY TABLES (kept for migration compatibility)
  // ============================================================

  // Product batches table (for tracking different purchase prices)
  // NOTE: This will be migrated to the new lot-based system
  static const String createProductBatchesTable = '''
    CREATE TABLE product_batches_legacy (
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
      FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
    )
  ''';

  // Transactions table (for both purchases and sales)
  // Updated to support lot-based inventory
  static const String createTransactionsTable = '''
    CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_number TEXT UNIQUE NOT NULL,
      transaction_type TEXT NOT NULL,
      transaction_date TEXT NOT NULL,
      lot_id INTEGER,
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
      currency_code TEXT DEFAULT 'BDT',
      currency_symbol TEXT DEFAULT '৳',
      created_by INTEGER,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (lot_id) REFERENCES lots(lot_id),
      FOREIGN KEY (created_by) REFERENCES users(id)
    )
  ''';

  // Transaction lines table
  // Updated to support lot-based inventory with composite foreign key
  static const String createTransactionLinesTable = '''
    CREATE TABLE transaction_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_id INTEGER NOT NULL,
      lot_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit TEXT,
      unit_price REAL NOT NULL,
      total_price REAL NOT NULL,
      discount_amount REAL DEFAULT 0,
      discount_percentage REAL DEFAULT 0,
      tax_amount REAL DEFAULT 0,
      tax_rate REAL DEFAULT 0,
      line_total REAL NOT NULL,
      notes TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
      FOREIGN KEY (lot_id) REFERENCES lots(lot_id),
      FOREIGN KEY (product_id, lot_id) REFERENCES products(product_id, lot_id)
    )
  ''';

  // Held bills table (for incomplete sales and purchases)
  static const String createHeldBillsTable = '''
    CREATE TABLE held_bills (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_name TEXT,
      type TEXT NOT NULL,
      party_id INTEGER,
      party_type TEXT,
      party_name TEXT,
      subtotal REAL DEFAULT 0,
      discount_amount REAL DEFAULT 0,
      tax_amount REAL DEFAULT 0,
      total_amount REAL DEFAULT 0,
      payment_mode TEXT,
      notes TEXT,
      created_by INTEGER,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (created_by) REFERENCES users(id)
    )
  ''';

  // Held bill items table
  static const String createHeldBillLinesTable = '''
    CREATE TABLE held_bill_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      held_bill_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit TEXT,
      unit_price REAL NOT NULL,
      discount_amount REAL DEFAULT 0,
      tax_amount REAL DEFAULT 0,
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

  // Invoice settings table (general invoice configuration)
  static const String createInvoiceSettingsTable = '''
    CREATE TABLE invoice_settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_type TEXT NOT NULL,
      prefix TEXT NOT NULL,
      starting_number INTEGER DEFAULT 1000,
      current_number INTEGER DEFAULT 1000,
      number_format TEXT DEFAULT 'PREFIX-NNNN',
      enable_auto_increment INTEGER DEFAULT 1,
      reset_period TEXT DEFAULT 'NEVER',
      currency_code TEXT DEFAULT 'BDT',
      currency_symbol TEXT DEFAULT '৳',
      default_tax_rate REAL DEFAULT 0,
      enable_tax_by_default INTEGER DEFAULT 1,
      enable_discount_by_default INTEGER DEFAULT 0,
      decimal_places INTEGER DEFAULT 2,
      date_format TEXT DEFAULT 'dd/MM/yyyy',
      time_format TEXT DEFAULT 'HH:mm',
      language TEXT DEFAULT 'en',
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  // Invoice header settings table
  static const String createInvoiceHeaderSettingsTable = '''
    CREATE TABLE invoice_header_settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_type TEXT NOT NULL,
      show_company_logo INTEGER DEFAULT 1,
      logo_path TEXT,
      logo_width INTEGER DEFAULT 150,
      logo_height INTEGER DEFAULT 80,
      logo_position TEXT DEFAULT 'LEFT',
      company_name TEXT,
      company_tagline TEXT,
      show_company_address INTEGER DEFAULT 1,
      company_address TEXT,
      show_company_phone INTEGER DEFAULT 1,
      company_phone TEXT,
      show_company_email INTEGER DEFAULT 1,
      company_email TEXT,
      show_company_website INTEGER DEFAULT 0,
      company_website TEXT,
      show_tax_id INTEGER DEFAULT 1,
      tax_id_label TEXT DEFAULT 'Tax ID',
      tax_id TEXT,
      show_registration_number INTEGER DEFAULT 0,
      registration_number TEXT,
      page_size TEXT DEFAULT 'A4',
      page_orientation TEXT DEFAULT 'PORTRAIT',
      header_alignment TEXT DEFAULT 'LEFT',
      header_background_color TEXT,
      header_text_color TEXT DEFAULT '#000000',
      show_invoice_title INTEGER DEFAULT 1,
      invoice_title TEXT DEFAULT 'INVOICE',
      title_font_size INTEGER DEFAULT 24,
      show_invoice_number INTEGER DEFAULT 1,
      show_invoice_date INTEGER DEFAULT 1,
      show_due_date INTEGER DEFAULT 1,
      custom_field1_label TEXT,
      custom_field1_value TEXT,
      custom_field2_label TEXT,
      custom_field2_value TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  // Invoice footer settings table
  static const String createInvoiceFooterSettingsTable = '''
    CREATE TABLE invoice_footer_settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_type TEXT NOT NULL,
      show_footer_text INTEGER DEFAULT 1,
      footer_text TEXT DEFAULT 'Thank you for your business!',
      footer_font_size INTEGER DEFAULT 10,
      footer_alignment TEXT DEFAULT 'CENTER',
      show_terms_and_conditions INTEGER DEFAULT 1,
      terms_and_conditions TEXT,
      show_payment_instructions INTEGER DEFAULT 1,
      payment_instructions TEXT,
      show_bank_details INTEGER DEFAULT 0,
      bank_name TEXT,
      account_holder_name TEXT,
      account_number TEXT,
      swift_code TEXT,
      iban TEXT,
      show_signature INTEGER DEFAULT 1,
      signature_label TEXT DEFAULT 'Authorized Signature',
      signature_image_path TEXT,
      signature_position TEXT DEFAULT 'RIGHT',
      show_stamp INTEGER DEFAULT 0,
      stamp_image_path TEXT,
      stamp_position TEXT DEFAULT 'LEFT',
      show_page_numbers INTEGER DEFAULT 1,
      page_number_format TEXT DEFAULT 'Page {current} of {total}',
      show_generated_info INTEGER DEFAULT 1,
      generated_info_text TEXT DEFAULT 'Generated on {date} at {time}',
      footer_background_color TEXT,
      footer_text_color TEXT DEFAULT '#666666',
      custom_footer_field1_label TEXT,
      custom_footer_field1_value TEXT,
      custom_footer_field2_label TEXT,
      custom_footer_field2_value TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  // Invoice body settings table
  static const String createInvoiceBodySettingsTable = '''
    CREATE TABLE invoice_body_settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_type TEXT NOT NULL,
      show_party_details INTEGER DEFAULT 1,
      party_label TEXT DEFAULT 'Bill To',
      show_party_name INTEGER DEFAULT 1,
      show_party_company INTEGER DEFAULT 1,
      show_party_address INTEGER DEFAULT 1,
      show_party_phone INTEGER DEFAULT 1,
      show_party_email INTEGER DEFAULT 1,
      show_party_tax_id INTEGER DEFAULT 0,
      show_item_image INTEGER DEFAULT 0,
      show_item_code INTEGER DEFAULT 1,
      show_item_description INTEGER DEFAULT 1,
      show_hsn_code INTEGER DEFAULT 0,
      show_unit_column INTEGER DEFAULT 1,
      show_quantity_column INTEGER DEFAULT 1,
      show_unit_price_column INTEGER DEFAULT 1,
      show_discount_column INTEGER DEFAULT 1,
      show_tax_column INTEGER DEFAULT 1,
      show_amount_column INTEGER DEFAULT 1,
      item_table_headers TEXT DEFAULT '["#","Item","Quantity","Unit Price","Amount"]',
      table_border_style TEXT DEFAULT 'SOLID',
      table_border_color TEXT DEFAULT '#CCCCCC',
      table_header_bg_color TEXT DEFAULT '#F5F5F5',
      table_row_alternate_color TEXT,
      show_subtotal INTEGER DEFAULT 1,
      show_total_discount INTEGER DEFAULT 1,
      show_total_tax INTEGER DEFAULT 1,
      show_shipping_charges INTEGER DEFAULT 0,
      shipping_charges_label TEXT DEFAULT 'Shipping',
      show_other_charges INTEGER DEFAULT 0,
      other_charges_label TEXT DEFAULT 'Other Charges',
      show_grand_total INTEGER DEFAULT 1,
      grand_total_label TEXT DEFAULT 'Grand Total',
      grand_total_font_size INTEGER DEFAULT 16,
      show_amount_in_words INTEGER DEFAULT 1,
      amount_in_words_label TEXT DEFAULT 'Amount in Words',
      show_qr_code INTEGER DEFAULT 0,
      qr_code_content TEXT DEFAULT '{invoice_number}',
      qr_code_size INTEGER DEFAULT 100,
      qr_code_position TEXT DEFAULT 'BOTTOM_RIGHT',
      color_theme TEXT DEFAULT 'DEFAULT',
      custom_body_field1_label TEXT,
      custom_body_field2_label TEXT,
      custom_body_field3_label TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  // Invoice type settings table
  static const String createInvoiceTypeSettingsTable = '''
    CREATE TABLE invoice_type_settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type_code TEXT UNIQUE NOT NULL,
      type_name TEXT NOT NULL,
      description TEXT,
      prefix TEXT NOT NULL,
      title TEXT NOT NULL,
      enable_party_selection INTEGER DEFAULT 1,
      party_label TEXT,
      enable_items INTEGER DEFAULT 1,
      enable_tax_calculation INTEGER DEFAULT 1,
      enable_discount INTEGER DEFAULT 1,
      enable_payment_mode INTEGER DEFAULT 1,
      enable_notes INTEGER DEFAULT 1,
      default_status TEXT DEFAULT 'DRAFT',
      requires_approval INTEGER DEFAULT 0,
      affects_inventory INTEGER DEFAULT 1,
      inventory_effect TEXT,
      show_in_dashboard INTEGER DEFAULT 1,
      icon_name TEXT,
      color_code TEXT,
      template_path TEXT,
      is_active INTEGER DEFAULT 1,
      display_order INTEGER DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  // Invoice print settings table
  static const String createInvoicePrintSettingsTable = '''
    CREATE TABLE invoice_print_settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_type TEXT NOT NULL,
      paper_size TEXT DEFAULT 'A4',
      paper_orientation TEXT DEFAULT 'PORTRAIT',
      layout_type TEXT DEFAULT 'STANDARD',
      print_format TEXT DEFAULT 'PDF',
      printer_name TEXT,
      copies INTEGER DEFAULT 1,
      print_color INTEGER DEFAULT 1,
      print_duplex INTEGER DEFAULT 0,
      margin_top REAL DEFAULT 20.0,
      margin_bottom REAL DEFAULT 20.0,
      margin_left REAL DEFAULT 20.0,
      margin_right REAL DEFAULT 20.0,
      show_watermark INTEGER DEFAULT 0,
      watermark_text TEXT,
      watermark_image_path TEXT,
      watermark_opacity REAL DEFAULT 0.3,
      watermark_rotation INTEGER DEFAULT 45,
      watermark_position TEXT DEFAULT 'CENTER',
      auto_print_on_save INTEGER DEFAULT 0,
      show_print_dialog INTEGER DEFAULT 1,
      compress_pdf INTEGER DEFAULT 1,
      pdf_quality INTEGER DEFAULT 90,
      enable_thermal_print INTEGER DEFAULT 0,
      thermal_width INTEGER DEFAULT 80,
      thermal_paper_length INTEGER DEFAULT 0,
      thermal_font_size INTEGER DEFAULT 10,
      thermal_line_spacing REAL DEFAULT 1.2,
      enable_qr_code INTEGER DEFAULT 0,
      qr_code_content_template TEXT,
      enable_barcode INTEGER DEFAULT 0,
      barcode_content_template TEXT,
      barcode_type TEXT DEFAULT 'CODE128',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  // Invoice activity logs table
  static const String createInvoiceActivityLogsTable = '''
    CREATE TABLE invoice_activity_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id INTEGER NOT NULL,
      invoice_number TEXT NOT NULL,
      invoice_type TEXT NOT NULL,
      action TEXT NOT NULL,
      action_category TEXT,
      user_id INTEGER,
      username TEXT,
      ip_address TEXT,
      device_info TEXT,
      old_values TEXT,
      new_values TEXT,
      changes_summary TEXT,
      session_id TEXT,
      notes TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (invoice_id) REFERENCES transactions(id),
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  ''';
}
