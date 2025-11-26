import 'dart:convert';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:crypto/crypto.dart';
import '../constants/app_constants.dart';
import 'package:universal_html/html.dart' as web;

class DeviceFingerprint {
  static DeviceFingerprint? _instance;
  String? _cachedFingerprint;

  DeviceFingerprint._();

  factory DeviceFingerprint() {
    _instance ??= DeviceFingerprint._();
    return _instance!;
  }

  /// Generate a unique device fingerprint based on hardware identifiers
  Future<String> generateFingerprint() async {
    if (_cachedFingerprint != null) {
      return _cachedFingerprint!;
    }

    List<String> identifiers = [];

    if (kIsWeb) {
      identifiers = await _getWebIdentifiers();
    } else if (Platform.isWindows) {
      identifiers = await _getWindowsIdentifiers();
    } else if (Platform.isLinux) {
      identifiers = await _getLinuxIdentifiers();
    } else if (Platform.isMacOS) {
      identifiers = await _getMacOSIdentifiers();
    } else {
      throw UnsupportedError('Platform not supported for device fingerprinting');
    }

    // Create a canonical string from identifiers
    identifiers.sort(); // Sort for consistency
    final canonicalString = identifiers.join('|');

    // Generate fingerprint: SHA256(salt + canonical_string)
    final combined = AppConstants.appSalt + canonicalString;
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);

