import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';
import '../config/routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    if (_isInitialized) return;
    
    try {
      // Initialize authentication state
      await Provider.of<AuthProvider>(context, listen: false).initializeAuth();
      
      // Add a small delay to show the splash screen
      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) return;
      
      // Get the current user and role
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      final role = authProvider.userRole;
      
      if (!mounted) return;
      
      if (user == null) {
        // User is not logged in, navigate to login screen
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      } else {
        // User is logged in, navigate based on role
        switch (role) {
          case 'admin':
            Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
            break;
          case 'student':
            Navigator.pushReplacementNamed(context, AppRoutes.studentDashboard);
            break;
          case 'driver':
            Navigator.pushReplacementNamed(context, AppRoutes.driverDashboard);
            break;
          case 'parent':
            Navigator.pushReplacementNamed(context, AppRoutes.parentDashboard);
            break;
          default:
            // If role is not recognized, navigate to login
            Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      }
    } catch (e) {
      if (!mounted) return;
      // If there's an error, navigate to login screen
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } finally {
      _isInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor,
              AppTheme.secondaryColor,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.directions_bus,
                  size: 60,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              // App Name
              Text(
                'School Bus Tracking',
                style: AppTheme.headingStyle.copyWith(
                  color: Colors.white,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 16),
              // Loading Indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 