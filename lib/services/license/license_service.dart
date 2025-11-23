import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../core/constants/app_constants.dart';
import '../../core/device_fingerprint/device_fingerprint.dart';
import '../../core/encryption/encryption_service.dart';
import '../../core/utils/path_helper.dart';
import 'license_model.dart';

class LicenseService {
  static LicenseService? _instance;
  final DeviceFingerprint _deviceFingerprint = DeviceFingerprint();
  final EncryptionService _encryptionService = EncryptionService();
  final PathHelper _pathHelper = PathHelper();

  LicenseModel? _currentLicense;

  LicenseService._();

  factory LicenseService() {
    _instance ??= LicenseService._();
    return _instance!;
  }

  /// Verify license on app startup
  Future<bool> verifyLicense() async {
    try {
      final licensePath = _pathHelper.getLicensePath();
      final licenseFile = File(licensePath);

      if (!await licenseFile.exists()) {
        return false;
      }

      final encryptedContent = await licenseFile.readAsString();
      final deviceFingerprint = await _deviceFingerprint.generateFingerprint();

      // Decrypt license file
      final key = _encryptionService.deriveKey(AppConstants.vendorSecret);
      final decryptedContent = _encryptionService.decryptData(encryptedContent, key);

      final license = LicenseModel.fromJsonString(decryptedContent);

      // Verify signature
      final dataToSign = _getLicenseDataForSigning(license);
      final isSignatureValid = _encryptionService.verifyHMAC(
        dataToSign,
        license.signature,
        AppConstants.vendorSecret,
      );

      if (!isSignatureValid) {
        throw Exception('License signature verification failed');
      }

      // Verify device fingerprint matches
      if (license.deviceFingerprint != deviceFingerprint) {
        throw Exception('License is not valid for this device');
      }

      // Check if expired
      if (license.isExpired()) {
        throw Exception('License has expired');
      }

      _currentLicense = license;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Create and save a license (used by license generator or initial setup)
  Future<void> saveLicense(LicenseModel license) async {
    final licensePath = _pathHelper.getLicensePath();
    final licenseFile = File(licensePath);

    // Encrypt license
    final key = _encryptionService.deriveKey(AppConstants.vendorSecret);
    final encryptedContent = _encryptionService.encryptData(
      license.toJsonString(),
      key,
    );

    await licenseFile.writeAsString(encryptedContent);
    _currentLicense = license;
  }

  /// Generate a license from installation code (used by license generator CLI)
  static LicenseModel generateLicense({
    required String customerId,
    required String customerName,
    required String deviceFingerprint,
    required List<String> features,
    DateTime? expiresOn,
  }) {
    final issuedOn = DateTime.now();

    final license = LicenseModel(
      customerId: customerId,
      customerName: customerName,
      deviceFingerprint: deviceFingerprint,
      issuedOn: issuedOn,
      expiresOn: expiresOn,
      features: features,
      signature: '', // Will be set below
    );

    // Generate signature
    final encryptionService = EncryptionService();
    final dataToSign = _getLicenseDataForSigning(license);
    final signature = encryptionService.generateHMAC(
      dataToSign,
      AppConstants.vendorSecret,
    );

    return LicenseModel(
      customerId: customerId,
      customerName: customerName,
      deviceFingerprint: deviceFingerprint,
      issuedOn: issuedOn,
      expiresOn: expiresOn,
      features: features,
      signature: signature,
    );
  }

  /// Get data to sign (all fields except signature)
  static String _getLicenseDataForSigning(LicenseModel license) {
    return '${license.customerId}|${license.customerName}|${license.deviceFingerprint}|${license.issuedOn.toIso8601String()}|${license.expiresOn?.toIso8601String() ?? ''}|${license.features.join(',')}';
  }

  /// Get current license
  LicenseModel? getCurrentLicense() {
    return _currentLicense;
  }

  /// Check if license file exists
  Future<bool> licenseExists() async {
    return await _pathHelper.licenseExists();
  }

  /// Get installation code for this device
  Future<String> getInstallationCode() async {
    return await _deviceFingerprint.generateInstallationCode();
  }

  /// Get device fingerprint
  Future<String> getDeviceFingerprint() async {
    return await _deviceFingerprint.generateFingerprint();
  }

  /// Export license to string (for transfer)
  Future<String> exportLicenseString(LicenseModel license) async {
    final key = _encryptionService.deriveKey(AppConstants.vendorSecret);
    return _encryptionService.encryptData(license.toJsonString(), key);
  }

  /// Import license from string
  Future<void> importLicenseString(String licenseString) async {
    final key = _encryptionService.deriveKey(AppConstants.vendorSecret);
    final decryptedContent = _encryptionService.decryptData(licenseString, key);
    final license = LicenseModel.fromJsonString(decryptedContent);

    // Verify signature
    final dataToSign = _getLicenseDataForSigning(license);
    final isSignatureValid = _encryptionService.verifyHMAC(
      dataToSign,
      license.signature,
      AppConstants.vendorSecret,
    );

    if (!isSignatureValid) {
      throw Exception('License signature verification failed');
    }

    // Verify device fingerprint
    final deviceFingerprint = await _deviceFingerprint.generateFingerprint();
    if (license.deviceFingerprint != deviceFingerprint) {
      throw Exception('License is not valid for this device');
    }

    await saveLicense(license);
  }
}
