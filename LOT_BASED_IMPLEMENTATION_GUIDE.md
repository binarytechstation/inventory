# Lot-Based Inventory System - Implementation Guide

## Overview

This document provides a complete guide for implementing and using the new lot-based inventory system in your Flutter application.

---

## What Changed?

### Old System
```
products (id, name, price, stock)
  └─ product_batches (batch_id, product_id, quantity)
```

### New System
```
lots (lot_id, received_date, description)
  └─ products (product_id, lot_id, name, unit_price) [Composite PK]
      └─ stock (stock_id, lot_id, product_id, count)
          └─ lot_history (id, lot_id, product_id, action, quantity_change)
```

---

## Database Migration

### Automatic Migration
When you update your app, the database will automatically migrate from version 5 to version 6:

1. **Backup**: Old tables renamed to `products_old`, `product_batches_old`, `transaction_lines_old`
2. **Create**: New lot-based tables created
3. **Migrate**: Data copied from old tables to new structure
4. **Update**: Transactions updated to include `lot_id`
5. **Preserve**: Old tables kept for safety (can be dropped later)

### Manual Migration (if needed)
```bash
# Backup your database first
cp ~/Library/Application\ Support/inventory/inventory.db ~/inventory_backup.db

# Run the app - migration happens automatically on first launch
flutter run -d macos
```

---

## Data Models

### 1. LotModel
```dart
LotModel(
  lotId: 1,
  receivedDate: '2025-11-26',
  description: 'January 2025 Delivery',
  supplierId: 5,
  referenceNumber: 'PO-2025-001',
  notes: 'Fresh stock from supplier',
);
```

### 2. ProductLotModel
```dart
ProductLotModel(
  productId: 1,
  lotId: 1,
  productName: 'Basmati Rice Premium',
  unitPrice: 60.00,
  unit: 'kg',
  category: 'Food',
);
```

### 3. StockModel
```dart
StockModel(
  lotId: 1,
  productId: 1,
  count: 500.0,
  reorderLevel: 50.0,
  reservedQuantity: 0.0,
);
```

### 4. LotHistoryModel
```dart
LotHistoryModel(
  lotId: 1,
  productId: 1,
  action: 'SALE',
  quantityChange: -50.0,
  quantityBefore: 500.0,
  quantityAfter: 450.0,
  referenceType: 'TRANSACTION',
  referenceId: 123,
);
```

---

## How to Use

### Receiving a New Lot

```dart
import 'package:your_app/data/models/lot_model.dart';
import 'package:your_app/data/models/product_lot_model.dart';
import 'package:your_app/data/models/stock_model.dart';

Future<void> receiveNewLot() async {
  final db = await DatabaseHelper().database;

  // Step 1: Create the lot
  final lot = LotModel(
    receivedDate: DateTime.now().toIso8601String().split('T')[0],
    description: 'January 2025 Delivery',
    supplierId: 5,
    referenceNumber: 'PO-2025-001',
  );

  final lotId = await db.insert('lots', lot.toMap());

  // Step 2: Add products to the lot
  final product1 = ProductLotModel(
    productId: 1,  // Get from product_master or generate new
    lotId: lotId,
    productName: 'Basmati Rice Premium',
    unitPrice: 60.00,
    unit: 'kg',
  );

  await db.insert('products', product1.toMap());

  // Step 3: Initialize stock
  final stock1 = StockModel(
    lotId: lotId,
    productId: 1,
    count: 500.0,
    reorderLevel: 50.0,
  );

  await db.insert('stock', stock1.toMap());

  // Step 4: Record history
  final history = LotHistoryModel.fromStockChange(
    lotId: lotId,
    productId: 1,
    action: 'RECEIVED',
    quantityBefore: 0.0,
    quantityAfter: 500.0,
    referenceType: 'PURCHASE',
    notes: 'Initial stock from lot receipt',
  );

  await db.insert('lot_history', history.toMap());
}
```

### Adding Product to Transaction

