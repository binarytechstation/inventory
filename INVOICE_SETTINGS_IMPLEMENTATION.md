# Invoice Settings Module - Implementation Documentation

## Overview
This document describes the comprehensive Invoice Settings Module implementation for the inventory management system. The module provides professional invoice configuration capabilities with detailed settings for headers, footers, body, printing, and activity tracking.

## Database Schema

### Tables Implemented

#### 1. invoice_settings
General invoice configuration for different invoice types.

**Key Fields:**
- `invoice_type`: Type of invoice (SALE, PURCHASE, etc.)
- `prefix`: Invoice number prefix (e.g., INV, PUR)
- `starting_number`, `current_number`: Invoice numbering
- `number_format`: Format template (e.g., PREFIX-NNNN)
- `enable_auto_increment`: Auto-increment invoice numbers
- `reset_period`: NEVER, YEARLY, MONTHLY, DAILY
- `currency_code`, `currency_symbol`: Currency settings
- `default_tax_rate`: Default tax percentage
- `enable_tax_by_default`, `enable_discount_by_default`: Defaults
- `decimal_places`: Precision for monetary values
- `date_format`, `time_format`: Display formats

#### 2. invoice_header_settings
Header configuration for invoices.

**Key Fields:**
- `show_company_logo`: Display company logo
- `logo_path`, `logo_width`, `logo_height`, `logo_position`: Logo settings
- `company_name`, `company_tagline`: Company branding
- `show_company_address`, `company_address`: Address display
- `show_company_phone`, `company_phone`: Phone display
- `show_company_email`, `company_email`: Email display
- `show_company_website`, `company_website`: Website display
- `show_tax_id`, `tax_id_label`, `tax_id`: Tax ID settings
- `show_registration_number`, `registration_number`: Registration
- `page_size`, `page_orientation`: A4, Letter, Portrait, Landscape
- `header_alignment`: LEFT, CENTER, RIGHT
- `header_background_color`, `header_text_color`: Styling
- `show_invoice_title`, `invoice_title`, `title_font_size`: Title settings
- `show_invoice_number`, `show_invoice_date`, `show_due_date`: Display options
- `custom_field1_label`, `custom_field1_value`: Custom fields

#### 3. invoice_footer_settings
Footer configuration for invoices.

**Key Fields:**
- `show_footer_text`, `footer_text`: Footer message
- `footer_font_size`, `footer_alignment`: Styling
- `show_terms_and_conditions`, `terms_and_conditions`: T&C display
- `show_payment_instructions`, `payment_instructions`: Payment info
- `show_bank_details`: Display bank information
- `bank_name`, `account_holder_name`, `account_number`: Bank details
- `swift_code`, `iban`: International banking codes
- `show_signature`, `signature_label`: Signature settings
- `signature_image_path`, `signature_position`: Signature display
- `show_stamp`, `stamp_image_path`, `stamp_position`: Stamp settings
- `show_page_numbers`, `page_number_format`: Pagination
- `show_generated_info`, `generated_info_text`: Generation info
- `footer_background_color`, `footer_text_color`: Styling

#### 4. invoice_body_settings
Body/content configuration for invoices.

**Key Fields:**
- `show_party_details`: Display customer/supplier info
- `party_label`: "Bill To", "Supplier", etc.
- `show_party_name`, `show_party_company`, `show_party_address`: Party fields
- `show_party_phone`, `show_party_email`, `show_party_tax_id`: Contact info
- `show_item_image`: Display product images
- `show_item_code`, `show_item_description`: Item display
- `show_hsn_code`: HSN/SAC code for tax compliance
- `show_unit_column`, `show_quantity_column`: Table columns
- `show_unit_price_column`, `show_discount_column`: Price columns
- `show_tax_column`, `show_amount_column`: Calculation columns
- `item_table_headers`: JSON array of column headers
- `table_border_style`, `table_border_color`: Table styling
- `table_header_bg_color`, `table_row_alternate_color`: Colors
- `show_subtotal`, `show_total_discount`, `show_total_tax`: Totals display
- `show_shipping_charges`, `shipping_charges_label`: Shipping
- `show_other_charges`, `other_charges_label`: Additional charges
- `show_grand_total`, `grand_total_label`, `grand_total_font_size`: Total
- `show_amount_in_words`, `amount_in_words_label`: Text amount
- `show_qr_code`, `qr_code_content`, `qr_code_size`, `qr_code_position`: QR code
- `color_theme`: Color scheme selection

