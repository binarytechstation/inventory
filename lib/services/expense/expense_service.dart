import '../../data/database/database_helper.dart';

class ExpenseService {
  static ExpenseService? _instance;
  factory ExpenseService() {
    _instance ??= ExpenseService._();
    return _instance!;
  }
  ExpenseService._();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  static const List<String> defaultCategories = [
    'General',
    'Rent',
    'Salary',
    'Utilities',
    'Transport',
    'Marketing',
    'Maintenance',
    'Office Supplies',
    'Food & Entertainment',
    'Tax & Fees',
    'Loan Repayment',
    'Other',
  ];

  // ─── CRUD ────────────────────────────────────────────────────────────────────

  Future<int> addExpense({
    required String title,
    required double amount,
    required DateTime expenseDate,
    String category = 'General',
    String paymentMethod = 'cash',
    String? notes,
    int? createdBy,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    return await db.insert('expenses', {
      'title': title,
      'amount': amount,
      'category': category,
      'expense_date': expenseDate.toIso8601String(),
      'payment_method': paymentMethod,
      'notes': notes,
      'created_by': createdBy,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateExpense({
    required int id,
    required String title,
    required double amount,
    required DateTime expenseDate,
    String category = 'General',
    String paymentMethod = 'cash',
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      'expenses',
      {
        'title': title,
        'amount': amount,
        'category': category,
        'expense_date': expenseDate.toIso8601String(),
        'payment_method': paymentMethod,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteExpense(int id) async {
    final db = await _dbHelper.database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) async {
    final db = await _dbHelper.database;
    final where = <String>[];
    final args = <dynamic>[];

    if (startDate != null) {
      where.add('expense_date >= ?');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      where.add('expense_date <= ?');
      args.add(end.toIso8601String());
    }
    if (category != null && category != 'All') {
      where.add('category = ?');
      args.add(category);
    }

    return await db.query(
      'expenses',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'expense_date DESC',
    );
  }

  Future<double> getTotalExpenses({DateTime? startDate, DateTime? endDate}) async {
    final db = await _dbHelper.database;
    final where = <String>[];
    final args = <dynamic>[];

    if (startDate != null) {
      where.add('expense_date >= ?');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      where.add('expense_date <= ?');
      args.add(end.toIso8601String());
    }

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM expenses'
      '${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'}',
      args.isEmpty ? null : args,
    );
    return (result.first['total'] as num).toDouble();
  }

  /// Returns categories with totals for the period.
  Future<List<Map<String, dynamic>>> getExpensesByCategory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;
    final where = <String>[];
    final args = <dynamic>[];

    if (startDate != null) {
      where.add('expense_date >= ?');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      where.add('expense_date <= ?');
      args.add(end.toIso8601String());
    }

    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    return await db.rawQuery(
      'SELECT category, COALESCE(SUM(amount), 0) as total, COUNT(*) as count '
      'FROM expenses $whereClause GROUP BY category ORDER BY total DESC',
      args.isEmpty ? null : args,
    );
  }
}
