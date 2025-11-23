import 'package:flutter/foundation.dart';

class AppProvider extends ChangeNotifier {
  String _currentRoute = '/';
  bool _isLoading = false;

  String get currentRoute => _currentRoute;
  bool get isLoading => _isLoading;

  void setCurrentRoute(String route) {
    _currentRoute = route;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
