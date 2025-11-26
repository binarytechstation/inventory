import '../../data/database/database_helper.dart';

/// Service to manage currency settings across the application
class CurrencyService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Cache for currency symbol
  String? _cachedCurrencySymbol;
  String? _cachedCurrencyCode;

  /// Get currency symbol from invoice settings
  /// Returns the currency symbol (e.g., '$', '€', '£')
  Future<String> getCurrencySymbol() async {
    // Return cached value if available
    if (_cachedCurrencySymbol != null) {
      return _cachedCurrencySymbol!;
    }

    final db = await _dbHelper.database;

    // Try to get currency from invoice settings (preferably SALE type)
    final result = await db.query(
      'invoice_settings',
      columns: ['currency_symbol'],
      where: 'invoice_type = ?',
      whereArgs: ['SALE'],
      limit: 1,
    );

    if (result.isNotEmpty && result.first['currency_symbol'] != null) {
      _cachedCurrencySymbol = result.first['currency_symbol'] as String;
      return _cachedCurrencySymbol!;
    }

    // Fallback: try any invoice settings
    final anyResult = await db.query(
      'invoice_settings',
      columns: ['currency_symbol'],
      limit: 1,
    );

    if (anyResult.isNotEmpty && anyResult.first['currency_symbol'] != null) {
      _cachedCurrencySymbol = anyResult.first['currency_symbol'] as String;
      return _cachedCurrencySymbol!;
    }

    // Default fallback
    _cachedCurrencySymbol = '\$';
    return _cachedCurrencySymbol!;
  }

  /// Get currency code from invoice settings
  /// Returns the currency code (e.g., 'USD', 'EUR', 'GBP')
  Future<String> getCurrencyCode() async {
    // Return cached value if available
    if (_cachedCurrencyCode != null) {
      return _cachedCurrencyCode!;
    }

    final db = await _dbHelper.database;

    // Try to get currency from invoice settings (preferably SALE type)
    final result = await db.query(
      'invoice_settings',
      columns: ['currency_code'],
      where: 'invoice_type = ?',
      whereArgs: ['SALE'],
      limit: 1,
    );

    if (result.isNotEmpty && result.first['currency_code'] != null) {
      _cachedCurrencyCode = result.first['currency_code'] as String;
      return _cachedCurrencyCode!;
    }

    // Fallback: try any invoice settings
    final anyResult = await db.query(
      'invoice_settings',
      columns: ['currency_code'],
      limit: 1,
    );

    if (anyResult.isNotEmpty && anyResult.first['currency_code'] != null) {
      _cachedCurrencyCode = anyResult.first['currency_code'] as String;
      return _cachedCurrencyCode!;
    }

    // Default fallback
    _cachedCurrencyCode = 'USD';
    return _cachedCurrencyCode!;
  }

  /// Format amount with currency symbol
  /// Example: formatAmount(123.45) returns "$123.45"
  Future<String> formatAmount(double amount, {int decimals = 2}) async {
    final symbol = await getCurrencySymbol();
    return '$symbol${amount.toStringAsFixed(decimals)}';
  }

  /// Clear cached currency values (call this when settings are updated)
  void clearCache() {
    _cachedCurrencySymbol = null;
    _cachedCurrencyCode = null;
  }

  /// Singleton pattern
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();
}
