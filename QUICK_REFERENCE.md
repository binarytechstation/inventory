# Lot-Based Inventory System - Quick Reference Card

## Core Concept

```
One Lot → Multiple Products → Each with Stock Tracking
```

---

## Tables Overview

| Table | Primary Key | Purpose |
|-------|-------------|---------|
| `lots` | `lot_id` | Master lot records |
| `products` | `(product_id, lot_id)` | Products in lots |
| `stock` | `stock_id` | Stock levels per product per lot |
| `lot_history` | `id` | Audit trail |
| `product_master` | `product_id` | Product catalog (optional) |

---

## Required Fields

### When Adding Product:
```dart
✅ lot_id          // Which lot this product belongs to
✅ product_name    // Name of the product
✅ unit_price      // Price per unit for this lot
```

### Optional Fields:
```dart
❌ product_image
❌ product_description
❌ All other fields have defaults
```

---

## Common Queries

### 1. Get Products in a Lot
```sql
SELECT p.*, s.count, s.available_quantity
FROM products p
JOIN stock s USING (product_id, lot_id)
WHERE p.lot_id = ?;
```

### 2. Get Total Stock for Product (All Lots)
```sql
SELECT SUM(s.count) AS total_stock
FROM stock s
WHERE s.product_id = ?;
```

### 3. Get Low Stock Products
```sql
SELECT p.*, s.count, s.reorder_level
FROM products p
JOIN stock s USING (product_id, lot_id)
WHERE s.count <= s.reorder_level
  AND s.reorder_level > 0;
```

---

## Transaction Flow

```
1. User selects Lot
   ↓
2. System shows Products in that Lot
   ↓
3. User selects Product + Quantity
   ↓
4. System validates Stock availability
   ↓
5. Create Transaction with lot_id
   ↓
6. Add Transaction Line with (lot_id, product_id)
   ↓
7. Update Stock
   ↓
8. Record History
```

---

## Pricing Options

User can enter **EITHER**:
- **Unit Price** → System calculates Total Price
- **Total Price** → System calculates Unit Price

Both stored in `transaction_lines`:
```sql
unit_price   REAL NOT NULL
total_price  REAL NOT NULL
```

---

## Key Features

✅ Same lot contains multiple products
✅ Same product in different lots can have different prices
✅ All transactions based on `lot_id`
✅ Complete audit trail via `lot_history`
✅ Stock tracking per product per lot
✅ Reorder level alerts
✅ Reserved quantity support

---

## Data Models

```dart
// 1. Create Lot
final lot = LotModel(
  receivedDate: '2025-11-26',
  description: 'January Delivery',
);

// 2. Add Product to Lot
final product = ProductLotModel(
  productId: 1,
  lotId: lotId,
  productName: 'Rice',
  unitPrice: 60.00,
);

// 3. Initialize Stock
final stock = StockModel(
  lotId: lotId,
  productId: 1,
  count: 500.0,
  reorderLevel: 50.0,
);
```

---

## File Locations

| File | Purpose |
|------|---------|
| [database_schema.dart](lib/data/database/database_schema.dart) | SQL table definitions |
| [database_helper.dart](lib/data/database/database_helper.dart) | Migration logic |
| [lot_model.dart](lib/data/models/lot_model.dart) | Lot data model |
| [product_lot_model.dart](lib/data/models/product_lot_model.dart) | Product data model |
| [stock_model.dart](lib/data/models/stock_model.dart) | Stock data model |

---

## Documentation

| Document | Lines | Purpose |
|----------|-------|---------|
| [NEW_LOT_BASED_SCHEMA.md](NEW_LOT_BASED_SCHEMA.md) | 6000+ | Complete SQL schema & queries |
| [LOT_BASED_IMPLEMENTATION_GUIDE.md](LOT_BASED_IMPLEMENTATION_GUIDE.md) | 500+ | How to use & code examples |
| [LOT_BASED_SYSTEM_SUMMARY.md](LOT_BASED_SYSTEM_SUMMARY.md) | 400+ | Executive summary |
| [QUICK_REFERENCE.md](QUICK_REFERENCE.md) | This file | Quick lookup |

---

## Migration

Database auto-migrates on first launch:
- Version: 5 → 6
- Old tables: Renamed to `*_old` (kept for safety)
- New tables: Created with data migration
- Indexes: 20+ created automatically

---

## Testing Migration

```bash
# Backup
cp ~/Library/Application\ Support/inventory/inventory.db ~/backup.db

# Run app
flutter run -d macos

# Check console for:
"Migrating to lot-based inventory system (v6)..."
"Migration to lot-based inventory system complete!"
```

---

## Indexes Created (20+)

- `idx_lots_*` (3 indexes on lots table)
- `idx_products_*` (4 indexes on products table)
- `idx_stock_*` (4 indexes on stock table)
- `idx_lot_history_*` (3 indexes on history table)
- `idx_transactions_lot` (1 index on transactions)
- `idx_transaction_lines_*` (3 indexes on transaction lines)

---

## Performance Tips

1. Use `JOIN` instead of multiple queries
2. Use `LIMIT` for large datasets
3. Use transactions for multi-table operations
4. Indexes already optimized
5. Use `EXPLAIN QUERY PLAN` for slow queries

---

## Status: ✅ COMPLETE

All deliverables ready:
- ✅ Database schema
- ✅ Data models
- ✅ Migration logic
- ✅ Indexes
- ✅ Documentation

**Next:** Implement UI and services layer
