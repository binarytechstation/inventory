# Inventory Report Black Screen Fix - Lot-Based System Compatibility

## Issue Description
Black screen appeared in the Inventory Report even when products existed in the database. This issue occurred **after implementing the lot-based inventory system**.

## Root Cause
When the inventory system was changed from simple product tracking to **lot-based tracking**, the database query structure changed significantly:

### Query Changes:
The `getInventoryReport()` query in [reports_service.dart](lib/services/reports/reports_service.dart:77-103) now returns:
- `product_name as name` (instead of direct product_name)
- `COUNT(DISTINCT p.lot_id) as lot_count` (NEW field for lot tracking)
- Aggregated stock across all lots using `SUM(s.count)`
- **No `sku` field** (removed in lot-based system)

### DataTable Issue:
The Inventory Report DataTable in [reports_screen.dart](lib/ui/screens/reports/reports_screen.dart:938-973) was trying to access:
- `item['sku']` - **This field doesn't exist in lot-based query results**
- This caused a runtime error and black screen rendering

## Solution Implemented

### File: `/lib/ui/screens/reports/reports_screen.dart` (Lines 938-973)

#### Change 1: Updated DataTable Columns
**Before:**
```dart
columns: const [
  DataColumn(label: Text('Product')),
  DataColumn(label: Text('SKU')),  // ❌ SKU doesn't exist in lot-based system
  DataColumn(label: Text('Stock')),
  DataColumn(label: Text('Value')),
],
```

**After:**
```dart
columns: const [
  DataColumn(label: Text('Product')),
  DataColumn(label: Text('Lots')),  // ✅ Changed to show lot count
  DataColumn(label: Text('Stock')),
  DataColumn(label: Text('Value')),
],
```

#### Change 2: Updated DataRow Cells
**Before:**
```dart
rows: items.map((item) {
  final reorderLevel = (item['reorder_level'] as int?) ?? 0;  // ❌ Wrong type
  // ...
  cells: [
    DataCell(Text(item['name'] ?? '')),
    DataCell(Text(item['sku'] ?? '')),  // ❌ Field doesn't exist
    DataCell(Text(stock.toStringAsFixed(1))),
    DataCell(Text('...')),
  ]
}).toList(),
```

**After:**
```dart
rows: items.map((item) {
  final stock = (item['current_stock'] as num?)?.toDouble() ?? 0;
  final reorderLevel = (item['reorder_level'] as num?)?.toDouble() ?? 0;  // ✅ Fixed type
  final lotCount = (item['lot_count'] as int?) ?? 0;  // ✅ NEW: Read lot count
  final isLowStock = stock <= reorderLevel;

  return DataRow(
    color: isLowStock
        ? WidgetStateProperty.all(Colors.orange[50])
        : null,
    cells: [
      DataCell(
        SizedBox(
          width: 200,
          child: Text(
            item['name'] ?? '',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      DataCell(Text(lotCount.toString())),  // ✅ Show lot count instead of SKU
      DataCell(Text(stock.toStringAsFixed(1))),
      DataCell(Text('$_currencySymbol${(item['inventory_value'] as num?)?.toStringAsFixed(2) ?? '0.00'}')),
    ],
  );
}).toList(),
```

## Query Structure (For Reference)

### File: `/lib/services/reports/reports_service.dart` (Lines 77-103)

```sql
SELECT
  p.product_id,
  p.product_name as name,                    -- Returns as 'name'
  p.unit,
  p.category,
  SUM(s.count) as current_stock,             -- Aggregated across all lots
  SUM(s.count - COALESCE(s.reserved_quantity, 0)) as available_stock,
  MIN(s.reorder_level) as reorder_level,     -- Returns as num (not int)
  COUNT(DISTINCT p.lot_id) as lot_count,     -- NEW: Number of lots per product
  AVG(p.unit_price) as avg_cost,
  COALESCE(SUM(s.count * p.unit_price), 0) as inventory_value
FROM products p
INNER JOIN stock s ON p.product_id = s.product_id AND p.lot_id = s.lot_id
WHERE p.is_active = 1
GROUP BY p.product_id, p.product_name, p.unit, p.category
ORDER BY p.product_name ASC
```

## Key Changes Summary

| Aspect | Before (Simple Inventory) | After (Lot-Based) |
|--------|---------------------------|-------------------|
| **Column Header** | "SKU" | "Lots" |
| **Data Field** | `item['sku']` | `item['lot_count']` |
| **Stock Tracking** | Direct product stock | Aggregated across lots |
| **reorder_level Type** | `int?` | `num?` |
| **Product Name** | Direct field | Aliased as 'name' |

## Testing Instructions

### Test 1: Inventory Report with Products
1. Run app: `flutter run -d macos`
2. Ensure you have products in inventory (with lots assigned)
3. Navigate: Dashboard → Reports → Inventory Report
4. **Expected:**
   - See DataTable with columns: Product, Lots, Stock, Value
   - Each row shows product name, number of lots, total stock, inventory value
   - No black screen
5. **Before Fix:** Black screen due to missing 'sku' field

### Test 2: Low Stock Highlighting
1. Set a product's stock below its reorder level
2. Open Inventory Report
3. **Expected:** Row highlighted in orange[50] background
4. Shows visual indicator for low stock items

### Test 3: Empty Inventory
1. Remove all products from database
2. Open Inventory Report
3. **Expected:** See empty state with icon and message "No products in inventory"
4. No black screen

### Test 4: Multiple Lots Per Product
1. Create a product with multiple lots (e.g., different purchase dates)
2. Open Inventory Report
3. **Expected:**
   - Product appears once (aggregated)
   - "Lots" column shows count (e.g., "3" for 3 lots)
   - Stock shows total across all lots

## Benefits of Lot-Based System

✅ **Better Traceability** - Track inventory by purchase batch/date
✅ **Expiry Management** - Monitor lot expiry dates
✅ **Quality Control** - Identify issues by lot
✅ **FIFO/LIFO Support** - Implement stock rotation policies
✅ **Accurate Costing** - Different lots may have different costs

## Migration Notes

If upgrading from simple to lot-based inventory:
1. Existing products need lot assignments
2. SKU field is no longer used in reports
3. Stock queries must aggregate across lots
4. All reports must be updated to use lot-based queries

## Files Modified

1. **lib/ui/screens/reports/reports_screen.dart**
   - Lines 938-973: Updated Inventory Report DataTable
   - Changed "SKU" column to "Lots" column
   - Added `lotCount` variable from `item['lot_count']`
   - Fixed `reorder_level` type casting from `int?` to `num?`
   - Added product name wrapping with SizedBox

## Related Issues Fixed

This fix is part of a larger series of report improvements:
1. ✅ Sales Summary empty state
2. ✅ Purchase Summary empty state
3. ✅ Profit & Loss empty state
4. ✅ Product Performance empty state
5. ✅ Customer Report empty state
6. ✅ Supplier Report empty state
7. ✅ Category Analysis empty state
8. ✅ **Inventory Report lot-based compatibility** (This fix)

## Future Enhancements

1. **Lot Details Dialog**: Click on lot count to see individual lot details
2. **Expiry Tracking**: Show lots near expiry in separate column
3. **Lot Performance**: Show best/worst performing lots
4. **Export by Lot**: Export inventory report with lot breakdowns

---

**Status:** ✅ **FIXED**
**Last Updated:** 2025-12-04
**Tested On:** macOS
**Developer:** Claude Code Assistant
**System:** Lot-Based Inventory
