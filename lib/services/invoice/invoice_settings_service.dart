import '../../data/database/database_helper.dart';

class InvoiceSettingsService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ==================== General Invoice Settings ====================

  /// Get invoice settings for a specific type
  Future<Map<String, dynamic>?> getInvoiceSettings(String invoiceType) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'invoice_settings',
      where: 'invoice_type = ?',
      whereArgs: [invoiceType],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Create or update invoice settings
  Future<int> saveInvoiceSettings(Map<String, dynamic> settings) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final existing = await getInvoiceSettings(settings['invoice_type']);

    if (existing != null) {
      return await db.update(
        'invoice_settings',
        {...settings, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
    } else {
      return await db.insert('invoice_settings', {
        ...settings,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  /// Generate next invoice number
  Future<String> generateInvoiceNumber(String invoiceType) async {
    final db = await _dbHelper.database;
    final settings = await getInvoiceSettings(invoiceType);

    if (settings == null) {
      throw Exception('Invoice settings not found for type: $invoiceType');
    }

    final prefix = settings['prefix'] as String;
    final currentNumber = settings['current_number'] as int;
    final numberFormat = settings['number_format'] as String;

    // Generate invoice number based on format
    String invoiceNumber = numberFormat
        .replaceAll('PREFIX', prefix)
        .replaceAll('NNNN', currentNumber.toString().padLeft(4, '0'))
        .replaceAll('NNN', currentNumber.toString().padLeft(3, '0'))
        .replaceAll('NN', currentNumber.toString().padLeft(2, '0'));

    // Increment current number if auto-increment is enabled
    if (settings['enable_auto_increment'] == 1) {
      await db.update(
        'invoice_settings',
        {'current_number': currentNumber + 1},
        where: 'id = ?',
        whereArgs: [settings['id']],
      );
    }

    return invoiceNumber;
  }

  // ==================== Invoice Header Settings ====================

  /// Get invoice header settings
  Future<Map<String, dynamic>?> getHeaderSettings(String invoiceType) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'invoice_header_settings',
      where: 'invoice_type = ?',
      whereArgs: [invoiceType],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Save invoice header settings
  Future<int> saveHeaderSettings(Map<String, dynamic> settings) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final existing = await getHeaderSettings(settings['invoice_type']);

    if (existing != null) {
      return await db.update(
        'invoice_header_settings',
        {...settings, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
    } else {
      return await db.insert('invoice_header_settings', {
        ...settings,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  // ==================== Invoice Footer Settings ====================

  /// Get invoice footer settings
  Future<Map<String, dynamic>?> getFooterSettings(String invoiceType) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'invoice_footer_settings',
      where: 'invoice_type = ?',
      whereArgs: [invoiceType],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Save invoice footer settings
  Future<int> saveFooterSettings(Map<String, dynamic> settings) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final existing = await getFooterSettings(settings['invoice_type']);

    if (existing != null) {
      return await db.update(
        'invoice_footer_settings',
        {...settings, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
    } else {
      return await db.insert('invoice_footer_settings', {
        ...settings,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  // ==================== Invoice Body Settings ====================

  /// Get invoice body settings
  Future<Map<String, dynamic>?> getBodySettings(String invoiceType) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'invoice_body_settings',
      where: 'invoice_type = ?',
      whereArgs: [invoiceType],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Save invoice body settings
  Future<int> saveBodySettings(Map<String, dynamic> settings) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final existing = await getBodySettings(settings['invoice_type']);

    if (existing != null) {
      return await db.update(
        'invoice_body_settings',
        {...settings, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
    } else {
      return await db.insert('invoice_body_settings', {
        ...settings,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  // ==================== Invoice Type Settings ====================

  /// Get all invoice types
  Future<List<Map<String, dynamic>>> getAllInvoiceTypes() async {
    final db = await _dbHelper.database;
    return await db.query(
      'invoice_type_settings',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'display_order ASC',
    );
  }

  /// Get invoice type by code
  Future<Map<String, dynamic>?> getInvoiceType(String typeCode) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'invoice_type_settings',
      where: 'type_code = ?',
      whereArgs: [typeCode],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Save invoice type settings
  Future<int> saveInvoiceType(Map<String, dynamic> typeSettings) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final existing = await getInvoiceType(typeSettings['type_code']);

    if (existing != null) {
      return await db.update(
        'invoice_type_settings',
        {...typeSettings, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
    } else {
      return await db.insert('invoice_type_settings', {
        ...typeSettings,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  // ==================== Invoice Print Settings ====================

  /// Get invoice print settings
  Future<Map<String, dynamic>?> getPrintSettings(String invoiceType) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'invoice_print_settings',
      where: 'invoice_type = ?',
      whereArgs: [invoiceType],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Save invoice print settings
  Future<int> savePrintSettings(Map<String, dynamic> settings) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final existing = await getPrintSettings(settings['invoice_type']);

    if (existing != null) {
      return await db.update(
        'invoice_print_settings',
        {...settings, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
    } else {
      return await db.insert('invoice_print_settings', {
        ...settings,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  // ==================== Invoice Activity Logs ====================

  /// Log invoice activity
  Future<int> logActivity({
    required int invoiceId,
    required String invoiceNumber,
    required String invoiceType,
    required String action,
    String? actionCategory,
    int? userId,
    String? username,
    String? ipAddress,
    String? deviceInfo,
    String? oldValues,
    String? newValues,
    String? changesSummary,
    String? sessionId,
    String? notes,
  }) async {
    final db = await _dbHelper.database;

    return await db.insert('invoice_activity_logs', {
      'invoice_id': invoiceId,
      'invoice_number': invoiceNumber,
      'invoice_type': invoiceType,
      'action': action,
      'action_category': actionCategory,
      'user_id': userId,
      'username': username,
      'ip_address': ipAddress,
      'device_info': deviceInfo,
      'old_values': oldValues,
      'new_values': newValues,
      'changes_summary': changesSummary,
      'session_id': sessionId,
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get activity logs for an invoice
  Future<List<Map<String, dynamic>>> getInvoiceActivityLogs(
    int invoiceId, {
    int limit = 50,
  }) async {
    final db = await _dbHelper.database;
    return await db.query(
      'invoice_activity_logs',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  /// Get activity logs with filters
  Future<List<Map<String, dynamic>>> getActivityLogs({
    String? invoiceType,
    String? action,
    int? userId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    final db = await _dbHelper.database;

    String whereClause = '1=1';
    final whereArgs = <dynamic>[];

    if (invoiceType != null) {
      whereClause += ' AND invoice_type = ?';
      whereArgs.add(invoiceType);
    }

    if (action != null) {
      whereClause += ' AND action = ?';
      whereArgs.add(action);
    }

    if (userId != null) {
      whereClause += ' AND user_id = ?';
      whereArgs.add(userId);
    }

    if (startDate != null) {
      whereClause += ' AND created_at >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClause += ' AND created_at <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    return await db.query(
      'invoice_activity_logs',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  /// Get activity summary by action
  Future<List<Map<String, dynamic>>> getActivitySummaryByAction() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT
        action,
        action_category,
        COUNT(*) as count,
        MAX(created_at) as last_action_date
      FROM invoice_activity_logs
      GROUP BY action, action_category
      ORDER BY count DESC
    ''');
  }

  /// Get activity summary by invoice type
  Future<List<Map<String, dynamic>>> getActivitySummaryByType() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT
        invoice_type,
        COUNT(*) as count,
        COUNT(DISTINCT invoice_id) as unique_invoices,
        MAX(created_at) as last_action_date
      FROM invoice_activity_logs
      GROUP BY invoice_type
      ORDER BY count DESC
    ''');
  }

  /// Delete old activity logs
  Future<int> deleteOldActivityLogs(int daysToKeep) async {
    final db = await _dbHelper.database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

    return await db.delete(
      'invoice_activity_logs',
      where: 'created_at < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  // ==================== Complete Invoice Configuration ====================

  /// Get complete invoice configuration for a type
  Future<Map<String, dynamic>> getCompleteInvoiceConfig(String invoiceType) async {
    final generalSettings = await getInvoiceSettings(invoiceType);
    final headerSettings = await getHeaderSettings(invoiceType);
    final footerSettings = await getFooterSettings(invoiceType);
    final bodySettings = await getBodySettings(invoiceType);
    final printSettings = await getPrintSettings(invoiceType);
    final typeInfo = await getInvoiceType(invoiceType);

    return {
      'general': generalSettings ?? {},
      'header': headerSettings ?? {},
      'footer': footerSettings ?? {},
      'body': bodySettings ?? {},
      'print': printSettings ?? {},
      'type_info': typeInfo ?? {},
    };
  }

  /// Initialize default settings for an invoice type
  Future<void> initializeDefaultSettings(String invoiceType) async {
    final now = DateTime.now().toIso8601String();

    // Check if settings already exist
    final existing = await getInvoiceSettings(invoiceType);
    if (existing != null) return;

    final db = await _dbHelper.database;

    // Create default general settings
    await db.insert('invoice_settings', {
      'invoice_type': invoiceType,
      'prefix': invoiceType == 'SALE' ? 'INV' : 'PUR',
      'starting_number': 1000,
      'current_number': 1000,
      'number_format': 'PREFIX-NNNN',
      'enable_auto_increment': 1,
      'reset_period': 'NEVER',
      'currency_code': 'USD',
      'currency_symbol': '\$',
      'default_tax_rate': 0,
      'enable_tax_by_default': 1,
      'enable_discount_by_default': 0,
      'decimal_places': 2,
      'date_format': 'dd/MM/yyyy',
      'time_format': 'HH:mm',
      'language': 'en',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    // Create default header settings
    await db.insert('invoice_header_settings', {
      'invoice_type': invoiceType,
      'show_company_logo': 1,
      'logo_width': 150,
      'logo_height': 80,
      'logo_position': 'LEFT',
      'show_company_address': 1,
      'show_company_phone': 1,
      'show_company_email': 1,
      'show_tax_id': 1,
      'tax_id_label': 'Tax ID',
      'page_size': 'A4',
      'page_orientation': 'PORTRAIT',
      'header_alignment': 'LEFT',
      'header_text_color': '#000000',
      'show_invoice_title': 1,
      'invoice_title': 'INVOICE',
      'title_font_size': 24,
      'show_invoice_number': 1,
      'show_invoice_date': 1,
      'show_due_date': 1,
      'created_at': now,
      'updated_at': now,
    });

    // Create default footer settings
    await db.insert('invoice_footer_settings', {
      'invoice_type': invoiceType,
      'show_footer_text': 1,
      'footer_text': 'Thank you for your business!',
      'footer_font_size': 10,
      'footer_alignment': 'CENTER',
      'show_terms_and_conditions': 1,
      'show_signature': 1,
      'signature_label': 'Authorized Signature',
      'signature_position': 'RIGHT',
      'show_page_numbers': 1,
      'page_number_format': 'Page {current} of {total}',
      'show_generated_info': 1,
      'generated_info_text': 'Generated on {date} at {time}',
      'footer_text_color': '#666666',
      'created_at': now,
      'updated_at': now,
    });

    // Create default body settings
    await db.insert('invoice_body_settings', {
      'invoice_type': invoiceType,
      'show_party_details': 1,
      'party_label': invoiceType == 'SALE' ? 'Bill To' : 'Supplier',
      'show_party_name': 1,
      'show_party_company': 1,
      'show_party_address': 1,
      'show_party_phone': 1,
      'show_party_email': 1,
      'show_item_code': 1,
      'show_item_description': 1,
      'show_unit_column': 1,
      'show_quantity_column': 1,
      'show_unit_price_column': 1,
      'show_discount_column': 1,
      'show_tax_column': 1,
      'show_amount_column': 1,
      'item_table_headers': '["#","Item","Quantity","Unit Price","Amount"]',
      'table_border_style': 'SOLID',
      'table_border_color': '#CCCCCC',
      'table_header_bg_color': '#F5F5F5',
      'show_subtotal': 1,
      'show_total_discount': 1,
      'show_total_tax': 1,
      'show_grand_total': 1,
      'grand_total_label': 'Grand Total',
      'grand_total_font_size': 16,
      'show_amount_in_words': 1,
      'amount_in_words_label': 'Amount in Words',
      'color_theme': 'DEFAULT',
      'created_at': now,
      'updated_at': now,
    });

    // Create default print settings
    await db.insert('invoice_print_settings', {
      'invoice_type': invoiceType,
      'paper_size': 'A4',
      'paper_orientation': 'PORTRAIT',
      'layout_type': 'STANDARD',
      'print_format': 'PDF',
      'copies': 1,
      'print_color': 1,
      'margin_top': 20.0,
      'margin_bottom': 20.0,
      'margin_left': 20.0,
      'margin_right': 20.0,
      'show_print_dialog': 1,
      'compress_pdf': 1,
      'pdf_quality': 90,
      'created_at': now,
      'updated_at': now,
    });
  }
}