```dart
Future<void> addProductToTransaction({
  required int transactionId,
  required int lotId,
  required int productId,
  required double quantity,
}) async {
  final db = await DatabaseHelper().database;

  // Get product details
  final productList = await db.query(
    'products',
    where: 'product_id = ? AND lot_id = ?',
    whereArgs: [productId, lotId],
    limit: 1,
  );

  if (productList.isEmpty) {
    throw Exception('Product not found in lot');
  }

  final product = ProductLotModel.fromMap(productList.first);

  // Check stock availability
  final stockList = await db.query(
    'stock',
    where: 'product_id = ? AND lot_id = ?',
    whereArgs: [productId, lotId],
    limit: 1,
  );

  if (stockList.isEmpty) {
    throw Exception('Stock record not found');
  }

  final stock = StockModel.fromMap(stockList.first);

  if (stock.availableQuantity < quantity) {
    throw Exception('Insufficient stock. Available: ${stock.availableQuantity}');
  }

  // Add to transaction
  await db.insert('transaction_lines', {
    'transaction_id': transactionId,
    'lot_id': lotId,
    'product_id': productId,
    'product_name': product.productName,
    'quantity': quantity,
    'unit': product.unit,
    'unit_price': product.unitPrice,
    'total_price': quantity * product.unitPrice,
    'line_total': quantity * product.unitPrice,
    'created_at': DateTime.now().toIso8601String(),
  });

  // Update stock
  final newStock = stock.removeStock(quantity);
  await db.update(
    'stock',
    newStock.toMap(),
    where: 'stock_id = ?',
    whereArgs: [stock.stockId],
  );

  // Record history
  final history = LotHistoryModel.fromStockChange(
    lotId: lotId,
    productId: productId,
    action: 'SALE',
    quantityBefore: stock.count,
    quantityAfter: newStock.count,
    referenceType: 'TRANSACTION',
    referenceId: transactionId,
  );

  await db.insert('lot_history', history.toMap());
}
```

### Selecting Product by Lot

```dart
Future<List<Map<String, dynamic>>> getProductsInLot(int lotId) async {
  final db = await DatabaseHelper().database;

  return await db.rawQuery('''
    SELECT
      p.product_id,
      p.lot_id,
      p.product_name,
      p.unit_price,
      p.unit,
      s.count AS stock_quantity,
      s.available_quantity,
      s.reorder_level,
      l.received_date,
      l.description AS lot_description
    FROM products p
    INNER JOIN stock s ON p.product_id = s.product_id AND p.lot_id = s.lot_id
    INNER JOIN lots l ON p.lot_id = l.lot_id
    WHERE p.lot_id = ?
      AND p.is_active = 1
      AND s.count > 0
    ORDER BY p.product_name
  ''', [lotId]);
}
```

### Getting Total Stock Across All Lots

```dart
Future<Map<String, dynamic>?> getTotalStockForProduct(int productId) async {
  final db = await DatabaseHelper().database;

  final result = await db.rawQuery('''
    SELECT
      p.product_id,
      p.product_name,
      SUM(s.count) AS total_stock,
      SUM(s.available_quantity) AS total_available,
      COUNT(DISTINCT p.lot_id) AS lots_count,
      AVG(p.unit_price) AS average_price,
      MIN(p.unit_price) AS min_price,
      MAX(p.unit_price) AS max_price
    FROM products p
    INNER JOIN stock s ON p.product_id = s.product_id AND p.lot_id = s.lot_id
    WHERE p.product_id = ?
      AND p.is_active = 1
    GROUP BY p.product_id, p.product_name
  ''', [productId]);

  return result.isNotEmpty ? result.first : null;
}
```

### Getting Low Stock Products

```dart
Future<List<Map<String, dynamic>>> getLowStockProducts() async {
  final db = await DatabaseHelper().database;

  return await db.rawQuery('''
    SELECT
      p.product_id,
      p.lot_id,
      p.product_name,
      p.unit_price,
      s.count,
      s.reorder_level,
      l.received_date,
      l.description AS lot_description
    FROM products p
    INNER JOIN stock s ON p.product_id = s.product_id AND p.lot_id = s.lot_id
    INNER JOIN lots l ON p.lot_id = l.lot_id
    WHERE s.count <= s.reorder_level
      AND s.reorder_level > 0
      AND p.is_active = 1
    ORDER BY (s.count / NULLIF(s.reorder_level, 0)) ASC
  ''');
}
```

