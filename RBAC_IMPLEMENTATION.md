# Role-Based Access Control (RBAC) Implementation

## Overview
This document describes the comprehensive role-based access control system implemented across the inventory management application.

## User Roles and Permissions

### 1. Admin (Administrator)
**Full Access** - Can do everything in the system

Permissions:
- ✅ All product operations (view, create, edit, delete)
- ✅ All transaction operations (view, create, edit, delete sales and purchases)
- ✅ All customer/supplier operations (view, create, edit, delete)
- ✅ View and export all reports
- ✅ Print invoices
- ✅ User management (view, create, edit, delete, change passwords)
- ✅ System settings access
- ✅ Full POS access
- ✅ Dashboard access with all features

### 2. Manager
**Business Operations Manager** - Can manage products, transactions, and reports

Permissions:
- ✅ All product operations (view, create, edit, delete)
- ✅ All transaction operations (view, create, edit, delete sales and purchases)
- ✅ All customer/supplier operations (view, create, edit, delete)
- ✅ View and export all reports
- ✅ Print invoices
- ✅ Full POS access
- ✅ Dashboard access
- ❌ User management (cannot manage users)
- ❌ System settings access

### 3. Cashier
**Sales Point Operator** - Can create sales and view products

Permissions:
- ✅ View products (read-only)
- ✅ Create sales transactions
- ✅ View sales transactions
- ✅ POS access (for creating sales)
- ✅ Dashboard access (limited)
- ❌ Cannot edit or delete products
- ❌ Cannot access purchases
- ❌ Cannot access customers/suppliers management
- ❌ Cannot access reports
- ❌ Cannot print invoices
- ❌ User management
- ❌ System settings

### 4. Viewer
**Read-Only Observer** - Can only view data, no modifications

Permissions:
- ✅ View products
- ✅ View transactions (sales and purchases)
- ✅ View customers and suppliers
- ✅ View reports (without export)
- ✅ View dashboard
- ❌ Cannot create, edit, or delete anything
- ❌ Cannot print invoices
- ❌ Cannot export reports
- ❌ No POS access
- ❌ User management
- ❌ System settings

## Permission Codes

The following permission codes are used throughout the application:

```dart
// Product permissions
'view_products'
'create_product'
'edit_product'
'delete_product'

// Transaction permissions
'view_transactions'
'create_sale'
'create_purchase'
'edit_transaction'
'delete_transaction'

// Customer/Supplier permissions
'view_customers'
'create_customer'
'edit_customer'
'delete_customer'
'view_suppliers'
'create_supplier'
'edit_supplier'
'delete_supplier'

// Report permissions
'view_reports'
'export_reports'

// Invoice permissions
'print_invoice'

// Dashboard permissions
'view_dashboard'

// User management permissions
'view_users'
'create_user'
'edit_user'
'delete_user'

// Settings permissions
'view_settings'
'edit_settings'
```

## Implementation in Code

### UserModel (lib/data/models/user_model.dart)

The `hasPermission()` method checks if a user has a specific permission:

```dart
bool hasPermission(String permission) {
  switch (role.toLowerCase()) {
    case 'admin':
      return true; // Full access
    case 'manager':
      return [...].contains(permission);
    case 'cashier':
      return [...].contains(permission);
    case 'viewer':
      return [...].contains(permission);
    default:
      return false;
  }
}
```

Helper getters:
```dart
bool get isAdmin => role.toLowerCase() == 'admin';
bool get isManager => role.toLowerCase() == 'manager';
bool get isCashier => role.toLowerCase() == 'cashier';
bool get isViewer => role.toLowerCase() == 'viewer';
```

### UI Implementation Pattern

Use `Consumer<AuthProvider>` to reactively show/hide UI elements:

```dart
Consumer<AuthProvider>(
  builder: (context, authProvider, child) {
    // Check if user has permission
    if (authProvider.currentUser?.hasPermission('create_product') != true) {
      return const SizedBox.shrink(); // Hide element
    }

    // Show element for authorized users
    return FloatingActionButton(
      onPressed: _addProduct,
      child: const Icon(Icons.add),
    );
  },
)
```

### Screens with RBAC Implementation

#### 1. Users Screen (lib/ui/screens/user/users_screen.dart)
- "Add User" button: Admin only
- Edit/Delete/Change Password actions: Admin only
- Non-admin users can view the user list but cannot modify

#### 2. Products Screen (lib/ui/screens/product/products_screen.dart)
- **Admin/Manager**: Full access (add, edit, delete)
- **Cashier/Viewer**: Read-only (no add/edit/delete buttons)

#### 3. Transactions Screen (lib/ui/screens/transaction/transactions_screen.dart)
- **Admin/Manager**: Full access (create/edit/delete sales and purchases)
- **Cashier**: Can create sales only, view transactions
- **Viewer**: View only

#### 4. Reports Screen (lib/ui/screens/reports/reports_screen.dart)
- **Admin/Manager**: View and export reports
- **Viewer**: View only (no export buttons)
- **Cashier**: No access

#### 5. POS Screen (lib/ui/screens/pos/pos_screen.dart)
- **Admin/Manager/Cashier**: Full access
- **Viewer**: No access

#### 6. Settings Screen (lib/ui/screens/settings/settings_screen.dart)
- **Admin**: Full access
- **All others**: No access

#### 7. Dashboard Screen (lib/ui/screens/dashboard/dashboard_screen.dart)
- Navigation menu items filtered based on role
- Quick action buttons filtered based on permissions
- Statistics cards visible to all (data viewing)

## Testing Checklist

### Admin Testing
- [ ] Can access all menu items
- [ ] Can create/edit/delete products
- [ ] Can create/edit/delete transactions (sales and purchases)
- [ ] Can manage users
- [ ] Can access settings
- [ ] Can export reports
- [ ] Can print invoices

### Manager Testing
- [ ] Can access products, transactions, reports, POS
- [ ] Cannot access users section
- [ ] Cannot access settings
- [ ] Can create/edit/delete products
- [ ] Can create/edit/delete transactions
- [ ] Can export reports
- [ ] Can print invoices

### Cashier Testing
- [ ] Can access POS
- [ ] Can view products (read-only)
- [ ] Can create sales only
- [ ] Cannot edit/delete products
- [ ] Cannot access purchases
- [ ] Cannot access reports
- [ ] Cannot access users/settings
- [ ] Cannot print invoices

### Viewer Testing
- [ ] Can view dashboard
- [ ] Can view products (read-only)
- [ ] Can view transactions (read-only)
- [ ] Can view reports (no export)
- [ ] Cannot create/edit/delete anything
- [ ] Cannot access POS
- [ ] Cannot access users/settings
- [ ] Cannot print invoices

## Security Notes

1. **Frontend Validation**: All UI restrictions are implemented using `Consumer<AuthProvider>` to reactively hide/disable unauthorized actions.

2. **Backend Validation**: Services should also validate permissions before performing operations (future enhancement).

3. **Session Management**: When user role changes, the UI automatically updates through Provider pattern.

4. **Default Deny**: If permission is not explicitly granted, access is denied by default.

## Future Enhancements

1. **Service-Level Validation**: Add permission checks in service methods
2. **Audit Logging**: Log all permission checks and access attempts
3. **Custom Permissions**: Allow admins to create custom roles with granular permissions
4. **Permission Groups**: Create permission sets for easier role management
5. **Time-Based Permissions**: Restrict certain actions to specific time periods
