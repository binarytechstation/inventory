import '../../data/database/database_helper.dart';

class HeldBillsService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Create a held bill (draft transaction)
  Future<int> createHeldBill({
    required String type, // 'SELL' or 'BUY'
    required int partyId,
    required String partyType,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
    String? notes,
    String? billName,
  }) async {
    final db = await _dbHelper.database;

    // Get party name
    String? partyName;
    if (partyType == 'customer') {
      final customers = await db.query('customers', where: 'id = ?', whereArgs: [partyId]);
      partyName = customers.isNotEmpty ? customers.first['name'] as String? : null;
    } else {
      final suppliers = await db.query('suppliers', where: 'id = ?', whereArgs: [partyId]);
      partyName = suppliers.isNotEmpty ? suppliers.first['name'] as String? : null;
    }

    final heldBillId = await db.insert('held_bills', {
      'type': type,
      'party_id': partyId,
      'party_type': partyType,
      'party_name': partyName,
      'subtotal': subtotal,
      'discount_amount': discount,
      'tax_amount': tax,
      'total_amount': total,
      'notes': notes,
      'bill_name': billName ?? 'Held Bill #${DateTime.now().millisecondsSinceEpoch}',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Insert held bill items
    for (final item in items) {
      // Get product details
      final products = await db.query('products', where: 'id = ?', whereArgs: [item['product_id']]);
      final productName = products.isNotEmpty ? products.first['name'] as String : 'Unknown';
      final productUnit = products.isNotEmpty ? products.first['unit'] as String? : 'piece';

      await db.insert('held_bill_items', {
        'held_bill_id': heldBillId,
        'product_id': item['product_id'],
        'product_name': productName,
        'quantity': item['quantity'],
        'unit': productUnit,
        'unit_price': item['unit_price'],
        'discount_amount': item['discount'] ?? 0,
        'tax_amount': item['tax'] ?? 0,
        'line_total': item['subtotal'],
      });
    }

    return heldBillId;
  }

  /// Get all held bills
  Future<List<Map<String, dynamic>>> getAllHeldBills({
    String? type,
    String sortBy = 'created_at',
    String sortOrder = 'DESC',
  }) async {
    final db = await _dbHelper.database;

    final whereConditions = <String>[];
    final whereArgs = <dynamic>[];

    if (type != null) {
      whereConditions.add('type = ?');
      whereArgs.add(type);
    }

    final whereClause = whereConditions.isNotEmpty ? whereConditions.join(' AND ') : null;

    final heldBills = await db.query(
      'held_bills',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: '$sortBy $sortOrder',
    );

    // Enrich with party information
    final enrichedBills = <Map<String, dynamic>>[];

    for (final bill in heldBills) {
      final enrichedBill = Map<String, dynamic>.from(bill);

      // Get party details
      final partyType = bill['party_type'] as String;
      final partyId = bill['party_id'] as int;

      if (partyType == 'customer') {
        final customers = await db.query(
          'customers',
          where: 'id = ?',
          whereArgs: [partyId],
          limit: 1,
        );
        enrichedBill['party'] = customers.isNotEmpty ? customers.first : null;
      } else {
        final suppliers = await db.query(
          'suppliers',
          where: 'id = ?',
          whereArgs: [partyId],
          limit: 1,
        );
        enrichedBill['party'] = suppliers.isNotEmpty ? suppliers.first : null;
      }

      // Get item count
      final itemCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM held_bill_items WHERE held_bill_id = ?',
        [bill['id']],
      );
      enrichedBill['item_count'] = (itemCount.first['count'] as int?) ?? 0;

      enrichedBills.add(enrichedBill);
    }

    return enrichedBills;
  }

  /// Get held bill by ID with all details
  Future<Map<String, dynamic>?> getHeldBillById(int id) async {
    final db = await _dbHelper.database;

    final heldBills = await db.query(
      'held_bills',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (heldBills.isEmpty) return null;

    final heldBill = Map<String, dynamic>.from(heldBills.first);

    // Get held bill items
    final items = await db.rawQuery('''
      SELECT
        hbi.*,
        p.name as product_name,
        p.sku as product_sku,
        p.unit as product_unit
      FROM held_bill_items hbi
      JOIN products p ON hbi.product_id = p.id
      WHERE hbi.held_bill_id = ?
    ''', [id]);

    heldBill['items'] = items;

    // Get party details
    final partyType = heldBill['party_type'] as String;
    final partyId = heldBill['party_id'] as int;

    if (partyType == 'customer') {
      final customers = await db.query(
        'customers',
        where: 'id = ?',
        whereArgs: [partyId],
        limit: 1,
      );
      heldBill['party'] = customers.isNotEmpty ? customers.first : null;
    } else {
      final suppliers = await db.query(
        'suppliers',
        where: 'id = ?',
        whereArgs: [partyId],
        limit: 1,
      );
      heldBill['party'] = suppliers.isNotEmpty ? suppliers.first : null;
    }

    return heldBill;
  }

  /// Update held bill
  Future<void> updateHeldBill({
    required int id,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
    String? notes,
    String? billName,
  }) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // Update held bill
      await txn.update(
        'held_bills',
        {
          'subtotal': subtotal,
          'discount_amount': discount,
          'tax_amount': tax,
          'total_amount': total,
          'notes': notes,
          'bill_name': billName,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      // Delete old items
      await txn.delete(
        'held_bill_items',
        where: 'held_bill_id = ?',
        whereArgs: [id],
      );

      // Insert new items
      for (final item in items) {
        // Get product details
        final products = await txn.query('products', where: 'id = ?', whereArgs: [item['product_id']]);
        final productName = products.isNotEmpty ? products.first['name'] as String : 'Unknown';
        final productUnit = products.isNotEmpty ? products.first['unit'] as String? : 'piece';

        await txn.insert('held_bill_items', {
          'held_bill_id': id,
          'product_id': item['product_id'],
          'product_name': productName,
          'quantity': item['quantity'],
          'unit': productUnit,
          'unit_price': item['unit_price'],
          'discount_amount': item['discount'] ?? 0,
          'tax_amount': item['tax'] ?? 0,
          'line_total': item['subtotal'],
        });
      }
    });
  }

  /// Delete held bill
  Future<void> deleteHeldBill(int id) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // Delete items first
      await txn.delete(
        'held_bill_items',
        where: 'held_bill_id = ?',
        whereArgs: [id],
      );

      // Delete held bill
      await txn.delete(
        'held_bills',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Get count of held bills
  Future<int> getHeldBillCount({String? type}) async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery(
      type != null
          ? 'SELECT COUNT(*) as count FROM held_bills WHERE type = ?'
          : 'SELECT COUNT(*) as count FROM held_bills',
      type != null ? [type] : null,
    );

    return (result.first['count'] as int?) ?? 0;
  }
}
