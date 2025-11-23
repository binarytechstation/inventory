class AppConstants {
  // App Information
  static const String appName = 'Inventory Management System';
  static const String appVersion = '1.0.0';

  // Security - This salt should be kept secret and consistent
  // In production, consider using a more secure method to store this
  static const String appSalt = 'INV_SECURE_SALT_2024_V1_CHANGE_THIS_IN_PRODUCTION';

  // Encryption
  static const int pbkdf2Iterations = 150000;
  static const int aesKeyLength = 32; // 256-bit

  // Database
  static const String dbFileName = 'inventory_db.db';
  static const String backupFolderName = 'backups';

  // License
  static const String licenseFileName = 'license.key';
  static const String vendorSecret = 'VENDOR_SECRET_KEY_CHANGE_IN_PRODUCTION';

  // Paths - These will be set at runtime
  static String? appDataPath;
  static String? dbPath;
  static String? licensePath;
  static String? backupPath;

  // Default Admin Credentials
  static const String defaultAdminUsername = 'admin';
  static const String defaultAdminPassword = 'admin';

  // Recovery
  static const int recoveryCodeLength = 32;

  // Invoice Settings
  static const String defaultInvoicePrefix = 'INV';
  static const int defaultInvoiceStartNumber = 1000;

  // Roles
  static const String roleAdmin = 'admin';
  static const String roleManager = 'manager';
  static const String roleCashier = 'cashier';
  static const String roleViewer = 'viewer';

  // Transaction Types
  static const String transactionTypeBuy = 'BUY';
  static const String transactionTypeSell = 'SELL';
  static const String transactionTypeReturn = 'RETURN';

  // Payment Modes
  static const String paymentModeCash = 'CASH';
  static const String paymentModeCredit = 'CREDIT';

  // Transaction Status
  static const String statusCompleted = 'COMPLETED';
  static const String statusHeld = 'HELD';
  static const String statusCancelled = 'CANCELLED';

  // Pagination
  static const int defaultPageSize = 50;

  // Date Formats
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  static const String displayDateFormat = 'dd MMM yyyy';
  static const String displayDateTimeFormat = 'dd MMM yyyy, hh:mm a';
}
