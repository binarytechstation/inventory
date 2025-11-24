# Remaining Tasks Implementation Guide

## Overview
This document provides a roadmap for completing the remaining features of the inventory management system. The Invoice Settings Module foundation is complete. This guide focuses on completing the remaining UI tabs, Reports Module, and PDF/Excel export functionality.

---

## ✅ Completed Features

### 1. Database Schema (COMPLETE)
- 7 invoice settings tables with comprehensive fields
- Database migration from v2 → v3
- 6 pre-seeded invoice types
- Activity logging infrastructure

### 2. Service Layer (COMPLETE)
- `InvoiceSettingsService` - 20+ methods for CRUD operations
- Invoice number generation with auto-increment
- Activity logging with change tracking
- Complete configuration management

### 3. UI Components (COMPLETE)
- `InvoiceSettingsMainScreen` - Tabbed interface
- `GeneralSettingsTab` - FULLY FUNCTIONAL ✅
  - Invoice numbering configuration
  - Currency settings
  - Tax and discount defaults
  - Date/time formats
- `HeaderSettingsTab` - FULLY FUNCTIONAL ✅
  - Company logo upload
  - Company details
  - Tax & registration info
  - Page settings
  - Invoice title configuration
- `InvoiceActivityLogScreen` - FULLY FUNCTIONAL ✅
  - Filtering by type, action, date range
  - Detailed log view

---

## 🚧 Pending Tasks

### Task 1: Footer Settings Tab Enhancement
**Priority:** HIGH
**Estimated Complexity:** MEDIUM
**File:** `lib/ui/screens/settings/invoice_settings_tabs/footer_settings_tab.dart`

**Implementation Steps:**
1. Add text controllers for:
   - Footer text
   - Terms and conditions
   - Payment instructions
   - Bank details (name, account holder, account number, SWIFT, IBAN)

2. Add toggle switches for:
   - Show footer text
   - Show terms and conditions
   - Show payment instructions
   - Show bank details
   - Show signature
   - Show stamp
   - Show page numbers
   - Show generated info

3. Add file pickers for:
   - Signature image upload
   - Stamp image upload

4. Add dropdowns for:
   - Footer alignment (LEFT, CENTER, RIGHT)
   - Signature position (LEFT, RIGHT)
   - Stamp position (LEFT, RIGHT)

5. Add text fields for:
   - Footer font size
   - Page number format
   - Generated info text

**Similar to:** `header_settings_tab.dart` - Follow the same pattern

---

### Task 2: Body Settings Tab Enhancement
**Priority:** HIGH
**Estimated Complexity:** MEDIUM
**File:** `lib/ui/screens/settings/invoice_settings_tabs/body_settings_tab.dart`

**Implementation Steps:**
1. Party Details Section:
   - Toggle switches for each party field (name, company, address, phone, email, tax ID)
   - Party label text field

2. Item Table Configuration:
   - Toggle switches for each column (item code, description, HSN, unit, quantity, price, discount, tax, amount)
   - Item image display toggle
   - Table header customization (JSON editor or multi-line text)

3. Table Styling:
   - Border style dropdown (SOLID, DASHED, DOTTED, NONE)
   - Color pickers for:
     - Border color
     - Header background
     - Row alternate color

4. Totals Display:
   - Toggle switches for: subtotal, discount, tax, shipping, other charges, grand total
   - Text fields for labels
   - Grand total font size

5. Additional Features:
   - QR code settings (show, content template, size, position)
   - Amount in words toggle
   - Color theme dropdown

---

### Task 3: Print Settings Tab Enhancement
**Priority:** HIGH
**Estimated Complexity:** MEDIUM
**File:** `lib/ui/screens/settings/invoice_settings_tabs/print_settings_tab.dart`

**Implementation Steps:**
1. Basic Print Settings:
   - Paper size dropdown (A4, Letter, Legal, Thermal 80mm)
   - Orientation (Portrait, Landscape)
   - Layout type (Standard, Compact, Detailed)
   - Print format (PDF, Direct Print)
   - Number of copies

2. Margins Configuration:
   - Numeric fields for: top, bottom, left, right margins
   - Unit selector (mm, inches)

