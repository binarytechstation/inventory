# License Generator Tool

This tool generates license keys for the Inventory Management System.

## Quick Start

### Windows (Double-Click)
Simply double-click `generate_license.bat`

### Command Line
```bash
cd license_generator
dart run license_generator.dart
```

## First-Time Setup

If this is your first time running the tool:

```bash
cd license_generator
dart pub get
```

## Usage

The tool will prompt you for:

1. **Customer ID**: Unique identifier (e.g., `CUST001`)
2. **Customer Name**: Customer or company name
3. **Installation Code**: Code from customer's activation screen (format: `XXXX-XXXX-XXXX-XXXX`)
4. **License Type**:
   - `perpetual` - Never expires (recommended)
   - `expiring` - Set expiration date
5. **Expiry Date**: Only if type is `expiring` (format: `YYYY-MM-DD`)

## Example Session

```
Enter Customer ID: CUST001
Enter Customer Name: Acme Corporation
Enter Installation Code (from customer's activation screen): A1B2-C3D4-E5F6-G7H8
License Type (perpetual/expiring) [perpetual]: perpetual

Generating license...

╔════════════════════════════════════════════════════════════╗
║  LICENSE GENERATED SUCCESSFULLY                            ║
╚════════════════════════════════════════════════════════════╝

Customer: Acme Corporation
Customer ID: CUST001
Device Fingerprint: abc123def456...
Issued: 2024-01-15T10:30:00.000Z
Expires: Never
Features: offline, multiuser, printing, excel_export, backup_restore

LICENSE KEY:
─────────────────────────────────────────────────────────────
eyJpdiI6ImlhbTMyY2hhcmFjdGVycyIsImRhdGEiOiJlbmNyeXB0ZWRkYXRhIn0=
─────────────────────────────────────────────────────────────

Save license to file? (y/n) [y]: y
License saved to: license_CUST001_1737012345678.key
```

## Compiling to Executable (Optional)

To create a standalone executable:

```bash
dart pub get
dart compile exe license_generator.dart -o license_gen.exe
```

You can then distribute `license_gen.exe` without requiring Dart/Flutter installation.

## Security Notes

- **Keep this tool secure** - only authorized personnel should have access
- **Never distribute to customers** - they only need the generated license keys
- **Protect the vendor secret** - it's hardcoded in the tool and main app
- **Log all license generations** for audit trail

## Workflow

1. **Customer installs app** → sees activation screen with Installation Code
2. **Customer contacts you** → provides Installation Code
3. **You run this tool** → enter customer info and Installation Code
4. **Tool generates license** → encrypted license key
5. **Send license to customer** → they paste it in activation screen
6. **Customer activates** → app verifies and unlocks

## Troubleshooting

**"dart: command not found"**
- Ensure Dart/Flutter is installed and in PATH
- Or use the batch file which should find Dart automatically

**"Package dependencies error"**
- Run `dart pub get` in this directory first

**"Build hooks not supported"**
- This is just a warning, the tool still works
- Use `dart run license_generator.dart` instead of compile

**License activation fails**
- Verify Installation Code was copied correctly
- Check that vendor secret matches between app and tool
- Ensure no extra spaces in license key when customer pastes

## Support

For issues or questions, contact the development team.
