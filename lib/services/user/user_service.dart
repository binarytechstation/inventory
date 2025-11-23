import 'package:bcrypt/bcrypt.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/user_model.dart';

class UserService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Get all active users
  Future<List<UserModel>> getAllUsers({String sortBy = 'name'}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'users',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: '$sortBy ASC',
    );
    return maps.map((map) => UserModel.fromMap(map)).toList();
  }

  /// Get user by ID
  Future<UserModel?> getUserById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'users',
      where: 'id = ? AND is_active = ?',
      whereArgs: [id, 1],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UserModel.fromMap(maps.first);
  }

  /// Get user by username
  Future<UserModel?> getUserByUsername(String username) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UserModel.fromMap(maps.first);
  }

  /// Search users by name or username
  Future<List<UserModel>> searchUsers(String query) async {
    final db = await _dbHelper.database;
    final searchQuery = '%$query%';
    final maps = await db.query(
      'users',
      where: '(name LIKE ? OR username LIKE ?) AND is_active = ?',
      whereArgs: [searchQuery, searchQuery, 1],
      orderBy: 'name ASC',
    );
    return maps.map((map) => UserModel.fromMap(map)).toList();
  }

  /// Create new user with BCrypt password hashing
  Future<int> createUser(UserModel user) async {
    final db = await _dbHelper.database;

    // Check if username already exists
    final existingUser = await getUserByUsername(user.username);
    if (existingUser != null) {
      throw Exception('Username ${user.username} already exists');
    }

    // Hash password using BCrypt
    final hashedPassword = BCrypt.hashpw(user.passwordHash, BCrypt.gensalt());

    // Create user map with hashed password
    final userMap = user.toMap();
    userMap['password_hash'] = hashedPassword;
    userMap['created_at'] = DateTime.now().toIso8601String();
    userMap['updated_at'] = DateTime.now().toIso8601String();

    return await db.insert('users', userMap);
  }

  /// Update existing user
  Future<int> updateUser(UserModel user) async {
    final db = await _dbHelper.database;

    // Check if username already exists (excluding current user)
    final existingUser = await getUserByUsername(user.username);
    if (existingUser != null && existingUser.id != user.id) {
      throw Exception('Username ${user.username} already exists');
    }

    final userMap = user.toMap();
    userMap['updated_at'] = DateTime.now().toIso8601String();

    return await db.update(
      'users',
      userMap,
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  /// Deactivate user (soft delete)
  Future<int> deleteUser(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'users',
      {
        'is_active': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Alias for consistency
  Future<int> deactivateUser(int id) => deleteUser(id);

  /// Change user password with BCrypt hashing
  Future<int> changePassword(int userId, String newPassword) async {
    final db = await _dbHelper.database;

    // Hash new password using BCrypt
    final hashedPassword = BCrypt.hashpw(newPassword, BCrypt.gensalt());

    return await db.update(
      'users',
      {
        'password_hash': hashedPassword,
        'must_change_password': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Verify user password using BCrypt
  Future<bool> verifyPassword(int userId, String password) async {
    final user = await getUserById(userId);
    if (user == null) return false;

    try {
      return BCrypt.checkpw(password, user.passwordHash);
    } catch (e) {
      return false;
    }
  }

  /// Get total user count
  Future<int> getUserCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM users WHERE is_active = 1',
    );
    final count = result.first['count'];
    return count is int ? count : 0;
  }

  /// Get users by role
  Future<List<UserModel>> getUsersByRole(String role) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'users',
      where: 'role = ? AND is_active = ?',
      whereArgs: [role, 1],
      orderBy: 'name ASC',
    );
    return maps.map((map) => UserModel.fromMap(map)).toList();
  }

  /// Update last login timestamp
  Future<int> updateLastLogin(int userId) async {
    final db = await _dbHelper.database;
    return await db.update(
      'users',
      {
        'last_login': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Check if user needs to change password
  Future<bool> mustChangePassword(int userId) async {
    final user = await getUserById(userId);
    return user?.mustChangePassword ?? false;
  }

  /// Get users that need password change
  Future<List<UserModel>> getUsersNeedingPasswordChange() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'users',
      where: 'must_change_password = ? AND is_active = ?',
      whereArgs: [1, 1],
      orderBy: 'name ASC',
    );
    return maps.map((map) => UserModel.fromMap(map)).toList();
  }
}
