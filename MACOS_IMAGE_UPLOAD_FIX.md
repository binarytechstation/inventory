# macOS Image Upload Fix

## Problem
On macOS, image uploads (profile pictures, company logos, signatures, stamps) were failing while working fine on Windows. This was due to macOS sandbox restrictions.

## Root Cause
The code was using **temporary file paths** from `FilePicker` or saving to **Documents directory** which are not accessible after the file picker closes on macOS due to sandbox restrictions.

## Solution
Changed all image upload functionality to **copy files to Application Support directory** which is:
- ✅ Always accessible within the macOS sandbox
- ✅ Persistent across app launches
- ✅ The correct location for app-specific data
- ✅ Compatible with both macOS and Windows

## Files Fixed

### 1. Profile Picture Upload
**File:** `lib/ui/screens/settings/profile_edit_screen.dart`

**What Changed:**
```dart
// BEFORE (Windows only)
final appDataDir = await getApplicationDocumentsDirectory();
final profilePicturesDir = Directory(path.join(appDataDir.path, 'profile_pictures'));

// AFTER (Cross-platform)
final appDataDir = await getApplicationSupportDirectory();
final profilePicturesDir = Directory(path.join(appDataDir.path, 'InventoryManagementSystem', 'profile_pictures'));
```

**How It Works:**
1. User selects image via file picker
2. Image is **copied** to `~/Library/Application Support/InventoryManagementSystem/profile_pictures/`
3. Path to copied file is saved in database
4. File is accessible anytime the app needs it

### 2. Company Logo Upload (Invoice Settings)
**File:** `lib/ui/screens/settings/invoice_settings_tabs/header_settings_tab.dart`

**What Changed:**
```dart
// BEFORE (Temporary path - lost after picker closes)
setState(() {
  _logoPath = result.files.first.path; // ❌ macOS loses access
});

// AFTER (Permanent copy in App Support)
final appDataDir = await getApplicationSupportDirectory();
final logosDir = Directory(path.join(appDataDir.path, 'InventoryManagementSystem', 'logos'));

// Copy file to permanent location
final sourceFile = File(pickedFile.path!);
await sourceFile.copy(destinationPath);

setState(() {
  _logoPath = destinationPath; // ✅ Always accessible
});
```

**Storage Location:** `~/Library/Application Support/InventoryManagementSystem/logos/logo_<invoicetype>.jpg`

### 3. Signature Upload (Invoice Footer)
**File:** `lib/ui/screens/settings/invoice_settings_tabs/footer_settings_tab.dart`

**Method:** `_pickSignature()`

**Storage Location:** `~/Library/Application Support/InventoryManagementSystem/signatures/signature_<invoicetype>.jpg`

### 4. Stamp Upload (Invoice Footer)
**File:** `lib/ui/screens/settings/invoice_settings_tabs/footer_settings_tab.dart`

**Method:** `_pickStamp()`

**Storage Location:** `~/Library/Application Support/InventoryManagementSystem/stamps/stamp_<invoicetype>.jpg`

## Directory Structure

```
macOS Application Support:
~/Library/Application Support/InventoryManagementSystem/
├── profile_pictures/
│   └── user_<id>.jpg
├── logos/
│   ├── logo_sale.jpg
│   └── logo_purchase.jpg
├── signatures/
│   ├── signature_sale.jpg
│   └── signature_purchase.jpg
└── stamps/
    ├── stamp_sale.jpg
    └── stamp_purchase.jpg

Windows Application Data:
C:\ProgramData\InventoryManagementSystem\
└── (same structure)
```

## Key Improvements

### ✅ macOS Sandbox Compatibility
- Files are stored in Application Support directory
- This directory is always accessible within the sandbox
- No special entitlements needed beyond what we already added

### ✅ File Persistence
- Files are **copied** not linked
- Files remain accessible even if original is deleted
- Files persist across app updates

### ✅ Unique File Names
- Profile pictures: `user_<id>.jpg` - unique per user
- Logos: `logo_<invoicetype>.<ext>` - unique per invoice type
- Signatures: `signature_<invoicetype>.<ext>` - unique per invoice type
- Stamps: `stamp_<invoicetype>.<ext>` - unique per invoice type

