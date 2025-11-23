# Developer Guide - Inventory Management System

## Table of Contents
1. [Development Environment Setup](#development-environment-setup)
2. [Project Architecture](#project-architecture)
3. [Security Implementation](#security-implementation)
4. [Database Management](#database-management)
5. [Adding New Features](#adding-new-features)
6. [Testing](#testing)
7. [Deployment](#deployment)

## Development Environment Setup

### Prerequisites

1. **Flutter SDK**
   ```bash
   # Download and install Flutter SDK 3.10.1+
   # https://docs.flutter.dev/get-started/install/windows

   # Verify installation
   flutter doctor -v
   ```

2. **Visual Studio 2022** (for Windows desktop development)
   - Install "Desktop development with C++" workload
   - Or install Visual Studio Build Tools 2022

3. **Git** for version control

### IDE Recommendations

**VS Code** (Recommended)
- Install Flutter extension
- Install Dart extension
- Recommended settings in `.vscode/settings.json`

**Android Studio / IntelliJ IDEA**
- Install Flutter and Dart plugins

### Project Setup

```bash
# Clone repository
git clone <repository-url>
cd inventory

# Get dependencies
flutter pub get

# Run in debug mode
flutter run -d windows

# Hot reload: Press 'r' in terminal
# Hot restart: Press 'R' in terminal
```

## Project Architecture

### Layered Architecture

```
┌─────────────────────────────────────┐
│           UI Layer                  │
│  (Screens, Widgets, Providers)      │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│        Services Layer                │
│  (Auth, License, Export, Print)      │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│         Data Layer                   │
│  (Repositories, Database, Models)    │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│         Core Layer                   │
│  (Encryption, Device, Utils)         │
└──────────────────────────────────────┘
```

### State Management

We use **Provider** for state management:

- `AuthProvider`: Manages authentication state
- `AppProvider`: Manages app-wide state
- Future: `ProductProvider`, `TransactionProvider`, etc.

### Data Flow

1. **User Action** → UI Screen
2. **Screen** → Calls Provider method
3. **Provider** → Calls Service
4. **Service** → Calls Repository
5. **Repository** → Database operation
6. **Database** → Returns data
7. **Data flows back** through layers
8. **Provider** notifies listeners
9. **UI** rebuilds with new data

## Security Implementation

### Device Fingerprinting

Located in: `lib/core/device_fingerprint/device_fingerprint.dart`

**How it works:**
1. Collects hardware identifiers (minimum 2 required)
2. Sorts identifiers for consistency
3. Creates canonical string: `ID1|ID2|ID3`
4. Hashes: `SHA256(app_salt + canonical_string)`

**Windows Implementation:**
```dart
// Uses PowerShell to query WMI
// - Motherboard serial: Win32_BaseBoard.SerialNumber
// - System UUID: Win32_ComputerSystemProduct.UUID
// - Disk serial: Win32_DiskDrive.SerialNumber (Index 0)
// - CPU ID: Win32_Processor.ProcessorId
```

**Adding Support for New Platform:**
```dart
Future<List<String>> _getYourPlatformIdentifiers() async {
  List<String> identifiers = [];

  // Collect hardware IDs
  // identifiers.add('TYPE:value');

  // Must have at least 2 identifiers
  if (identifiers.length < 2) {
    throw Exception('Insufficient identifiers');
  }

  return identifiers;
}
```

### Database Encryption

Located in: `lib/core/encryption/encryption_service.dart`

**Key Derivation:**
```dart
// Input: device fingerprint
// Process:
//   1. Combine: fingerprint + app_salt
//   2. PBKDF2(combined, salt=app_salt, iterations=150000, keyLength=32)
// Output: 256-bit AES key
```

**Encryption Algorithm:**
- AES-256-GCM (authenticated encryption)
- Random 16-byte IV per encryption operation
- Data format: `{iv: base64, data: base64}`

**Important Notes:**
- Database is NOT encrypted at rest (SQLite file is plain)
- Future enhancement: Implement SQLCipher or file-level encryption
- Current implementation encrypts sensitive fields only

### License System

Located in: `lib/services/license/`

**License Structure:**
```json
{
  "customer_id": "CUST001",
  "customer_name": "Acme Corp",
  "device_fingerprint": "abc123...",
  "issued_on": "2024-01-01T00:00:00.000Z",
  "expires_on": null,
  "features": ["offline", "multiuser", "printing"],
  "signature": "hmac_sha256_signature"
}
```

**Verification Process:**
1. Decrypt license file with vendor secret
2. Verify HMAC signature
3. Compare device fingerprint with current device
4. Check expiration date
5. Grant access if all checks pass

**Generating Signatures:**
```dart
String dataToSign = '$customerId|$customerName|$fingerprint|$issuedOn|$expiresOn|${features.join(',')}';
String signature = HMAC_SHA256(dataToSign, vendor_secret);
```

## Database Management

### Schema Updates

When modifying schema:

1. Update `lib/data/database/database_schema.dart`
2. Increment database version in `database_helper.dart`
3. Implement migration in `_onUpgrade`:

```dart
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    // Migration from v1 to v2
    await db.execute('ALTER TABLE products ADD COLUMN new_field TEXT');
  }

  if (oldVersion < 3) {
    // Migration from v2 to v3
    // ...
  }
}
```

### Creating a New Model

1. Create model class in `lib/data/models/`:

```dart
class YourModel {
  final int? id;
  final String field1;
  final DateTime createdAt;

  YourModel({
    this.id,
    required this.field1,
    required this.createdAt,
  });

  // toMap for database insert/update
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'field1': field1,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // fromMap for database query
  factory YourModel.fromMap(Map<String, dynamic> map) {
    return YourModel(
      id: map['id'] as int?,
      field1: map['field1'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
```

2. Create repository in `lib/data/repositories/`:

```dart
class YourRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> insert(YourModel model) async {
    final db = await _dbHelper.database;
    return await db.insert('your_table', model.toMap());
  }

  Future<List<YourModel>> getAll() async {
    final db = await _dbHelper.database;
    final results = await db.query('your_table');
    return results.map((map) => YourModel.fromMap(map)).toList();
  }

  Future<YourModel?> getById(int id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'your_table',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return YourModel.fromMap(results.first);
  }

  Future<int> update(YourModel model) async {
    final db = await _dbHelper.database;
    return await db.update(
      'your_table',
      model.toMap(),
      where: 'id = ?',
      whereArgs: [model.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'your_table',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
```

## Adding New Features

### Example: Adding Transaction Module

1. **Create Model** (`transaction_model.dart`)
2. **Create Repository** (`transaction_repository.dart`)
3. **Create Service** (`transaction_service.dart`) - business logic
4. **Create Provider** (`transaction_provider.dart`) - state management
5. **Create UI** (`transaction_screen.dart`)

### Provider Pattern Example

```dart
class TransactionProvider extends ChangeNotifier {
  final TransactionRepository _repo = TransactionRepository();
  List<TransactionModel> _transactions = [];
  bool _isLoading = false;

  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;

  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    _transactions = await _repo.getAll();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> createTransaction(TransactionModel transaction) async {
    _isLoading = true;
    notifyListeners();

    await _repo.insert(transaction);
    await loadTransactions(); // Reload

    _isLoading = false;
    notifyListeners();
  }
}
```

### Using Provider in UI

```dart
class TransactionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return CircularProgressIndicator();
        }

        return ListView.builder(
          itemCount: provider.transactions.length,
          itemBuilder: (context, index) {
            final transaction = provider.transactions[index];
            return ListTile(
              title: Text(transaction.invoiceNumber),
              subtitle: Text(transaction.totalAmount.toString()),
            );
          },
        );
      },
    );
  }
}
```

## Testing

### Unit Tests

Create tests in `test/` directory:

```dart
// test/services/auth_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/services/auth/auth_service.dart';

void main() {
  group('AuthService Tests', () {
    test('Login with valid credentials should succeed', () async {
      final authService = AuthService();

      final user = await authService.login('admin', 'admin');

      expect(user, isNotNull);
      expect(user?.username, equals('admin'));
    });

    test('Login with invalid credentials should fail', () async {
      final authService = AuthService();

      final user = await authService.login('admin', 'wrongpassword');

      expect(user, isNull);
    });
  });
}
```

Run tests:
```bash
flutter test
```

### Integration Tests

For testing complete workflows:

```dart
// test/integration/transaction_flow_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Complete sale transaction flow', (WidgetTester tester) async {
    // 1. Build app
    // 2. Login
    // 3. Navigate to transactions
    // 4. Create a sale
    // 5. Verify sale is saved
  });
}
```

### Manual Testing Checklist

See README.md for comprehensive manual test checklist.

## Deployment

### Build for Release

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build Windows release
flutter build windows --release
```

### Output Structure

```
build/windows/x64/runner/Release/
├── inventory.exe           # Main executable
├── flutter_windows.dll     # Flutter engine
├── *.dll                   # Other dependencies
└── data/                   # Flutter assets
```

### Creating Installer

1. **Using NSIS** (Nullsoft Scriptable Install System)

Create `installer.nsi`:
```nsis
!define APP_NAME "Inventory Management System"
!define APP_VERSION "1.0.0"

Name "${APP_NAME}"
OutFile "InventoryManagement_Setup.exe"
InstallDir "$PROGRAMFILES64\InventoryManagementSystem"

Section "Install"
  SetOutPath "$INSTDIR"
  File /r "build\windows\x64\runner\Release\*.*"

  CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\inventory.exe"

  WriteUninstaller "$INSTDIR\Uninstall.exe"
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir /r "$INSTDIR"

  MessageBox MB_YESNO "Delete application data?" IDYES DeleteData
  Goto End
  DeleteData:
    RMDir /r "$PROGRAMDATA\InventoryManagementSystem"
  End:
SectionEnd
```

Compile:
```bash
makensis installer.nsi
```

2. **Using Inno Setup** (Alternative)

More user-friendly GUI for creating installers.

### Version Management

Update version in `pubspec.yaml`:
```yaml
version: 1.0.0+1  # version+buildNumber
```

## Best Practices

### Code Style
- Follow [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter analyze` to check for issues
- Format code with `dart format .`

### Error Handling
```dart
try {
  // Operation
} catch (e) {
  // Log error (in production, use proper logging)
  print('Error: $e');

  // Show user-friendly message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Operation failed')),
  );
}
```

### Security
- Never commit secrets or API keys
- Change default salts before production
- Use environment variables for sensitive config
- Always validate user input
- Sanitize data before database operations

### Performance
- Use `const` constructors where possible
- Implement pagination for large lists
- Use `ListView.builder` instead of `ListView`
- Lazy load data when appropriate

### Git Workflow
```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes and commit
git add .
git commit -m "Add new feature"

# Push and create PR
git push origin feature/new-feature
```

## Troubleshooting

### Common Issues

**Issue**: Flutter not recognized
```bash
# Add Flutter to PATH
# Windows: System Properties > Environment Variables > Path
# Add: C:\path\to\flutter\bin
```

**Issue**: Build fails with Visual Studio error
```bash
# Install Visual Studio Build Tools
# Or install full Visual Studio with C++ workload
```

**Issue**: Database locked error
```bash
# Close all instances of the app
# Delete build folder and rebuild
flutter clean
flutter run
```

## Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Provider Package](https://pub.dev/packages/provider)
- [SQLite Documentation](https://www.sqlite.org/docs.html)

---

**Last Updated**: 2024
**Author**: Development Team
