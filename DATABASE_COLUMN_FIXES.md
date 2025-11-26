# Database Column Fixes - Stock Table Schema Correction

## Status: ✅ COMPLETE

All database column reference errors have been resolved. The app now correctly uses the actual stock table schema.

---

## Problem

The application was trying to insert/update a non-existent column `available_quantity` in the stock table:

```
Error: SqliteFfiException(sqlite_error: 1, SqliteException(1):
table stock has no column named available_quantity
```

### Root Cause

The service layer code was referencing `available_quantity` but the actual database schema only has:
- `count` - Total stock quantity
- `reserved_quantity` - Reserved/allocated stock
- `reorder_level` - Minimum stock threshold

**Available stock** = `count - reserved_quantity` (calculated, not stored)

---

## Actual Stock Table Schema

```sql
CREATE TABLE stock (
  stock_id INTEGER PRIMARY KEY AUTOINCREMENT,
  lot_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  count REAL NOT NULL DEFAULT 0,              -- Total stock
  reorder_level REAL DEFAULT 0,                -- Reorder threshold
  reserved_quantity REAL DEFAULT 0,            -- Reserved stock
  last_stock_update TEXT,                      -- Last update timestamp
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (lot_id) REFERENCES lots(lot_id) ON DELETE CASCADE,
  FOREIGN KEY (product_id, lot_id) REFERENCES products(product_id, lot_id) ON DELETE CASCADE,
  UNIQUE (lot_id, product_id)
)
```

---

## Files Fixed

### 1. ProductService ([lib/services/product/product_service.dart](lib/services/product/product_service.dart))

#### createProduct Method (Line 498-507)

**Before:**
```dart
await db.insert('stock', {
  'lot_id': defaultLotId,
  'product_id': nextId,
  'count': product.currentStock ?? 0,
  'available_quantity': product.currentStock ?? 0,  // ❌ Column doesn't exist
  'reorder_level': product.reorderLevel,
});
```

**After:**
```dart
await db.insert('stock', {
  'lot_id': defaultLotId,
  'product_id': nextId,
  'count': product.currentStock ?? 0,
  'reorder_level': product.reorderLevel ?? 0,
  'reserved_quantity': 0,                            // ✅ Correct column
  'last_stock_update': DateTime.now().toIso8601String(),
  'created_at': DateTime.now().toIso8601String(),
  'updated_at': DateTime.now().toIso8601String(),
});
```

#### updateProduct Method (Line 542-565)

**Before:**
```dart
await db.update('stock', {
  'count': product.currentStock ?? 0,
  'available_quantity': product.currentStock ?? 0,  // ❌ Column doesn't exist
  'reorder_level': product.reorderLevel,
}, ...);
```

**After:**
```dart
await db.update('stock', {
  'count': product.currentStock ?? 0,
  'reorder_level': product.reorderLevel,
  'last_stock_update': DateTime.now().toIso8601String(),
  'updated_at': DateTime.now().toIso8601String(),
}, ...);
```

#### Query Methods (Multiple locations)

**Before:**
```sql
SELECT s.available_quantity
FROM stock s
```

**After:**
```sql
SELECT (s.count - COALESCE(s.reserved_quantity, 0)) as available_stock
FROM stock s
```

**Changed Queries:**
1. `getAllProductsAggregated()` - Line 25
2. `getProductsInLot()` - Line 59
3. `getProductAggregated()` - Line 87
4. `getProductInLot()` - Line 110
5. `searchProducts()` - Line 139

---

### 2. ReportsService ([lib/services/reports/reports_service.dart](lib/services/reports/reports_service.dart))

#### getInventoryReport Method (Line 88)

**Before:**
```sql
SUM(s.available_quantity) as available_stock
```

**After:**
```sql
SUM(s.count - COALESCE(s.reserved_quantity, 0)) as available_stock
```

---

## Key Changes Summary

### Column Name Corrections

| Operation | Old (Incorrect) | New (Correct) |
|-----------|----------------|---------------|
| **Insert/Update** | `available_quantity` | Removed (calculated instead) |
| **SELECT (Display)** | `s.available_quantity` | `(s.count - COALESCE(s.reserved_quantity, 0)) as available_stock` |
| **New Fields Added** | - | `reserved_quantity`, `last_stock_update`, `created_at`, `updated_at` |

### Available Stock Calculation

Available stock is now properly calculated as:
```sql
count - COALESCE(reserved_quantity, 0)
```

This gives the **actual available inventory** after accounting for reserved/allocated items.

---

