import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/supabase_service.dart';
import '../../services/cache_service.dart';
import '../../providers/absensi_provider.dart';
import '../../models/unit_model.dart';
import '../../models/kelas_model.dart';
import '../../helpers/export_helper.dart';

class LaporanScreenMobile extends StatefulWidget {
  const LaporanScreenMobile({super.key});

  @override
  State<LaporanScreenMobile> createState() => _LaporanScreenMobileState();
}

class _LaporanScreenMobileState extends State<LaporanScreenMobile>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Filters
  int? _selectedUnitId;
  int? _selectedKelasId;
  String? _selectedKategori;
  int? _selectedUserId;
  
  // Data
  List<UnitModel> _unitList = [];
  List<KelasModel> _kelasList = [];
  List<Map<String, dynamic>> _guruList = [];
  List<Map<String, dynamic>> _siswaList = [];
  
  // Calendar
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, List<Color>> _markedDates = {};
  Map<String, int> _statistik = {'hadir': 0, 'izin': 0, 'sakit': 0, 'alpha': 0};
  Map<String, int> _statistikBulanIni = {'hadir': 0, 'izin': 0, 'sakit': 0, 'alpha': 0};
  
  // Summary
  List<Map<String, dynamic>> _summaryData = [];
  String _summaryType = 'guru';
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  String _getMonthName(int month) {
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month];
  }

  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Try cache first
    final cachedUnits = CacheService.getData('units');
    if (cachedUnits != null) {
      _unitList = (cachedUnits as List)
          .map((j) => UnitModel.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
      _unitList.sort((a, b) => a.name.compareTo(b.name));
    }
    
    // Load from network
    try {
      final unitResponse = await SupabaseService.client
          .from('unit_pendidikan')
          .select()
          .order('name');
      _unitList = (unitResponse as List).map((j) => UnitModel.fromJson(j as Map<String, dynamic>)).toList();
      await CacheService.saveData('units', unitResponse);
    } catch (e) {
      // Use cache if available
    }
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _loadKelas(int unitId) async {
    final cachedKelas = CacheService.getData('kelas_$unitId');
    if (cachedKelas != null) {
      setState(() {
        _kelasList = (cachedKelas as List)
            .map((j) => KelasModel.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _kelasList.sort((a, b) => a.name.compareTo(b.name));
      });
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
      // Use cache
    }
  }
  
  Future<void> _loadGuru(int unitId, {int? kelasId}) async {
    final cacheKey = 'guru_$unitId';
    final cachedGuru = CacheService.getData(cacheKey);
    if (cachedGuru != null) {
      var list = (cachedGuru as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (kelasId != null && kelasId != 0) {
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
    
    try {
      final response = await SupabaseService.client
          .from('guru')
          .select()
          .contains('unit_ids', [unitId])
          .order('name');
      
      await CacheService.saveData(cacheKey, response);
      
      var list = List<Map<String, dynamic>>.from(response as List);
      if (kelasId != null && kelasId != 0) {
        list = list.where((g) {
          final List<dynamic>? kIds = g['kelas_ids'] as List<dynamic>?;
          return kIds != null && kIds.contains(kelasId);
        }).toList();
      }
      
      setState(() {
        _guruList = list;
      });
    } catch (e) {
      // Use cache
    }
  }
  
  Future<void> _loadSiswa(int unitId, int kelasId) async {
    final cacheKey = 'siswa_${unitId}_$kelasId';
    final cachedSiswa = CacheService.getData(cacheKey);
    if (cachedSiswa != null) {
      setState(() {
        _siswaList = (cachedSiswa as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _siswaList.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      });
    }
    
    try {
      var query = SupabaseService.client
          .from('siswa')
          .select()
          .eq('unit_id', unitId);
      
      if (kelasId != 0) {
        query = query.eq('kelas_id', kelasId);
      }
      
      final response = await query.order('name');
      setState(() {
        _siswaList = List<Map<String, dynamic>>.from(response as List);
      });
      await CacheService.saveData(cacheKey, response);
    } catch (e) {
      // Use cache
    }
  }
  
  Future<void> _loadUserAbsensi() async {
    if (_selectedUserId == null || _selectedKategori == null) return;
    
    try {
      final now = DateTime.now();
      
      // Selected Month query
      var query = SupabaseService.client
          .from('absensi')
          .select()
          .eq('user_id', _selectedUserId!)
          .eq('user_type', _selectedKategori!)
          .gte('date', DateTime(_focusedDay.year, _focusedDay.month, 1)
              .toIso8601String()
              .split('T')
              .first)
          .lte('date', DateTime(_focusedDay.year, _focusedDay.month + 1, 0)
              .toIso8601String()
              .split('T')
              .first);
              
      if (_selectedUnitId != null) {
        query = query.eq('unit_id', _selectedUnitId!);
      }
      if (_selectedKategori == 'siswa' && _selectedKelasId != null && _selectedKelasId != 0) {
        query = query.eq('kelas_id', _selectedKelasId!);
      }
      
      final response = await query;
      
      // Sort response by ID ascending so the latest row (highest ID) wins
      final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(response as List);
      list.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

      final Map<DateTime, List<Color>> marks = {};
      final Map<DateTime, String> finalStatusPerDate = {};
      
      for (var item in list) {
        final parsedDate = DateTime.parse(item['date']);
        final date = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
        finalStatusPerDate[date] = item['status']?.toString().toLowerCase() ?? '';
        
        Color color;
        switch (item['status']?.toString().toLowerCase()) {
          case 'hadir': color = Colors.green; break;
          case 'izin': color = Colors.orange; break;
          case 'sakit': color = Colors.blue; break;
          default: color = Colors.red;
        }
        marks[date] = [color];
      }
      
      int hadir = 0, izin = 0, sakit = 0, alpha = 0;
      for (var status in finalStatusPerDate.values) {
        switch (status) {
          case 'hadir': hadir++; break;
          case 'izin': izin++; break;
          case 'sakit': sakit++; break;
          default: alpha++;
        }
      }
      
      // Running Month query (statistik bulan berjalan)
      int hadirIni = 0, izinIni = 0, sakitIni = 0, alphaIni = 0;
      if (_focusedDay.year == now.year && _focusedDay.month == now.month) {
        hadirIni = hadir;
        izinIni = izin;
        sakitIni = sakit;
        alphaIni = alpha;
      } else {
        var queryIni = SupabaseService.client
            .from('absensi')
            .select()
            .eq('user_id', _selectedUserId!)
            .eq('user_type', _selectedKategori!)
            .gte('date', DateTime(now.year, now.month, 1)
                .toIso8601String()
                .split('T')
                .first)
            .lte('date', DateTime(now.year, now.month + 1, 0)
                .toIso8601String()
                .split('T')
                .first);
                
        if (_selectedUnitId != null) {
          queryIni = queryIni.eq('unit_id', _selectedUnitId!);
        }
        if (_selectedKategori == 'siswa' && _selectedKelasId != null && _selectedKelasId != 0) {
          queryIni = queryIni.eq('kelas_id', _selectedKelasId!);
        }
        
        final responseIni = await queryIni;
        final List<Map<String, dynamic>> listIni = List<Map<String, dynamic>>.from(responseIni as List);
        listIni.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

        final Map<DateTime, String> finalStatusPerDateIni = {};
        for (var item in listIni) {
          final parsedDate = DateTime.parse(item['date']);
          final date = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
          finalStatusPerDateIni[date] = item['status']?.toString().toLowerCase() ?? '';
        }

        for (var status in finalStatusPerDateIni.values) {
          switch (status) {
            case 'hadir': hadirIni++; break;
            case 'izin': izinIni++; break;
            case 'sakit': sakitIni++; break;
            default: alphaIni++;
          }
        }
      }
      
      setState(() {
        _markedDates = marks;
        _statistik = {'hadir': hadir, 'izin': izin, 'sakit': sakit, 'alpha': alpha};
        _statistikBulanIni = {'hadir': hadirIni, 'izin': izinIni, 'sakit': sakitIni, 'alpha': alphaIni};
      });
    } catch (e) {
      print('Error loading absensi: $e');
    }
  }
  
  Future<void> _loadSummary() async {
    setState(() {
      _summaryData = [];
      _isLoading = true;
    });
    
    try {
      final startDate = DateTime(_focusedDay.year, _focusedDay.month, 1).toIso8601String().split('T').first;
      final endDate = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).toIso8601String().split('T').first;
      
      // Load holidays for this month
      final holidayRes = await SupabaseService.client
          .from('libur_nasional')
          .select()
          .gte('tanggal', startDate)
          .lte('tanggal', endDate);
      final monthHolidays = List<Map<String, dynamic>>.from(holidayRes as List);

      int countHolidaysForUnit(int? unitId) {
        if (unitId == null) {
          return monthHolidays.where((h) => h['unit_id'] == null).length;
        }
        return monthHolidays.where((h) => h['unit_id'] == null || h['unit_id'] == unitId).length;
      }
      
      int countHolidaysForUnits(List<dynamic>? unitIds) {
        if (unitIds == null || unitIds.isEmpty) {
          return monthHolidays.where((h) => h['unit_id'] == null).length;
        }
        return monthHolidays.where((h) => h['unit_id'] == null || unitIds.contains(h['unit_id'])).length;
      }

      // Fetch all attendance for this month
      var absensiQuery = SupabaseService.client
          .from('absensi')
          .select('id, user_id, status, unit_id, kelas_id, date')
          .gte('date', startDate)
          .lte('date', endDate);
          
      if (_summaryType == 'guru') {
        absensiQuery = absensiQuery.eq('user_type', 'guru');
      } else {
        absensiQuery = absensiQuery.eq('user_type', 'siswa');
      }
      
      if (_selectedUnitId != null) {
        absensiQuery = absensiQuery.eq('unit_id', _selectedUnitId!);
      }
      if (_summaryType == 'siswa' && _selectedKelasId != null && _selectedKelasId != 0) {
        absensiQuery = absensiQuery.eq('kelas_id', _selectedKelasId!);
      }
      
      final absensiData = await absensiQuery;
      final absensiList = List<Map<String, dynamic>>.from(absensiData as List);

      if (_summaryType == 'guru') {
        dynamic query = SupabaseService.client.from('guru').select();
        if (_selectedUnitId != null) {
          query = query.contains('unit_ids', [_selectedUnitId!]);
        }
        query = query.order('name');
        final guruList = await query;
        
        for (var guru in guruList) {
          final int guruId = guru['id'];
          final guruAbsensi = absensiList.where((a) => a['user_id'] == guruId).toList();
          guruAbsensi.sort((a, b) => ((a['id'] ?? 0) as int).compareTo((b['id'] ?? 0) as int));
          
          final Map<String, String> statusPerDate = {};
          for (var a in guruAbsensi) {
            final String dateStr = a['date'].toString().split('T').first;
            statusPerDate[dateStr] = a['status']?.toString().toLowerCase() ?? '';
          }

          int hadirCount = 0, izinCount = 0, sakitCount = 0, alphaCount = 0;
          for (var status in statusPerDate.values) {
            switch (status) {
              case 'hadir': hadirCount++; break;
              case 'izin': izinCount++; break;
              case 'sakit': sakitCount++; break;
              default: alphaCount++; break;
            }
          }
          
          final List<dynamic>? unitIds = guru['unit_ids'] as List<dynamic>?;
          int liburCount = countHolidaysForUnits(unitIds);
          
          _summaryData.add({
            'name': guru['name'],
            'group': '-',
            'hadir': hadirCount,
            'izin': izinCount,
            'sakit': sakitCount,
            'alpha': alphaCount,
            'libur': liburCount,
          });
        }
      } else {
        dynamic query = SupabaseService.client.from('siswa').select();
        if (_selectedUnitId != null) {
          query = query.eq('unit_id', _selectedUnitId!);
        }
        if (_selectedKelasId != null && _selectedKelasId != 0) {
          query = query.eq('kelas_id', _selectedKelasId!);
        }
        query = query.order('name');
        final siswaList = await query;
        
        for (var siswa in siswaList) {
          final int siswaId = siswa['id'];
          final siswaAbsensi = absensiList.where((a) => a['user_id'] == siswaId).toList();
          siswaAbsensi.sort((a, b) => ((a['id'] ?? 0) as int).compareTo((b['id'] ?? 0) as int));
          
          final Map<String, String> statusPerDate = {};
          for (var a in siswaAbsensi) {
            final String dateStr = a['date'].toString().split('T').first;
            statusPerDate[dateStr] = a['status']?.toString().toLowerCase() ?? '';
          }

          int hadirCount = 0, izinCount = 0, sakitCount = 0, alphaCount = 0;
          for (var status in statusPerDate.values) {
            switch (status) {
              case 'hadir': hadirCount++; break;
              case 'izin': izinCount++; break;
              case 'sakit': sakitCount++; break;
              default: alphaCount++; break;
            }
          }
          
          final int? unitId = siswa['unit_id'] as int?;
          int liburCount = countHolidaysForUnit(unitId);
          
          _summaryData.add({
            'name': siswa['name'],
            'group': '-',
            'hadir': hadirCount,
            'izin': izinCount,
            'sakit': sakitCount,
            'alpha': alphaCount,
            'libur': liburCount,
          });
        }
      }
    } catch (e) {
      print('Error loading summary: $e');
    }
    
    setState(() => _isLoading = false);
  }
  
  String? get _selectedUnitName {
    if (_selectedUnitId == null) return 'Semua Unit';
    final unit = _unitList.firstWhere(
      (u) => u.id == _selectedUnitId,
      orElse: () => UnitModel(id: 0, name: 'Semua Unit', createdAt: DateTime.now()),
    );
    return unit.name;
  }

  String? get _selectedKelasName {
    if (_selectedKelasId == null || _selectedKelasId == 0) return 'Semua Kelas';
    final kelas = _kelasList.firstWhere(
      (k) => k.id == _selectedKelasId,
      orElse: () => KelasModel(id: 0, unitId: 0, name: 'Semua Kelas', createdAt: DateTime.now()),
    );
    return kelas.name;
  }

  Future<void> _exportLaporan() async {
    final exportHelper = ExportHelper();
    await exportHelper.exportLaporan(
      context,
      reportType: _selectedKategori ?? 'guru',
      userId: _selectedUserId,
      month: _focusedDay,
      unitId: _selectedUnitId,
      kelasId: _selectedKelasId,
    );
  }

  Future<void> _exportSummary() async {
    if (_summaryData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada data summary untuk diexport'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final exportHelper = ExportHelper();
    await exportHelper.exportSummaryLaporan(
      context,
      reportType: _summaryType,
      month: _focusedDay,
      summaryData: _summaryData,
      unitName: _selectedUnitName,
      kelasName: _summaryType == 'siswa' ? _selectedKelasName : null,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final bool showFab = _tabController.index == 0
        ? _selectedUserId != null
        : _summaryData.isNotEmpty;

    return Scaffold(
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              onPressed: _tabController.index == 0 ? _exportLaporan : _exportSummary,
              icon: const Icon(Icons.file_download),
              label: Text(_tabController.index == 0
                  ? 'Export User'
                  : 'Export Rekap ${_summaryType == 'guru' ? 'Guru' : 'Siswa'}'),
              backgroundColor: Colors.teal,
            )
          : null,
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Unit Pendidikan',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  value: _selectedUnitId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Pilih Unit')),
                    ..._unitList.map((unit) {
                      return DropdownMenuItem(
                        value: unit.id,
                        child: Text(unit.name),
                      );
                    }),
                  ],
                  onChanged: (v) async {
                    setState(() {
                      _selectedUnitId = v;
                      _selectedKelasId = null;
                      _selectedUserId = null;
                      _selectedKategori = null;
                    });
                    if (v != null) {
                      await _loadKelas(v);
                      await _loadGuru(v, kelasId: null);
                      await _loadSiswa(v, 0);
                    }
                  },
                ),
                const SizedBox(height: 8),
                if (_selectedUnitId != null)
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Kelas',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _selectedKelasId,
                    items: [
                      const DropdownMenuItem(value: 0, child: Text('Semua Kelas')),
                      ..._kelasList.map((kelas) {
                        return DropdownMenuItem(
                          value: kelas.id,
                          child: Text(kelas.name),
                        );
                      }),
                    ],
                    onChanged: (v) async {
                      setState(() {
                        _selectedKelasId = v == 0 ? null : v;
                        _selectedUserId = null;
                      });
                      if (_selectedUnitId != null && v != null) {
                        await _loadSiswa(_selectedUnitId!, v);
                        await _loadGuru(_selectedUnitId!, kelasId: v);
                      }
                    },
                  ),
                const SizedBox(height: 8),
                if (_selectedUnitId != null)
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          value: _selectedKategori,
                          items: const [
                            DropdownMenuItem(value: 'guru', child: Text('Guru')),
                            DropdownMenuItem(value: 'siswa', child: Text('Siswa')),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _selectedKategori = v;
                              _selectedUserId = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Nama',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          value: _selectedUserId,
                          items: _selectedKategori == 'guru'
                              ? _guruList.map<DropdownMenuItem<int>>((g) {
                                  return DropdownMenuItem<int>(
                                    value: g['id'] as int,
                                    child: Text(g['name'] as String),
                                  );
                                }).toList()
                              : _selectedKategori == 'siswa'
                                  ? _siswaList.map<DropdownMenuItem<int>>((s) {
                                      return DropdownMenuItem<int>(
                                        value: s['id'] as int,
                                        child: Text(s['name'] as String),
                                      );
                                    }).toList()
                                  : [],
                          onChanged: (v) async {
                            setState(() => _selectedUserId = v);
                            if (v != null) await _loadUserAbsensi();
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Per User', icon: Icon(Icons.person)),
              Tab(text: 'Summary', icon: Icon(Icons.summarize)),
            ],
          ),
          
          // Tab Bar View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Per User Tab
                _selectedUserId == null
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off, size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('Pilih user terlebih dahulu'),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 80),
                        child: Column(
                          children: [
                            Card(
                              margin: const EdgeInsets.all(12),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: TableCalendar(
                                  firstDay: DateTime(2020),
                                  lastDay: DateTime.now(),
                                  focusedDay: _focusedDay,
                                  calendarFormat: CalendarFormat.month,
                                  onDaySelected: (selected, focused) {
                                    setState(() {
                                      _focusedDay = focused;
                                    });
                                    _loadUserAbsensi();
                                  },
                                  onPageChanged: (focusedDay) {
                                    setState(() {
                                      _focusedDay = focusedDay;
                                    });
                                    _loadUserAbsensi();
                                    _loadSummary();
                                  },
                                  calendarBuilders: CalendarBuilders(
                                    defaultBuilder: (context, day, focusedDay) {
                                      final normalizedDay = DateTime(day.year, day.month, day.day);
                                      final marks = _markedDates[normalizedDay];
                                      return Container(
                                        decoration: marks != null
                                            ? BoxDecoration(
                                                color: marks[0],
                                                shape: BoxShape.circle,
                                              )
                                            : null,
                                        child: Center(
                                          child: Text(
                                            day.day.toString(),
                                            style: TextStyle(
                                              color: marks != null ? Colors.white : null,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  calendarStyle: const CalendarStyle(
                                    weekendTextStyle: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            ),
                            // 1. STATISTIK BULAN BERJALAN
                            Card(
                              margin: const EdgeInsets.all(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Text(
                                      'STATISTIK BULAN BERJALAN (${_getMonthName(DateTime.now().month)} ${DateTime.now().year})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildStatItem('Hadir', _statistikBulanIni['hadir']!, Colors.green),
                                        _buildStatItem('Izin', _statistikBulanIni['izin']!, Colors.orange),
                                        _buildStatItem('Sakit', _statistikBulanIni['sakit']!, Colors.blue),
                                        _buildStatItem('Alpha', _statistikBulanIni['alpha']!, Colors.red),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // 2. STATISTIK BULAN TERPILIH (jika berbeda dari bulan berjalan)
                            if (_focusedDay.year != DateTime.now().year || _focusedDay.month != DateTime.now().month)
                              Card(
                                margin: const EdgeInsets.all(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Text(
                                        'STATISTIK BULAN TERPILIH (${_getMonthName(_focusedDay.month)} ${_focusedDay.year})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.teal,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _buildStatItem('Hadir', _statistik['hadir']!, Colors.green),
                                          _buildStatItem('Izin', _statistik['izin']!, Colors.orange),
                                          _buildStatItem('Sakit', _statistik['sakit']!, Colors.blue),
                                          _buildStatItem('Alpha', _statistik['alpha']!, Colors.red),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                
                // Summary Tab
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Month Selector Banner for Summary
                      Card(
                        elevation: 0,
                        color: Colors.teal.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.teal.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left, color: Colors.teal),
                                tooltip: 'Bulan Sebelumnya',
                                onPressed: () async {
                                  setState(() {
                                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                                  });
                                  await _loadSummary();
                                },
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_month, color: Colors.teal, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Periode: ${_getMonthName(_focusedDay.month)} ${_focusedDay.year}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right, color: Colors.teal),
                                tooltip: 'Bulan Berikutnya',
                                onPressed: () async {
                                  setState(() {
                                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                                  });
                                  await _loadSummary();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'guru', label: Text('Guru')),
                                ButtonSegment(value: 'siswa', label: Text('Siswa')),
                              ],
                              selected: {_summaryType},
                              onSelectionChanged: (set) async {
                                setState(() => _summaryType = set.first);
                                await _loadSummary();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: _loadSummary,
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Refresh',
                          ),
                          const SizedBox(width: 4),
                          IconButton.filled(
                            onPressed: _summaryData.isNotEmpty ? _exportSummary : null,
                            icon: const Icon(Icons.file_download),
                            tooltip: 'Export Rekap',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _summaryData.isEmpty
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.data_usage, size: 48, color: Colors.grey),
                                        SizedBox(height: 12),
                                        Text('Belum ada data'),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 80),
                                    itemCount: _summaryData.length,
                                    itemBuilder: (context, index) {
                                      final item = _summaryData[index];
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: Colors.teal.shade50,
                                            child: Text(
                                              '${index + 1}',
                                              style: const TextStyle(color: Colors.teal),
                                            ),
                                          ),
                                          title: Text(
                                            item['name'],
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade100,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'H: ${item['hadir']}',
                                                  style: const TextStyle(color: Colors.green),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade100,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'I: ${item['izin']}',
                                                  style: const TextStyle(color: Colors.orange),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade100,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'S: ${item['sakit'] ?? 0}',
                                                  style: const TextStyle(color: Colors.blue),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade100,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'A: ${item['alpha'] ?? 0}',
                                                  style: const TextStyle(color: Colors.red),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.purple.shade100,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'L: ${item['libur'] ?? 0}',
                                                  style: const TextStyle(color: Colors.purple),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