#### 5. invoice_type_settings
Configuration for different invoice types.

**Key Fields:**
- `type_code`: Unique code (SALE, PURCHASE, QUOTATION, etc.)
- `type_name`: Display name
- `prefix`: Invoice number prefix
- `title`: Invoice document title
- `enable_party_selection`: Allow customer/supplier selection
- `party_label`: Label for party field
- `enable_items`, `enable_tax_calculation`, `enable_discount`: Features
- `enable_payment_mode`, `enable_notes`: Additional features
- `default_status`: DRAFT, COMPLETED, PENDING
- `requires_approval`: Approval workflow
- `affects_inventory`: Inventory impact
- `inventory_effect`: INCREASE, DECREASE, NONE
- `show_in_dashboard`: Dashboard visibility
- `icon_name`, `color_code`: UI styling
- `template_path`: Custom template
- `display_order`: Sort order

**Pre-seeded Invoice Types:**
1. **SALE** - Sales Invoice (Green, decreases inventory)
2. **PURCHASE** - Purchase Invoice (Blue, increases inventory)
3. **QUOTATION** - Price Quotation (Orange, no inventory impact)
4. **RETURN_SALE** - Sales Return (Red, increases inventory)
5. **RETURN_PURCHASE** - Purchase Return (Pink, decreases inventory)
6. **DELIVERY_CHALLAN** - Delivery Note (Purple, no inventory impact)

#### 6. invoice_print_settings
Print configuration for invoices.

**Key Fields:**
- `paper_size`: A4, Letter, Legal, Thermal
- `paper_orientation`: PORTRAIT, LANDSCAPE
- `layout_type`: STANDARD, COMPACT, DETAILED
- `print_format`: PDF, Direct Print
- `printer_name`: Selected printer
- `copies`: Number of copies
- `print_color`: Color vs B&W
- `print_duplex`: Single/double-sided
- `margin_top`, `margin_bottom`, `margin_left`, `margin_right`: Margins
- `show_watermark`, `watermark_text`, `watermark_image_path`: Watermark
- `watermark_opacity`, `watermark_rotation`, `watermark_position`: Styling
- `auto_print_on_save`: Auto-print after save
- `show_print_dialog`: Show print dialog
- `compress_pdf`, `pdf_quality`: PDF settings
- `enable_thermal_print`: Thermal printer support
- `thermal_width`, `thermal_paper_length`: Thermal settings
- `thermal_font_size`, `thermal_line_spacing`: Thermal formatting
- `enable_qr_code`, `qr_code_content_template`: QR code on print
- `enable_barcode`, `barcode_content_template`, `barcode_type`: Barcode

#### 7. invoice_activity_logs
Activity tracking for invoices.

**Key Fields:**
- `invoice_id`, `invoice_number`, `invoice_type`: Invoice reference
- `action`: CREATED, EDITED, VIEWED, PRINTED, SHARED, DELETED, etc.
- `action_category`: Categorization
- `user_id`, `username`: User who performed action
- `ip_address`: IP address
- `device_info`: Device information
- `old_values`, `new_values`: Change tracking (JSON)
- `changes_summary`: Human-readable summary
- `session_id`: Session tracking
- `notes`: Additional notes
- `created_at`: Timestamp

## Service Layer

### InvoiceSettingsService

Located at: `lib/services/invoice/invoice_settings_service.dart`

**Key Methods:**

#### General Settings
- `getInvoiceSettings(String invoiceType)` - Get settings for invoice type
- `saveInvoiceSettings(Map<String, dynamic> settings)` - Save/update settings
- `generateInvoiceNumber(String invoiceType)` - Generate next invoice number with auto-increment

#### Header Settings
- `getHeaderSettings(String invoiceType)` - Get header configuration
- `saveHeaderSettings(Map<String, dynamic> settings)` - Save header settings

#### Footer Settings
- `getFooterSettings(String invoiceType)` - Get footer configuration
- `saveFooterSettings(Map<String, dynamic> settings)` - Save footer settings

#### Body Settings
- `getBodySettings(String invoiceType)` - Get body configuration
- `saveBodySettings(Map<String, dynamic> settings)` - Save body settings