3. Watermark Settings:
   - Enable watermark toggle
   - Text watermark or image upload
   - Opacity slider (0-100%)
   - Rotation angle
   - Position dropdown

4. PDF Settings:
   - Compress PDF toggle
   - PDF quality slider (1-100)

5. Thermal Printer Settings:
   - Enable thermal print toggle
   - Thermal width (58mm, 80mm)
   - Font size
   - Line spacing

6. QR/Barcode:
   - Enable QR code toggle
   - QR content template
   - Enable barcode toggle
   - Barcode type dropdown (CODE128, EAN13, QR)

7. Test Print Button:
   - Generate sample invoice with current settings
   - Preview before print

---

### Task 4: Reports Service
**Priority:** HIGH
**Estimated Complexity:** HIGH
**File:** `lib/services/reports/reports_service.dart`

**Database Queries Needed:**

```dart
class ReportsService {
  // Sales Reports
  Future<Map<String, dynamic>> getSalesReport({
    DateTime? startDate,
    DateTime? endDate,
    String? customerId,
    String? productId,
  });

  Future<List<Map<String, dynamic>>> getTopSellingProducts(int limit);

  Future<List<Map<String, dynamic>>> getSalesByCustomer({
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<Map<String, dynamic>> getDailySalesSummary(DateTime date);
  Future<Map<String, dynamic>> getMonthlySalesSummary(int year, int month);

  // Purchase Reports
  Future<Map<String, dynamic>> getPurchaseReport({
    DateTime? startDate,
    DateTime? endDate,
    String? supplierId,
  });

  Future<List<Map<String, dynamic>>> getPurchasesBySupplier({
    DateTime? startDate,
    DateTime? endDate,
  });

  // Inventory Reports
  Future<List<Map<String, dynamic>>> getCurrentInventory();
  Future<List<Map<String, dynamic>>> getLowStockReport();
  Future<List<Map<String, dynamic>>> getStockValueReport();
  Future<List<Map<String, dynamic>>> getInventoryMovement({
    DateTime? startDate,
    DateTime? endDate,
  });

  // P&L Report
  Future<Map<String, dynamic>> getProfitLossReport({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    // Calculate:
    // - Total Sales Revenue
    // - Total Purchase Costs (COGS)
    // - Gross Profit
    // - Operating Expenses (if tracked)
    // - Net Profit
  }

  // Tax Reports
  Future<Map<String, dynamic>> getTaxReport({
    DateTime? startDate,
    DateTime? endDate,
  });

  // Payment Reports
  Future<Map<String, dynamic>> getPaymentModeSummary({
    DateTime? startDate,
    DateTime? endDate,
  });
}
```

**Key Calculations:**
- **Gross Profit** = Total Sales - COGS (using FIFO from product_batches)
- **Profit Margin** = (Gross Profit / Total Sales) × 100
- **Stock Value** = Sum of (quantity_remaining × purchase_price) for all batches
- **Average Sale Value** = Total Sales / Number of Transactions

---

### Task 5: Reports UI Screens
**Priority:** HIGH
**Estimated Complexity:** HIGH
**Files to Create:**
- `lib/ui/screens/reports/reports_dashboard_screen.dart`
- `lib/ui/screens/reports/sales_report_screen.dart`
- `lib/ui/screens/reports/purchase_report_screen.dart`
- `lib/ui/screens/reports/inventory_report_screen.dart`
- `lib/ui/screens/reports/profit_loss_screen.dart`

**Reports Dashboard Layout:**
```
┌─────────────────────────────────────┐
│   Reports Dashboard                 │
├─────────────────────────────────────┤
│                                     │
│  📊 Sales Reports                   │
│    - Daily/Monthly/Yearly           │
│    - By Customer                    │
│    - By Product                     │
│                                     │
│  🛒 Purchase Reports                │
│    - By Supplier                    │
│    - By Period                      │
│                                     │
│  📦 Inventory Reports               │
│    - Current Stock                  │
│    - Low Stock Alert                │
│    - Stock Valuation                │
│    - Stock Movement                 │
│                                     │
│  💰 Financial Reports               │
│    - Profit & Loss                  │
│    - Tax Summary                    │
│    - Payment Mode Analysis          │
│                                     │
│  📥 Export Options                  │
│    [PDF] [Excel] [CSV]             │
│                                     │
└─────────────────────────────────────┘
```

