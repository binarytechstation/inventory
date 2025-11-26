# Product Form - Visual Guide

## Updated Add Product Screen Layout

```
┌─────────────────────────────────────────────────────────────┐
│ Add Product                                          [Save] │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Product Information                                     │ │
│ ├─────────────────────────────────────────────────────────┤ │
│ │ Product Name * [________________________]               │ │
│ │ Description    [________________________]               │ │
│ │                [________________________]               │ │
│ │                [________________________]               │ │
│ │ Unit *         [________]  Category  [________]         │ │
│ │ Reorder Level  [________________________]               │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ ☑ Add Initial Stock (Lot)                              │ │
│ ├─────────────────────────────────────────────────────────┤ │
│ │ Add product in lot/batch with quantity and pricing     │ │
│ │                                                         │ │
│ │ Lot Number      [________________________]              │ │
│ │ Total Product   [________________________] pieces       │ │
│ │ in This Lot *                                           │ │
│ │                                                         │ │
│ │ Price Information (Optional)                            │ │
│ │ Purchase Price  [_______] Selling Price [_______]       │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│               [Cancel]           [Create Product]           │
└─────────────────────────────────────────────────────────────┘
```

## Field Breakdown

### Section 1: Product Information (Always Visible)

| Field | Required | Description | Example |
|-------|----------|-------------|---------|
| **Product Name** | ✅ Yes | Main product identifier | "Laptop Dell XPS 15" |
| **Description** | ❌ No | Detailed product information | "15-inch business laptop with i7 processor" |
| **Unit** | ✅ Yes | Unit of measurement | "piece", "kg", "box", "liter" |
| **Category** | ❌ No | Product category with dropdown | "Electronics", "Food", "Clothing" |
| **Reorder Level** | ❌ No | Low stock alert threshold | "10" (alert when stock ≤ 10) |

### Section 2: Add Initial Stock (Checkbox Controlled)

**When Checkbox is Checked:**

| Field | Required | Description | Example |
|-------|----------|-------------|---------|
| **Lot Number** | ❌ No | Batch/Lot identifier | "LOT-2025-001" |
| **Total Product in This Lot** | ✅ Yes | Quantity in this batch | "100", "50.5" |
| **Purchase Price** | ❌ No | Cost per unit for this lot | "৳45,000" |
| **Selling Price** | ❌ No | Default selling price | "৳55,000" |

**When Checkbox is Unchecked:**
- Entire section collapses
- Product created without initial stock
- Can add stock later via purchase transactions

## Workflow Examples

### Example 1: Full Entry with Stock

```
Step 1: Fill Product Info
├─ Product Name: "Rice Basmati Premium"
├─ Description: "Premium quality basmati rice"
├─ Unit: "kg"
├─ Category: "Food"
└─ Reorder Level: "50"

Step 2: Enable Add Initial Stock ☑
├─ Lot Number: "RICE-JAN-2025"
├─ Total Quantity: "500" kg
├─ Purchase Price: "৳60"
└─ Selling Price: "৳75"

Step 3: Click "Create Product"
Result: ✅ Product created with 500 kg stock in RICE-JAN-2025 batch
```

### Example 2: Product Only (No Stock)

```
Step 1: Fill Product Info
├─ Product Name: "T-Shirt Blue Medium"
├─ Unit: "piece"
└─ Category: "Clothing"

Step 2: Uncheck Add Initial Stock ☐

Step 3: Click "Create Product"
Result: ✅ Product created without stock (0 units)
```

### Example 3: Minimal Entry

```
Step 1: Fill Required Fields Only
├─ Product Name: "Generic Notebook"
└─ Unit: "piece"

Step 2: Uncheck Add Initial Stock ☐

Step 3: Click "Create Product"
Result: ✅ Product created with minimal information
```

## UI/UX Features

### Visual Indicators

#### Blue Card = Initial Stock Section
```
┌──────────────────────────────────────────┐
│ ☑ Add Initial Stock (Lot)               │  ← Bold header
├──────────────────────────────────────────┤
│ [Light blue background]                 │  ← Highlighted section
│                                          │
│ [White input fields]                     │  ← Clean input areas
└──────────────────────────────────────────┘
```

#### Dynamic Unit Display
```
Total Product in This Lot * [_______] pieces
                                      ^^^^^^
                            Auto-updates based on Unit field
```

#### Price Fields with Currency
```
Purchase Price  [৳ _______]
                 ^^
         Currency symbol prefix
```

### Checkbox Behavior

**Checked (Default for new products):**
- Shows full lot entry form
- Lot Number: Optional
- Quantity: Required
- Prices: Optional

