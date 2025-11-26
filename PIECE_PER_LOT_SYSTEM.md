# Piece Per Lot Product System - Complete Implementation

## Overview
Implemented a "piece per lot" product management system where products are defined by:
- **Item** = Number of pieces per lot
- **Stock** = Lot Quantity × Item (total individual pieces)
- **Product Name** = Base Name + Current Date + Lot Number
- **Price** = Initially empty, updated during transactions

## New Product Structure

### Formula
```
Stock = Buying Lot Quantity × Item

Example:
- Item: 50 piece per lot
- Buying Lot Quantity: 10 lots
- Stock: 10 × 50 = 500 total pieces
```

### Product Name Format
```
Format: {Base Name} {Current Date} {Lot Number}

Examples:
- "Rice Premium 26-Nov-2024 BATCH-A"
- "Biscuit 26-Nov-2024 LOT-001"
- "Chips 26-Nov-2024" (if no lot number provided)
```

## Form Fields

### 1. Product Information Section

#### Name of Product * (Required)
- Base product name
- Will be combined with date and lot number
- Example: "Rice Premium"

#### Lot Number (Optional)
- Batch identifier
- Example: "BATCH-A", "LOT-001"
- Auto-generates if left empty
- Uppercase input

#### Full Product Name Preview
- Live preview showing: Base Name + Date + Lot Number
- Updates as you type
- Blue highlighted box

#### Description (Optional)
- Product details
- Multiline text area

### 2. Lot Details Section (Green Card)

#### Item (Total Product in a Lot) * (Required)
- How many pieces in one lot
- Example: 50 means "50 pieces per lot"
- Suffix: "piece per lot"
- Integer only

#### Buying Lot Quantity * (Required)
- How many lots are you buying
- Example: 10 means "10 lots"
- Suffix: "lots"
- Integer only

#### Total Stock Calculation (Auto-calculated)
- Real-time display
- Formula: Lot Quantity × Item
- Shows as: "10 lots × 50 pieces per lot = 500 total pieces"
- Green highlighted box

### 3. Additional Settings Section

#### Reorder Level (Optional)
- Low stock alert threshold
- In pieces (not lots)
- Example: 100 pieces

#### Price Note (Info Box)
- "Price will be empty initially. It will be updated when you make a purchase or sale transaction."

## How It Works

### Adding a New Product

**Example: Rice in Bulk**

```
1. Product Information:
   - Name: "Rice Basmati"
   - Lot Number: "BATCH-NOV-2024"

   → Full Name: "Rice Basmati 26-Nov-2024 BATCH-NOV-2024"

2. Lot Details:
   - Item: 50 (50 pieces per lot)
   - Buying Lot Quantity: 20 (buying 20 lots)

   → Stock: 20 × 50 = 1000 total pieces

3. Save Product

   ✅ Product created:
      - Name: "Rice Basmati 26-Nov-2024 BATCH-NOV-2024"
      - Unit: "piece per lot"
      - Stock: 1000 pieces
      - Price: Empty (will update during transaction)
```

### Database Storage

#### Products Table
```sql
INSERT INTO products (
  name,
  unit,
  default_purchase_price,
  default_selling_price,
  reorder_level,
  ...
) VALUES (
  'Rice Basmati 26-Nov-2024 BATCH-NOV-2024',
  'piece per lot',
  0,  -- Initially empty
  0,  -- Initially empty
  100,
  ...
);
```

#### Product Batches Table
```sql
INSERT INTO product_batches (
  product_id,
  batch_code,
  purchase_price,
  quantity_added,
  quantity_remaining,
  notes,
  ...
) VALUES (
  1,
  'BATCH-NOV-2024',
  0,  -- Initially empty
  1000,  -- 20 lots × 50 pieces
  1000,
  'Initial stock - 20 lots × 50 pieces per lot = 1000 total pieces',
  ...
);
```

## Visual Layout

