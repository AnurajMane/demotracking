import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _storage = const FlutterSecureStorage();
  User? _user;
  bool _isLoading = false;
  String? _error;
  String? _userRole;
  bool _isAuthenticated = false;

  // Getters
  User? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get userRole => _userRole;

  AuthProvider() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Check for stored session
      final session = await _storage.read(key: Constants.authTokenKey);
      if (session != null) {
        final user = _supabase.auth.currentUser;
        if (user != null) {
          _user = user;
          notifyListeners();
        } else {
          await _storage.delete(key: Constants.authTokenKey);
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize auth: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      debugPrint('Attempting to sign in with email: $email');

      // 1. Authenticate with Supabase
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      debugPrint('Supabase auth response received: ${response.user != null}');

      if (response.user != null) {
        debugPrint('User authenticated, fetching profile...');
        // 2. Get user profile with role
        final profileResponse = await _supabase
            .from('profiles')
            .select('role, full_name, phone_number')
            .eq('id', response.user!.id)
            .single();

        debugPrint('Profile fetched, role: ${profileResponse['role']}, name: ${profileResponse['full_name']}');

        // 3. Update state
        _user = response.user;
        _userRole = profileResponse['role'];

        // 4. Store session
        await _storage.write(
          key: Constants.authTokenKey,
          value: response.session?.accessToken,
        );

        debugPrint('Auth state updated - user: ${_user != null}, role: $_userRole');
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Sign in error: $e');
      _error = 'Failed to sign in: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabase.auth.signOut();
      await _storage.delete(key: Constants.authTokenKey);
      _user = null;
      _userRole = null;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to sign out: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final user = _supabase.auth.currentUser;
      if (user != null) {
        _user = user;
      } else {
        await _storage.delete(key: Constants.authTokenKey);
        _user = null;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to check auth status: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabase.auth.resetPasswordForEmail(email);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to reset password: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Make initializeAuth public and implement it properly
  Future<void> initializeAuth() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Check for stored session
      final session = await _storage.read(key: Constants.authTokenKey);
      if (session != null) {
        final user = _supabase.auth.currentUser;
        if (user != null) {
          try {
            // Get user profile with role
            final profileResponse = await _supabase
                .from('profiles')
                .select('role, full_name, phone_number')
                .eq('id', user.id)
                .single();

            _user = user;
            _userRole = profileResponse['role'] as String?;
            notifyListeners();
          } catch (e) {
            debugPrint('Error fetching user profile: $e');
            await _storage.delete(key: Constants.authTokenKey);
            _user = null;
            _userRole = null;
          }
        } else {
          await _storage.delete(key: Constants.authTokenKey);
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize auth: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
}