# Selling Price Fix - Purchase Order and Lot Details

**Date:** 2025-12-03
**Status:** ✅ Fixed and Tested

---

## Issues Reported

### Issue 1: Selling Price Not Saved in Purchase Orders
**Problem:** When creating a purchase order with a selling price, the value was being entered but showing as 0.00 in the lot details view.

**User Impact:** Users couldn't see the selling price they had entered, and profit calculations showed incorrect values.

### Issue 2: Selling Price Not Auto-filled from Product
**Problem:** When selecting an existing product in purchase order, the selling price field remained empty instead of auto-filling from the product's master data.

**User Impact:** Users had to manually look up and re-enter the selling price each time, even though it was already stored in the product record.

### Issue 3: Selling Price Not Editable in Lot Details
**Problem:** The "Edit Lot-wise Details" dialog didn't include a field to edit the selling price, making it impossible to correct or update the selling price after purchase.

**User Impact:** If the selling price needed to be changed, there was no way to do it through the UI.

### Issue 4: Selling Price Showing 0.00 in Lot Details View
**Problem:** Even after saving the selling price, the lot details view was still showing 0.00 for selling price, but the "Edit Lot-wise Details" showed the correct value.

**User Impact:** Users couldn't see the accurate selling price when viewing lot details, making profit calculations appear incorrect in the UI.

---

## Root Cause Analysis

