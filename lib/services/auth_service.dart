import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum UserRole {
  admin,
  driver,
  parent,
  student,
}

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _storage = const FlutterSecureStorage();

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        await _storage.write(key: 'user_id', value: response.user!.id);
        await _storage.write(key: 'session', value: response.session?.accessToken);
      }
      
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      await _storage.delete(key: 'user_id');
      await _storage.delete(key: 'session');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserRole?> getUserRole() async {
    try {
      final userId = await _storage.read(key: 'user_id');
      if (userId == null) return null;

      final response = await _supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', userId)
          .single();

      return UserRole.values.firstWhere(
        (role) => role.toString() == 'UserRole.${response['role']}',
      );
    } catch (e) {
      return null;
    }
  }

  Future<bool> isAuthenticated() async {
    try {
      final session = await _storage.read(key: 'session');
      return session != null;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getUserId() async {
    try {
      return await _storage.read(key: 'user_id');
    } catch (e) {
      return null;
    }
  }
} 