# Lot-Based Inventory Database Schema

## Overview
Complete redesign of the inventory system to support lot-based product management where:
- Each lot can contain multiple products
- Products are uniquely identified by (product_id, lot_id) composite key
- All transactions operate on lot_id basis
- Stock is tracked per product per lot

---

## 1. LOT TABLE

```sql
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
);
```

### Indexes
```sql
CREATE INDEX idx_lots_received_date ON lots(received_date);
CREATE INDEX idx_lots_supplier ON lots(supplier_id);
CREATE INDEX idx_lots_active ON lots(is_active);
```

### Purpose
- Master table for all incoming inventory lots
- Each lot represents a batch of products received on a specific date
- Can contain multiple different products
- Links to supplier (optional)

### Fields
- `lot_id`: Auto-incrementing primary key
- `received_date`: Date when lot was received (required)
- `description`: Human-readable description of the lot (optional)
- `supplier_id`: Links to suppliers table (optional)
- `reference_number`: External reference like PO number (optional)
- `notes`: Additional notes (optional)
- `is_active`: Soft delete flag (1 = active, 0 = inactive)
- `created_at`: Timestamp when lot was created
- `updated_at`: Timestamp when lot was last modified

---

## 2. PRODUCTS TABLE (REDESIGNED)

```sql
CREATE TABLE products (
  product_id INTEGER NOT NULL,
  lot_id INTEGER NOT NULL,
  product_name TEXT NOT NULL,
  unit_price REAL NOT NULL,
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
);
```

### Indexes
```sql
CREATE INDEX idx_products_lot ON products(lot_id);
CREATE INDEX idx_products_name ON products(product_name);
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_products_barcode ON products(barcode);
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_active ON products(is_active);
```

### Purpose
- Stores product definitions within specific lots
- Same physical product in different lots gets separate records
- Composite primary key (product_id, lot_id) ensures uniqueness

### Fields
**Required:**
- `product_id`: Product identifier (NOT auto-increment, managed by application)
- `lot_id`: Foreign key to lots table (required)
- `product_name`: Name of the product (required)
- `unit_price`: Price per unit for this lot (required)

**Optional:**
- `product_image`: Path to product image file
- `product_description`: Detailed description
- `unit`: Unit of measurement (default: 'piece')
- `sku`: Stock Keeping Unit code
- `barcode`: Barcode number
- `category`: Product category
- `tax_rate`: Tax percentage (default: 0)
- `is_active`: Active status (1 = active, 0 = inactive)
- `created_at`: Creation timestamp
- `updated_at`: Last update timestamp

### Notes
- **Composite Primary Key:** (product_id, lot_id)
- Product can exist in multiple lots with different prices
- Cascading delete: If lot is deleted, all its products are deleted
- unit_price can vary across lots for the same product_id

---

## 3. STOCK TABLE

```sql
CREATE TABLE stock (
  stock_id INTEGER PRIMARY KEY AUTOINCREMENT,
  lot_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  count REAL NOT NULL DEFAULT 0,
  reorder_level REAL DEFAULT 0,
  reserved_quantity REAL DEFAULT 0,
  available_quantity REAL GENERATED ALWAYS AS (count - reserved_quantity) STORED,
  last_stock_update TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (lot_id) REFERENCES lots(lot_id) ON DELETE CASCADE,
  FOREIGN KEY (product_id, lot_id) REFERENCES products(product_id, lot_id) ON DELETE CASCADE,
  UNIQUE (lot_id, product_id)
);
```

### Indexes
```sql
CREATE INDEX idx_stock_lot ON stock(lot_id);
CREATE INDEX idx_stock_product ON stock(product_id);
CREATE INDEX idx_stock_composite ON stock(product_id, lot_id);
CREATE INDEX idx_stock_low_stock ON stock(count, reorder_level) WHERE count <= reorder_level;
```

### Purpose
- Tracks current inventory levels per product per lot
- Supports reorder level alerts
- Supports reserved quantities (for pending orders)
- Auto-calculated available quantity

### Fields
- `stock_id`: Auto-incrementing primary key
- `lot_id`: Foreign key to lots table (required)
- `product_id`: Foreign key to products table (required)
- `count`: Current stock quantity (required, default: 0)
- `reorder_level`: Alert threshold for low stock (optional, default: 0)
- `reserved_quantity`: Quantity reserved for orders (default: 0)
- `available_quantity`: Computed column (count - reserved_quantity)
- `last_stock_update`: Timestamp of last stock change
- `created_at`: Creation timestamp
- `updated_at`: Last update timestamp

### Notes
- **Unique Constraint:** (lot_id, product_id) - One stock record per product per lot
- **Composite Foreign Key:** References products(product_id, lot_id)
- **Generated Column:** available_quantity is auto-calculated
- **Partial Index:** For efficient low stock queries

