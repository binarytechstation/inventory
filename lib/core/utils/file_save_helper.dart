import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart' as universal_io;

/// Helper class for saving files cross-platform
/// - Windows: Saves directly to Documents folder (existing behavior)
/// - macOS: Uses native save dialog for proper sandbox permissions
/// - Linux: Uses native save dialog
class FileSaveHelper {
  /// Save a file with platform-specific behavior
  ///
  /// [bytes] - File content as bytes
  /// [fileName] - Suggested file name
  /// [dialogTitle] - Title for save dialog (macOS/Linux only)
  /// [allowedExtensions] - List of allowed file extensions (e.g., ['pdf', 'xlsx'])
  ///
  /// Returns the saved file path or null if cancelled/failed
  static Future<String?> saveFile({
    required List<int> bytes,
    required String fileName,
    String? dialogTitle,
    List<String>? allowedExtensions,
  }) async {
    if (kIsWeb) {
      // Web handling - use browser download
      throw UnsupportedError('Web file saving not implemented in this helper');
    }

    // On macOS and Linux, use save dialog for proper permissions
    if (universal_io.Platform.isMacOS || universal_io.Platform.isLinux) {
      return await _saveWithDialog(
        bytes: bytes,
        fileName: fileName,
        dialogTitle: dialogTitle,
        allowedExtensions: allowedExtensions,
      );
    }

    // On Windows, maintain existing behavior - save directly to Documents
    if (universal_io.Platform.isWindows) {
      return await _saveToDocuments(bytes: bytes, fileName: fileName);
    }

    throw UnsupportedError('Platform not supported');
  }

  /// Save file using native save dialog (macOS/Linux)
  static Future<String?> _saveWithDialog({
    required List<int> bytes,
    required String fileName,
    String? dialogTitle,
    List<String>? allowedExtensions,
  }) async {
    try {
      // Show native save dialog
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle ?? 'Save File',
        fileName: fileName,
        type: allowedExtensions != null && allowedExtensions.isNotEmpty
            ? FileType.custom
            : FileType.any,
        allowedExtensions: allowedExtensions,
      );

      if (outputPath == null) {
        // User cancelled
        return null;
      }

      // Write file to selected location
      final file = File(outputPath);
      await file.writeAsBytes(bytes);

      return outputPath;
    } catch (e) {
      print('Error saving file with dialog: $e');
      return null;
    }
  }

  /// Save file directly to Documents folder (Windows)
  static Future<String?> _saveToDocuments({
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      return filePath;
    } catch (e) {
      print('Error saving file to Documents: $e');
      return null;
    }
  }

  /// Save a PDF file specifically
  static Future<String?> savePdf({
    required List<int> pdfBytes,
    required String fileName,
  }) async {
    // Ensure fileName has .pdf extension
    final pdfFileName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';

    return await saveFile(
      bytes: pdfBytes,
      fileName: pdfFileName,
      dialogTitle: 'Save PDF',
      allowedExtensions: ['pdf'],
    );
  }

  /// Save an Excel file specifically
  static Future<String?> saveExcel({
    required List<int> excelBytes,
    required String fileName,
  }) async {
    // Ensure fileName has .xlsx extension
    final excelFileName =
        fileName.endsWith('.xlsx') ? fileName : '$fileName.xlsx';

    return await saveFile(
      bytes: excelBytes,
      fileName: excelFileName,
      dialogTitle: 'Save Excel File',
      allowedExtensions: ['xlsx', 'xls'],
    );
  }

  /// Get a safe path for temporary file operations
  /// This returns a path within the app's sandbox that's safe to write to
  static Future<String> getTempFilePath(String fileName) async {
    final tempDir = await getTemporaryDirectory();
    return '${tempDir.path}/$fileName';
  }

  /// Check if a file path is accessible (for reading existing files)
  static Future<bool> isFileAccessible(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}