```
┌─────────────────────────────────────────────────────────────┐
│ Add Product                                          [Save] │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Product Information                                     │ │
│ ├─────────────────────────────────────────────────────────┤ │
│ │ Name of Product * [Rice Basmati___________________]    │ │
│ │ Lot Number        [BATCH-NOV-2024_________________]    │ │
│ │                                                         │ │
│ │ ┌─────────────────────────────────────────────────────┐ │ │
│ │ │ 📋 Full Product Name:                              │ │ │
│ │ │ Rice Basmati 26-Nov-2024 BATCH-NOV-2024           │ │ │
│ │ └─────────────────────────────────────────────────────┘ │ │
│ │                                                         │ │
│ │ Description       [Optional description____________]   │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Lot Details                                             │ │
│ ├─────────────────────────────────────────────────────────┤ │
│ │ Item (Total Product in a Lot) * [50___] piece per lot │ │
│ │ Buying Lot Quantity *               [20___] lots       │ │
│ │                                                         │ │
│ │ ┌─────────────────────────────────────────────────────┐ │ │
│ │ │ 🧮 Total Stock Calculation                         │ │ │
│ │ │ 20 lots × 50 pieces per lot = 1000 total pieces   │ │ │
│ │ │ Stock: 1000 pieces                                │ │ │
│ │ └─────────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Additional Settings                                     │ │
│ ├─────────────────────────────────────────────────────────┤ │
│ │ Reorder Level [100_______________________] pieces      │ │
│ │                                                         │ │
│ │ ⚠️ Price will be empty initially. It will be updated  │ │
│ │    when you make a purchase or sale transaction.      │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│               [Cancel]           [Create Product]           │
└─────────────────────────────────────────────────────────────┘
```

## Success Message

```
┌──────────────────────────────────────────────────┐
│ ✅ Product created successfully                  │
│                                                  │
│ Item: 50 piece per lot                          │
│ Stock: 20 lots × 50 = 1000 pieces              │
└──────────────────────────────────────────────────┘
```

## Real-World Examples

### Example 1: Biscuits in Cartons
```
Product Name: Biscuit Premium
Lot Number: CART-001
Item: 24 piece per lot (24 packets per carton)
Buying Quantity: 50 lots (50 cartons)
Stock: 50 × 24 = 1200 packets

Full Name: "Biscuit Premium 26-Nov-2024 CART-001"
```

### Example 2: Chips in Boxes
```
Product Name: Chips Spicy
Lot Number: BOX-A
Item: 30 piece per lot (30 bags per box)
Buying Quantity: 100 lots (100 boxes)
Stock: 100 × 30 = 3000 bags

Full Name: "Chips Spicy 26-Nov-2024 BOX-A"
```

### Example 3: Rice in Sacks
```
Product Name: Rice Basmati
Lot Number: SACK-2024
Item: 50 piece per lot (50 kg per sack)
Buying Quantity: 20 lots (20 sacks)
Stock: 20 × 50 = 1000 kg

Full Name: "Rice Basmati 26-Nov-2024 SACK-2024"
```

### Example 4: Bottles in Cases
```
Product Name: Water Bottle
Lot Number: CASE-001
Item: 12 piece per lot (12 bottles per case)
Buying Quantity: 200 lots (200 cases)
Stock: 200 × 12 = 2400 bottles

Full Name: "Water Bottle 26-Nov-2024 CASE-001"
```

## Key Features

### ✅ Auto-Generated Product Name
- Includes current date automatically
- Date format: dd-MMM-yyyy (e.g., 26-Nov-2024)
- Adds lot number if provided
- Live preview as you type

### ✅ Real-Time Stock Calculation
- Updates instantly as you type
- Visual formula display
- Clear calculation breakdown
- Green highlighted for easy visibility

### ✅ Fixed Unit System
- All products use "piece per lot"
- Consistent across the system
- Easy to understand

### ✅ Initial Empty Pricing
- No price fields during product creation
- Prices updated during transactions
- Cleaner workflow
- Matches real business process

### ✅ Lot Tracking
- Every product linked to batch
- Batch notes include full calculation
- Traceability from day one