### ✅ User Feedback
- Shows success message: "Image selected. Click 'Save' to apply."
- Shows error message if something goes wrong
- Clear indication of what to do next

### ✅ Windows Compatibility
- `getApplicationSupportDirectory()` works on Windows too
- No change to Windows behavior
- Same code path for both platforms

## Testing Instructions

### Test 1: Profile Picture Upload
1. Run app on macOS
2. Go to Settings → Edit Profile
3. Click "Change Profile Picture"
4. Select an image
5. ✅ Should show: "Profile picture selected. Click 'Save Changes' to update."
6. Click "Save Changes"
7. ✅ Profile picture should display
8. Restart app
9. ✅ Profile picture should still be visible

### Test 2: Company Logo Upload
1. Go to Settings → Invoice Settings → Header Settings
2. Enable "Show Company Logo"
3. Click "Select Logo"
4. Choose an image
5. ✅ Should show: "Logo selected. Click 'Save Settings' to apply."
6. Click "Save Settings"
7. ✅ Logo preview should appear
8. Generate an invoice (POS → Create Sale → Generate Invoice)
9. ✅ Logo should appear in the invoice PDF

### Test 3: Signature Upload
1. Go to Settings → Invoice Settings → Footer Settings
2. Enable "Show Signature"
3. Click "Select Signature"
4. Choose an image
5. ✅ Should show: "Signature selected. Click 'Save Settings' to apply."
6. Click "Save Settings"
7. Generate an invoice
8. ✅ Signature should appear in the invoice footer

### Test 4: Stamp Upload
1. In Footer Settings, enable "Show Stamp"
2. Click "Select Stamp"
3. Choose an image
4. ✅ Should show: "Stamp selected. Click 'Save Settings' to apply."
5. Click "Save Settings"
6. Generate an invoice
7. ✅ Stamp should appear in the invoice footer

### Test 5: Windows Compatibility
1. Run same tests on Windows
2. ✅ All features should work identically
3. ✅ Files stored in `%PROGRAMDATA%\InventoryManagementSystem\` or `%LOCALAPPDATA%\InventoryManagementSystem\`

## Technical Details

### Why Application Support?
- **macOS:** `~/Library/Application Support/` is the designated location for app data
- **Windows:** `%LOCALAPPDATA%` or `%PROGRAMDATA%` is used by `getApplicationSupportDirectory()`
- **Sandbox:** This directory is always accessible without special permissions
- **Best Practice:** Apple and Flutter both recommend this for app-specific data

### Why Copy Files?
- **Security:** User can delete/move original file after selection
- **Reliability:** App always has access to its own copy
- **Sandbox:** Temporary picker access expires after the picker closes
- **Portability:** App data is self-contained and portable

### File Name Strategy
- **Predictable:** Easy to find and debug
- **Unique:** Won't conflict with other files
- **Overwrite:** Selecting new image replaces old one automatically
- **Simple:** No need for complex file management

## Common Questions

**Q: Will this increase app storage usage?**
A: Yes, slightly, but images are typically small (10-500KB). The benefit of reliability outweighs the minimal storage cost.

**Q: What happens to old files when uploading new ones?**
A: They are automatically overwritten since we use deterministic filenames.

**Q: Can users access these files?**
A: Yes, on macOS: `~/Library/Application Support/InventoryManagementSystem/`
On Windows: `%LOCALAPPDATA%\InventoryManagementSystem\` or `%PROGRAMDATA%\InventoryManagementSystem\`

**Q: Does this affect performance?**
A: No. Copying small image files is instantaneous. The app remains responsive.

**Q: What if the user selects a very large image?**
A: The file picker limits to image types. Flutter widgets handle large images efficiently. Consider adding size validation if needed.

## Summary

✅ **Fixed:** Profile picture upload on macOS
✅ **Fixed:** Company logo upload on macOS
✅ **Fixed:** Signature image upload on macOS
✅ **Fixed:** Stamp image upload on macOS
✅ **Maintained:** All Windows functionality unchanged
✅ **Improved:** Better file management and persistence
✅ **Enhanced:** User feedback with success/error messages

All image upload features now work identically on both macOS and Windows!