**Unchecked:**
- Hides entire lot section
- Product created without batch
- Cleaner form for catalog-only entry

### Auto-Generation Feature

If Lot Number is left empty:
```
User enters: [_________________]  (empty)

System generates: LOT-1732584000000
                       ^^^^^^^^^^^^
                    Millisecond timestamp
```

## Form States

### 1. New Product (Add Mode)
- Initial Stock checkbox: ✅ Checked by default
- All lot fields visible
- Button text: "Create Product"

### 2. Edit Product Mode
- Initial Stock section: ❌ Hidden completely
- Shows only product info and pricing
- Button text: "Update Product"

### 3. Loading State
- Circular progress indicator in app bar
- All inputs disabled
- Buttons disabled

### 4. Validation Errors
```
Product Name * [________________________]
               ↑ Product name is required

Total Quantity * [________________________]
                 ↑ Quantity is required
```

## Success Messages

### With Stock Added
```
┌──────────────────────────────────────────────────┐
│ ✅ Product created with initial stock of        │
│    100 pieces                                    │
└──────────────────────────────────────────────────┘
```

### Without Stock
```
┌──────────────────────────────────────────────────┐
│ ✅ Product created successfully                  │
└──────────────────────────────────────────────────┘
```

### Updated
```
┌──────────────────────────────────────────────────┐
│ ✅ Product updated successfully                  │
└──────────────────────────────────────────────────┘
```

## Mobile vs Desktop Layout

### Mobile (Narrow Screen)
```
Product Name
[____________________]

Description
[____________________]
[____________________]

Unit          Category
[_______]     [_______]

┌──────────────────┐
│ ☑ Add Initial   │
│   Stock          │
└──────────────────┘
```

### Desktop (Wide Screen)
```
Product Name [_________________________________]

Description  [_________________________________]
             [_________________________________]

Unit [________]  Category [________]

┌─────────────────────────────────────────────┐
│ ☑ Add Initial Stock (Lot)                  │
│                                             │
│ Lot Number    [_____________]               │
│ Total Product [_____________]               │
│ Purchase [___] Selling [___]                │
└─────────────────────────────────────────────┘
```

## Keyboard Shortcuts & Navigation

### Tab Order
1. Product Name
2. Description
3. Unit
4. Category
5. Reorder Level
6. Add Initial Stock checkbox
7. Lot Number (if checked)
8. Total Quantity (if checked)
9. Purchase Price (if checked)
10. Selling Price (if checked)
11. Cancel button
12. Create/Update button

### Input Types
- **Product Name**: Text (auto-capitalizes words)
- **Description**: Multiline text
- **Unit**: Text
- **Category**: Text with dropdown suggestions
- **Reorder Level**: Numeric keyboard
- **Lot Number**: Text (auto-uppercase)
- **Quantity**: Decimal keyboard (0-9, .)
- **Prices**: Decimal keyboard (0-9, .)

## Comparison: Old vs New

### Old Form (Before)
```
Basic Information
├─ Product Name *
├─ SKU
├─ Barcode
└─ Description

Pricing & Unit
├─ Unit *
├─ Purchase Price *
├─ Selling Price *
└─ Tax Rate

Inventory Management
├─ Category
└─ Reorder Level

⚠️ Problem: No way to add initial stock
⚠️ Too many required fields
⚠️ Separate transaction needed for stock
```

### New Form (After)
```
Product Information
├─ Product Name *
├─ Description
├─ Unit *
├─ Category
└─ Reorder Level

Add Initial Stock (Optional)
├─ ☑ Enable/Disable
├─ Lot Number
├─ Total Quantity *
├─ Purchase Price
└─ Selling Price

✅ All-in-one entry
✅ Optional lot tracking
✅ Simplified required fields
```

## Benefits Summary

| Feature | Old | New |
|---------|-----|-----|
| Add stock during product creation | ❌ No | ✅ Yes |
| Required fields | 5 | 2 |
| Lot/Batch tracking | ❌ No | ✅ Yes |
| Single-step entry | ❌ No | ✅ Yes |
| Flexible (with/without stock) | ❌ No | ✅ Yes |
| Real-world aligned | ❌ No | ✅ Yes |

## Summary

The updated Add Product form provides a streamlined, lot-based entry system that:
- ✅ Supports real-world inventory receiving workflows
- ✅ Reduces required fields to bare essentials
- ✅ Enables batch/lot tracking from creation
- ✅ Offers flexibility (with or without initial stock)
- ✅ Maintains clean, intuitive UI
- ✅ Follows modern UX patterns

Perfect for businesses that receive products in bulk and need immediate lot tracking!
