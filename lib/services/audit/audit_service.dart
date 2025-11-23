import '../../data/database/database_helper.dart';

class AuditService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Log user action
  Future<int> logAction(
    int userId,
    String action,
    String entity,
    int? entityId,
    String? details,
  ) async {
    final db = await _dbHelper.database;

    return await db.insert(
      'audit_logs',
      {
        'user_id': userId,
        'action': action,
        'entity_type': entity,
        'entity_id': entityId,
        'details': details,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Get audit logs with optional filters
  Future<List<Map<String, dynamic>>> getAuditLogs({
    int? userId,
    String? action,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    final db = await _dbHelper.database;

    String whereClause = '1=1';
    final whereArgs = <dynamic>[];

    if (userId != null) {
      whereClause += ' AND user_id = ?';
      whereArgs.add(userId);
    }

    if (action != null) {
      whereClause += ' AND action = ?';
      whereArgs.add(action);
    }

    if (startDate != null) {
      whereClause += ' AND created_at >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClause += ' AND created_at <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final maps = await db.query(
      'audit_logs',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return maps;
  }

  /// Get recent audit logs
  Future<List<Map<String, dynamic>>> getRecentLogs(int limit) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'audit_logs',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps;
  }

  /// Get audit logs for specific user
  Future<List<Map<String, dynamic>>> getUserAuditLogs(int userId, {int limit = 100}) async {
    return await getAuditLogs(userId: userId, limit: limit);
  }

  /// Get audit logs by action type
  Future<List<Map<String, dynamic>>> getAuditLogsByAction(
    String action, {
    int limit = 100,
  }) async {
    return await getAuditLogs(action: action, limit: limit);
  }

  /// Get audit logs for specific entity
  Future<List<Map<String, dynamic>>> getEntityAuditLogs(
    String entityType,
    int entityId, {
    int limit = 100,
  }) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'audit_logs',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps;
  }

  /// Get audit logs count
  Future<int> getAuditLogsCount({
    int? userId,
    String? action,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;

    String whereClause = '1=1';
    final whereArgs = <dynamic>[];

    if (userId != null) {
      whereClause += ' AND user_id = ?';
      whereArgs.add(userId);
    }

    if (action != null) {
      whereClause += ' AND action = ?';
      whereArgs.add(action);
    }

    if (startDate != null) {
      whereClause += ' AND created_at >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClause += ' AND created_at <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM audit_logs WHERE $whereClause',
      whereArgs,
    );

    final count = result.first['count'];
    return count is int ? count : 0;
  }

  /// Clear old logs older than specified number of days
  Future<int> clearOldLogs(int daysToKeep) async {
    final db = await _dbHelper.database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

    return await db.delete(
      'audit_logs',
      where: 'created_at < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  /// Delete specific audit log
  Future<int> deleteAuditLog(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'audit_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Clear all audit logs (use with caution)
  Future<int> clearAllLogs() async {
    final db = await _dbHelper.database;
    return await db.delete('audit_logs');
  }

  /// Get audit logs summary by action
  Future<List<Map<String, dynamic>>> getAuditSummaryByAction() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT
        action,
        COUNT(*) as count,
        MAX(created_at) as last_action_date
      FROM audit_logs
      GROUP BY action
      ORDER BY count DESC
    ''');
    return result;
  }

  /// Get audit logs summary by user
  Future<List<Map<String, dynamic>>> getAuditSummaryByUser() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT
        user_id,
        username,
        COUNT(*) as action_count,
        MAX(created_at) as last_action_date
      FROM audit_logs
      WHERE user_id IS NOT NULL
      GROUP BY user_id
      ORDER BY action_count DESC
    ''');
    return result;
  }

  /// Get audit logs for date range
  Future<List<Map<String, dynamic>>> getAuditLogsByDateRange(
    DateTime startDate,
    DateTime endDate, {
    int limit = 100,
  }) async {
    return await getAuditLogs(
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }
}
