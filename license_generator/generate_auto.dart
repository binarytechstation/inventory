import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:pointycastle/export.dart';

const String APP_SALT = 'INV_SECURE_SALT_2024_V1_CHANGE_THIS_IN_PRODUCTION';
const String VENDOR_SECRET = 'VENDOR_SECRET_KEY_CHANGE_IN_PRODUCTION';
const int PBKDF2_ITERATIONS = 150000;
const int AES_KEY_LENGTH = 32;

void main() {
  // Your installation code
  final installationCode = '6C75-E060-2D11-5761';

  // Customer details
  final customerId = 'DEMO001';
  final customerName = 'Demo Customer';

  print('Generating license for:');
  print('Customer ID: $customerId');
  print('Customer Name: $customerName');
  print('Installation Code: $installationCode');
  print('');

  // Convert installation code to fingerprint
  final deviceFingerprint = convertInstallationCodeToFingerprint(installationCode);

  // Generate license
  final license = generateLicense(
    customerId: customerId,
    customerName: customerName,
    deviceFingerprint: deviceFingerprint,
    features: ['offline', 'multiuser', 'printing', 'excel_export', 'backup_restore'],
    expiresOn: null, // perpetual
  );

  // Encrypt license
  final licenseString = encryptLicense(license);

  print('LICENSE KEY:');
  print('═══════════════════════════════════════════════════════════');
  print(licenseString);
  print('═══════════════════════════════════════════════════════════');
  print('');
  print('Copy the entire license key above and paste it into the activation screen.');
}

String convertInstallationCodeToFingerprint(String installationCode) {
  final cleanCode = installationCode.replaceAll('-', '').toLowerCase();
  final bytes = utf8.encode(cleanCode + APP_SALT);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

Map<String, dynamic> generateLicense({
  required String customerId,
  required String customerName,
  required String deviceFingerprint,
  required List<String> features,
  DateTime? expiresOn,
}) {
  final issuedOn = DateTime.now();

  final license = {
    'customer_id': customerId,
    'customer_name': customerName,
    'device_fingerprint': deviceFingerprint,
    'issued_on': issuedOn.toIso8601String(),
    'expires_on': expiresOn?.toIso8601String(),
    'features': features,
  };

  final dataToSign = '${license['customer_id']}|${license['customer_name']}|${license['device_fingerprint']}|${license['issued_on']}|${license['expires_on'] ?? ''}|${features.join(',')}';
  final signature = generateHMAC(dataToSign, VENDOR_SECRET);

  license['signature'] = signature;

  return license;
}

String generateHMAC(String data, String secret) {
  final key = utf8.encode(secret);
  final bytes = utf8.encode(data);
  final hmac = Hmac(sha256, key);
  final digest = hmac.convert(bytes);
  return digest.toString();
}

String encryptLicense(Map<String, dynamic> license) {
  final licenseJson = json.encode(license);

  final key = deriveKey(VENDOR_SECRET);

  final encryptKey = encrypt_pkg.Key(key);
  final iv = encrypt_pkg.IV.fromSecureRandom(16);
  final encrypter = encrypt_pkg.Encrypter(
    encrypt_pkg.AES(encryptKey, mode: encrypt_pkg.AESMode.gcm),
  );

  final encrypted = encrypter.encrypt(licenseJson, iv: iv);

  final combined = {
    'iv': iv.base64,
    'data': encrypted.base64,
  };

  return base64.encode(utf8.encode(json.encode(combined)));
}

Uint8List deriveKey(String passphrase) {
  final salt = utf8.encode(APP_SALT);

  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(
      Uint8List.fromList(salt),
      PBKDF2_ITERATIONS,
      AES_KEY_LENGTH,
    ));

  return derivator.process(Uint8List.fromList(utf8.encode(passphrase + APP_SALT)));
}