## Stock Table Fields Explained

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `count` | REAL | Total physical stock in warehouse | 100.0 |
| `reserved_quantity` | REAL | Stock reserved for orders/allocations | 15.0 |
| `available_stock` | Calculated | Stock available for sale = count - reserved | 85.0 |
| `reorder_level` | REAL | Minimum stock threshold | 20.0 |
| `last_stock_update` | TEXT | Last stock change timestamp | "2025-11-26T13:45:00Z" |

---

## Testing Results

✅ **Build:** Successful
✅ **App Launch:** Successful
✅ **Product Creation:** Now works without errors
✅ **Product Update:** Now works without errors
✅ **Stock Queries:** Return correct calculated available stock
✅ **Reports:** Inventory reports show correct available stock

### Test Case: Create Product

**Steps:**
1. Navigate to Products screen
2. Click "Add Product"
3. Fill in product details
4. Set initial stock quantity
5. Save product

**Result:** ✅ Product created successfully with stock record

**Database:**
```sql
-- Products table
INSERT INTO products (product_id, lot_id, product_name, unit_price, ...)
VALUES (23, 1, 'Test Product', 50.00, ...);

-- Stock table
INSERT INTO stock (lot_id, product_id, count, reserved_quantity, reorder_level, ...)
VALUES (1, 23, 100, 0, 20, ...);
```

---

## Available Stock Calculation Examples

### Example 1: No Reservations
```
count: 100
reserved_quantity: 0
available_stock: 100 - 0 = 100 ✅
```

### Example 2: With Reservations
```
count: 100
reserved_quantity: 15
available_stock: 100 - 15 = 85 ✅
```

### Example 3: Null Reserved Quantity
```
count: 100
reserved_quantity: NULL
available_stock: 100 - COALESCE(NULL, 0) = 100 ✅
```

---

## Impact on UI

### Product List View
- Shows total stock (`count`)
- Available stock calculated automatically
- Stock status based on `count` vs `reorder_level`

### Inventory Reports
- Current stock: Total `count` across all lots
- Available stock: `SUM(count - reserved_quantity)` across all lots
- Reserved stock: `SUM(reserved_quantity)` across all lots

### Transaction Processing
When selling/allocating products:
1. Check `available_stock` (not just `count`)
2. Update `reserved_quantity` when order placed
3. Decrease `count` when shipped
4. Update `last_stock_update` timestamp

---

## Future Enhancements

### Stock Reservation System
```dart
// Reserve stock for an order
Future<void> reserveStock(int productId, int lotId, double quantity) async {
  await db.rawUpdate('''
    UPDATE stock
    SET reserved_quantity = reserved_quantity + ?,
        last_stock_update = ?,
        updated_at = ?
    WHERE product_id = ? AND lot_id = ?
  ''', [quantity, now, now, productId, lotId]);
}

// Release reservation
Future<void> releaseReservation(int productId, int lotId, double quantity) async {
  await db.rawUpdate('''
    UPDATE stock
    SET reserved_quantity = MAX(0, reserved_quantity - ?),
        last_stock_update = ?,
        updated_at = ?
    WHERE product_id = ? AND lot_id = ?
  ''', [quantity, now, now, productId, lotId]);
}

// Fulfill order (ship reserved stock)
Future<void> fulfillOrder(int productId, int lotId, double quantity) async {
  await db.rawUpdate('''
    UPDATE stock
    SET count = count - ?,
        reserved_quantity = reserved_quantity - ?,
        last_stock_update = ?,
        updated_at = ?
    WHERE product_id = ? AND lot_id = ?
  ''', [quantity, quantity, now, now, productId, lotId]);
}
```

---

## Migration Notes

### No Database Migration Required

These fixes only corrected the service layer code to match the existing database schema. The database structure itself didn't change.

### Backward Compatibility

- Existing data remains intact
- No data migration needed
- All existing records continue to work
- `reserved_quantity` defaults to 0 for existing records

---

## Summary

✅ **Column Name Errors:** Fixed - Using correct schema
✅ **Insert Operations:** Working - Correct columns
✅ **Update Operations:** Working - Correct columns
✅ **Query Operations:** Working - Calculated available stock
✅ **Product Creation:** Working - No more errors
✅ **Product Updates:** Working - No more errors
✅ **Reports:** Working - Correct stock calculations

The service layer now correctly aligns with the actual database schema. All operations for creating, updating, and querying products now work without column-related errors.

---

## Related Documentation

- [DATABASE_SCHEMA_FIX_SUMMARY.md](DATABASE_SCHEMA_FIX_SUMMARY.md) - Initial schema migration fixes
- [PRODUCT_SCREEN_UI_UPDATE.md](PRODUCT_SCREEN_UI_UPDATE.md) - UI enhancements for lot-based system
- [SERVICE_LAYER_UPDATE_COMPLETE.md](SERVICE_LAYER_UPDATE_COMPLETE.md) - Complete service layer changes