#### Invoice Types
- `getAllInvoiceTypes()` - Get all active invoice types
- `getInvoiceType(String typeCode)` - Get specific invoice type
- `saveInvoiceType(Map<String, dynamic> typeSettings)` - Save invoice type

#### Print Settings
- `getPrintSettings(String invoiceType)` - Get print configuration
- `savePrintSettings(Map<String, dynamic> settings)` - Save print settings

#### Activity Logging
- `logActivity({...})` - Log invoice activity with full details
- `getInvoiceActivityLogs(int invoiceId)` - Get logs for specific invoice
- `getActivityLogs({filters...})` - Get filtered activity logs
- `getActivitySummaryByAction()` - Aggregate by action type
- `getActivitySummaryByType()` - Aggregate by invoice type
- `deleteOldActivityLogs(int daysToKeep)` - Cleanup old logs

#### Complete Configuration
- `getCompleteInvoiceConfig(String invoiceType)` - Get all settings at once
- `initializeDefaultSettings(String invoiceType)` - Create default settings

## UI Components

### 1. InvoiceSettingsMainScreen
**Location:** `lib/ui/screens/settings/invoice_settings_main_screen.dart`

**Features:**
- Tabbed interface with 5 tabs (General, Header, Footer, Body, Print)
- Invoice type selector dropdown with color-coded types
- Single-screen access to all invoice configuration
- Responsive layout with tab scrolling

**Navigation:** Settings → Invoice Settings

### 2. GeneralSettingsTab
**Location:** `lib/ui/screens/settings/invoice_settings_tabs/general_settings_tab.dart`

**Features:**
- Invoice numbering configuration (prefix, format, auto-increment)
- Reset period options (Never, Yearly, Monthly, Daily)
- Currency settings (code, symbol, decimal places)
- Tax and discount defaults
- Date and time format selection
- Real-time validation
- Auto-loads settings when invoice type changes

### 3. HeaderSettingsTab
**Location:** `lib/ui/screens/settings/invoice_settings_tabs/header_settings_tab.dart`

**Status:** Placeholder (under construction)
**Planned Features:**
- Company logo upload and positioning
- Company details configuration
- Page size and orientation
- Header styling and colors
- Custom fields

### 4. FooterSettingsTab
**Location:** `lib/ui/screens/settings/invoice_settings_tabs/footer_settings_tab.dart`

**Status:** Placeholder (under construction)
**Planned Features:**
- Footer text configuration
- Terms and conditions
- Bank details
- Signature and stamp upload
- Page numbering format

### 5. BodySettingsTab
**Location:** `lib/ui/screens/settings/invoice_settings_tabs/body_settings_tab.dart`

**Status:** Placeholder (under construction)
**Planned Features:**
- Party details configuration
- Item table column selection
- Table styling
- Totals display options
- QR code settings
- Color theme selection

### 6. PrintSettingsTab
**Location:** `lib/ui/screens/settings/invoice_settings_tabs/print_settings_tab.dart`

**Status:** Placeholder (under construction)
**Planned Features:**
- Paper size and orientation
- Printer selection
- Margin configuration
- Watermark settings
- Thermal printer support
- PDF quality settings

### 7. InvoiceActivityLogScreen
**Location:** `lib/ui/screens/settings/invoice_activity_log_screen.dart`

**Features:**
- Filter by invoice type (Sales, Purchase, etc.)
- Filter by action (Created, Edited, Printed, etc.)
- Date range picker for time-based filtering
- Color-coded action indicators
- Detailed log view with changes summary
- Shows username, timestamp, IP address
- Expandable details dialog
- Refresh functionality

**Navigation:** Settings → Security → Invoice Activity Log

## Database Migration

### Version 3 Migration
The module includes automatic migration from database version 2 to 3:

**Migration Actions:**
1. Creates all 7 invoice settings tables
2. Creates indexes on activity logs for performance
3. Seeds default invoice type settings (6 pre-configured types)
4. Initializes with sensible defaults

**Database Version:** Updated from 2 → 3 in `database_helper.dart`

## Integration Points

### Settings Screen Integration
The invoice settings are accessible from the main Settings screen:

1. **Invoice Settings** - Opens `InvoiceSettingsMainScreen`
2. **Invoice Activity Log** - Opens `InvoiceActivityLogScreen` (under Security section)

### Future Integration Points

