#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:pointycastle/export.dart';

// NOTE: These constants MUST match the ones in the main application
const String APP_SALT = 'INV_SECURE_SALT_2024_V1_CHANGE_THIS_IN_PRODUCTION';
const String VENDOR_SECRET = 'VENDOR_SECRET_KEY_CHANGE_IN_PRODUCTION';
const int PBKDF2_ITERATIONS = 150000;
const int AES_KEY_LENGTH = 32;

void main(List<String> arguments) {
  print('╔════════════════════════════════════════════════════════════╗');
  print('║  Inventory Management System - License Generator          ║');
  print('║  Version 1.0.0                                             ║');
  print('╚════════════════════════════════════════════════════════════╝');
  print('');

  if (arguments.isNotEmpty && (arguments[0] == '--help' || arguments[0] == '-h')) {
    printHelp();
    return;
  }

  try {
    // Get customer information
    stdout.write('Enter Customer ID: ');
    final customerId = stdin.readLineSync() ?? '';
    if (customerId.isEmpty) {
      print('Error: Customer ID is required');
      exit(1);
    }

    stdout.write('Enter Customer Name: ');
    final customerName = stdin.readLineSync() ?? '';
    if (customerName.isEmpty) {
      print('Error: Customer Name is required');
      exit(1);
    }

    stdout.write('Enter Installation Code (from customer\'s activation screen): ');
    final installationCode = stdin.readLineSync() ?? '';
    if (installationCode.isEmpty) {
      print('Error: Installation Code is required');
      exit(1);
    }

    // Convert installation code back to fingerprint
    final deviceFingerprint = convertInstallationCodeToFingerprint(installationCode);

    stdout.write('License Type (perpetual/expiring) [perpetual]: ');
    final licenseType = stdin.readLineSync() ?? 'perpetual';

    DateTime? expiresOn;
    if (licenseType.toLowerCase() == 'expiring') {
      stdout.write('Expiry Date (YYYY-MM-DD): ');
      final expiryDateStr = stdin.readLineSync() ?? '';
      try {
        expiresOn = DateTime.parse(expiryDateStr);
      } catch (e) {
        print('Error: Invalid date format. Use YYYY-MM-DD');
        exit(1);
      }
    }

    // Features
    final features = ['offline', 'multiuser', 'printing', 'excel_export', 'backup_restore'];

    print('');
    print('Generating license...');

    // Generate license
    final license = generateLicense(
      customerId: customerId,
      customerName: customerName,
      deviceFingerprint: deviceFingerprint,
      features: features,
      expiresOn: expiresOn,
    );

    // Encrypt license
    final licenseString = encryptLicense(license);

    print('');
    print('╔════════════════════════════════════════════════════════════╗');
    print('║  LICENSE GENERATED SUCCESSFULLY                            ║');
    print('╚════════════════════════════════════════════════════════════╝');
    print('');
    print('Customer: $customerName');
    print('Customer ID: $customerId');
    print('Device Fingerprint: ${deviceFingerprint.substring(0, 16)}...');
    print('Issued: ${license['issued_on']}');
    print('Expires: ${license['expires_on'] ?? 'Never'}');
    print('Features: ${features.join(', ')}');
    print('');
    print('LICENSE KEY:');
    print('─────────────────────────────────────────────────────────────');
    print(licenseString);
    print('─────────────────────────────────────────────────────────────');
    print('');

    // Save to file
    stdout.write('Save license to file? (y/n) [y]: ');
    final saveToFile = stdin.readLineSync() ?? 'y';

    if (saveToFile.toLowerCase() == 'y' || saveToFile.isEmpty) {
      final filename = 'license_${customerId}_${DateTime.now().millisecondsSinceEpoch}.key';
      final file = File(filename);
      file.writeAsStringSync(licenseString);
      print('License saved to: ${file.absolute.path}');
    }

    print('');
    print('INSTRUCTIONS FOR CUSTOMER:');
    print('1. Copy the LICENSE KEY above');
    print('2. Open the application activation screen');
    print('3. Paste the license key in the input field');
    print('4. Click "Activate License"');
    print('');

  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

String convertInstallationCodeToFingerprint(String installationCode) {
  // Remove dashes and convert to lowercase
  final cleanCode = installationCode.replaceAll('-', '').toLowerCase();

  // The installation code is the first 16 characters of the fingerprint
  // We need to regenerate the full fingerprint, but since we don't have the original
  // hardware identifiers, we'll use the installation code as a seed

  // For this demo, we'll use a hash of the installation code to create a full fingerprint
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

  // Generate signature
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

  // Derive encryption key
  final key = deriveKey(VENDOR_SECRET);

  // Encrypt
  final encryptKey = encrypt_pkg.Key(key);
  final iv = encrypt_pkg.IV.fromSecureRandom(16);
  final encrypter = encrypt_pkg.Encrypter(
    encrypt_pkg.AES(encryptKey, mode: encrypt_pkg.AESMode.gcm),
  );

  final encrypted = encrypter.encrypt(licenseJson, iv: iv);

  // Combine IV and encrypted data
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

void printHelp() {
  print('Usage: dart license_generator.dart');
  print('');
  print('This tool generates license keys for the Inventory Management System.');
  print('');
  print('The tool will prompt you for the following information:');
  print('  - Customer ID: Unique identifier for the customer');
  print('  - Customer Name: Name of the customer or company');
  print('  - Installation Code: Code provided by the customer from activation screen');
  print('  - License Type: perpetual or expiring');
  print('  - Expiry Date: Required if license type is expiring (YYYY-MM-DD format)');
  print('');
  print('The generated license key should be provided to the customer to activate');
  print('their installation of the software.');
  print('');
  print('Options:');
  print('  -h, --help    Show this help message');
  print('');
}
