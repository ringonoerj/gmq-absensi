import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/supabase_service.dart';
import '../../services/cache_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/absensi_provider.dart';
import '../../models/unit_model.dart';
import '../../models/kelas_model.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  // Selection states
  int? _selectedUnitId;
  int? _selectedKelasId;
  String? _selectedUserType;
  int? _selectedUserId;
  List<DateTime> _selectedDates = [];
  
  // Data lists
  List<UnitModel> _unitList = [];
  List<KelasModel> _kelasList = [];
  List<Map<String, dynamic>> _guruList = [];
  List<Map<String, dynamic>> _siswaList = [];
  List<Map<String, dynamic>> _holidayList = [];
  
  // UI states
  bool _isLoading = false;
  bool _isOffline = false;
  final _reasonController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadData();
  }
  
  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = connectivityResult == ConnectivityResult.none;
    });
    
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOffline = result == ConnectivityResult.none;
      });
      if (!_isOffline) {
        _syncOfflineData();
      }
    });
  }
  
  Future<void> _syncOfflineData() async {
    await CacheService.syncOfflineData();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Try load from cache first if offline
    if (_isOffline) {
      final cachedUnits = CacheService.getData('units');
      final cachedHolidays = CacheService.getData('holidays');
      if (cachedUnits != null) {
        _unitList = (cachedUnits as List)
            .map((j) => UnitModel.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _unitList.sort((a, b) => a.name.compareTo(b.name));
      }
      if (cachedHolidays != null) {
        _holidayList = (cachedHolidays as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (cachedUnits != null) {
        setState(() => _isLoading = false);
        return;
      }
    }
    
    // Load from network
    try {
      final unitResponse = await SupabaseService.client
          .from('unit_pendidikan')
          .select()
          .order('name');
      _unitList = (unitResponse as List).map((j) => UnitModel.fromJson(j as Map<String, dynamic>)).toList();
      await CacheService.saveData('units', unitResponse);
      
      final holidayResponse = await SupabaseService.client
          .from('libur_nasional')
          .select();
      _holidayList = List<Map<String, dynamic>>.from(holidayResponse as List);
      await CacheService.saveData('holidays', holidayResponse);
    } catch (e) {
      // Try cache as fallback
      final cachedUnits = CacheService.getData('units');
      if (cachedUnits != null) {
        _unitList = (cachedUnits as List)
            .map((j) => UnitModel.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _unitList.sort((a, b) => a.name.compareTo(b.name));
      }
      final cachedHolidays = CacheService.getData('holidays');
      if (cachedHolidays != null) {
        _holidayList = (cachedHolidays as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _loadKelas(int unitId) async {
    if (_isOffline) {
      final cachedKelas = CacheService.getData('kelas_$unitId');
      if (cachedKelas != null) {
        setState(() {
          _kelasList = (cachedKelas as List)
              .map((j) => KelasModel.fromJson(Map<String, dynamic>.from(j as Map)))
              .toList();
          _kelasList.sort((a, b) => a.name.compareTo(b.name));
        });
        return;
      }
    }
    
    try {
      final response = await SupabaseService.client
          .from('kelas')
          .select()
          .eq('unit_id', unitId)
          .order('name');
      setState(() {
        _kelasList = (response as List).map((j) => KelasModel.fromJson(j as Map<String, dynamic>)).toList();
      });
      await CacheService.saveData('kelas_$unitId', response);
    } catch (e) {
      final cachedKelas = CacheService.getData('kelas_$unitId');
      if (cachedKelas != null) {
        setState(() {
          _kelasList = (cachedKelas as List)
              .map((j) => KelasModel.fromJson(Map<String, dynamic>.from(j as Map)))
              .toList();
          _kelasList.sort((a, b) => a.name.compareTo(b.name));
        });
      }
    }
  }
  
  Future<void> _loadGuru(int unitId, {int? kelasId}) async {
    final cacheKey = 'guru_$unitId';
    final cachedGuru = CacheService.getData(cacheKey);
    if (cachedGuru != null) {
      var list = (cachedGuru as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (kelasId != null) {
        list = list.where((g) {
          final List<dynamic>? kIds = g['kelas_ids'] as List<dynamic>?;
          return kIds != null && kIds.contains(kelasId);
        }).toList();
      }
      setState(() {
        _guruList = list;
        _guruList.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      });
      if (_isOffline) return;
    }
    
    try {
      final response = await SupabaseService.client
          .from('guru')
          .select()
          .contains('unit_ids', [unitId])
          .order('name');
      await CacheService.saveData(cacheKey, response);
      
      var list = List<Map<String, dynamic>>.from(response as List);
      if (kelasId != null) {
        list = list.where((g) {
          final List<dynamic>? kIds = g['kelas_ids'] as List<dynamic>?;
          return kIds != null && kIds.contains(kelasId);
        }).toList();
      }
      setState(() {
        _guruList = list;
      });
    } catch (e) {
      final cachedGuru = CacheService.getData(cacheKey);
      if (cachedGuru != null) {
        var list = (cachedGuru as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (kelasId != null) {
          list = list.where((g) {
            final List<dynamic>? kIds = g['kelas_ids'] as List<dynamic>?;
            return kIds != null && kIds.contains(kelasId);
          }).toList();
        }
        setState(() {
          _guruList = list;
          _guruList.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        });
      }
    }
  }
  
  Future<void> _loadSiswa(int unitId, int kelasId) async {
    final cacheKey = 'siswa_${unitId}_$kelasId';
    
    if (_isOffline) {
      final cachedSiswa = CacheService.getData(cacheKey);
      if (cachedSiswa != null) {
        setState(() {
          _siswaList = (cachedSiswa as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _siswaList.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        });
        return;
      }
    }
    
    try {
      final response = await SupabaseService.client
          .from('siswa')
          .select()
          .eq('unit_id', unitId)
          .eq('kelas_id', kelasId)
          .order('name');
      setState(() {
        _siswaList = List<Map<String, dynamic>>.from(response as List);
      });
      await CacheService.saveData(cacheKey, response);
    } catch (e) {
      final cachedSiswa = CacheService.getData(cacheKey);
      if (cachedSiswa != null) {
        setState(() {
          _siswaList = (cachedSiswa as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _siswaList.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        });
      }
    }
  }
  
  Map<String, dynamic>? _getHoliday(DateTime date, int? unitId) {
    if (unitId == null) return null;
    final dateStr = date.toIso8601String().split('T').first;
    for (var h in _holidayList) {
      if (h['tanggal'] == dateStr && (h['unit_id'] == unitId || h['unit_id'] == null)) {
        return h;
      }
    }
    return null;
  }
  
  void _showDatePicker() async {
    if (_selectedUnitId == null) {
      _showError('Pilih Unit Pendidikan terlebih dahulu');
      return;
    }
    
    final now = DateTime.now();
    DateTime tempFocusedDay = DateTime.now();
    List<DateTime> tempSelected = List.from(_selectedDates);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setStateSheet) {
          
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pilih Tanggal',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TableCalendar(
                  firstDay: DateTime(2020),
                  lastDay: now,
                  focusedDay: tempFocusedDay,
                  rowHeight: 40,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  selectedDayPredicate: (day) {
                    return tempSelected.any((d) => isSameDay(d, day));
                  },
                  onDaySelected: (selected, focused) {
                    final holiday = _getHoliday(selected, _selectedUnitId);
                    if (holiday != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Libur: ${holiday['name']}'),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    setStateSheet(() {
                      final index = tempSelected.indexWhere((d) => isSameDay(d, selected));
                      if (index != -1) {
                        tempSelected.removeAt(index);
                      } else {
                        tempSelected.add(selected);
                      }
                      tempFocusedDay = focused;
                    });
                  },
                  calendarStyle: const CalendarStyle(
                    selectedDecoration: BoxDecoration(
                      color: Colors.teal,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: Colors.tealAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _selectedDates = tempSelected;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  void _removeDate(DateTime date) {
    setState(() {
      _selectedDates.removeWhere((d) => isSameDay(d, date));
    });
  }
  
  Future<void> _saveToOfflineCache(
    String userType,
    int userId,
    List<DateTime> dates,
    String status,
    String? reason,
    int? unitId,
    int? kelasId,
    String? userName,
    String? unitName,
    String? className,
  ) async {
    final List<dynamic> offlineEntries = List.from(CacheService.getData('offline_absensi') ?? []);
    
    for (var date in dates) {
      offlineEntries.add({
        'user_type': userType,
        'user_id': userId,
        'date': date.toIso8601String().split('T').first,
        'status': status,
        'izin_reason': reason,
        'recorded_by': SupabaseService.currentUserId,
        'synced': false,
        'unit_id': unitId,
        'kelas_id': kelasId,
        'user_name': userName ?? 'User ID $userId',
        'unit_name': unitName ?? 'Unit',
        'class_name': className ?? '-',
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    
    await CacheService.saveData('offline_absensi', offlineEntries);
  }
  
  Future<void> _saveAbsensi(String status) async {
    // Validations
    if (_selectedUnitId == null) {
      _showError('Pilih Unit Pendidikan');
      return;
    }
    if (_selectedUserType == null) {
      _showError('Pilih tipe (Guru/Siswa)');
      return;
    }
    if (_selectedUserId == null) {
      _showError('Pilih nama');
      return;
    }
    if (_selectedDates.isEmpty) {
      _showError('Pilih minimal 1 tanggal');
      return;
    }
    
    for (var date in _selectedDates) {
      final holiday = _getHoliday(date, _selectedUnitId);
      if (holiday != null) {
        _showError('Libur: Tanggal ${date.day}/${date.month}/${date.year} adalah hari libur (${holiday['name']})');
        return;
      }
    }
    
    String? izinReason;
    if (status == 'izin') {
      final result = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Alasan Izin'),
          content: TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              hintText: 'Masukkan alasan izin...',
            ),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(_),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(_, _reasonController.text),
              child: const Text('Simpan'),
            ),
          ],
        ),
      );
      
      if (result == null || result.isEmpty) {
        _showError('Alasan izin wajib diisi');
        return;
      }
      izinReason = result;
    }
    
    setState(() => _isLoading = true);
    
    String? userName;
    if (_selectedUserType == 'guru') {
      final guru = _guruList.firstWhere((g) => g['id'] == _selectedUserId, orElse: () => {});
      userName = guru['name'] as String?;
    } else {
      final siswa = _siswaList.firstWhere((s) => s['id'] == _selectedUserId, orElse: () => {});
      userName = siswa['name'] as String?;
    }
    
    String? unitName = (_selectedUnitId != null && _unitList.any((u) => u.id == _selectedUnitId))
        ? _unitList.firstWhere((u) => u.id == _selectedUnitId).name 
        : null;
    String? className = (_selectedKelasId != null && _kelasList.any((k) => k.id == _selectedKelasId))
        ? _kelasList.firstWhere((k) => k.id == _selectedKelasId).name 
        : null;

    final finalKelasId = _selectedUserType == 'siswa' ? _selectedKelasId : null;
    final finalClassName = _selectedUserType == 'siswa' ? className : null;
    
    // If offline, save to cache
    if (_isOffline) {
      await _saveToOfflineCache(
        _selectedUserType!,
        _selectedUserId!,
        _selectedDates,
        status,
        izinReason,
        _selectedUnitId,
        finalKelasId,
        userName,
        unitName,
        finalClassName,
      );
      setState(() => _isLoading = false);
      _showSuccess('Disimpan secara offline. Akan tersinkronisasi saat online.');
      _resetForm();
      _reasonController.clear();
      return;
    }
    
    // Online: save to database
    final absensiProvider = Provider.of<AbsensiProvider>(context, listen: false);
    
    final result = await absensiProvider.saveAbsensi(
      userType: _selectedUserType!,
      userId: _selectedUserId!,
      dates: _selectedDates,
      status: status,
      izinReason: izinReason,
      recordedBy: SupabaseService.currentUserId!,
      unitId: _selectedUnitId,
      kelasId: finalKelasId,
      userName: userName,
      unitName: unitName,
      className: finalClassName,
    );
    
    setState(() => _isLoading = false);
    
    if (result['success'] != null && result['success']! > 0) {
      _showSuccess('Berhasil menyimpan ${result['success']} absensi $status');
      _resetForm();
      _reasonController.clear();
    } else {
      _showError('Gagal menyimpan: semua tanggal sudah ada absensi');
    }
  }
  
  void _resetForm() {
    setState(() {
      _selectedUnitId = null;
      _selectedKelasId = null;
      _selectedUserType = null;
      _selectedUserId = null;
      _selectedDates.clear();
      _kelasList = [];
      _guruList = [];
      _siswaList = [];
    });
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Offline banner
                  if (_isOffline)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mode Offline: Data akan disimpan dan tersinkronisasi saat koneksi kembali.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.edit_note, color: Colors.teal),
                              SizedBox(width: 8),
                              Text(
                                'INPUT ABSENSI',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Unit Dropdown
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Unit Pendidikan *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.business),
                            ),
                            value: _selectedUnitId,
                            items: _unitList.map((unit) {
                              return DropdownMenuItem(
                                value: unit.id,
                                child: Text(unit.name),
                              );
                            }).toList(),
                            onChanged: (v) async {
                              setState(() {
                                _selectedUnitId = v;
                                _selectedKelasId = null;
                                _selectedUserType = null;
                                _selectedUserId = null;
                              });
                              if (v != null) {
                                await _loadKelas(v);
                                await _loadGuru(v);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          
                          // Kelas Dropdown
                          if (_selectedUnitId != null)
                            DropdownButtonFormField<int>(
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Kelas (untuk Siswa)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.class_),
                              ),
                              value: _selectedKelasId,
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Pilih Kelas'),
                                ),
                                ..._kelasList.map((kelas) {
                                  return DropdownMenuItem(
                                    value: kelas.id,
                                    child: Text(kelas.name),
                                  );
                                }),
                              ],
                              onChanged: (v) async {
                                setState(() {
                                  _selectedKelasId = v;
                                  _selectedUserType = null;
                                  _selectedUserId = null;
                                });
                                if (_selectedUnitId != null) {
                                  if (v != null) {
                                    await _loadSiswa(_selectedUnitId!, v);
                                  } else {
                                    setState(() {
                                      _siswaList = [];
                                    });
                                  }
                                  await _loadGuru(_selectedUnitId!, kelasId: v);
                                }
                              },
                            ),
                          const SizedBox(height: 12),
                          
                          // User Type Dropdown
                          if (_selectedUnitId != null)
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Tipe *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              value: _selectedUserType,
                              items: const [
                                DropdownMenuItem(
                                  value: 'guru',
                                  child: Row(
                                    children: [
                                      Icon(Icons.person, size: 18),
                                      SizedBox(width: 8),
                                      Text('GURU'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'siswa',
                                  child: Row(
                                    children: [
                                      Icon(Icons.people, size: 18),
                                      SizedBox(width: 8),
                                      Text('SISWA'),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _selectedUserType = v;
                                  _selectedUserId = null;
                                });
                              },
                            ),
                          const SizedBox(height: 12),
                          
                          // Name Dropdown
                          if (_selectedUserType != null && _selectedUnitId != null)
                            DropdownButtonFormField<int>(
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: _selectedUserType == 'guru' ? 'Nama Guru *' : 'Nama Siswa *',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.badge),
                              ),
                              value: _selectedUserId,
                              items: _selectedUserType == 'guru'
                                  ? _guruList.map<DropdownMenuItem<int>>((g) {
                                      return DropdownMenuItem<int>(
                                        value: g['id'] as int,
                                        child: Text(g['name'] as String),
                                      );
                                    }).toList()
                                  : _siswaList.map<DropdownMenuItem<int>>((s) {
                                      return DropdownMenuItem<int>(
                                        value: s['id'] as int,
                                        child: Text(s['name'] as String),
                                      );
                                    }).toList(),
                              onChanged: (v) => setState(() => _selectedUserId = v),
                            ),
                          const SizedBox(height: 16),
                          
                          // Date Selection
                          const Text(
                            'Pilih Tanggal *',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _selectedDates.map((date) {
                                    return Chip(
                                      label: Text('${date.day}/${date.month}/${date.year}'),
                                      onDeleted: () => _removeDate(date),
                                      deleteIcon: const Icon(Icons.close, size: 16),
                                      backgroundColor: Colors.teal.shade50,
                                    );
                                  }).toList(),
                                ),
                                if (_selectedDates.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Text(
                                      'Belum ada tanggal dipilih',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _showDatePicker,
                                    icon: const Icon(Icons.calendar_today),
                                    label: const Text('Tambah Tanggal'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _saveAbsensi('hadir'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text(
                                      'HADIR',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _saveAbsensi('izin'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text(
                                      'IZIN',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _saveAbsensi('sakit'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.blue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text('SAKIT'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _saveAbsensi('alpha'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text('ALPHA'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
