import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:pointycastle/export.dart';
import '../constants/app_constants.dart';

class EncryptionService {
  static EncryptionService? _instance;

  EncryptionService._();

  factory EncryptionService() {
    _instance ??= EncryptionService._();
    return _instance!;
  }

  /// Derive encryption key from device fingerprint and app salt using PBKDF2
  Uint8List deriveKey(String deviceFingerprint) {
    final passphrase = deviceFingerprint + AppConstants.appSalt;
    final salt = utf8.encode(AppConstants.appSalt);

    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(
        Uint8List.fromList(salt),
        AppConstants.pbkdf2Iterations,
        AppConstants.aesKeyLength,
      ));

    return derivator.process(Uint8List.fromList(utf8.encode(passphrase)));
  }

  /// Encrypt data using AES-256-GCM
  String encryptData(String data, Uint8List key) {
    final encryptKey = encrypt_pkg.Key(key);
    final iv = encrypt_pkg.IV.fromSecureRandom(16);
    final encrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(encryptKey, mode: encrypt_pkg.AESMode.gcm),
    );

    final encrypted = encrypter.encrypt(data, iv: iv);

    // Combine IV and encrypted data
    final combined = {
      'iv': iv.base64,
      'data': encrypted.base64,
    };

    return base64.encode(utf8.encode(json.encode(combined)));
  }

  /// Decrypt data using AES-256-GCM
  String decryptData(String encryptedData, Uint8List key) {
    try {
      final decoded = json.decode(utf8.decode(base64.decode(encryptedData)));
      final iv = encrypt_pkg.IV.fromBase64(decoded['iv']);
      final encrypted = encrypt_pkg.Encrypted.fromBase64(decoded['data']);

      final encryptKey = encrypt_pkg.Key(key);
      final encrypter = encrypt_pkg.Encrypter(
        encrypt_pkg.AES(encryptKey, mode: encrypt_pkg.AESMode.gcm),
      );

      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw Exception('Decryption failed: Invalid key or corrupted data');
    }
  }

  /// Encrypt file contents
  Future<void> encryptFile(String sourcePath, String destPath, Uint8List key) async {
    final file = await Future.value(sourcePath);
    // For file encryption, we'll use a streaming approach in production
    // For now, this is a placeholder that will be implemented with actual file handling
    throw UnimplementedError('File encryption will be implemented with database backup');
  }

  /// Decrypt file contents
  Future<void> decryptFile(String sourcePath, String destPath, Uint8List key) async {
    throw UnimplementedError('File decryption will be implemented with database restore');
  }

  /// Generate HMAC signature for data integrity
  String generateHMAC(String data, String secret) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return digest.toString();
  }

  /// Verify HMAC signature
  bool verifyHMAC(String data, String signature, String secret) {
    final generated = generateHMAC(data, secret);
    return generated == signature;
  }

  /// Hash password using SHA-256 (will be replaced with bcrypt in auth service)
  String hashPassword(String password, String salt) {
    final combined = password + salt;
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