## Validation Rules

| Field | Rule | Error Message |
|-------|------|---------------|
| Name of Product | Required, not empty | "Product name is required" |
| Lot Number | Optional | - |
| Description | Optional | - |
| Item | Required, integer, > 0 | "Item quantity is required" / "Enter valid number" |
| Buying Lot Quantity | Required, integer, > 0 | "Lot quantity is required" / "Enter valid number" |
| Reorder Level | Optional, integer | - |

## Data Flow

### On Save (New Product)

```
1. Calculate Stock
   └─ totalStock = item × lotQuantity

2. Generate Full Name
   └─ name = baseName + " " + date + " " + lotNumber

3. Create Product
   └─ unit = "piece per lot"
   └─ prices = 0 (empty)

4. Create Batch
   └─ quantity_added = totalStock
   └─ quantity_remaining = totalStock
   └─ notes = calculation details

5. Show Success
   └─ Display item, stock calculation
```

## Product Display (After Creation)

When viewing product list:

```
┌─────────────────────────────────────────────────┐
│ Rice Basmati 26-Nov-2024 BATCH-NOV-2024        │
│ Stock: 1000 pieces                             │
│ Unit: piece per lot                            │
│ Price: ৳0.00 (will update on transaction)      │
└─────────────────────────────────────────────────┘
```

## Transaction Integration

### When Purchase Transaction Occurs
- Update `default_purchase_price` in products table
- Update `purchase_price` in batch
- Adjust stock based on transaction quantity

### When Sale Transaction Occurs
- Update `default_selling_price` in products table
- Deduct from `quantity_remaining` in batch
- Use FIFO/LIFO for batch selection

## Benefits

### For Business
✅ **Natural Workflow** - Matches how products are actually received (in lots/cartons/boxes)
✅ **Easy Calculation** - Simple multiplication for stock
✅ **Batch Tracking** - Full traceability per lot
✅ **Flexible** - Works for any packaged products

### For Users
✅ **Simple Entry** - Only 4 required fields
✅ **Auto-Naming** - No manual date entry needed
✅ **Visual Feedback** - See calculations in real-time
✅ **Clean Interface** - No pricing confusion initially

## Technical Details

### Product Model
```dart
ProductModel(
  name: 'Rice Basmati 26-Nov-2024 BATCH-NOV-2024',
  unit: 'piece per lot',
  defaultPurchasePrice: 0,
  defaultSellingPrice: 0,
  reorderLevel: 100,
  ...
)
```

### Batch Creation
```dart
await db.insert('product_batches', {
  'product_id': productId,
  'batch_code': lotNumber,
  'quantity_added': totalStock,  // item × lotQuantity
  'quantity_remaining': totalStock,
  'purchase_price': 0,  // Empty initially
  'notes': '$lotQuantity lots × $item pieces per lot = $totalStock total pieces',
});
```

## Testing Checklist

### Basic Entry
- [ ] Enter product name
- [ ] See live name preview
- [ ] Add optional lot number
- [ ] Preview updates correctly

### Lot Calculation
- [ ] Enter item quantity
- [ ] Enter lot quantity
- [ ] See real-time stock calculation
- [ ] Formula displays correctly

### Save Product
- [ ] Product created with full name
- [ ] Stock matches calculation
- [ ] Batch created in database
- [ ] Success message shows details

### Edge Cases
- [ ] Empty lot number (auto-generates)
- [ ] Large quantities (e.g., 10000)
- [ ] Single lot (quantity = 1)
- [ ] Long product names

## Summary

✅ **Unit Fixed** - All products are "piece per lot"
✅ **Stock Calculated** - Buying Lot Quantity × Item
✅ **Auto-Named** - Name + Date + Lot Number
✅ **Price Empty** - Updated during transactions
✅ **Real-Time Preview** - See full name and stock as you type
✅ **Clean UI** - Color-coded sections (blue, green, amber)
✅ **Simple Entry** - Only essential fields required

Perfect for businesses that receive products in standardized lots/boxes/cartons!