**Common Report Screen Features:**
1. Date range picker (Today, This Week, This Month, This Year, Custom)
2. Filter options (Customer, Supplier, Product, Payment Mode)
3. Data table with sorting
4. Summary cards showing totals
5. Charts/graphs (using fl_chart package)
6. Export buttons (PDF, Excel, CSV)

---

### Task 6: PDF/Excel Export
**Priority:** HIGH
**Estimated Complexity:** HIGH
**Packages Required:**
```yaml
dependencies:
  pdf: ^3.10.0           # PDF generation
  excel: ^2.1.0          # Excel generation
  path_provider: ^2.1.0  # Already included
  printing: ^5.11.0      # PDF preview and printing
```

**Implementation:**

#### A. PDF Export Service
**File:** `lib/services/export/pdf_export_service.dart`

```dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfExportService {
  // Invoice PDF
  Future<void> generateInvoicePdf({
    required Map<String, dynamic> transaction,
    required Map<String, dynamic> headerSettings,
    required Map<String, dynamic> footerSettings,
    required Map<String, dynamic> bodySettings,
    required Map<String, dynamic> printSettings,
  });

  // Report PDFs
  Future<void> generateSalesReportPdf(List<Map<String, dynamic>> data);
  Future<void> generateInventoryReportPdf(List<Map<String, dynamic>> data);
  Future<void> generateProfitLossReportPdf(Map<String, dynamic> data);

  // Helper methods
  pw.Widget _buildPdfHeader(Map<String, dynamic> settings);
  pw.Widget _buildPdfFooter(Map<String, dynamic> settings);
  pw.Widget _buildPdfTable(List<Map<String, dynamic>> data);
}
```

#### B. Excel Export Service
**File:** `lib/services/export/excel_export_service.dart`

```dart
import 'package:excel/excel.dart';

class ExcelExportService {
  Future<String> exportSalesReport(List<Map<String, dynamic>> data);
  Future<String> exportInventoryReport(List<Map<String, dynamic>> data);
  Future<String> exportPurchaseReport(List<Map<String, dynamic>> data);

  // Helper to style Excel sheets
  void _styleHeader(Sheet sheet);
  void _addTotalsRow(Sheet sheet, Map<String, dynamic> totals);
}
```

#### C. Integration Points
1. **Invoice Generation** - When viewing transaction details, add "Export PDF" button
2. **Report Screens** - Add export buttons at the top of each report
3. **Bulk Export** - Export multiple invoices as ZIP
4. **Email Integration** - Future: Send PDF via email

---

## 📋 Implementation Checklist

### Phase 1: Complete Settings Tabs (1-2 days)
- [ ] Enhance Footer Settings Tab
- [ ] Enhance Body Settings Tab
- [ ] Enhance Print Settings Tab
- [ ] Test all tabs with different invoice types
- [ ] Verify settings persistence

### Phase 2: Reports Service (2-3 days)
- [ ] Create ReportsService class
- [ ] Implement sales reports queries
- [ ] Implement purchase reports queries
- [ ] Implement inventory reports queries
- [ ] Implement P&L calculations
- [ ] Add unit tests for calculations

### Phase 3: Reports UI (2-3 days)
- [ ] Create Reports Dashboard
- [ ] Create Sales Report Screen with charts
- [ ] Create Purchase Report Screen
- [ ] Create Inventory Report Screen
- [ ] Create Profit & Loss Screen
- [ ] Add date range filters
- [ ] Add export buttons

### Phase 4: PDF/Excel Export (2-3 days)
- [ ] Add pdf and excel packages to pubspec.yaml
- [ ] Create PdfExportService
- [ ] Implement invoice PDF generation
- [ ] Implement report PDF generation
- [ ] Create ExcelExportService
- [ ] Implement Excel export for all reports
- [ ] Add print preview functionality
- [ ] Test on Windows platform

