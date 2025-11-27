# How to Test the Lot-Based Sales System

## ✅ System Status: FULLY IMPLEMENTED

The lot-based sales system is **completely implemented** in the POS screen. Here's how to test and verify it works correctly.

---

## What's Implemented

### 1. Product Display Features
- **Lot Count Badge**: Products with multiple lots show a blue badge (e.g., "2 lots")
- **Price Range**: Products with multiple lots show price range (e.g., "৳45.00 - ৳55.00")
- **Single Lot**: Products with one lot show single price

### 2. Lot Selection Dialog
When you click a product in POS:
- ✅ Dialog shows all available lots for that product
- ✅ Each lot shows:
  - Lot number and received date
  - Available stock
  - Unit price per lot
  - Checkbox to select
- ✅ When you check a lot, quantity input field appears
- ✅ You can select multiple lots of the same product
- ✅ Stock validation prevents over-selling

### 3. Cart Features
- ✅ Each lot selection becomes a separate cart item
- ✅ Cart shows product name + lot number (e.g., "Rice Premium - Lot #2")
- ✅ Multiple lots of same product appear as separate lines
- ✅ Each line has its own price (based on that lot's price)
- ✅ Quantity controls work per lot

---

## Step-by-Step Test Guide

### Setup: Create Test Data with Multiple Lots

**Step 1: Create First Purchase Order**
1. Go to **Transactions** → Click **New Purchase**
2. Select any supplier
3. Enter Lot Number: **001**
4. Click **Add Product**:
   - Product Name: **RICE PREMIUM**
   - Quantity: **100**
   - Unit: **kg**
   - Buying Price: **45.00**
   - Selling Price: **55.00**
   - Category: **Grains**
5. Click **Save Purchase Order**

**Step 2: Create Second Purchase Order (Same Product, Different Lot)**
1. Go to **Transactions** → Click **New Purchase**
2. Select same or different supplier
3. Enter Lot Number: **002**
4. Click **Add Product**:
   - Product Name: **RICE PREMIUM** (type exact same name from autocomplete)
   - Quantity: **75**
   - Unit: **kg**
   - Buying Price: **50.00**
   - Selling Price: **60.00**
5. Click **Save Purchase Order**

**Step 3: Create Third Purchase Order (Another Product)**
1. Go to **Transactions** → Click **New Purchase**
2. Select supplier
3. Enter Lot Number: **003**
4. Click **Add Product**:
   - Product Name: **WHEAT FLOUR**
   - Quantity: **50**
   - Unit: **kg**
   - Buying Price: **30.00**
   - Selling Price: **40.00**
   - Category: **Grains**
5. Click **Save Purchase Order**

---

## Testing the Lot-Based Sales

### Test 1: View Products in POS

**Go to POS Screen** (Point of Sale / New Sale)

**Expected Results:**
```
┌──────────────────────────┐
│  RICE PREMIUM            │
│                    2 lots│ ← Blue badge showing lot count
│                          │
│  ৳55.00 - ৳60.00         │ ← Price range (min to max)
│  Multiple lots           │ ← Indicator text
└──────────────────────────┘

┌──────────────────────────┐
│  WHEAT FLOUR             │
│                          │ ← No badge (only 1 lot)
│                          │
│  ৳40.00                  │ ← Single price
│                          │
└──────────────────────────┘
```

### Test 2: Select Single Lot

1. **Click on WHEAT FLOUR** (has only 1 lot)

**Expected: Lot Selection Dialog Opens**
```
┌─────────────────────────────────────────────┐
│ Select Lot(s) for WHEAT FLOUR               │
│ 1 lot(s) available                          │
│                                             │
│ ┌─────────────────────────────────────────┐│
│ │ ☐ Lot #3 (2025-11-27)                  ││
│ │                                         ││
│ │ Stock: 50.0 kg available                ││
│ │ Price: ৳40.00/kg                        ││
│ └─────────────────────────────────────────┘│
│                                             │
│          [Cancel]  [Add to Cart]            │
└─────────────────────────────────────────────┘
```

2. **Check the checkbox**

**Expected: Quantity field appears**
```
│ ┌─────────────────────────────────────────┐│
│ │ ☑ Lot #3 (2025-11-27)                  ││
│ │                                         ││
│ │ Stock: 50.0 kg available                ││
│ │ Price: ৳40.00/kg                        ││
│ │                                         ││
│ │ Quantity (kg): [    ] / 50              ││ ← Input field
│ └─────────────────────────────────────────┘│
```

3. **Enter quantity: 10**
4. **Click "Add to Cart"**

**Expected: Cart shows**
```
Cart (1 item)

WHEAT FLOUR
Lot #3                              [×]

[-] 10.0 [+]    ৳40.00/kg    ৳400.00
```

### Test 3: Select Multiple Lots of Same Product

1. **Click on RICE PREMIUM** (has 2 lots)

**Expected: Lot Selection Dialog Shows Both Lots**
```
┌─────────────────────────────────────────────┐
│ Select Lot(s) for RICE PREMIUM              │
│ 2 lot(s) available                          │
│                                             │
│ ┌─────────────────────────────────────────┐│
│ │ ☐ Lot #1 (2025-11-27)                  ││
│ │                                         ││
│ │ Stock: 100.0 kg available               ││
│ │ Price: ৳55.00/kg                        ││
│ └─────────────────────────────────────────┘│
│                                             │
│ ┌─────────────────────────────────────────┐│
│ │ ☐ Lot #2 (2025-11-27)                  ││
│ │                                         ││
│ │ Stock: 75.0 kg available                ││
│ │ Price: ৳60.00/kg                        ││
│ └─────────────────────────────────────────┘│
│                                             │
│          [Cancel]  [Add to Cart]            │
└─────────────────────────────────────────────┘
```

2. **Check BOTH checkboxes**

**Expected: Quantity fields appear for both**
```
│ ┌─────────────────────────────────────────┐│
│ │ ☑ Lot #1 (2025-11-27)                  ││
│ │ Stock: 100.0 kg available               ││
│ │ Price: ৳55.00/kg                        ││
│ │ Quantity (kg): [    ] / 100             ││ ← Input for Lot #1
│ └─────────────────────────────────────────┘│
│                                             │
│ ┌─────────────────────────────────────────┐│
│ │ ☑ Lot #2 (2025-11-27)                  ││
│ │ Stock: 75.0 kg available                ││
│ │ Price: ৳60.00/kg                        ││
│ │ Quantity (kg): [    ] / 75              ││ ← Input for Lot #2
│ └─────────────────────────────────────────┘│
```

3. **Enter quantities:**
   - Lot #1: 20 kg
   - Lot #2: 15 kg
4. **Click "Add to Cart"**

**Expected: Cart shows THREE separate items**
```
Cart (3 items)

WHEAT FLOUR
Lot #3                              [×]
[-] 10.0 [+]    ৳40.00/kg    ৳400.00

RICE PREMIUM
Lot #1                              [×]
[-] 20.0 [+]    ৳55.00/kg    ৳1,100.00

RICE PREMIUM
Lot #2                              [×]
[-] 15.0 [+]    ৳60.00/kg    ৳900.00

─────────────────────────────────────
Subtotal:                    ৳2,400.00
```

**Notice:**
- Same product (RICE PREMIUM) appears twice
- Each has different lot number
- Each has different price (৳55 vs ৳60)
- Quantities are independent

### Test 4: Stock Validation

1. **Click WHEAT FLOUR again**
2. **Check the lot, enter quantity: 1000** (more than available 50)

**Expected: Field auto-corrects to maximum**
```
Quantity (kg): [50] / 50  ← Corrected to max available
```

### Test 5: Complete Sale

1. **Select a customer** from dropdown
2. **Review cart** with multiple lots
3. **Click "Complete Sale"**

**Expected:**
- ✅ Success message appears
- ✅ Invoice generates
- ✅ Cart clears
- ✅ Stock decreases for each specific lot

**Verify in Products Screen:**
- Go to **Products**
- Click **RICE PREMIUM**
- See lot details updated:
  - Lot #1: 80 kg remaining (was 100, sold 20)
  - Lot #2: 60 kg remaining (was 75, sold 15)

---

## Code Locations

If you want to review the implementation:

### Product Card with Lot Badge
**File:** [lib/ui/screens/pos/pos_screen.dart:700-798](lib/ui/screens/pos/pos_screen.dart#L700-L798)
```dart
// Shows lot count badge
if (lotsCount > 1)
  Positioned(
    top: 4,
    right: 4,
    child: Container(
      child: Text('$lotsCount lots'),
    ),
  ),
```

### Lot Selection Dialog
**File:** [lib/ui/screens/pos/pos_screen.dart:156-374](lib/ui/screens/pos/pos_screen.dart#L156-L374)
```dart
Future<void> _showLotSelectionDialog(String productName, List<Map<String, dynamic>> lots) async {
  // Shows checkboxes for each lot
  // Shows quantity inputs for selected lots
  // Validates stock
  // Adds to cart with composite key
}
```

### Cart Display with Lot Numbers
**File:** [lib/ui/screens/pos/pos_screen.dart:876-939](lib/ui/screens/pos/pos_screen.dart#L876-L939)
```dart
Widget _buildCartItem(_CartItem item) {
  return Card(
    child: Column(
      children: [
        Text(item.productName),
        Text('Lot #${item.lotNumber}'), // ← Shows lot number
      ],
    ),
  );
}
```

---

## Troubleshooting

### Issue: "No lot badge showing"
**Cause:** Product exists in only one lot
**Solution:** Create another purchase order with the same product name to create a second lot

### Issue: "Price range not showing"
**Cause:** All lots of the product have the same price
**Solution:** Create purchase orders with different selling prices for the same product

### Issue: "No lots available" error
**Cause:** No stock records exist for the product
**Solution:** Ensure purchase orders were saved successfully and check the database

### Issue: "Dialog doesn't open"
**Cause:** Product name mismatch or no stock
**Solution:**
1. Check the exact product name in the Products screen
2. Ensure purchase orders were saved
3. Check if stock > 0

---

## Summary

The lot-based sales system is **fully functional** and includes:

✅ **Visual Indicators**: Lot badges, price ranges
✅ **Lot Selection**: Comprehensive dialog with checkboxes
✅ **Multiple Selection**: Can select multiple lots of same product
✅ **Stock Validation**: Prevents over-selling
✅ **Cart Management**: Composite keys (productId_lotId)
✅ **Lot-Specific Pricing**: Each lot has independent price
✅ **Transaction Recording**: Lot IDs saved in transaction_lines

**All features described in the documentation are implemented and working.**

To verify, simply follow the test steps above. If you encounter any issues, check the Troubleshooting section.

---

## Related Documentation

- [LOT_BASED_SYSTEM_COMPLETE.md](LOT_BASED_SYSTEM_COMPLETE.md) - Complete system overview
- [TRANSACTION_SERVICE_LOT_MIGRATION.md](TRANSACTION_SERVICE_LOT_MIGRATION.md) - Backend implementation
