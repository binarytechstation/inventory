# Hourly Transaction Details - Date & Hour Range Filter

## Overview
Enhanced the Hourly Transaction Reports to allow users to:
1. **Select any date** (not just today)
2. **Filter by hour range** (e.g., 9:00 AM to 5:00 PM)
3. **Default to current date** with all hours

## Features Added

### 1. Date Selection
- **Default**: Current date (today)
- **Customizable**: Click "Date" button to select any date
- **Range**: From 2020 to one year in the future
- Automatically reloads data when date changes

### 2. Hour Range Filter
- **Default**: All hours (00:00 - 23:59)
- **Customizable**: Click "Hours" button to select specific hour range
- **Options**:
  - Start Hour: 00:00 to 23:00 (or "All Hours")
  - End Hour: 00:00 to 23:00 (or "All Hours")
- Examples:
  - Morning shift: 06:00 - 12:00
  - Afternoon shift: 12:00 - 18:00
  - Evening shift: 18:00 - 23:00
  - Business hours: 09:00 - 17:00

### 3. Visual Indicators
- **Selected Date**: Displayed prominently (e.g., "26 Nov 2025")
- **Hour Range**: Shows when filtered (e.g., "Hours: 09:00 - 17:59")
- **No Filter**: Only date shown when viewing all hours

## User Interface

### Header Controls
```
┌─────────────────────────────────────────────────────────────┐
│ Hourly Transactions                                          │
│ 26 Nov 2025                                                  │
│ Hours: 09:00 - 17:59        [Date] [Hours] [Refresh] [Export]│
├─────────────────────────────────────────────────────────────┤
│ Total Transactions: 25        Grand Total: ৳85,450.00        │
└─────────────────────────────────────────────────────────────┘
```

### Action Buttons
- **Date** (📅) - Opens date picker
- **Hours** (🕐) - Opens hour range dialog
- **Refresh** (🔄) - Reloads data for current selection
- **Export** (⬇️) - Exports to Excel

## Hour Range Dialog

```
┌───────────────────────────────┐
│ Select Hour Range             │
├───────────────────────────────┤
│ Start Hour:  [09:00 ▼]       │
│                               │
│ End Hour:    [17:00 ▼]       │
├───────────────────────────────┤
│         [Cancel]  [Apply]     │
└───────────────────────────────┘
```

**Dropdowns show:**
- All Hours (clears filter)
- 00:00, 01:00, 02:00, ... 23:00

## How to Use

### View Specific Date
1. Open **Reports** → **Transaction Details**
2. Go to **Purchase (Today Hourly)** or **Sales (Today Hourly)** tab
3. Click **Date** button
4. Select desired date from calendar
5. Data automatically loads for that date

### Filter by Hour Range
1. Click **Hours** button
2. Select **Start Hour** (e.g., 09:00)
3. Select **End Hour** (e.g., 17:00)
4. Click **Apply**
5. Table shows only transactions within that hour range

### Clear Hour Filter
1. Click **Hours** button
2. Select **"All Hours"** for both start and end
3. Click **Apply**
4. Shows all transactions for the selected date

### Common Use Cases

**Morning Sales Analysis:**
- Date: Today
- Hours: 06:00 - 12:00
- Shows all morning transactions

**Compare Yesterday:**
- Date: Select yesterday
- Hours: All Hours
- Compare with today's data

**Business Hours Only:**
- Date: Any date
- Hours: 09:00 - 17:00
- Exclude off-hours transactions

**Night Shift:**
- Date: Today
- Hours: 18:00 - 23:00
- View evening sales

## Technical Implementation

### Service Layer Changes

**New Method: `getHourlyTransactions()`**
```dart
Future<List<Map<String, dynamic>>> getHourlyTransactions({
  required String type,
  required DateTime date,
  int? startHour,  // Optional hour filter
  int? endHour,    // Optional hour filter
}) async {
  // Builds DateTime range based on date and hours
  final startOfDay = startHour != null
      ? DateTime(date.year, date.month, date.day, startHour, 0, 0)
      : DateTime(date.year, date.month, date.day, 0, 0, 0);

  final endOfDay = endHour != null
      ? DateTime(date.year, date.month, date.day, endHour, 59, 59)
      : DateTime(date.year, date.month, date.day, 23, 59, 59);

  // Queries transactions between these times
}
```

**Backward Compatibility:**
```dart
Future<List<Map<String, dynamic>>> getTodayHourlyTransactions({
  required String type,
}) async {
  return getHourlyTransactions(type: type, date: DateTime.now());
}
```

### UI Layer Changes

**State Variables:**
```dart
DateTime _selectedDate = DateTime.now(); // Default to today
int? _startHour;  // null = all hours
int? _endHour;    // null = all hours
```