### Product Search Across All Lots

```dart
Future<List<Map<String, dynamic>>> searchProducts(String query) async {
  final db = await DatabaseHelper().database;

  return await db.rawQuery('''
    SELECT
      p.product_id,
      p.lot_id,
      p.product_name,
      p.unit_price,
      p.unit,
      s.count AS stock_quantity,
      s.available_quantity,
      l.received_date,
      l.description AS lot_description
    FROM products p
    INNER JOIN stock s ON p.product_id = s.product_id AND p.lot_id = s.lot_id
    INNER JOIN lots l ON p.lot_id = l.lot_id
    WHERE p.product_name LIKE ?
      AND p.is_active = 1
      AND s.count > 0
    ORDER BY l.received_date DESC, p.product_name
  ''', ['%$query%']);
}
```

---

## UI Implementation Examples

### Product Selection Screen

```dart
class ProductLotSelectionScreen extends StatefulWidget {
  @override
  _ProductLotSelectionScreenState createState() => _ProductLotSelectionScreenState();
}

class _ProductLotSelectionScreenState extends State<ProductLotSelectionScreen> {
  List<Map<String, dynamic>> _products = [];
  int? _selectedLotId;

  @override
  void initState() {
    super.initState();
    _loadLots();
  }

  Future<void> _loadLots() async {
    final db = await DatabaseHelper().database;
    final lots = await db.query('lots', where: 'is_active = 1');
    // Show lot selection dropdown
  }

  Future<void> _loadProductsInLot(int lotId) async {
    final products = await getProductsInLot(lotId);
    setState(() {
      _products = products;
      _selectedLotId = lotId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select Product')),
      body: Column(
        children: [
          // Lot selection dropdown
          DropdownButton<int>(
            hint: Text('Select Lot'),
            value: _selectedLotId,
            onChanged: (lotId) {
              if (lotId != null) {
                _loadProductsInLot(lotId);
              }
            },
            // ... items
          ),

          // Product list
          Expanded(
            child: ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return ListTile(
                  title: Text(product['product_name']),
                  subtitle: Text(
                    'Stock: ${product['stock_quantity']} ${product['unit']} | '
                    'Price: ৳${product['unit_price']}'
                  ),
                  trailing: Text('Lot: ${product['lot_description']}'),
                  onTap: () {
                    Navigator.pop(context, product);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Best Practices

### 1. Always Use Transactions for Multi-Table Operations

```dart
Future<void> createSaleWithStockUpdate() async {
  final db = await DatabaseHelper().database;

  await db.transaction((txn) async {
    // 1. Create transaction
    final transactionId = await txn.insert('transactions', {...});

    // 2. Add transaction lines
    await txn.insert('transaction_lines', {...});

    // 3. Update stock
    await txn.update('stock', {...});

    // 4. Record history
    await txn.insert('lot_history', {...});
  });
}
```

### 2. Validate Stock Before Sales

```dart
Future<bool> validateStockAvailability(int lotId, int productId, double quantity) async {
  final db = await DatabaseHelper().database;

  final stockList = await db.query(
    'stock',
    where: 'lot_id = ? AND product_id = ?',
    whereArgs: [lotId, productId],
    limit: 1,
  );

  if (stockList.isEmpty) return false;

  final stock = StockModel.fromMap(stockList.first);
  return stock.availableQuantity >= quantity;
}
```

### 3. Use Product Master for Quick Entry

```dart
Future<List<ProductMasterModel>> getProductCatalog() async {
  final db = await DatabaseHelper().database;

  final products = await db.query(
    'product_master',
    where: 'is_active = 1',
    orderBy: 'product_name',
  );

  return products.map((p) => ProductMasterModel.fromMap(p)).toList();
}
```

### 4. Implement FIFO/LIFO for Stock Consumption

```dart
// FIFO - First In First Out
Future<Map<String, dynamic>?> getOldestLotForProduct(int productId) async {
  final db = await DatabaseHelper().database;

  final result = await db.rawQuery('''
    SELECT p.*, s.count, l.received_date
    FROM products p
    INNER JOIN stock s ON p.product_id = s.product_id AND p.lot_id = s.lot_id
    INNER JOIN lots l ON p.lot_id = l.lot_id
    WHERE p.product_id = ?
      AND s.count > 0
      AND p.is_active = 1
    ORDER BY l.received_date ASC
    LIMIT 1
  ''', [productId]);

  return result.isNotEmpty ? result.first : null;
}

