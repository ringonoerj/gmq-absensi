import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'supabase_service.dart';

class CacheService {
  static Box? _cacheBox;
  
  static Future<void> init() async {
    _cacheBox = await Hive.openBox('gmq_cache');
  }
  
  static Future<void> saveData(String key, dynamic value) async {
    await _cacheBox?.put(key, value);
  }
  
  static dynamic getData(String key) {
    return _cacheBox?.get(key);
  }
  
  static Future<void> deleteData(String key) async {
    await _cacheBox?.delete(key);
  }
  
  static Future<void> clearCache() async {
    await _cacheBox?.clear();
  }
  
  static Future<void> syncOfflineData() async {
    final offlineEntries = _cacheBox?.get('offline_absensi', defaultValue: []);
    
    if (offlineEntries != null && offlineEntries.isNotEmpty) {
      List failedEntries = [];
      
      for (var entry in offlineEntries) {
        try {
          final Map<String, dynamic> rawEntry = Map<String, dynamic>.from(entry as Map);
          
          // Only send actual database columns to prevent Supabase rejecting metadata
          final Map<String, dynamic> cleanEntry = {
            'user_type': rawEntry['user_type'],
            'user_id': rawEntry['user_id'],
            'date': rawEntry['date'],
            'status': rawEntry['status'],
            'izin_reason': rawEntry['izin_reason'] ?? rawEntry['reason'],
            'recorded_by': rawEntry['recorded_by'],
          };
          
          await SupabaseService.client.from('absensi').insert(cleanEntry);
        } catch (e) {
          failedEntries.add(entry);
          print('Sync failed: $e');
        }
      }
      
      await _cacheBox?.put('offline_absensi', failedEntries);
    }
  }
  
  static Future<int> getOfflineCount() async {
    final offlineEntries = _cacheBox?.get('offline_absensi', defaultValue: []);
    return (offlineEntries as List?)?.length ?? 0;
  }

  // Box name getter for raw access
  static String get cacheBoxName => 'gmq_cache';

  // Master Data Cache helper
  static List<dynamic> getCachedMasterData(String key) {
    final data = _cacheBox?.get(key, defaultValue: []);
    if (data is List) return data;
    return [];
  }
  
  static Future<void> cacheMasterData(String key, List<dynamic> data) async {
    await saveData(key, data);
  }

  // Offline Attendance helpers
  static Future<void> saveOfflineAttendance(Map<String, dynamic> attendance) async {
    final list = getOfflineAttendance();
    list.add(attendance);
    await _cacheBox?.put('offline_absensi', list);
  }
  
  static List<Map<String, dynamic>> getOfflineAttendance() {
    final rawList = _cacheBox?.get('offline_absensi', defaultValue: []);
    if (rawList is List) {
      return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }
  
  static Future<void> removeOfflineAttendanceAt(int index) async {
    final list = getOfflineAttendance();
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await _cacheBox?.put('offline_absensi', list);
    }
  }
  
  static Future<void> clearOfflineAttendance() async {
    await _cacheBox?.put('offline_absensi', []);
  }

  // Network Connectivity helper
  static Future<bool> hasConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      
      // Support both list (connectivity_plus v5+) and single enum (connectivity_plus v4-)
      dynamic res = connectivityResult;
      if (res is List) {
        if (res.isEmpty || res.contains(ConnectivityResult.none)) {
          return false;
        }
      } else {
        if (res == ConnectivityResult.none) {
          return false;
        }
      }

      if (kIsWeb) {
        // InternetAddress.lookup is not supported on web.
        return true;
      }
      
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