**Date Picker:**
```dart
Future<void> _selectDate() async {
  final picked = await showDatePicker(
    context: context,
    initialDate: _selectedDate,
    firstDate: DateTime(2020),
    lastDate: DateTime.now().add(const Duration(days: 365)),
  );
  // Updates _selectedDate and reloads data
}
```

**Hour Range Dialog:**
```dart
Future<void> _selectHourRange() async {
  // Shows dialog with two dropdowns
  // Start Hour: 00:00 - 23:00 or "All Hours"
  // End Hour: 00:00 - 23:00 or "All Hours"
  // Returns selected hours or null for "All Hours"
}
```

## Database Query

**Query Logic:**
```sql
SELECT * FROM transactions
WHERE transaction_type = ?
  AND transaction_date >= ? -- Start: YYYY-MM-DD HH:00:00
  AND transaction_date <= ? -- End: YYYY-MM-DD HH:59:59
ORDER BY transaction_date DESC
```

**Examples:**

*All hours on specific date:*
- Start: 2025-11-26 00:00:00
- End: 2025-11-26 23:59:59

*Specific hour range:*
- Start: 2025-11-26 09:00:00
- End: 2025-11-26 17:59:59

## Excel Export

**File Name Includes Date:**
- Purchase_Hourly (Today)_20251126_143000.xlsx
- Sales_Hourly (Today)_20251126_143000.xlsx

**Header Reflects Selection:**
```
Row 1: Purchase Transaction Details - Hourly (Today)
Row 2: Date: 26 Nov 2025
Row 3: [Empty]
Row 4: Headers (Invoice, Hour, Exact Time, Party, ...)
```

If hour filter is applied, could be enhanced to show:
```
Row 2: Date: 26 Nov 2025 | Hours: 09:00 - 17:59
```

## Benefits

### 1. Historical Analysis
- Review sales from any past date
- Compare performance across different dates
- Analyze patterns over time

### 2. Shift Management
- Morning shift: 06:00 - 14:00
- Evening shift: 14:00 - 22:00
- Night shift: 22:00 - 06:00
- Track shift-specific performance

### 3. Business Hours Focus
- Filter out off-hours transactions
- Focus on peak business times
- Exclude maintenance/testing transactions

### 4. Flexible Reporting
- Any date, any time range
- Quick comparison with date picker
- Export filtered data to Excel

## Code Locations

**UI Screen:** [transaction_details_screen.dart](lib/ui/screens/reports/transaction_details_screen.dart)
- Line 352-486: _HourlyReportState with date/hour selection
- Line 388-402: _selectDate() method
- Line 404-486: _selectHourRange() method
- Line 525-581: Updated header with Date and Hours buttons

**Service:** [transaction_details_service.dart](lib/services/reports/transaction_details_service.dart)
- Line 74-79: getTodayHourlyTransactions() (backward compatible)
- Line 81-137: getHourlyTransactions() with date and hour params

## Testing Checklist

### Date Selection
- [ ] Default shows today's date
- [ ] Click Date button - opens calendar
- [ ] Select past date - loads historical data
- [ ] Select today - shows today's data
- [ ] Select future date (if applicable) - handles correctly

### Hour Range Selection
- [ ] Default shows all hours (no hour filter text)
- [ ] Click Hours button - opens dialog
- [ ] Select start hour only - filters from that hour to end of day
- [ ] Select end hour only - filters from start of day to that hour
- [ ] Select both start and end - shows only that range
- [ ] Select "All Hours" - clears filter
- [ ] Hour range displays in UI (e.g., "Hours: 09:00 - 17:59")

### Data Accuracy
- [ ] Filtered data matches selected criteria
- [ ] Grand total calculates correctly for filtered data
- [ ] Transaction count accurate
- [ ] No data shown if no transactions in range

### Excel Export
- [ ] Exported file contains only filtered transactions
- [ ] File name includes date
- [ ] Header shows correct date
- [ ] All filtered transactions present in Excel

### Edge Cases
- [ ] No transactions on selected date - shows empty state
- [ ] Invalid hour range (end before start) - handles gracefully
- [ ] Same start and end hour - shows 1 hour of data
- [ ] Date in future with no data - shows empty appropriately

## Summary

✅ **Date Selection** - Pick any date, not just today
✅ **Hour Range Filter** - Filter by specific hours (e.g., 9-5)
✅ **Visual Feedback** - Shows selected date and hour range
✅ **Default Behavior** - Starts with today, all hours
✅ **Easy to Use** - Simple Date and Hours buttons
✅ **Flexible Analysis** - Historical data, shift tracking, business hours
✅ **Excel Export** - Exports filtered data

The hourly transaction report now provides complete flexibility for analyzing transactions by date and time, perfect for shift management, historical analysis, and business hour tracking!
