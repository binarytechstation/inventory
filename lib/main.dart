import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/utils/path_helper.dart';
import 'services/auth/auth_service.dart';
import 'data/database/database_helper.dart';
import 'ui/screens/activation/activation_screen.dart';
import 'ui/screens/auth/login_screen.dart';
import 'ui/screens/dashboard/dashboard_screen.dart';
import 'ui/providers/auth_provider.dart';
import 'ui/providers/app_provider.dart';
import 'ui/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize path helper first
  final pathHelper = PathHelper();
  await pathHelper.initialize();

  // Initialize database
  final dbHelper = DatabaseHelper();
  await dbHelper.database; // This will create the database if it doesn't exist

  // Initialize default admin user
  final authService = AuthService();
  await authService.initializeDefaultAdmin();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Inventory Management System',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const AppInitializer(),
            routes: {
              '/activation': (context) => const ActivationScreen(),
              '/login': (context) => const LoginScreen(),
              '/dashboard': (context) => const DashboardScreen(),
            },
          );
        },
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  final bool _isInitializing = true;
  String _initializationMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      setState(() {
        _initializationMessage = 'Loading application...';
      });

      // Skip license check, go directly to login
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      setState(() {
        _initializationMessage = 'Initialization error: $e';
      });

      // On error, wait a bit and try going to login anyway
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'Inventory Management System',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            if (_isInitializing) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_initializationMessage),
            ],
          ],
        ),
      ),
    );
  }
}