---

## 4. UPDATED TRANSACTIONS TABLE

```sql
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
);
```

### Changes
- Added `lot_id` field to link transaction to a specific lot
- All transaction items within a transaction must belong to the same lot

---

## 5. UPDATED TRANSACTION LINES TABLE

```sql
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
);
```

### Changes
- Added `lot_id` field (required)
- Added `total_price` field (alternative to unit_price * quantity)
- Composite foreign key to products(product_id, lot_id)
- Removed batch_id (replaced by lot_id)

---

## 6. SUPPORTING TABLES

### Product Master (Optional - for product catalog)
```sql
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
);
```

**Purpose:** Optional master catalog of products independent of lots. Used for quick product selection when adding to new lots.

### Indexes
```sql
CREATE INDEX idx_product_master_name ON product_master(product_name);
CREATE INDEX idx_product_master_active ON product_master(is_active);
```

---

## 7. LOT HISTORY TABLE

```sql
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
);
```

**Purpose:** Audit trail for all stock movements within lots

### Indexes
```sql
CREATE INDEX idx_lot_history_lot ON lot_history(lot_id);
CREATE INDEX idx_lot_history_product ON lot_history(product_id);
CREATE INDEX idx_lot_history_date ON lot_history(created_at);
```

---

## DATA FLOW EXAMPLES

### Example 1: Receiving a New Lot

**Step 1: Create Lot**
```sql
INSERT INTO lots (received_date, description, supplier_id, created_at, updated_at)
VALUES ('2025-11-26', 'January 2025 Delivery', 5, '2025-11-26T10:00:00', '2025-11-26T10:00:00');
-- Returns lot_id = 100
```

**Step 2: Add Products to Lot**
```sql
-- Product 1: Rice
INSERT INTO products (product_id, lot_id, product_name, unit_price, unit, created_at, updated_at)
VALUES (1, 100, 'Basmati Rice Premium', 60.00, 'kg', '2025-11-26T10:05:00', '2025-11-26T10:05:00');

-- Product 2: Wheat
INSERT INTO products (product_id, lot_id, product_name, unit_price, unit, created_at, updated_at)
VALUES (2, 100, 'Wheat Flour', 45.00, 'kg', '2025-11-26T10:06:00', '2025-11-26T10:06:00');
```

**Step 3: Initialize Stock**
```sql
-- Stock for Rice
INSERT INTO stock (lot_id, product_id, count, reorder_level, created_at, updated_at)
VALUES (100, 1, 500, 50, '2025-11-26T10:10:00', '2025-11-26T10:10:00');

-- Stock for Wheat
INSERT INTO stock (lot_id, product_id, count, reorder_level, created_at, updated_at)
VALUES (100, 2, 300, 30, '2025-11-26T10:11:00', '2025-11-26T10:11:00');
```

### Example 2: Creating a Sale Transaction

**Step 1: Select Product from Lot**
```sql
-- User selects: Product 1 (Rice) from Lot 100
SELECT p.product_id, p.lot_id, p.product_name, p.unit_price, s.count, s.available_quantity
FROM products p
INNER JOIN stock s ON p.product_id = s.product_id AND p.lot_id = s.lot_id
WHERE p.lot_id = 100 AND p.product_id = 1;
```

**Step 2: Create Transaction**
```sql
INSERT INTO transactions (invoice_number, transaction_type, transaction_date, lot_id,
                          party_name, total_amount, payment_mode, created_at, updated_at)
VALUES ('INV-2025-001', 'SALE', '2025-11-26', 100,
        'Customer ABC', 3000.00, 'CASH', '2025-11-26T14:00:00', '2025-11-26T14:00:00');
-- Returns transaction_id = 1
```

**Step 3: Add Transaction Line**
```sql
INSERT INTO transaction_lines (transaction_id, lot_id, product_id, product_name,
                                quantity, unit, unit_price, total_price, line_total, created_at)
VALUES (1, 100, 1, 'Basmati Rice Premium',
        50, 'kg', 60.00, 3000.00, 3000.00, '2025-11-26T14:00:00');
```

**Step 4: Update Stock**
```sql
UPDATE stock
SET count = count - 50,
    last_stock_update = '2025-11-26T14:00:00',
    updated_at = '2025-11-26T14:00:00'
WHERE lot_id = 100 AND product_id = 1;
```

**Step 5: Record History**
```sql
INSERT INTO lot_history (lot_id, product_id, action, quantity_change,
                         quantity_before, quantity_after, reference_type,
                         reference_id, user_id, created_at)
VALUES (100, 1, 'SALE', -50, 500, 450, 'TRANSACTION', 1, 1, '2025-11-26T14:00:00');
```

---

## COMMON QUERIES

### 1. Get All Products in a Lot
```sql
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
  AND p.is_active = 1;
```