// LIFO - Last In First Out
Future<Map<String, dynamic>?> getNewestLotForProduct(int productId) async {
  final db = await DatabaseHelper().database;

  final result = await db.rawQuery('''
    SELECT p.*, s.count, l.received_date
    FROM products p
    INNER JOIN stock s ON p.product_id = s.product_id AND p.lot_id = s.lot_id
    INNER JOIN lots l ON p.lot_id = l.lot_id
    WHERE p.product_id = ?
      AND s.count > 0
      AND p.is_active = 1
    ORDER BY l.received_date DESC
    LIMIT 1
  ''', [productId]);

  return result.isNotEmpty ? result.first : null;
}
```

---

## Common Queries

### All queries are documented in [NEW_LOT_BASED_SCHEMA.md](NEW_LOT_BASED_SCHEMA.md)

Key queries include:
- Get all products in a lot
- Get total stock across all lots for a product
- Get low stock products
- Search products across all lots
- Get stock movement history
- Get all lots with stock summary

---

## Troubleshooting

### Problem: Migration fails

**Solution:**
```bash
# Backup database
cp ~/Library/Application\ Support/inventory/inventory.db ~/inventory_backup.db

# Delete database and recreate
rm ~/Library/Application\ Support/inventory/inventory.db

# Restart app - new database will be created
flutter run -d macos
```

### Problem: Foreign key constraint errors

**Solution:**
```dart
// Ensure foreign key enforcement is enabled
final db = await DatabaseHelper().database;
await db.execute('PRAGMA foreign_keys = ON');
```

### Problem: Cannot find product in lot

**Solution:**
```dart
// Check if product exists in specified lot
final result = await db.query(
  'products',
  where: 'product_id = ? AND lot_id = ?',
  whereArgs: [productId, lotId],
);

if (result.isEmpty) {
  throw Exception('Product $productId not found in lot $lotId');
}
```

---

## Performance Tips

1. **Use Indexes**: All recommended indexes are created automatically during migration
2. **Use Joins**: Prefer single query with joins over multiple queries
3. **Limit Results**: Use `LIMIT` for large datasets
4. **Use Transactions**: Batch multiple operations in a single transaction
5. **Analyze Queries**: Use `EXPLAIN QUERY PLAN` to optimize slow queries

```dart
// Example: Analyze query performance
final db = await DatabaseHelper().database;
final plan = await db.rawQuery('EXPLAIN QUERY PLAN SELECT * FROM products WHERE lot_id = ?', [1]);
print(plan);
```

---

## Testing

### Unit Test Example

```dart
import 'package:test/test.dart';

void main() {
  group('StockModel', () {
    test('should add stock correctly', () {
      final stock = StockModel(lotId: 1, productId: 1, count: 100);
      final updated = stock.addStock(50);

      expect(updated.count, 150);
      expect(updated.lotId, 1);
      expect(updated.productId, 1);
    });

    test('should prevent negative stock', () {
      final stock = StockModel(lotId: 1, productId: 1, count: 100);

      expect(
        () => stock.removeStock(150),
        throwsException,
      );
    });

    test('should calculate available quantity correctly', () {
      final stock = StockModel(
        lotId: 1,
        productId: 1,
        count: 100,
        reservedQuantity: 20,
      );

      expect(stock.availableQuantity, 80);
    });
  });
}
```

---

## Summary

The lot-based inventory system provides:
- ✅ Full lot tracking with multiple products per lot
- ✅ Composite primary key (product_id, lot_id) for unique identification
- ✅ Separate stock management per product per lot
- ✅ Complete audit trail via lot_history
- ✅ Flexible pricing (same product can have different prices in different lots)
- ✅ Performance optimized with comprehensive indexes
- ✅ Data integrity with foreign key constraints
- ✅ Automatic migration from old system

For detailed schema information, see [NEW_LOT_BASED_SCHEMA.md](NEW_LOT_BASED_SCHEMA.md)
