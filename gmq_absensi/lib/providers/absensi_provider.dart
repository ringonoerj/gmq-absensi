import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/supabase_service.dart';
import '../services/cache_service.dart';
import '../models/absensi_model.dart';

class AbsensiProvider extends ChangeNotifier {
  List<AbsensiModel> _absensi = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  List<AbsensiModel> get absensi => _absensi;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  Future<List<AbsensiModel>> getAbsensiByDate(DateTime date, {String? userType, int? userId, int? unitId, int? kelasId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    final isOnline = await CacheService.hasConnection();
    if (!isOnline) {
      _isLoading = false;
      _errorMessage = 'Offline: Tidak dapat mengambil data absensi dari server.';
      notifyListeners();
      return _absensi;
    }
    
    try {
      var query = SupabaseService.client
          .from('absensi')
          .select()
          .eq('date', date.toIso8601String().split('T').first);
      
      if (userType != null) {
        query = query.eq('user_type', userType);
      }
      if (userId != null) {
        query = query.eq('user_id', userId);
      }
      if (unitId != null) {
        query = query.eq('unit_id', unitId);
      }
      if (kelasId != null) {
        query = query.eq('kelas_id', kelasId);
      }
      
      final response = await query;
      _absensi = (response as List).map((e) => AbsensiModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _errorMessage = 'Error get absensi: ${e.toString()}';
      print(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    
    return _absensi;
  }
  
  Future<Map<String, int>> saveAbsensi({
    required String userType,
    required int userId,
    required List<DateTime> dates,
    required String status,
    String? izinReason,
    required String recordedBy,
    String? userName,
    String? unitName,
    String? className,
    int? unitId,
    int? kelasId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    int successCount = 0;
    int duplicateCount = 0;
    int offlineCount = 0;
    
    final isOnline = await CacheService.hasConnection();
    
    if (!isOnline) {
      try {
        for (var date in dates) {
          final formattedDate = date.toIso8601String().split('T').first;
          
          // Save to Hive offline queue via CacheService
          await CacheService.saveOfflineAttendance({
            'user_type': userType,
            'user_id': userId,
            'date': formattedDate,
            'status': status,
            'izin_reason': izinReason,
            'recorded_by': recordedBy,
            'user_name': userName ?? 'User ID $userId',
            'unit_name': unitName ?? 'Unit',
            'class_name': className ?? '-',
            'created_at': DateTime.now().toIso8601String(),
            'unit_id': unitId,
            'kelas_id': kelasId,
          });
          offlineCount++;
        }
      } catch (e) {
        _errorMessage = 'Gagal menyimpan offline: ${e.toString()}';
      } finally {
        _isLoading = false;
        notifyListeners();
      }
      return {'success': successCount, 'duplicate': duplicateCount, 'offline': offlineCount};
    }
    
    try {
      for (var date in dates) {
        final formattedDate = date.toIso8601String().split('T').first;
        
        var query = SupabaseService.client
            .from('absensi')
            .select()
            .eq('user_type', userType)
            .eq('user_id', userId)
            .eq('date', formattedDate);
            
        if (unitId != null) {
          query = query.eq('unit_id', unitId);
        }
        if (kelasId != null) {
          query = query.eq('kelas_id', kelasId);
        }
        
        final existing = await query;
        
        if ((existing as List).isEmpty) {
          await SupabaseService.client.from('absensi').insert({
            'user_type': userType,
            'user_id': userId,
            'date': formattedDate,
            'status': status,
            'izin_reason': izinReason,
            'recorded_by': recordedBy,
            'unit_id': unitId,
            'kelas_id': kelasId,
          });
          successCount++;
        } else {
          duplicateCount++;
        }
      }
    } catch (e) {
      _errorMessage = 'Error save absensi: ${e.toString()}';
      print(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    
    return {'success': successCount, 'duplicate': duplicateCount, 'offline': 0};
  }
  
  Future<Map<String, int>> syncOfflineAttendance() async {
    final isOnline = await CacheService.hasConnection();
    if (!isOnline) {
      return {'success': 0, 'failed': 0};
    }
    
    final offlineQueue = CacheService.getOfflineAttendance();
    if (offlineQueue.isEmpty) {
      return {'success': 0, 'failed': 0};
    }
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    int successCount = 0;
    int failedCount = 0;
    
    List<Map<String, dynamic>> remainingQueue = [];
    
    for (var item in offlineQueue) {
      try {
        final formattedDate = item['date'] as String;
        final userType = item['user_type'] as String;
        final userId = item['user_id'] as int;
        final status = item['status'] as String;
        final izinReason = item['izin_reason'] as String?;
        final recordedBy = item['recorded_by'] as String;
        final unitId = item['unit_id'] as int?;
        final kelasId = item['kelas_id'] as int?;
        
        var query = SupabaseService.client
            .from('absensi')
            .select()
            .eq('user_type', userType)
            .eq('user_id', userId)
            .eq('date', formattedDate);
            
        if (unitId != null) {
          query = query.eq('unit_id', unitId);
        }
        if (kelasId != null) {
          query = query.eq('kelas_id', kelasId);
        }
        
        final existing = await query;
        
        if ((existing as List).isEmpty) {
          await SupabaseService.client.from('absensi').insert({
            'user_type': userType,
            'user_id': userId,
            'date': formattedDate,
            'status': status,
            'izin_reason': izinReason,
            'recorded_by': recordedBy,
            'unit_id': unitId,
            'kelas_id': kelasId,
          });
        }
        successCount++;
      } catch (e) {
        print('Error syncing item: $e');
        failedCount++;
        remainingQueue.add(item);
      }
    }
    
    // Save remaining back to queue
    await Hive.box(CacheService.cacheBoxName).put('offline_absensi', remainingQueue);
    
    _isLoading = false;
    notifyListeners();
    
    return {'success': successCount, 'failed': failedCount};
  }
  
  Future<Map<String, int>> getStatistikHariIni(DateTime date, {String? userType, int? unitId}) async {
    final isOnline = await CacheService.hasConnection();
    final formattedDate = date.toIso8601String().split('T').first;
    final cacheKey = 'stats_$formattedDate';

    if (!isOnline) {
      // Get cached statistics
      final cachedList = CacheService.getCachedMasterData(cacheKey);
      Map<String, int> stats = {'hadir': 0, 'izin': 0, 'sakit': 0, 'alpha': 0};
      
      if (cachedList.isNotEmpty && cachedList[0] is Map) {
        final cachedMap = Map<String, dynamic>.from(cachedList[0] as Map);
        stats = cachedMap.map((key, value) => MapEntry(key, value as int));
      }
      
      // Add any unsynced offline records from the queue for today
      final offlineQueue = CacheService.getOfflineAttendance();
      for (var item in offlineQueue) {
        if (item['date'] == formattedDate) {
          if (userType == null || item['user_type'] == userType) {
            if (unitId == null || item['unit_id'] == unitId) {
              final status = item['status'] as String;
              if (stats.containsKey(status)) {
                stats[status] = (stats[status] ?? 0) + 1;
              }
            }
          }
        }
      }
      return stats;
    }
    
    try {
      var query = SupabaseService.client
          .from('absensi')
          .select('status')
          .eq('date', formattedDate);
      
      if (userType != null) {
        query = query.eq('user_type', userType);
      }
      if (unitId != null) {
        query = query.eq('unit_id', unitId);
      }
      
      final response = await query;
      
      int hadir = (response as List).where((a) => a['status'] == 'hadir').length;
      int izin = response.where((a) => a['status'] == 'izin').length;
      int sakit = response.where((a) => a['status'] == 'sakit').length;
      int alpha = response.where((a) => a['status'] == 'alpha').length;
      
      final stats = {'hadir': hadir, 'izin': izin, 'sakit': sakit, 'alpha': alpha};
      
      // Cache statistic for offline view
      await CacheService.saveData(cacheKey, [stats]);
      
      return stats;
    } catch (e) {
      print('Error get statistik: $e');
      return {'hadir': 0, 'izin': 0, 'sakit': 0, 'alpha': 0};
    }
  }
  
  Future<Map<DateTime, List<Color>>> getMarkedDates(int userId, String userType, DateTime month, {int? unitId, int? kelasId}) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0);
    
    var query = SupabaseService.client
        .from('absensi')
        .select('date, status')
        .eq('user_id', userId)
        .eq('user_type', userType)
        .gte('date', startDate.toIso8601String().split('T').first)
        .lte('date', endDate.toIso8601String().split('T').first);
        
    if (unitId != null) {
      query = query.eq('unit_id', unitId);
    }
    if (kelasId != null) {
      query = query.eq('kelas_id', kelasId);
    }
    
    final response = await query;
    final Map<DateTime, List<Color>> markedDates = {};
    
    for (var item in (response as List)) {
      final date = DateTime.parse(item['date']);
      Color color;
      switch (item['status']) {
        case 'hadir': color = Colors.green; break;
        case 'izin': color = Colors.orange; break;
        case 'sakit': color = Colors.blue; break;
        default: color = Colors.red;
      }
      markedDates[date] = [color];
    }
    
    return markedDates;
  }

  Future<bool> updateOrCreateAbsensi({
    required String userType,
    required int userId,
    required DateTime date,
    required String status,
    String? izinReason,
    required String recordedBy,
    int? unitId,
    int? kelasId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    final isOnline = await CacheService.hasConnection();
    if (!isOnline) {
      _isLoading = false;
      _errorMessage = 'Tidak dapat memperbarui absensi dalam mode offline.';
      notifyListeners();
      return false;
    }
    try {
      final formattedDate = date.toIso8601String().split('T').first;
      
      // Check if record already exists for this user, type, date, and unit
      var query = SupabaseService.client
          .from('absensi')
          .select('id')
          .eq('user_type', userType)
          .eq('user_id', userId)
          .eq('date', formattedDate);
          
      if (unitId != null) {
        query = query.eq('unit_id', unitId);
      }
      
      final existing = await query;
      
      if ((existing as List).isNotEmpty) {
        // Update existing record
        final recordId = existing[0]['id'];
        await SupabaseService.client.from('absensi').update({
          'status': status,
          'izin_reason': (status == 'izin' || status == 'sakit') ? izinReason : null,
          'recorded_by': recordedBy,
          'kelas_id': kelasId,
        }).eq('id', recordId);
      } else {
        // Insert new record
        await SupabaseService.client.from('absensi').insert({
          'user_type': userType,
          'user_id': userId,
          'date': formattedDate,
          'status': status,
          'izin_reason': (status == 'izin' || status == 'sakit') ? izinReason : null,
          'recorded_by': recordedBy,
          'unit_id': unitId,
          'kelas_id': kelasId,
        });
      }
      
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui absensi: ${e.toString()}';
      print(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAbsensi({
    required String userType,
    required int userId,
    required DateTime date,
    int? unitId,
    int? kelasId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    final isOnline = await CacheService.hasConnection();
    if (!isOnline) {
      _isLoading = false;
      _errorMessage = 'Tidak dapat menghapus absensi dalam mode offline.';
      notifyListeners();
      return false;
    }
    
    try {
      final formattedDate = date.toIso8601String().split('T').first;
      var query = SupabaseService.client
          .from('absensi')
          .delete()
          .eq('user_type', userType)
          .eq('user_id', userId)
          .eq('date', formattedDate);
          
      if (unitId != null) {
        query = query.eq('unit_id', unitId);
      }
      if (kelasId != null) {
        query = query.eq('kelas_id', kelasId);
      }
      
      await query;
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menghapus absensi: ${e.toString()}';
      print(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

