# Installation & Deployment Guide

## For End Users

### System Requirements

- Windows 10 or Windows 11 (64-bit)
- 4GB RAM minimum (8GB recommended)
- 500MB free disk space
- Administrator privileges for installation

### Installation Steps

1. **Download the Installer**
   - Download `InventoryManagement_Setup.exe` from your vendor

2. **Run the Installer**
   - Double-click the installer file
   - If Windows SmartScreen appears, click "More info" then "Run anyway"
   - Accept the license agreement
   - Choose installation location (default: `C:\Program Files\InventoryManagementSystem`)
   - Click Install

3. **First Launch**
   - Find the shortcut on your desktop or Start Menu
   - Launch "Inventory Management System"
   - You'll see the Activation Screen

4. **Activation**
   - Copy the **Installation Code** shown on screen
   - Contact your vendor and provide this code
   - Vendor will generate and send you a **License Key**
   - Paste the License Key into the activation screen
   - Click "Activate License"

5. **First Login**
   - Username: `admin`
   - Password: `admin`
   - **IMPORTANT**: Change your password when prompted!

6. **Start Using**
   - Your data is stored in: `C:\ProgramData\InventoryManagementSystem`
   - This folder persists even if you uninstall the application

### Uninstallation

1. Go to Windows Settings > Apps > Apps & Features
2. Find "Inventory Management System"
3. Click Uninstall
4. You'll be asked if you want to keep your data
   - **Yes**: Data remains in ProgramData (can reinstall later)
   - **No**: All data will be deleted permanently

### Troubleshooting

**Problem**: Activation fails with "License not valid"
- Solution: Ensure you copied the entire license key correctly

**Problem**: Can't login after password change
- Solution: Contact vendor for password recovery options

**Problem**: Application won't start
- Solution: Try running as Administrator, or contact support

## For Developers

### Development Installation

1. **Install Flutter**
   ```bash
   # Download Flutter SDK from https://flutter.dev
   # Extract to C:\flutter (or your preferred location)
   # Add to PATH: C:\flutter\bin
   ```

2. **Install Visual Studio 2022**
   - Download Visual Studio Community 2022
   - Install "Desktop development with C++" workload

3. **Verify Setup**
   ```bash
   flutter doctor -v
   ```

   Should show:
   - ✓ Flutter (Channel stable)
   - ✓ Windows Version (with Visual Studio)
   - ✓ VS Code or Android Studio (optional)

4. **Clone and Run**
   ```bash
   cd c:\Users\ASUS\OneDrive\Desktop\inventory\inventory
   flutter pub get
   flutter run -d windows
   ```

### Building for Production

#### Step 1: Prepare for Release

1. **Update Version**
   - Edit `pubspec.yaml`:
     ```yaml
     version: 1.0.0+1  # Format: version+buildNumber
     ```

2. **Change Security Secrets** (IMPORTANT!)
   - Edit `lib/core/constants/app_constants.dart`:
     ```dart
     static const String appSalt = 'YOUR_UNIQUE_SALT_HERE_CHANGE_THIS';
     static const String vendorSecret = 'YOUR_VENDOR_SECRET_CHANGE_THIS';
     ```
   - **Warning**: Never commit these to public repos!

3. **Update Company Information**
   - Edit default profile data in `database_helper.dart`
   - Update company name, logo, etc.

#### Step 2: Build Release Executable

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build for Windows release
flutter build windows --release
```

**Output Location**: `build\windows\x64\runner\Release\`

**Contents**:
- `inventory.exe` - Main executable
- `*.dll` - Required libraries
- `data\` - Flutter assets

#### Step 3: Test the Build

```bash
cd build\windows\x64\runner\Release
inventory.exe
```

Test thoroughly:
- First run and activation
- Login and password change
- Create sample data
- Test all features
- Check data persists after restart

#### Step 4: Create Installer

**Option A: NSIS (Recommended)**

1. Install NSIS from https://nsis.sourceforge.io/

2. Create `installer\installer.nsi`:

```nsis
!define APP_NAME "Inventory Management System"
!define APP_VERSION "1.0.0"
!define APP_PUBLISHER "Your Company Name"
!define APP_EXE "inventory.exe"
!define APP_GUID "{12345678-1234-1234-1234-123456789012}"

!include "MUI2.nsh"

Name "${APP_NAME}"
OutFile "..\InventoryManagement_Setup.exe"
InstallDir "$PROGRAMFILES64\InventoryManagementSystem"
RequestExecutionLevel admin

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "..\LICENSE.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Section "Install"
  SetOutPath "$INSTDIR"

  File /r "..\build\windows\x64\runner\Release\*.*"

  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
  CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"

  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_GUID}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_GUID}" "UninstallString" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_GUID}" "Publisher" "${APP_PUBLISHER}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_GUID}" "DisplayVersion" "${APP_VERSION}"

  WriteUninstaller "$INSTDIR\Uninstall.exe"
SectionEnd

