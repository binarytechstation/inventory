# Inventory Management System

A secure, offline-first desktop inventory management application built with Flutter for Windows, featuring device-bound licensing, encrypted database, and comprehensive business features.

## Features

### Core Functionality
- **Product Management**: Track products with SKU, barcode, pricing, and stock levels
- **Supplier Management**: Maintain supplier database with contact details
- **Customer Management**: Track customers with credit limits and balances
- **Purchase Transactions**: Record purchases with batch tracking
- **Sales Transactions**: Process sales with multiple payment modes
- **Returns Processing**: Handle product returns and refunds
- **Held Bills**: Save incomplete transactions for later completion
- **Multi-user Support**: Role-based access control (Admin, Manager, Cashier, Viewer)

### Security & Licensing
- **Device Locking**: Software bound to specific hardware via device fingerprinting
- **Encrypted Database**: AES-256-GCM encryption using device-specific keys
- **Offline Licensing**: One-time activation without cloud dependency
- **Password Security**: BCrypt hashing with configurable requirements
- **Offline Password Recovery**: Recovery codes and security questions

### Business Features
- **Inventory Tracking**: Real-time stock levels with low-stock alerts
- **Batch Pricing**: Support for multiple purchase prices per product
- **Discounts**: Line-item and invoice-level discounts
- **Tax Calculation**: Configurable tax rates per product
- **Payment Modes**: Cash and credit with outstanding balance tracking
- **Invoice Numbering**: Customizable prefixes and auto-incrementing numbers

### Reporting & Export
- **Sales Reports**: Daily, custom range, by product/customer
- **Purchase Reports**: Track purchases by supplier and date
- **Excel Export**: Export transactions and reports to .xlsx format
- **PDF Generation**: Print receipts and purchase orders
- **Backup/Restore**: Encrypted backup with external restore capability

## System Requirements

### Development
- Flutter SDK 3.10.1 or higher (stable channel)
- Dart SDK 3.10.1 or higher
- Windows 10/11 (primary target platform)
- Visual Studio 2019/2022 with C++ desktop development

### Runtime
- Windows 10/11 (64-bit)
- 4GB RAM minimum, 8GB recommended
- 500MB free disk space for application
- Additional space for database and backups

## Quick Start

### Installation

```bash
cd inventory
flutter pub get
flutter run -d windows
```

### Default Login
- **Username**: `admin`
- **Password**: `admin`
- You will be prompted to change the password on first login

### Database Location
- Windows: `C:\ProgramData\InventoryManagementSystem\inventory_db.db`
- License: `C:\ProgramData\InventoryManagementSystem\license.key`
- Backups: `C:\ProgramData\InventoryManagementSystem\backups\`

## License Generation

The license generator is located in `license_generator/license_generator.dart`.

```bash
cd license_generator
dart license_generator.dart
```

Follow the prompts to generate a license key for a specific device.

## Architecture

### Security Model
1. **Device Fingerprinting**: Collects hardware IDs (motherboard, disk, CPU) and generates SHA256 hash
2. **Database Encryption**: Derives AES-256 key from device fingerprint using PBKDF2 (150k iterations)
3. **License Binding**: License contains device fingerprint and HMAC signature to prevent tampering
4. **Data Persistence**: Stores data outside install directory to survive uninstall/reinstall

### Project Structure

```
lib/
├── core/                    # Core utilities
│   ├── constants/          # App-wide constants
│   ├── device_fingerprint/ # Hardware ID generation
│   ├── encryption/         # AES encryption
│   └── utils/              # Path helpers
├── data/                    # Data layer
│   ├── database/           # SQLite schema
│   └── models/             # Data models
├── services/                # Business logic
│   ├── auth/               # Authentication
│   ├── license/            # License management
│   ├── backup/             # Backup/restore (planned)
│   ├── export/             # Excel/PDF (planned)
│   └── print/              # Printing (planned)
└── ui/                      # User interface
    ├── providers/          # State management
    ├── screens/            # App screens
    └── widgets/            # Reusable widgets
```

## Configuration

### Security Settings (IMPORTANT)

Edit [lib/core/constants/app_constants.dart](lib/core/constants/app_constants.dart):

```dart
// CHANGE THESE IN PRODUCTION
static const String appSalt = 'YOUR_UNIQUE_SALT_HERE';
static const String vendorSecret = 'YOUR_VENDOR_SECRET_HERE';
```

**Warning**: Changing these after deployment invalidates all licenses and databases!

## Building for Production

### Build Release

```bash
flutter build windows --release
```

Output: `build\windows\x64\runner\Release\`

### Create Installer

See the full README section on creating installers using NSIS or other packaging tools.

## User Roles

| Role | Permissions |
|------|------------|
| **Admin** | Full access including user management |
| **Manager** | Products, transactions, reports |
| **Cashier** | Sales, printing, held bills |
| **Viewer** | Read-only access |

## Testing

### Test Device Locking
1. Build and run the app on Machine A
2. Complete activation
3. Create some data
4. Copy `C:\ProgramData\InventoryManagementSystem\` to Machine B
5. Try to open app on Machine B → should fail with decryption error ✓

### Test Data Persistence
1. Install and activate app
2. Create some data
3. Uninstall app (keep data when prompted)
4. Reinstall app
5. Data should still be there ✓

## Documentation

- **README.md** (this file) - Quick start and overview
- **DEVELOPER_GUIDE.md** (to be created) - Detailed development guide
- **ARCHITECTURE.md** (to be created) - System design and architecture
- **API_REFERENCE.md** (to be created) - Code documentation

## Status

### ✅ Completed
- Core project structure
- Device fingerprinting (Windows/Linux/macOS)
- Database encryption layer
- License system
- Authentication & user management
- Basic UI framework
- License generator CLI

### 🔄 In Progress
- Transaction management UI
- Reporting module
- Excel export
- PDF generation

### ⏳ Planned
- Barcode scanning
- Advanced dashboards
- Bulk import/export
- Multi-currency

## Support

For issues or questions:
- Create an issue in this repository
- Contact: support@yourcompany.com

## License

Proprietary Software - All Rights Reserved

---

**Version**: 1.0.0
**Platform**: Windows Desktop
**Framework**: Flutter 3.10+
