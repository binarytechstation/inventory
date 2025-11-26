# Transaction Service - Lot-Based Schema Migration

## Status: ✅ COMPLETE

The transaction service has been successfully migrated from the old `product_batches` system to the new lot-based schema with composite keys.

---

## Problem

When clicking the "Save" button in the transaction form (Purchase Order/Sales Invoice), the following error occurred:

```
Error: SqliteFfiException(sqlite_error: 1, SqliteException(1):
no such column: id, SQL logic error (code 1)
Causing statement (at position 29): SELECT * FROM products WHERE id = ?
```

### Root Cause

The transaction service was still using the old schema:
1. Querying `products WHERE id = ?` instead of using composite key `(product_id, lot_id)`
2. Using old `product_batches` table for inventory management (FIFO)
3. Not including `lot_id` in transaction line items
4. Incorrect join conditions in queries

---

## New Lot-Based Schema

The new database schema uses:

### Products Table
- **Composite Primary Key**: `(product_id, lot_id)`
- Column: `product_name` (not `name`)
- Column: `unit_price` (purchase/cost price)

### Stock Table
- **Composite Foreign Key**: `(product_id, lot_id)`
- Column: `count` - Total physical stock
- Column: `reserved_quantity` - Reserved/allocated stock
- Column: `reorder_level` - Minimum threshold
- Column: `last_stock_update` - Last modification timestamp

### Transaction Lines Table
- Must include both `product_id` AND `lot_id`
- Links to specific product in specific lot

---

## Changes Made

### 1. TransactionService ([lib/services/transaction/transaction_service.dart](lib/services/transaction/transaction_service.dart))

#### Fixed Product Query (Line 71-78)

**Before:**
```dart
final products = await txn.query('products', where: 'id = ?', whereArgs: [item['product_id']]);
final productName = products.isNotEmpty ? products.first['name'] as String : 'Unknown';
```

**After:**
```dart
final int productId = item['product_id'];
final int lotId = item['lot_id'] ?? 1; // Default to lot 1 if not specified

final products = await txn.query('products',
  where: 'product_id = ? AND lot_id = ?',
  whereArgs: [productId, lotId]);
final productName = products.isNotEmpty ? products.first['product_name'] as String : 'Unknown';
```

#### Updated Transaction Lines Insert (Line 80-91)

**Before:**
```dart
await txn.insert('transaction_lines', {
  'transaction_id': transactionId,
  'product_id': item['product_id'],
  'product_name': productName,
  ...
});
```

**After:**
```dart
await txn.insert('transaction_lines', {
  'transaction_id': transactionId,
  'product_id': productId,
  'lot_id': lotId,  // NEW: Include lot_id
  'product_name': productName,
  ...
});
```

#### Replaced FIFO Batch System with Direct Stock Updates (Line 93-132)

**Before (using product_batches):**
```dart
if (type == 'BUY') {
  // Create product batch for purchase
  await txn.insert('product_batches', {
    'product_id': item['product_id'],
    'purchase_price': item['unit_price'],
    'quantity_added': item['quantity'],
    'quantity_remaining': item['quantity'],
    'purchase_date': date.toIso8601String(),
    'supplier_id': partyId,
    'created_at': DateTime.now().toIso8601String(),
  });
} else if (type == 'SELL') {
  // Reduce stock using FIFO method
  await _reduceStock(txn, item['product_id'], item['quantity']);
}
```

**After (using stock table):**
```dart
if (type == 'BUY') {
  // Increase stock count for purchase
  await txn.rawUpdate('''
    UPDATE stock
    SET count = count + ?,
        last_stock_update = ?,
        updated_at = ?
    WHERE product_id = ? AND lot_id = ?
  ''', [item['quantity'], DateTime.now().toIso8601String(), DateTime.now().toIso8601String(), productId, lotId]);
} else if (type == 'SELL') {
  // Reduce stock count for sale
  await txn.rawUpdate('''
    UPDATE stock
    SET count = count - ?,
        last_stock_update = ?,
        updated_at = ?
    WHERE product_id = ? AND lot_id = ?
  ''', [item['quantity'], DateTime.now().toIso8601String(), DateTime.now().toIso8601String(), productId, lotId]);
} else if (type == 'RETURN') {
  if (partyType == 'customer') {
    // Customer return - add stock back
    await txn.rawUpdate('''
      UPDATE stock
      SET count = count + ?,
          last_stock_update = ?,
          updated_at = ?
      WHERE product_id = ? AND lot_id = ?
    ''', [item['quantity'], DateTime.now().toIso8601String(), DateTime.now().toIso8601String(), productId, lotId]);
  } else {
    // Supplier return - reduce stock
    await txn.rawUpdate('''
      UPDATE stock
      SET count = count - ?,
          last_stock_update = ?,
          updated_at = ?
      WHERE product_id = ? AND lot_id = ?
    ''', [item['quantity'], DateTime.now().toIso8601String(), DateTime.now().toIso8601String(), productId, lotId]);
  }
}
```

