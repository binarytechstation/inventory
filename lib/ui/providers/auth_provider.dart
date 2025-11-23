import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../services/auth/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.login(username, password);
      if (user != null) {
        _currentUser = user;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _authService.logout();
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> changePassword(String newPassword) async {
    if (_currentUser == null) return false;

    final success = await _authService.changePassword(_currentUser!.id!, newPassword);
    if (success && _currentUser!.mustChangePassword) {
      _currentUser = _currentUser!.copyWith(mustChangePassword: false);
      notifyListeners();
    }
    return success;
  }

  bool hasPermission(String permission) {
    return _currentUser?.hasPermission(permission) ?? false;
  }

  Future<void> refreshCurrentUser() async {
    if (_currentUser == null) return;

    try {
      final users = await _authService.getAllUsers();
      final updatedUser = users.firstWhere(
        (user) => user.id == _currentUser!.id,
        orElse: () => _currentUser!,
      );
      _currentUser = updatedUser;
      notifyListeners();
    } catch (e) {
      // If refresh fails, keep the current user
      print('Error refreshing user: $e');
    }
  }
}
