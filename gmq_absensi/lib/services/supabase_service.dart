import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseService {
  // Kredensial dari gmq-absensi-kredensial.txt
  static const String supabaseUrl = 'https://dqrymuvfkxtzzltlqzhw.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_n1xS13CZ4_-liMGwg5L5hA_VckZygrY';
  
  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
  
  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => Supabase.instance.client.auth;
  static String? get currentUserId => auth.currentUser?.id;
  
  static Future<String?> getCurrentUserRole() async {
    final userId = currentUserId;
    if (userId == null) return null;
    try {
      final response = await client
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();
      return response['role'] as String?;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }
  
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final userId = currentUserId;
    if (userId == null) return null;
    try {
      final response = await client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }
  
  static Future<void> logout() async {
    await auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
