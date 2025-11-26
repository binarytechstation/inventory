import 'package:bcrypt/bcrypt.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/user_model.dart';

class AuthService {
  static AuthService? _instance;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  UserModel? _currentUser;

  AuthService._();

  factory AuthService() {
    _instance ??= AuthService._();
    return _instance!;
  }

  /// Login user with username and password
  Future<UserModel?> login(String username, String password) async {
    try {
      final db = await _dbHelper.database;

      final results = await db.query(
        'users',
        where: 'username = ? AND is_active = 1',
        whereArgs: [username],
      );

      if (results.isEmpty) {
        return null;
      }

      final user = UserModel.fromMap(results.first);

      // Verify password
      final isPasswordValid = BCrypt.checkpw(password, user.passwordHash);

      if (!isPasswordValid) {
        return null;
      }

      // Update last login
      await db.update(
        'users',
        {'last_login': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [user.id],
      );

      _currentUser = user;
      return user;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  /// Logout current user
  void logout() {
    _currentUser = null;
  }

  /// Get current logged-in user
  UserModel? getCurrentUser() {
    return _currentUser;
  }

  /// Check if user is logged in
  bool isLoggedIn() {
    return _currentUser != null;
  }

  /// Create new user
  Future<UserModel?> createUser({
    required String username,
    required String password,
    required String role,
    required String name,
    String? email,
    String? phone,
    bool mustChangePassword = false,
  }) async {
    try {
      final db = await _dbHelper.database;

      // Check if username already exists
      final existing = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username],
      );

      if (existing.isNotEmpty) {
        throw Exception('Username already exists');
      }

      // Hash password
      final passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());

      final now = DateTime.now();
      final user = UserModel(
        username: username,
        passwordHash: passwordHash,
        role: role,
        name: name,
        email: email,
        phone: phone,
        mustChangePassword: mustChangePassword,
        createdAt: now,
        updatedAt: now,
      );

      final id = await db.insert('users', user.toMap());

      return user.copyWith(id: id);
    } catch (e) {
      print('Create user error: $e');
      return null;
    }
  }

  /// Change password
  Future<bool> changePassword(int userId, String newPassword) async {
    try {
      final db = await _dbHelper.database;

      final passwordHash = BCrypt.hashpw(newPassword, BCrypt.gensalt());

      await db.update(
        'users',
        {
          'password_hash': passwordHash,
          'must_change_password': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [userId],
      );

      return true;
    } catch (e) {
      print('Change password error: $e');
      return false;
    }
  }

  /// Initialize default admin user with hashed password
  Future<void> initializeDefaultAdmin() async {
    try {
      final db = await _dbHelper.database;

      // Check if admin exists
      final results = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: ['admin'],
      );

      if (results.isEmpty) {
        // Create admin if doesn't exist
        await createUser(
          username: 'admin',
          password: 'admin',
          role: 'admin',
          name: 'Administrator',
          mustChangePassword: true,
        );
      } else {
        // Update admin password hash if it's still the temp value
        final user = UserModel.fromMap(results.first);
        if (user.passwordHash == 'TEMP_WILL_BE_SET_BY_AUTH_SERVICE') {
          final passwordHash = BCrypt.hashpw('admin', BCrypt.gensalt());
          await db.update(
            'users',
            {
              'password_hash': passwordHash,
              'must_change_password': 1,
            },
            where: 'id = ?',
            whereArgs: [user.id],
          );
        }
      }
    } catch (e) {
      print('Initialize admin error: $e');
    }
  }

  /// Verify current password
  Future<bool> verifyPassword(int userId, String password) async {
    try {
      final db = await _dbHelper.database;

      final results = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (results.isEmpty) {
        return false;
      }

      final user = UserModel.fromMap(results.first);
      return BCrypt.checkpw(password, user.passwordHash);
    } catch (e) {
      print('Verify password error: $e');
      return false;
    }
  }

  /// Get all users
  Future<List<UserModel>> getAllUsers() async {
    try {
      final db = await _dbHelper.database;

      // Show ALL users (both active and inactive)
      final results = await db.query(
        'users',
        orderBy: 'created_at DESC',
      );

      return results.map((map) => UserModel.fromMap(map)).toList();
    } catch (e) {
      print('Get all users error: $e');
      return [];
    }
  }

  /// Update user
  Future<bool> updateUser(UserModel user) async {
    try {
      final db = await _dbHelper.database;

      await db.update(
        'users',
        user.toMap()..['updated_at'] = DateTime.now().toIso8601String(),
        where: 'id = ?',
        whereArgs: [user.id],
      );

      return true;
    } catch (e) {
      print('Update user error: $e');
      return false;
    }
  }

  /// Deactivate user (soft delete by setting is_active to false)
  Future<bool> deactivateUser(int userId) async {
    try {
      final db = await _dbHelper.database;

      await db.update(
        'users',
        {
          'is_active': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [userId],
      );

      return true;
    } catch (e) {
      print('Deactivate user error: $e');
      return false;
    }
  }

  /// Delete user permanently (hard delete from database)
  /// WARNING: This permanently removes the user and cannot be undone
  Future<bool> deleteUser(int userId) async {
    try {
      final db = await _dbHelper.database;

      await db.delete(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      return true;
    } catch (e) {
      print('Delete user error: $e');
      return false;
    }
  }
}