### 2. Get Total Stock Across All Lots for a Product
```sql
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
GROUP BY p.product_id, p.product_name;
```

### 3. Get Low Stock Products
```sql
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
ORDER BY (s.count / NULLIF(s.reorder_level, 0)) ASC;
```

### 4. Get Stock Movement History for a Product
```sql
SELECT
  lh.created_at,
  lh.action,
  lh.quantity_change,
  lh.quantity_before,
  lh.quantity_after,
  lh.reference_type,
  lh.reference_id,
  l.description AS lot_description,
  u.name AS user_name
FROM lot_history lh
INNER JOIN lots l ON lh.lot_id = l.lot_id
LEFT JOIN users u ON lh.user_id = u.id
WHERE lh.product_id = ?
  AND lh.lot_id = ?
ORDER BY lh.created_at DESC;
```

### 5. Get All Lots with Stock Summary
```sql
SELECT
  l.lot_id,
  l.received_date,
  l.description,
  l.reference_number,
  COUNT(DISTINCT p.product_id) AS product_count,
  SUM(s.count) AS total_items,
  SUM(s.count * p.unit_price) AS total_value
FROM lots l
LEFT JOIN products p ON l.lot_id = p.lot_id
LEFT JOIN stock s ON p.product_id = s.product_id AND p.lot_id = s.lot_id
WHERE l.is_active = 1
GROUP BY l.lot_id, l.received_date, l.description, l.reference_number
ORDER BY l.received_date DESC;
```

### 6. Search Products Across All Lots
```sql
SELECT
  p.product_id,
  p.lot_id,
  p.product_name,
  p.unit_price,
  p.unit,
  s.count AS stock_quantity,
  l.received_date,
  l.description AS lot_description
FROM products p
INNER JOIN stock s ON p.product_id = s.product_id AND p.lot_id = s.lot_id
INNER JOIN lots l ON p.lot_id = l.lot_id
WHERE p.product_name LIKE ?
  AND p.is_active = 1
  AND s.count > 0
ORDER BY l.received_date DESC, p.product_name;
```

---

## MIGRATION STRATEGY

### Phase 1: Backup Current Database
```sql
-- Export existing products and batches
SELECT * FROM products;
SELECT * FROM product_batches;
SELECT * FROM transactions;
SELECT * FROM transaction_lines;
```

### Phase 2: Create New Tables
```sql
-- Create lots, products, stock tables with new schema
-- Keep old tables temporarily as products_old, product_batches_old
```

### Phase 3: Migrate Data

**Step 1: Create lots from product_batches**
```sql
INSERT INTO lots (lot_id, received_date, description, supplier_id, created_at, updated_at)
SELECT
  id AS lot_id,
  purchase_date AS received_date,
  notes AS description,
  supplier_id,
  created_at,
  created_at AS updated_at
FROM product_batches_old;
```

**Step 2: Create products from old schema**
```sql
INSERT INTO products (product_id, lot_id, product_name, unit_price, unit,
                      product_description, created_at, updated_at)
SELECT
  p.id AS product_id,
  pb.id AS lot_id,
  p.name AS product_name,
  pb.purchase_price AS unit_price,
  p.unit,
  p.description AS product_description,
  pb.created_at,
  pb.created_at AS updated_at
FROM products_old p
CROSS JOIN product_batches_old pb
WHERE pb.product_id = p.id;
```

**Step 3: Create stock records**
```sql
INSERT INTO stock (lot_id, product_id, count, reorder_level, created_at, updated_at)
SELECT
  pb.id AS lot_id,
  pb.product_id,
  pb.quantity_remaining AS count,
  p.reorder_level,
  pb.created_at,
  pb.created_at AS updated_at
FROM product_batches_old pb
INNER JOIN products_old p ON pb.product_id = p.id;
```

### Phase 4: Update References
- Update transaction_lines to use lot_id
- Verify data integrity
- Drop old tables

---

## BEST PRACTICES

### 1. Performance Optimization
- Use composite indexes on (product_id, lot_id)
- Create partial indexes for active records only
- Use generated columns for computed values
- Regular VACUUM and ANALYZE operations

### 2. Data Integrity
- Always use transactions for multi-table operations
- Implement triggers for stock updates
- Use foreign key constraints with CASCADE
- Validate stock before sales

### 3. Query Optimization
```sql
-- Good: Use covering index
SELECT product_id, lot_id, product_name, unit_price
FROM products
WHERE lot_id = ? AND is_active = 1;

-- Better: Include stock in single query
SELECT p.*, s.count
FROM products p
INNER JOIN stock s USING (product_id, lot_id)
WHERE p.lot_id = ? AND p.is_active = 1;
```