#### Transaction Service Integration
When creating invoices, the TransactionService should:
- Call `generateInvoiceNumber(type)` for invoice numbering
- Log activity using `logActivity()` after CRUD operations
- Apply tax/discount defaults from invoice settings

#### PDF Generation Integration
When generating PDFs:
- Load complete config using `getCompleteInvoiceConfig(type)`
- Apply header settings (logo, company info)
- Apply body settings (table format, columns)
- Apply footer settings (terms, signatures)
- Apply print settings (margins, watermarks)

#### Print Service Integration
When printing:
- Load print settings using `getPrintSettings(type)`
- Apply paper size and orientation
- Apply margins
- Handle thermal printing if enabled
- Add watermarks if configured

## Best Practices

### Configuration Management
1. **Type-Specific Settings**: Each invoice type has its own complete configuration
2. **Default Initialization**: Settings are auto-created with sensible defaults
3. **Change Tracking**: All modifications logged in activity logs
4. **Validation**: Form validation ensures data integrity

### Activity Logging
1. **Comprehensive Tracking**: Log all significant invoice operations
2. **Change Details**: Store old and new values for audit
3. **User Attribution**: Track user, IP, device info
4. **Retention Policy**: Implement log cleanup with `deleteOldActivityLogs()`

### Performance
1. **Indexed Queries**: Activity logs indexed by invoice_id and date
2. **Lazy Loading**: Settings loaded on-demand per invoice type
3. **Caching**: Service can be enhanced with in-memory caching

### Security
1. **IP Tracking**: All activities logged with IP address
2. **User Attribution**: Activities linked to user accounts
3. **Immutable Logs**: Activity logs should not be editable
4. **Access Control**: Implement role-based access for settings

## Sample Configuration JSON

```json
{
  "general": {
    "invoice_type": "SALE",
    "prefix": "INV",
    "starting_number": 1000,
    "current_number": 1045,
    "number_format": "PREFIX-NNNN",
    "currency_code": "USD",
    "currency_symbol": "$",
    "default_tax_rate": 18.0,
    "enable_tax_by_default": true
  },
  "header": {
    "show_company_logo": true,
    "company_name": "ACME Corporation",
    "page_size": "A4",
    "invoice_title": "SALES INVOICE"
  },
  "footer": {
    "footer_text": "Thank you for your business!",
    "show_terms_and_conditions": true,
    "show_signature": true
  },
  "body": {
    "party_label": "Bill To",
    "show_subtotal": true,
    "show_grand_total": true,
    "show_amount_in_words": true
  },
  "print": {
    "paper_size": "A4",
    "paper_orientation": "PORTRAIT",
    "margin_top": 20.0,
    "print_format": "PDF"
  }
}
```

## Pending Tasks

### High Priority
1. **Complete Tab UIs**: Implement full UI for Header, Footer, Body, and Print tabs
2. **PDF Generation**: Integrate settings with PDF generation library
3. **Print Service**: Implement actual printing with configured settings
4. **Reports Module**: Create comprehensive reporting system

### Medium Priority
1. **Template System**: Allow custom invoice templates
2. **Preview Function**: Real-time invoice preview with settings
3. **Import/Export**: Export/import invoice configurations
4. **Multi-language**: Support for multiple languages

### Low Priority
1. **Advanced Watermarks**: Rotate, opacity, custom positioning
2. **QR Code Generation**: Dynamic QR codes on invoices
3. **Barcode Support**: Product barcodes on invoices
4. **Email Integration**: Email invoice directly from app

## Testing Checklist

- [ ] Database migration from v2 to v3 works correctly
- [ ] Default invoice types are seeded properly
- [ ] General settings save and load correctly
- [ ] Invoice number generation works with auto-increment
- [ ] Activity logging captures all required information
- [ ] Filters work correctly in activity log screen
- [ ] Date range picker functions properly
- [ ] Settings persist across app restarts
- [ ] Multiple invoice types can coexist with different settings
- [ ] Navigation from settings screen works correctly

## Conclusion

The Invoice Settings Module provides a solid foundation for professional invoice management. The database schema is comprehensive, the service layer is well-structured, and the UI provides easy access to configuration options. The activity logging system ensures full audit capability.

The modular design allows for easy enhancement of individual components (Header, Footer, Body, Print tabs) without affecting the overall system architecture.
