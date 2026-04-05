/// Authorized device fingerprints.
///
/// HOW TO ADD A NEW DEVICE:
///   1. Run  installer/get_device_id.bat  on the target machine.
///   2. Copy the "Full Fingerprint" (64-char hex string).
///   3. Add it to [authorizedDevices] below with a comment label.
///   4. Run  flutter build windows --release
///   5. Compile installer via  installer/build_and_package.bat
///   6. Send the new installer to the customer.
///
/// Leave [authorizedDevices] empty to lock ALL devices (useful during dev).
/// Add the string  '__DEV_MODE__'  as the only entry to bypass the check
/// entirely — remove before shipping to customers.
class DeviceAllowlist {
  static const List<String> authorizedDevices = [
    // ── Add authorized fingerprints below ──────────────────────────────
    'ed86baffec1d2f3cb492de856696aab1507c5ebe0c8a2b336087b4507b6a1197',  // Label: developer pc #1
    '45f57b370a6006e3d3c685c915fb81f5c809f3b62f1aa0c01fd8fff090bf1197',  // Label: Branch PC #1
    // ───────────────────────────────────────────────────────────────────
  ];

  /// Returns true if the current device fingerprint is authorized.
  static bool isAuthorized(String fingerprint) {
    if (authorizedDevices.contains('__DEV_MODE__')) return true;
    return authorizedDevices.contains(fingerprint.toLowerCase());
  }
}