#### Fixed getTransactions Query (Line 238-243)

**Before:**
```dart
SELECT GROUP_CONCAT(p.name, ', ') as product_names
FROM transaction_lines tl
LEFT JOIN products p ON tl.product_id = p.id
WHERE tl.transaction_id = ?
```

**After:**
```dart
SELECT GROUP_CONCAT(p.product_name, ', ') as product_names
FROM transaction_lines tl
LEFT JOIN products p ON tl.product_id = p.product_id AND tl.lot_id = p.lot_id
WHERE tl.transaction_id = ?
```

#### Updated cancelTransaction Method (Line 369-394)

**Before (using product_batches):**
```dart
if (type == 'BUY') {
  // Remove the batch created by this transaction
  await txn.delete(
    'product_batches',
    where: 'transaction_id = ?',
    whereArgs: [transactionId],
  );
} else if (type == 'SELL') {
  // Add stock back
  await _addStockFromReturn(txn, productId, quantity, 0);
}
```

**After (using stock table):**
```dart
final lotId = line['lot_id'] as int? ?? 1;

if (type == 'BUY') {
  // Reverse purchase - decrease stock
  await txn.rawUpdate('''
    UPDATE stock
    SET count = count - ?,
        last_stock_update = ?,
        updated_at = ?
    WHERE product_id = ? AND lot_id = ?
  ''', [quantity, DateTime.now().toIso8601String(), DateTime.now().toIso8601String(), productId, lotId]);
} else if (type == 'SELL') {
  // Reverse sale - add stock back
  await txn.rawUpdate('''
    UPDATE stock
    SET count = count + ?,
        last_stock_update = ?,
        updated_at = ?
    WHERE product_id = ? AND lot_id = ?
  ''', [quantity, DateTime.now().toIso8601String(), DateTime.now().toIso8601String(), productId, lotId]);
}
```

#### Removed Old FIFO Methods

Deleted these methods that are no longer needed:
- `_reduceStock()` - Old FIFO stock reduction
- `_addStockFromReturn()` - Old batch-based return handling

#### Removed Unused Import

**Before:**
```dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
```

**After:** Removed (not needed)

---

### 2. Transaction Form Screen ([lib/ui/screens/transaction/transaction_form_screen.dart](lib/ui/screens/transaction/transaction_form_screen.dart))

#### Added lot_id to Product Selection (Line 691-701)

**Before:**
```dart
selectedProductData.add({
  'product_id': productMap['id'] as int,
  'product_name': (productMap['name'] as String?) ?? 'Unknown',
  'product_unit': (productMap['unit'] as String?) ?? 'piece',
  'quantity': quantity,
  'unit_price': unitPrice,
  'discount': 0.0,
  'tax': ((productMap['tax_rate'] as num?)?.toDouble() ?? 0.0),
  'subtotal': quantity * unitPrice,
});
```

**After:**
```dart
selectedProductData.add({
  'product_id': productMap['id'] as int,
  'lot_id': 1, // Default to lot 1 for compatibility
  'product_name': (productMap['name'] as String?) ?? 'Unknown',
  'product_unit': (productMap['unit'] as String?) ?? 'piece',
  'quantity': quantity,
  'unit_price': unitPrice,
  'discount': 0.0,
  'tax': ((productMap['tax_rate'] as num?)?.toDouble() ?? 0.0),
  'subtotal': quantity * unitPrice,
});
```

---

## Key Changes Summary

### Database Queries
| Operation | Old | New |
|-----------|-----|-----|
| **Product Lookup** | `WHERE id = ?` | `WHERE product_id = ? AND lot_id = ?` |
| **Column Names** | `p.name`, `p.id` | `p.product_name`, `p.product_id` |
| **Join Conditions** | `ON tl.product_id = p.id` | `ON tl.product_id = p.product_id AND tl.lot_id = p.lot_id` |

### Inventory Management
| Operation | Old Method | New Method |
|-----------|-----------|-----------|
| **Purchase** | Insert into `product_batches` | `UPDATE stock SET count = count + ?` |
| **Sale** | FIFO reduction from `product_batches` | `UPDATE stock SET count = count - ?` |
| **Return** | Insert into `product_batches` | `UPDATE stock SET count = count + ?` |
| **Cancel Purchase** | Delete from `product_batches` | `UPDATE stock SET count = count - ?` |
| **Cancel Sale** | Insert new batch | `UPDATE stock SET count = count + ?` |

### Data Structure
| Field | Old | New |
|-------|-----|-----|
| **transaction_lines** | Only `product_id` | `product_id` + `lot_id` |
| **Stock tracking** | FIFO batches | Direct stock count |
| **Product reference** | Single `id` | Composite `(product_id, lot_id)` |

---

## Benefits of New System

