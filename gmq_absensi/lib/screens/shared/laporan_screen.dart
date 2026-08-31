import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
import '../../providers/absensi_provider.dart';
import '../../models/unit_model.dart';
import '../../models/kelas_model.dart';
import '../../helpers/export_helper.dart';

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Filter
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
  String _summaryType = 'guru'; // guru or siswa
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    await Future.wait([
      _loadUnits(),
      _loadKategori(),
    ]);
  }
  
  Future<void> _loadUnits() async {
    try {
      final response = await SupabaseService.client
          .from('unit_pendidikan')
          .select()
          .order('name');
      setState(() {
        _unitList = (response as List).map((j) => UnitModel.fromJson(j as Map<String, dynamic>)).toList();
      });
    } catch (e) {
      print('Error loading units: $e');
    }
  }
  
  Future<void> _loadKelas(int unitId) async {
    try {
      final response = await SupabaseService.client
          .from('kelas')
          .select()
          .eq('unit_id', unitId)
          .order('name');
      setState(() {
        _kelasList = (response as List).map((j) => KelasModel.fromJson(j as Map<String, dynamic>)).toList();
      });
    } catch (e) {
      print('Error loading classes: $e');
    }
  }
  
  Future<void> _loadKategori() async {
    try {
      await SupabaseService.client
          .from('kategori')
          .select();
    } catch (e) {
      print('Error loading categories: $e');
    }
  }
  
  Future<void> _loadGuru(int unitId, {int? kelasId}) async {
    try {
      var query = SupabaseService.client
          .from('guru')
          .select()
          .contains('unit_ids', [unitId]);
      
      if (kelasId != null && kelasId != 0) {
        query = query.contains('kelas_ids', [kelasId]);
      }
      
      final response = await query.order('name');
      setState(() {
        _guruList = List<Map<String, dynamic>>.from(response as List);
      });
    } catch (e) {
      print('Error loading teachers: $e');
    }
  }
  
  Future<void> _loadSiswa(int unitId, int kelasId) async {
    try {
      dynamic query = SupabaseService.client
          .from('siswa')
          .select()
          .eq('unit_id', unitId);
      
      if (kelasId != 0) {
        query = query.eq('kelas_id', kelasId);
      }
      
      query = query.order('name');
      
      final response = await query;
      setState(() {
        _siswaList = List<Map<String, dynamic>>.from(response as List);
      });
    } catch (e) {
      print('Error loading students: $e');
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
          .gte('date', DateTime(_focusedDay.year, _focusedDay.month, 1).toIso8601String().split('T').first)
          .lte('date', DateTime(_focusedDay.year, _focusedDay.month + 1, 0).toIso8601String().split('T').first);
          
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
            .gte('date', DateTime(now.year, now.month, 1).toIso8601String().split('T').first)
            .lte('date', DateTime(now.year, now.month + 1, 0).toIso8601String().split('T').first);
            
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
      print('Error loading user attendance: $e');
    }
  }
  
  Future<void> _loadSummary() async {
    setState(() => _summaryData = []);
    
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
      
      setState(() {});
    } catch (e) {
      print('Error loading summary: $e');
    }
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

  Widget _buildCalendarDay(DateTime day, {bool isToday = false, bool isOutside = false}) {
    final marks = _markedDates[DateTime(day.year, day.month, day.day)];
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: marks != null
          ? BoxDecoration(
              color: marks[0],
              shape: BoxShape.circle,
            )
          : isToday
              ? BoxDecoration(
                  color: Colors.teal.shade100,
                  shape: BoxShape.circle,
                )
              : null,
      child: Center(
        child: Text(
          day.day.toString(),
          style: TextStyle(
            color: marks != null 
                ? Colors.white 
                : isOutside 
                    ? Colors.grey 
                    : Colors.black,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _selectedUserId != null ? _exportLaporan : null,
              icon: const Icon(Icons.file_download, color: Colors.white),
              label: const Text('Export User', style: TextStyle(color: Colors.white)),
              backgroundColor: _selectedUserId != null ? Colors.teal : Colors.grey,
            )
          : FloatingActionButton.extended(
              onPressed: _summaryData.isNotEmpty ? _exportSummary : null,
              icon: const Icon(Icons.file_download, color: Colors.white),
              label: Text(
                'Export Rekap ${_summaryType == 'guru' ? 'Guru' : 'Siswa'}',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: _summaryData.isNotEmpty ? Colors.teal : Colors.grey,
            ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Unit Pendidikan',
                    border: OutlineInputBorder(),
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
                      _markedDates = {};
                      _statistik = {'hadir': 0, 'izin': 0, 'sakit': 0, 'alpha': 0};
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
                      labelText: 'Kelas (untuk Siswa)',
                      border: OutlineInputBorder(),
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
                        _markedDates = {};
                        _statistik = {'hadir': 0, 'izin': 0, 'sakit': 0, 'alpha': 0};
                      });
                      if (_selectedUnitId != null) {
                        await _loadSiswa(_selectedUnitId!, _selectedKelasId ?? 0);
                        await _loadGuru(_selectedUnitId!, kelasId: _selectedKelasId);
                      }
                    },
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                          border: OutlineInputBorder(),
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
                            _markedDates = {};
                            _statistik = {'hadir': 0, 'izin': 0, 'sakit': 0, 'alpha': 0};
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
                          setState(() {
                            _selectedUserId = v;
                          });
                          if (v != null) {
                            await _loadUserAbsensi();
                          }
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
              Tab(text: 'Per User'),
              Tab(text: 'Summary'),
            ],
          ),
          
          // Tab Bar View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Per User Tab
                _selectedUserId == null
                    ? const Center(child: Text('Pilih user terlebih dahulu'))
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
                                  },
                                  onPageChanged: (focusedDay) {
                                    setState(() {
                                      _focusedDay = focusedDay;
                                    });
                                    _loadUserAbsensi();
                                    _loadSummary();
                                  },
                                  calendarBuilders: CalendarBuilders(
                                    defaultBuilder: (context, day, focusedDay) => _buildCalendarDay(day),
                                    todayBuilder: (context, day, focusedDay) => _buildCalendarDay(day, isToday: true),
                                    outsideBuilder: (context, day, focusedDay) => _buildCalendarDay(day, isOutside: true),
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
                                      style: const TextStyle(fontWeight: FontWeight.bold),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                  const Icon(Icons.calendar_month, color: Colors.teal, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Periode: ${_getMonthName(_focusedDay.month)} ${_focusedDay.year}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
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
                          ElevatedButton.icon(
                            onPressed: _loadSummary,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _summaryData.isNotEmpty ? _exportSummary : null,
                            icon: const Icon(Icons.file_download),
                            label: const Text('Export Rekap'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _summaryData.isEmpty
                            ? const Center(child: Text('Belum ada data'))
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 80),
                                itemCount: _summaryData.length,
                                itemBuilder: (context, index) {
                                  final item = _summaryData[index];
                                  return Card(
                                    child: ListTile(
                                      title: Text(item['name']),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Chip(
                                            label: Text('H: ${item['hadir']}'),
                                            backgroundColor: Colors.green.shade100,
                                          ),
                                          const SizedBox(width: 4),
                                          Chip(
                                            label: Text('I: ${item['izin']}'),
                                            backgroundColor: Colors.orange.shade100,
                                          ),
                                          const SizedBox(width: 4),
                                          Chip(
                                            label: Text('S: ${item['sakit'] ?? 0}'),
                                            backgroundColor: Colors.blue.shade100,
                                          ),
                                          const SizedBox(width: 4),
                                          Chip(
                                            label: Text('A: ${item['alpha'] ?? 0}'),
                                            backgroundColor: Colors.red.shade100,
                                          ),
                                          const SizedBox(width: 4),
                                          Chip(
                                            label: Text('L: ${item['libur'] ?? 0}'),
                                            backgroundColor: Colors.purple.shade100,
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
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month - 1];
  }
}