Section "Uninstall"
  Delete "$DESKTOP\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
  RMDir "$SMPROGRAMS\${APP_NAME}"

  Delete "$INSTDIR\Uninstall.exe"
  RMDir /r "$INSTDIR"

  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_GUID}"

  MessageBox MB_YESNO "Do you want to delete all application data? (This will remove your inventory database!)" IDYES DeleteData IDNO KeepData
  DeleteData:
    RMDir /r "$PROGRAMDATA\InventoryManagementSystem"
  KeepData:
SectionEnd
```

3. Compile:
```bash
cd installer
makensis installer.nsi
```

**Option B: Inno Setup**

1. Download and install Inno Setup from https://jrsoftware.org/isinfo.php

2. Create `installer\setup.iss`:

```iss
[Setup]
AppName=Inventory Management System
AppVersion=1.0.0
AppPublisher=Your Company
DefaultDirName={autopf}\InventoryManagementSystem
DefaultGroupName=Inventory Management System
OutputDir=..\
OutputBaseFilename=InventoryManagement_Setup
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=admin

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\Inventory Management System"; Filename: "{app}\inventory.exe"
Name: "{autodesktop}\Inventory Management System"; Filename: "{app}\inventory.exe"

[UninstallDelete]
Type: filesandordirs; Name: "{commonappdata}\InventoryManagementSystem"

[Code]
function ShouldDeleteData(): Boolean;
begin
  Result := MsgBox('Do you want to delete all application data? This will remove your inventory database!', mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    if ShouldDeleteData() then
      DelTree(ExpandConstant('{commonappdata}\InventoryManagementSystem'), True, True, True);
  end;
end;
```

3. Open in Inno Setup Compiler and click "Compile"

#### Step 5: Sign the Executable (Optional but Recommended)

```bash
# Using signtool (from Windows SDK)
signtool sign /f certificate.pfx /p password /t http://timestamp.digicert.com inventory.exe
```

#### Step 6: Test the Installer

1. Install on a clean Windows machine (VM recommended)
2. Run through activation process
3. Test all features
4. Uninstall and verify data persistence
5. Reinstall and verify data loads correctly
6. Copy database to another machine - should fail to decrypt

### License Generator Setup

The license generator is a separate tool for vendors to create license keys.

1. **Location**: `license_generator/license_generator.dart`

2. **Run Directly**:
   ```bash
   cd license_generator
   dart license_generator.dart
   ```

3. **Compile to Executable** (Optional):
   ```bash
   dart compile exe license_generator.dart -o license_generator.exe
   ```

4. **Usage**:
   ```bash
   # Interactive mode
   dart license_generator.dart

   # Or if compiled
   license_generator.exe
   ```

5. **Secure the Tool**:
   - Keep on secure, offline machine
   - Never distribute to customers
   - Log all license generations
   - Protect vendor secret

### Deployment Checklist

Before releasing to customers:

- [ ] Updated version number in pubspec.yaml
- [ ] Changed APP_SALT and VENDOR_SECRET
- [ ] Updated company information
- [ ] Built release executable
- [ ] Tested on clean machine
- [ ] Created installer
- [ ] Tested installer (install/uninstall/reinstall)
- [ ] Tested device locking
- [ ] Signed executable (if applicable)
- [ ] Prepared license generator for vendor use
- [ ] Created user manual
- [ ] Set up customer support process
- [ ] Tested backup/restore
- [ ] Verified data persistence

### Continuous Deployment (Optional)

Create a GitHub Actions workflow:

```yaml
# .github/workflows/build.yml
name: Build Windows Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: windows-latest

    steps:
    - uses: actions/checkout@v2

    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.10.1'
        channel: 'stable'

    - name: Get dependencies
      run: flutter pub get

    - name: Build Windows
      run: flutter build windows --release

    - name: Create installer
      run: |
        choco install nsis -y
        makensis installer/installer.nsi

    - name: Upload artifact
      uses: actions/upload-artifact@v2
      with:
        name: windows-installer
        path: InventoryManagement_Setup.exe
```

### Distribution

**Methods**:
1. Direct download from your website
2. Email to customers
3. USB drive for offline distribution
4. Corporate network share

**Support**:
- Provide installation guide (this document)
- Setup customer support email/phone
- Create FAQ document
- Offer remote assistance if needed

### Licensing Model

**Perpetual License**:
- One-time fee
- License never expires
- Bound to specific hardware

**Subscription License** (if implemented):
- Monthly or yearly fee
- License has expiration date
- Renewal required

**Trial License**:
- Set expiry date (e.g., 30 days from issue)
- Full features
- Convert to paid after trial

### Customer Onboarding

1. **Receive Order**
2. **Collect Installation Code** from customer
3. **Generate License** using license generator tool
4. **Send License Key** to customer
5. **Provide Support** for activation
6. **Training** (if included)
7. **Follow-up** after 1 week

---

## Maintenance & Updates

### Updating the Application

1. Build new version
2. Create new installer
3. Customers download and run new installer
4. Data persists automatically

### Database Migrations

If schema changes:
1. Increment database version
2. Implement migration in `_onUpgrade`
3. Test migration with existing data
4. Document changes

### Support

For support inquiries:
- Email: support@yourcompany.com
- Phone: +1-XXX-XXX-XXXX
- Documentation: https://docs.yourcompany.com

---

**Last Updated**: 2024
**Document Version**: 1.0