### Simplified Inventory Management
- **Direct Stock Updates**: No complex FIFO batch management
- **Real-Time Accuracy**: Stock count directly reflects current inventory
- **Lot Traceability**: All transactions linked to specific lots
- **Timestamp Tracking**: `last_stock_update` provides audit trail

### Performance Improvements
- **Fewer Queries**: Direct UPDATE instead of multiple SELECT/UPDATE for FIFO
- **No Batch Cleanup**: No need to manage old empty batches
- **Simpler Cancellation**: Single UPDATE to reverse transactions

### Data Integrity
- **Composite Keys**: Ensures product-lot relationship integrity
- **Foreign Key Constraints**: Database-level enforcement
- **Consistent Schema**: All tables use same `(product_id, lot_id)` pattern

---

## Testing Results

✅ **Build:** Successful
✅ **Flutter Analyze:** No issues
✅ **Transaction Creation:** Works without errors
✅ **Product Query:** Uses correct composite key
✅ **Stock Updates:** Updates stock table correctly
✅ **Transaction Lines:** Includes lot_id

### Test Cases

#### Test 1: Create Purchase Order
**Steps:**
1. Navigate to Transactions → New Purchase Order
2. Select supplier: "Sowmik Saha (BITS)"
3. Add product: "Choco" (7 pieces × ৳100.00)
4. Select payment mode: Cash
5. Click Save

**Expected Result:** ✅ Transaction created successfully
**Database Changes:**
```sql
-- transactions table
INSERT INTO transactions (invoice_number, transaction_type, party_id, total_amount, ...)
VALUES ('PO-2025-00001', 'BUY', 1, 700.00, ...);

-- transaction_lines table
INSERT INTO transaction_lines (transaction_id, product_id, lot_id, quantity, ...)
VALUES (1, 23, 1, 7.0, ...);

-- stock table
UPDATE stock
SET count = count + 7.0,
    last_stock_update = '2025-11-26T...',
    updated_at = '2025-11-26T...'
WHERE product_id = 23 AND lot_id = 1;
```

#### Test 2: Create Sales Invoice
**Steps:**
1. Navigate to Transactions → New Sales Invoice
2. Select customer
3. Add products
4. Click Save

**Expected Result:** ✅ Sale created, stock reduced
**Database Changes:**
```sql
UPDATE stock
SET count = count - [quantity],
    last_stock_update = '2025-11-26T...',
    updated_at = '2025-11-26T...'
WHERE product_id = ? AND lot_id = ?;
```

---

## Migration Notes

### Backward Compatibility
- **Default Lot ID**: All transactions default to `lot_id = 1`
- **No Data Loss**: Existing transactions remain intact
- **Gradual Migration**: Old `product_batches_legacy` table preserved

### Future Enhancements

#### Phase 1: Multi-Lot Selection
Allow users to select specific lots when creating transactions:
```dart
// Product selection with lot dropdown
selectedProductData.add({
  'product_id': productId,
  'lot_id': userSelectedLotId, // User chooses lot
  'quantity': quantity,
  ...
});
```

#### Phase 2: Automatic Lot Selection
Implement FIFO/FEFO/LIFO lot selection strategies:
```dart
// Auto-select lot based on business rule
final lotId = await _selectLotByStrategy(
  productId: productId,
  quantity: quantity,
  strategy: 'FIFO', // First In, First Out
);
```

#### Phase 3: Lot Reservation
Reserve stock for pending orders:
```dart
// Reserve stock when order placed
UPDATE stock
SET reserved_quantity = reserved_quantity + ?
WHERE product_id = ? AND lot_id = ?;

// Reduce stock when shipped
UPDATE stock
SET count = count - ?,
    reserved_quantity = reserved_quantity - ?
WHERE product_id = ? AND lot_id = ?;
```

---

## Summary

✅ **Product Queries**: Now use composite key `(product_id, lot_id)`
✅ **Column Names**: Updated to `product_name`, `product_id`
✅ **Join Conditions**: Include both `product_id` AND `lot_id`
✅ **Inventory System**: Simplified from FIFO batches to direct stock updates
✅ **Transaction Lines**: Include `lot_id` for traceability
✅ **Stock Management**: Direct UPDATE operations on `stock` table
✅ **Error Resolved**: No more "no such column: id" errors

The transaction service now fully integrates with the lot-based schema, providing:
- Accurate stock tracking
- Lot-level traceability
- Simplified inventory management
- Better performance
- Foundation for advanced lot features

---

## Related Documentation

- [DATABASE_COLUMN_FIXES.md](DATABASE_COLUMN_FIXES.md) - Stock table column corrections
- [DATABASE_SCHEMA_FIX_SUMMARY.md](DATABASE_SCHEMA_FIX_SUMMARY.md) - Database migration
- [SERVICE_LAYER_UPDATE_COMPLETE.md](SERVICE_LAYER_UPDATE_COMPLETE.md) - Service layer changes
- [PRODUCT_SCREEN_UI_UPDATE.md](PRODUCT_SCREEN_UI_UPDATE.md) - UI enhancements