### Phase 5: Testing & Polish (1-2 days)
- [ ] End-to-end testing of invoice workflow
- [ ] Test PDF generation with all settings combinations
- [ ] Test Excel export with large datasets
- [ ] Performance optimization for reports
- [ ] Error handling and validation
- [ ] User documentation

---

## 🎯 Quick Start Guide

### To Continue Footer Tab:
1. Open `footer_settings_tab.dart`
2. Copy the pattern from `header_settings_tab.dart`
3. Replace controllers and fields with footer-specific ones
4. Add signature/stamp file pickers similar to logo picker
5. Test save/load functionality

### To Start Reports:
1. Create `reports_service.dart`
2. Start with simple sales query: `SELECT SUM(total_amount) FROM transactions WHERE transaction_type = 'SELL'`
3. Add date filtering
4. Expand to more complex queries
5. Create one report screen at a time

### To Add PDF Export:
1. Run: `flutter pub add pdf printing`
2. Create basic PDF with header and table
3. Test PDF preview
4. Enhance with invoice settings
5. Add footer and styling

---

## 📚 Reference Documentation

### Packages Documentation:
- **pdf**: https://pub.dev/packages/pdf
- **excel**: https://pub.dev/packages/excel
- **printing**: https://pub.dev/packages/printing
- **fl_chart** (for charts): https://pub.dev/packages/fl_chart

### SQL Query Examples:
```sql
-- Sales by period
SELECT
  DATE(transaction_date) as date,
  COUNT(*) as transaction_count,
  SUM(total_amount) as total_sales
FROM transactions
WHERE transaction_type = 'SELL'
  AND transaction_date BETWEEN ? AND ?
GROUP BY DATE(transaction_date)
ORDER BY date DESC;

-- Top selling products
SELECT
  p.name,
  SUM(tl.quantity) as total_quantity,
  SUM(tl.line_total) as total_revenue
FROM transaction_lines tl
JOIN products p ON tl.product_id = p.id
JOIN transactions t ON tl.transaction_id = t.id
WHERE t.transaction_type = 'SELL'
  AND t.transaction_date BETWEEN ? AND ?
GROUP BY p.id, p.name
ORDER BY total_revenue DESC
LIMIT ?;

-- Profit calculation (FIFO-based)
-- This requires joining with product_batches to get actual cost
SELECT
  SUM(t.total_amount) as revenue,
  SUM(pb.purchase_price * tl.quantity) as cost,
  SUM(t.total_amount) - SUM(pb.purchase_price * tl.quantity) as profit
FROM transactions t
JOIN transaction_lines tl ON t.id = tl.transaction_id
LEFT JOIN product_batches pb ON tl.batch_id = pb.id
WHERE t.transaction_type = 'SELL'
  AND t.transaction_date BETWEEN ? AND ?;
```

---

## 💡 Tips & Best Practices

1. **Incremental Development**: Complete one tab/report at a time and test thoroughly
2. **Code Reusability**: Extract common widgets (date pickers, export buttons) into separate files
3. **Performance**: Use pagination for large reports (limit 100 rows, add "Load More")
4. **Error Handling**: Always wrap database queries in try-catch
5. **User Feedback**: Show loading indicators for slow operations
6. **Testing**: Test with realistic data volumes (1000+ transactions)

---

## 🚀 Next Steps

**Immediate Next Action:** Enhance Footer Settings Tab
- File: `lib/ui/screens/settings/invoice_settings_tabs/footer_settings_tab.dart`
- Reference: `header_settings_tab.dart` (just completed)
- Time: ~2-3 hours

**After Footer Tab:** Body Settings Tab → Print Settings Tab → Reports Service → Reports UI → PDF/Excel

---

## 📞 Support

If you encounter issues:
1. Check existing similar code (header_settings_tab.dart, general_settings_tab.dart)
2. Verify database schema matches field names
3. Test settings save/load cycle
4. Check Flutter/Dart documentation for package-specific issues

---

*Last Updated: [Current Date]*
*System Version: Database v3, Invoice Settings Module Complete*