    _cachedFingerprint = digest.toString();
    return _cachedFingerprint!;
  }

  /// Get Windows hardware identifiers using PowerShell/WMI
  Future<List<String>> _getWindowsIdentifiers() async {
    List<String> identifiers = [];

    try {
      // Get motherboard serial number
      final mbResult = await Process.run('powershell', [
        '-Command',
        'Get-CimInstance -ClassName Win32_BaseBoard | Select-Object -ExpandProperty SerialNumber'
      ]);

      if (mbResult.exitCode == 0 && mbResult.stdout.toString().trim().isNotEmpty) {
        final mbSerial = mbResult.stdout.toString().trim();
        if (mbSerial.isNotEmpty && mbSerial != 'To be filled by O.E.M.' && mbSerial != 'Default string') {
          identifiers.add('MB:$mbSerial');
        }
      }
    } catch (e) {
      print('Error getting motherboard serial: $e');
    }

    try {
      // Get system UUID
      final uuidResult = await Process.run('powershell', [
        '-Command',
        'Get-CimInstance -ClassName Win32_ComputerSystemProduct | Select-Object -ExpandProperty UUID'
      ]);

      if (uuidResult.exitCode == 0 && uuidResult.stdout.toString().trim().isNotEmpty) {
        final uuid = uuidResult.stdout.toString().trim();
        if (uuid.isNotEmpty && uuid != 'FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF') {
          identifiers.add('UUID:$uuid');
        }
      }
    } catch (e) {
      print('Error getting system UUID: $e');
    }

    try {
      // Get primary disk serial number
      final diskResult = await Process.run('powershell', [
        '-Command',
        r'Get-CimInstance -ClassName Win32_DiskDrive | Where-Object {$_.Index -eq 0} | Select-Object -ExpandProperty SerialNumber'
      ]);

      if (diskResult.exitCode == 0 && diskResult.stdout.toString().trim().isNotEmpty) {
        final diskSerial = diskResult.stdout.toString().trim();
        if (diskSerial.isNotEmpty) {
          identifiers.add('DISK:$diskSerial');
        }
      }
    } catch (e) {
      print('Error getting disk serial: $e');
    }

    try {
      // Get processor ID as fallback
      final cpuResult = await Process.run('powershell', [
        '-Command',
        'Get-CimInstance -ClassName Win32_Processor | Select-Object -ExpandProperty ProcessorId'
      ]);

      if (cpuResult.exitCode == 0 && cpuResult.stdout.toString().trim().isNotEmpty) {
        final cpuId = cpuResult.stdout.toString().trim();
        if (cpuId.isNotEmpty) {
          identifiers.add('CPU:$cpuId');
        }
      }
    } catch (e) {
      print('Error getting CPU ID: $e');
    }

    // Ensure we have at least 2 identifiers
    if (identifiers.length < 2) {
      throw Exception('Unable to generate device fingerprint: insufficient hardware identifiers found');
    }

    return identifiers;
  }

  /// Get Linux hardware identifiers
  Future<List<String>> _getLinuxIdentifiers() async {
    List<String> identifiers = [];

    try {
      // Get machine ID
      final machineIdFile = File('/etc/machine-id');
      if (await machineIdFile.exists()) {
        final machineId = await machineIdFile.readAsString();
        identifiers.add('MACHINE_ID:${machineId.trim()}');
      }
    } catch (e) {
      print('Error getting machine ID: $e');
    }

    try {
      // Get product UUID
      final uuidResult = await Process.run('cat', ['/sys/class/dmi/id/product_uuid']);
      if (uuidResult.exitCode == 0 && uuidResult.stdout.toString().trim().isNotEmpty) {
        identifiers.add('UUID:${uuidResult.stdout.toString().trim()}');
      }
    } catch (e) {
      print('Error getting product UUID: $e');
    }

    try {
      // Get board serial
      final boardResult = await Process.run('cat', ['/sys/class/dmi/id/board_serial']);
      if (boardResult.exitCode == 0 && boardResult.stdout.toString().trim().isNotEmpty) {
        identifiers.add('BOARD:${boardResult.stdout.toString().trim()}');
      }
    } catch (e) {
      print('Error getting board serial: $e');
    }

    if (identifiers.length < 2) {
      throw Exception('Unable to generate device fingerprint: insufficient hardware identifiers found');
    }

    return identifiers;
  }

  /// Get macOS hardware identifiers
  Future<List<String>> _getMacOSIdentifiers() async {
    List<String> identifiers = [];

    try {
      // Get hardware UUID
      final uuidResult = await Process.run('system_profiler', ['SPHardwareDataType']);
      if (uuidResult.exitCode == 0) {
        final output = uuidResult.stdout.toString();
        final uuidMatch = RegExp(r'Hardware UUID:\s*(.+)').firstMatch(output);
        if (uuidMatch != null) {
          identifiers.add('UUID:${uuidMatch.group(1)!.trim()}');
        }
      }
    } catch (e) {
      print('Error getting hardware UUID: $e');
    }

    try {
      // Get serial number
      final serialResult = await Process.run('system_profiler', ['SPHardwareDataType']);
      if (serialResult.exitCode == 0) {
        final output = serialResult.stdout.toString();
        final serialMatch = RegExp(r'Serial Number \(system\):\s*(.+)').firstMatch(output);
        if (serialMatch != null) {
          identifiers.add('SERIAL:${serialMatch.group(1)!.trim()}');
        }
      }
    } catch (e) {
      print('Error getting serial number: $e');
    }

    if (identifiers.length < 2) {
      throw Exception('Unable to generate device fingerprint: insufficient hardware identifiers found');
    }

    return identifiers;
  }

  /// Get Web browser identifiers
  Future<List<String>> _getWebIdentifiers() async {
    List<String> identifiers = [];

    // For web, we'll use browser fingerprinting techniques
    // This is a simplified version - in production you might want more sophisticated methods

    // Use a combination of browser properties
    identifiers.add('PLATFORM:web');
    identifiers.add('USERAGENT:${web.window.navigator.userAgent}');
    identifiers.add('LANGUAGE:${web.window.navigator.language}');

    // Screen resolution
    identifiers.add('SCREEN:${web.window.screen?.width}x${web.window.screen?.height}');

    // Timezone
    identifiers.add('TIMEZONE:${DateTime.now().timeZoneOffset.inMinutes}');

    // Hardware concurrency (CPU cores)
    final hardwareConcurrency = web.window.navigator.hardwareConcurrency;
    if (hardwareConcurrency != null) {
      identifiers.add('CORES:$hardwareConcurrency');
    }

    return identifiers;
  }

  /// Generate an installation code for display to user (shortened fingerprint)
  Future<String> generateInstallationCode() async {
    final fingerprint = await generateFingerprint();
    // Take first 16 characters and format in groups of 4
    final code = fingerprint.substring(0, 16).toUpperCase();
    return '${code.substring(0, 4)}-${code.substring(4, 8)}-${code.substring(8, 12)}-${code.substring(12, 16)}';
  }

  /// Clear cached fingerprint (for testing)
  void clearCache() {
    _cachedFingerprint = null;
  }
}