### Issue 1: Missing Field in Database Insert
**Location:** [transaction_service.dart:528-542](lib/services/transaction/transaction_service.dart#L528-L542)

**Root Cause:** When creating a NEW product in a purchase order, the `selling_price` field was not being included in the database insert statement. Only existing products (line 509) had the selling price set.

**Code Before:**
```dart
// NEW PRODUCT: Generate new product_id and create entry
await txn.insert('products', {
  'product_id': productId,
  'lot_id': lotId,
  'product_name': productName,
  'unit_price': productData['buying_price'],
  // selling_price was MISSING here
  'unit': productData['unit'],
  'category': productData['category'] ?? '',
  // ...
});
```

### Issue 2: Selling Price Not Auto-filled
**Location:** [purchase_order_screen.dart:911-934](lib/ui/screens/transaction/purchase_order_screen.dart#L911-L934)

**Root Cause:** The `_onProductNameSelected` method loaded product details (category, description, unit) but didn't populate the selling price field.

**Code Before:**
```dart
setState(() {
  _isExistingProduct = true;
  _categoryController.text = productDetails['category'] ?? '';
  _descriptionController.text = productDetails['product_description'] ?? '';
  _unit = productDetails['unit'] ?? 'piece';
  // selling_price was NOT being loaded
});
```

### Issue 3: Selling Price Not Editable
**Location:** [products_screen.dart:940-1259](lib/ui/screens/product/products_screen.dart#L940-L1259)

**Root Cause:** The `_buildEditableLotCard` method only included read-only fields for unit price and stock, but didn't include a selling price field at all.

### Issue 4: Selling Price Not Displayed Per Lot
**Location:** [products_screen.dart:158-435](lib/ui/screens/product/products_screen.dart#L158-L435)

**Root Cause:** The `_showProductLotDetails` method was extracting the selling price once from the aggregated `product` object (line 160) and using that single value for ALL lots (line 435). Each lot can have its own selling price, so it should extract `selling_price` from each individual `lot` object in the loop.

**Code Before:**
```dart
Future<void> _showProductLotDetails(Map<String, dynamic> product) async {
  final productName = product['name'] as String;
  final sellingPrice = (product['selling_price'] as num?)?.toDouble() ?? 0.0;  // Wrong: using product's price

  // ... in the loop ...
  itemBuilder: (context, index) {
    final lot = lots[index];
    final buyingPrice = (lot['unit_price'] as num?)?.toDouble() ?? 0.0;
    // Missing: final sellingPrice = (lot['selling_price'] as num?)?.toDouble() ?? 0.0;

    // Uses the single sellingPrice from product for all lots
    final profitPerUnit = sellingPrice - buyingPrice;
  }
}
```

---

## Solutions Implemented

### Fix 1: Add Selling Price to New Product Creation

**File:** [transaction_service.dart:533](lib/services/transaction/transaction_service.dart#L533)

**Change:**
```dart
// Insert new product
await txn.insert('products', {
  'product_id': productId,
  'lot_id': lotId,
  'product_name': productName,
  'unit_price': productData['buying_price'],
  'selling_price': productData['selling_price'],  // ✅ ADDED
  'unit': productData['unit'],
  'category': productData['category'] ?? '',
  'sku': productData['sku'] ?? '',
  'barcode': productData['barcode'] ?? '',
  'product_description': productData['description'] ?? '',
  'is_active': 1,
  'created_at': DateTime.now().toIso8601String(),
  'updated_at': DateTime.now().toIso8601String(),
});
```

**Impact:** Selling price is now properly saved when creating new products in purchase orders.

---

### Fix 2: Auto-fill Selling Price from Product

**File:** [purchase_order_screen.dart:921-925](lib/ui/screens/transaction/purchase_order_screen.dart#L921-L925)

**Change:**
```dart
setState(() {
  _isExistingProduct = true;
  _categoryController.text = productDetails['category'] ?? '';
  _descriptionController.text = productDetails['product_description'] ?? '';
  _unit = productDetails['unit'] ?? 'piece';

  // ✅ ADDED: Auto-fill selling price from product (can be edited)
  final sellingPrice = productDetails['selling_price'];
  if (sellingPrice != null) {
    _sellingPriceController.text = sellingPrice.toString();
  }

  // Note: SKU, barcode, and buying price are NOT auto-filled
  // because each lot can have different values
});
```

**Impact:** When selecting an existing product, the selling price automatically fills from the product's master data, but remains editable for lot-specific adjustments.

---

### Fix 3: Add Editable Selling Price to Lot Details

**File:** [products_screen.dart:940-1259](lib/ui/screens/product/products_screen.dart#L940-L1259)

**Changes:**

#### 3.1: Add Selling Price Controller
```dart
Widget _buildEditableLotCard(Map<String, dynamic> lot, int serialNumber) {
  final lotId = lot['lot_id'] as int;
  final productId = lot['product_id'] as int;
  final unitPrice = (lot['unit_price'] as num?)?.toDouble() ?? 0.0;
  final sellingPrice = (lot['selling_price'] as num?)?.toDouble() ?? 0.0;  // ✅ ADDED

  final lotNameController = TextEditingController(text: productName);
  final sellingPriceController = TextEditingController(text: sellingPrice.toStringAsFixed(2));  // ✅ ADDED
  final notesController = TextEditingController(text: notes);
```

#### 3.2: Add Selling Price Field to UI
```dart
// Read-only and editable fields in a grid
Row(
  children: [
    Expanded(
      child: TextField(
        controller: TextEditingController(text: unitPrice.toStringAsFixed(2)),
        decoration: InputDecoration(
          labelText: 'Buying Price ($_currencySymbol)',  // ✅ RENAMED
          prefixIcon: const Icon(Icons.shopping_cart),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
        enabled: false,  // Read-only
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: TextField(
        controller: sellingPriceController,  // ✅ ADDED
        decoration: InputDecoration(
          labelText: 'Selling Price ($_currencySymbol)',  // ✅ NEW FIELD
          prefixIcon: const Icon(Icons.sell),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        keyboardType: TextInputType.number,  // Editable
      ),
    ),
  ],
),
```

#### 3.3: Update Save Logic
```dart
onPressed: () async {
  try {
    // ✅ ADDED: Parse and validate selling price
    final newSellingPrice = double.tryParse(sellingPriceController.text.trim());
    if (newSellingPrice == null || newSellingPrice < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid selling price'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await _productService.updateLotData(
      productId: productId,
      lotId: lotId,
      lotName: lotNameController.text.trim().isEmpty ? null : lotNameController.text.trim(),
      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      sellingPrice: newSellingPrice,  // ✅ ADDED
    );

    // ... success handling
  } catch (e) {
    // ... error handling
  }
},
```

#### 3.4: Update Info Message
```dart
// ✅ UPDATED INFO MESSAGE
Text(
  'You can edit: Lot Name, Selling Price, and Description. Buying price, stock, and date are read-only.',
  style: TextStyle(
    fontSize: 12,
    color: Colors.blue.shade900,
  ),
),
```

**Impact:** Users can now view and edit the selling price for each lot through the "Edit Lot-wise Details" dialog.

---

### Fix 4: Extract Selling Price Per Lot

**File:** [products_screen.dart:158-253](lib/ui/screens/product/products_screen.dart#L158-L253)

**Change:**

#### 4.1: Remove Single Selling Price Variable
```dart
// REMOVED this line:
// final sellingPrice = (product['selling_price'] as num?)?.toDouble() ?? 0.0;

Future<void> _showProductLotDetails(Map<String, dynamic> product) async {
  final productName = product['name'] as String;
  // No longer extracting selling price from product here

  try {
    final lots = await _productService.getAllLotsForProduct(productName);
```

#### 4.2: Get Selling Price From Each Lot
```dart
itemBuilder: (context, index) {
  final lot = lots[index];
  final lotDescription = lot['lot_description'] as String?;
  final receivedDate = lot['received_date'] as String?;
  final stock = (lot['current_stock'] as num?)?.toDouble() ?? 0.0;
  final buyingPrice = (lot['unit_price'] as num?)?.toDouble() ?? 0.0;
  final sellingPrice = (lot['selling_price'] as num?)?.toDouble() ?? 0.0;  // ✅ ADDED: Get from each lot
  final unit = lot['unit'] as String? ?? 'piece';
  final serialNumber = index + 1;

  // Calculate profit margin (now using lot-specific selling price)
  final profitPerUnit = sellingPrice - buyingPrice;
  final profitMargin = buyingPrice > 0 ? ((profitPerUnit / buyingPrice) * 100) : 0.0;
```

**Impact:** Each lot now displays its own selling price correctly, allowing for different selling prices per lot if needed. Profit calculations are now accurate for each individual lot.

---

## Files Modified

1. **[lib/services/transaction/transaction_service.dart](lib/services/transaction/transaction_service.dart)**
   - Line 533: Added `selling_price` field to new product creation

2. **[lib/ui/screens/transaction/purchase_order_screen.dart](lib/ui/screens/transaction/purchase_order_screen.dart)**
   - Lines 921-925: Auto-fill selling price when existing product selected

3. **[lib/ui/screens/product/products_screen.dart](lib/ui/screens/product/products_screen.dart)**
   - Line 160: Removed incorrect single selling price extraction from product
   - Line 253: Added selling price extraction from each lot object
   - Line 944: Added sellingPrice variable extraction (Edit Lot dialog)
   - Line 952: Added sellingPriceController (Edit Lot dialog)
   - Lines 1086-1117: Reorganized price fields layout (buying + selling)
   - Lines 1121-1159: Reorganized stock and date fields
   - Line 1190: Updated info message
   - Lines 1208-1220: Added selling price validation
   - Line 1227: Added sellingPrice parameter to updateLotData call

---

## Testing Results

### Static Analysis
```bash
flutter analyze lib/ui/screens/product/products_screen.dart
               lib/services/transaction/transaction_service.dart
               lib/ui/screens/transaction/purchase_order_screen.dart
```

**Result:** 18 info-level issues found (deprecation warnings, unused elements)
**Critical Issues:** 0
**Blocking Issues:** 0

### Manual Testing Checklist

#### Purchase Order - New Product
- [x] Enter selling price when creating new product in purchase order
- [x] Selling price saves to database
- [x] Selling price appears in lot details view
- [x] Profit calculation shows correct values

#### Purchase Order - Existing Product
- [x] Select existing product from dropdown
- [x] Selling price auto-fills from product master data
- [x] Can edit auto-filled selling price if needed
- [x] Custom selling price saves correctly

#### Lot Details Dialog
- [x] "Edit Lot-wise Details" button works
- [x] Selling price field appears in dialog
- [x] Selling price is editable (not read-only)
- [x] Can save updated selling price
- [x] Updated price reflects in lot details view
- [x] Profit margin recalculates correctly

---

## User Experience Improvements

### Before
1. ❌ Selling price entered but showed as 0.00
2. ❌ Had to manually re-enter selling price for existing products
3. ❌ No way to edit selling price after purchase
4. ❌ Profit calculations incorrect due to missing selling price

### After
1. ✅ Selling price saves and displays correctly
2. ✅ Selling price auto-fills for existing products
3. ✅ Can edit selling price through "Edit Lot-wise Details"
4. ✅ Profit calculations accurate with correct selling price
5. ✅ Clear visual distinction between buying price (read-only) and selling price (editable)

---

## Data Flow

### Purchase Order Creation Flow
```
1. User selects/enters product name
   ↓
2. If existing product: Auto-fill selling price from master data
   ↓
3. User enters/edits buying price and selling price
   ↓
4. User saves purchase order
   ↓
5. TransactionService.createPurchaseOrderWithLot()
   ↓
6. Product record created with selling_price field
   ↓
7. Selling price visible in lot details
```

### Lot Editing Flow
```
1. User clicks "Edit Lot-wise Details"
   ↓
2. Dialog loads lot data including selling_price
   ↓
3. Selling price displayed in editable field
   ↓
4. User modifies selling price
   ↓
5. User clicks "Save Changes"
   ↓
6. ProductService.updateLotData() with sellingPrice parameter
   ↓
7. Database updated with new selling price
   ↓
8. Updated price reflects immediately
```

---

## Database Schema

The `products` table already had the `selling_price` column. No schema changes were required.

**Relevant Fields:**
- `product_id` - Product identifier
- `lot_id` - Lot identifier
- `unit_price` - Buying price (cost)
- `selling_price` - Selling price (revenue) **← Now properly populated**
- `product_name` - Product name
- `unit` - Unit of measurement

---

## Best Practices Applied

### 1. Data Consistency
- Selling price now consistently saved across all product creation paths
- Auto-fill ensures consistency with master data while allowing lot-specific overrides

### 2. User Experience
- Clear visual distinction: Buying Price (read-only) vs Selling Price (editable)
- Validation prevents invalid prices (negative or non-numeric)
- Informative messages guide user on what can be edited

### 3. Code Quality
- Used existing ProductService.updateLotData() method (no duplication)
- Proper validation before database operations
- Clear variable naming (unitPrice vs sellingPrice)

### 4. Error Handling
- Validates selling price before saving
- Shows clear error message for invalid input
- Try-catch blocks for database operations

---

## Future Considerations

### Potential Enhancements
1. **Bulk Price Update:** Allow updating selling price for multiple lots at once
2. **Price History:** Track selling price changes over time
3. **Profit Analysis:** Add reports showing profit margins by lot
4. **Price Suggestions:** Auto-suggest selling price based on markup percentage
5. **Price Alerts:** Notify when selling price is below cost

### Related Features
- Profit & Loss reports now have accurate data
- Product performance analytics improved
- Pricing strategy decisions now data-driven

---

## Summary

All four issues have been successfully resolved:

1. ✅ **Selling price now saves correctly** when creating purchase orders
2. ✅ **Auto-fill works** for existing products (while remaining editable)
3. ✅ **Lot details dialog** now includes editable selling price field
4. ✅ **Lot details view** now displays the correct selling price for each lot

### Impact
- Purchase orders now capture complete pricing information
- Profit calculations are accurate
- Users can manage pricing effectively
- Data integrity maintained across the system

---

**Fixes Applied:** 2025-12-03
**Status:** ✅ Completed and Tested
**Build Status:** ✅ No blocking issues

---

*End of Fix Documentation*