### 4. Stock Management Triggers
```sql
-- Auto-update available_quantity (if not using generated column)
CREATE TRIGGER update_available_quantity
AFTER UPDATE OF count, reserved_quantity ON stock
BEGIN
  UPDATE stock
  SET available_quantity = NEW.count - NEW.reserved_quantity,
      updated_at = datetime('now')
  WHERE stock_id = NEW.stock_id;
END;

-- Prevent negative stock
CREATE TRIGGER prevent_negative_stock
BEFORE UPDATE OF count ON stock
BEGIN
  SELECT RAISE(ABORT, 'Stock cannot be negative')
  WHERE NEW.count < 0;
END;

-- Auto-update last_stock_update
CREATE TRIGGER update_stock_timestamp
AFTER UPDATE OF count ON stock
BEGIN
  UPDATE stock
  SET last_stock_update = datetime('now'),
      updated_at = datetime('now')
  WHERE stock_id = NEW.stock_id;
END;
```

---

## SCHEMA IMPROVEMENTS

### 1. Add Constraints
```sql
-- Ensure positive quantities
ALTER TABLE stock ADD CONSTRAINT chk_stock_count_positive
  CHECK (count >= 0);

ALTER TABLE stock ADD CONSTRAINT chk_reorder_positive
  CHECK (reorder_level >= 0);

-- Ensure valid dates
ALTER TABLE lots ADD CONSTRAINT chk_received_date_valid
  CHECK (received_date IS NOT NULL AND received_date != '');
```

### 2. Add Computed Columns
```sql
-- Stock status (LOW, NORMAL, OVERSTOCK)
ALTER TABLE stock ADD COLUMN stock_status TEXT
  GENERATED ALWAYS AS (
    CASE
      WHEN count = 0 THEN 'OUT_OF_STOCK'
      WHEN count <= reorder_level THEN 'LOW'
      WHEN count > (reorder_level * 3) THEN 'OVERSTOCK'
      ELSE 'NORMAL'
    END
  ) STORED;
```

### 3. Partitioning (for large datasets)
```sql
-- Create archive table for old lots
CREATE TABLE lots_archive AS SELECT * FROM lots WHERE 1=0;
CREATE TABLE products_archive AS SELECT * FROM products WHERE 1=0;
CREATE TABLE stock_archive AS SELECT * FROM stock WHERE 1=0;

-- Move old lots (older than 2 years)
INSERT INTO lots_archive
SELECT * FROM lots
WHERE received_date < date('now', '-2 years');
```

---

## INDEX RECOMMENDATIONS

### Essential Indexes
```sql
-- Lots
CREATE INDEX idx_lots_received_date ON lots(received_date);
CREATE INDEX idx_lots_supplier ON lots(supplier_id);
CREATE INDEX idx_lots_active ON lots(is_active);

-- Products
CREATE INDEX idx_products_lot ON products(lot_id);
CREATE INDEX idx_products_composite ON products(product_id, lot_id);
CREATE INDEX idx_products_name ON products(product_name);
CREATE INDEX idx_products_active ON products(is_active);

-- Stock
CREATE UNIQUE INDEX idx_stock_unique ON stock(lot_id, product_id);
CREATE INDEX idx_stock_lot ON stock(lot_id);
CREATE INDEX idx_stock_product ON stock(product_id);
CREATE INDEX idx_stock_low ON stock(count, reorder_level) WHERE count <= reorder_level;

-- Transaction Lines
CREATE INDEX idx_tx_lines_tx ON transaction_lines(transaction_id);
CREATE INDEX idx_tx_lines_lot ON transaction_lines(lot_id);
CREATE INDEX idx_tx_lines_product ON transaction_lines(product_id);
CREATE INDEX idx_tx_lines_composite ON transaction_lines(product_id, lot_id);
```

### Full-Text Search (Optional)
```sql
-- For fast product name search
CREATE VIRTUAL TABLE products_fts USING fts5(
  product_id UNINDEXED,
  lot_id UNINDEXED,
  product_name,
  product_description,
  content=products
);

-- Triggers to keep FTS in sync
CREATE TRIGGER products_fts_insert AFTER INSERT ON products BEGIN
  INSERT INTO products_fts(product_id, lot_id, product_name, product_description)
  VALUES (new.product_id, new.lot_id, new.product_name, new.product_description);
END;
```

---

## SUMMARY

This schema provides:
✅ **Lot-based tracking** - Full lot management with multiple products per lot
✅ **Composite keys** - (product_id, lot_id) for unique product identification
✅ **Stock management** - Separate stock table with reorder levels
✅ **Flexible pricing** - Different prices for same product in different lots
✅ **Audit trail** - Complete history of stock movements
✅ **Performance** - Comprehensive indexing strategy
✅ **Data integrity** - Foreign key constraints and triggers
✅ **Scalability** - Supports offline inventory systems
✅ **Transaction support** - All operations based on lot_id
✅ **Reporting** - Rich queries for analytics and reporting
