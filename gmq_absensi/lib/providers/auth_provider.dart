import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;
  
  AuthProvider() {
    loadUserFromSession();
  }
  
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  bool get isSuperadmin => _currentUser?.role == 'superadmin';
  bool get isOperator => _currentUser?.role == 'operator';
  bool get isSupervisor => _currentUser?.role == 'supervisor';
  bool get isAuthenticated => _currentUser != null;
  
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    final trimmedEmail = email.trim();
    print('--- LOGIN ATTEMPT ---');
    print('Email entered: "$trimmedEmail"');
    
    try {
      final response = await SupabaseService.auth.signInWithPassword(
        email: trimmedEmail,
        password: password,
      );
      
      if (response.user != null) {
        final userUuid = response.user!.id;
        print('Supabase Auth authentication SUCCESS.');
        print('User Auth UUID: "$userUuid"');
        print('User Auth Email: "${response.user!.email}"');
        
        print('Querying public.users table for ID: "$userUuid"...');
        final userData = await SupabaseService.client
            .from('users')
            .select()
            .eq('id', userUuid)
            .maybeSingle();
        
        print('Database response from public.users: $userData');
        
        if (userData == null) {
          _errorMessage = 'User tidak ditemukan di database';
          print('Error: User UUID "$userUuid" exists in Auth but is MISSING in public.users table.');
          _isLoading = false;
          notifyListeners();
          return false;
        }
        
        _currentUser = UserModel.fromJson(userData);
        print('User Profile mapped successfully: role=${_currentUser!.role}, isActive=${_currentUser!.isActive}');
        
        if (!_currentUser!.isActive) {
          _errorMessage = 'Akun Anda tidak aktif. Hubungi administrator.';
          print('Error: User account is inactive.');
          _currentUser = null;
          _isLoading = false;
          notifyListeners();
          return false;
        }
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_role', _currentUser!.role);
        await prefs.setString('user_email', _currentUser!.email);
        await prefs.setString('user_name', _currentUser!.name);
        
        _isLoading = false;
        notifyListeners();
        print('Login fully COMPLETED successfully.');
        return true;
      } else {
        _errorMessage = 'Email atau password salah';
        print('Error: Supabase Auth returned null user response.');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Login gagal: ${e.toString()}';
      print('Exception during login: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    await SupabaseService.logout();
    _currentUser = null;
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<void> loadUserFromSession() async {
    _isLoading = true;
    notifyListeners();
    
    final session = SupabaseService.auth.currentSession;
    print('--- LOAD SESSION CHECK ---');
    if (session != null) {
      final sessionUuid = session.user.id;
      print('Active session found for user ID: "$sessionUuid", email: "${session.user.email}"');
      try {
        print('Querying public.users for session user ID: "$sessionUuid"...');
        final userData = await SupabaseService.client
            .from('users')
            .select()
            .eq('id', sessionUuid)
            .maybeSingle();
        
        print('Session user database response: $userData');
        if (userData != null) {
          _currentUser = UserModel.fromJson(userData);
          print('Session user profile mapped successfully.');
        } else {
          print('Warning: Session user ID "$sessionUuid" not found in public.users table.');
        }
      } catch (e) {
        print('Error loading user from session query: $e');
      }
    } else {
      print('No active session found.');
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
