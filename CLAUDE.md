# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
# Run on Windows (debug)
flutter run -d windows

# Build release for Windows
flutter run --release -d windows

# Get dependencies
flutter pub get

# Analyze code
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/path/to/test_file.dart
```

**Prerequisites for Windows builds:**
- Visual Studio 2022 with "Desktop development with C++" workload
- Windows Developer Mode enabled (required for symlinks)

## Architecture Overview

This is an **offline-first Windows desktop inventory management app**. There is no backend, cloud, or internet dependency — all data lives in a local SQLite database at `C:\ProgramData\InventoryManagementSystem\`.

### Layer Structure

```
UI (lib/ui/screens/, lib/ui/widgets/)
    ↓
State Management (lib/ui/providers/) — Provider/ChangeNotifier
    ↓
Services (lib/services/) — Business logic singletons
    ↓
Data (lib/data/models/, lib/data/database/)
    ↓
Core (lib/core/) — Encryption, device fingerprinting, constants
```

### Key Architectural Decisions

**Services are singletons** using factory constructors with static `_instance`. Always use them as `ServiceName()` — never instantiate directly.

**No caching layer** — services query SQLite directly each time. Screens fetch data in `initState()` and refresh via `setState()`. Only the 3 global Providers use ChangeNotifier.

**Lot-based inventory** — stock is tracked per `(product_id, lot_id)` composite key, not just per product.

**Device-locked licensing** — hardware fingerprint (motherboard/CPU/disk SHA256) is embedded in the license file. License is AES-256-GCM encrypted + HMAC signed.

### Global Providers (MultiProvider in main.dart)

| Provider | Manages |
|---|---|
| `AuthProvider` | Current user, login/logout, permission checks |
| `ThemeProvider` | Light/dark mode, persisted via SharedPreferences |
| `AppProvider` | Current route string, global loading state |

### Navigation

Only 3 named routes: `/activation`, `/login`, `/dashboard`. All in-app navigation (between Products, Transactions, etc.) is handled inside `DashboardScreen` via stateful sidebar selection — not named routes.

### Database

- SQLite via `sqflite_common_ffi` (required for Windows desktop)
- Schema defined in `lib/data/database/database_schema.dart`
- Connection managed by `DatabaseHelper` singleton
- Database path: `C:\ProgramData\InventoryManagementSystem\inventory_db.db`

### Security

- Passwords: BCrypt hashed
- Database encryption: AES-256-GCM with PBKDF2 key derivation (150k iterations)
- Keys and vendor secrets in `lib/core/constants/app_constants.dart`

### Default Credentials

- Username: `admin` / Password: `admin` (forced change on first login)

### User Roles

`Admin` → `Manager` → `Cashier` → `Viewer` (decreasing permissions). Permission strings checked via `authProvider.hasPermission('permission_key')`.

## File Locations

- App data root: `C:\ProgramData\InventoryManagementSystem\`
- Database: `inventory_db.db`
- License file: `license.key`
- Backups: `backups/` subdirectory
- Image assets: `assets/images/`, `assets/icons/`
