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
    }
    
    // Load from network
    try {
      final unitResponse = await SupabaseService.client
          .from('unit_pendidikan')
          .select();
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
      });
    }
    
    try {
      final response = await SupabaseService.client
          .from('kelas')
          .select()
          .eq('unit_id', unitId);
      setState(() {
        _kelasList = (response as List).map((j) => KelasModel.fromJson(j as Map<String, dynamic>)).toList();
      });
      await CacheService.saveData('kelas_$unitId', response);
    } catch (e) {
      // Use cache
    }
  }
  
  Future<void> _loadGuru(int unitId) async {
    final cachedGuru = CacheService.getData('guru_$unitId');
    if (cachedGuru != null) {
      setState(() {
        _guruList = (cachedGuru as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    }
    
    try {
      final response = await SupabaseService.client
          .from('guru')
          .select()
          .eq('unit_id', unitId);
      setState(() {
        _guruList = List<Map<String, dynamic>>.from(response as List);
      });
      await CacheService.saveData('guru_$unitId', response);
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
      });
    }
    
    try {
      final response = await SupabaseService.client
          .from('siswa')
          .select()
          .eq('unit_id', unitId)
          .eq('kelas_id', kelasId);
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
      final response = await SupabaseService.client
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
      
      final Map<DateTime, List<Color>> marks = {};
      int hadir = 0, izin = 0, sakit = 0, alpha = 0;
      
      for (var item in response) {
        final parsedDate = DateTime.parse(item['date']);
        final date = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
        Color color;
        switch (item['status']) {
          case 'hadir':
            color = Colors.green;
            hadir++;
            break;
          case 'izin':
            color = Colors.orange;
            izin++;
            break;
          case 'sakit':
            color = Colors.blue;
            sakit++;
            break;
          default:
            color = Colors.red;
            alpha++;
        }
        marks[date] = [color];
      }
      
      // Running Month query (statistik bulan berjalan)
      int hadirIni = 0, izinIni = 0, sakitIni = 0, alphaIni = 0;
      if (_focusedDay.year == now.year && _focusedDay.month == now.month) {
        hadirIni = hadir;
        izinIni = izin;
        sakitIni = sakit;
        alphaIni = alpha;
      } else {
        final responseIni = await SupabaseService.client
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
                
        for (var item in responseIni) {
          switch (item['status']) {
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
      if (_summaryType == 'guru') {
        var query = SupabaseService.client.from('guru').select();
        if (_selectedUnitId != null) {
          query = query.eq('unit_id', _selectedUnitId!);
        }
        final guruList = await query;
        
        for (var guru in guruList) {
          final hadirData = await SupabaseService.client
              .from('absensi')
              .select('id')
              .eq('user_id', guru['id'])
              .eq('user_type', 'guru')
              .eq('status', 'hadir')
              .gte('date', DateTime(_focusedDay.year, _focusedDay.month, 1)
                  .toIso8601String()
                  .split('T')
                  .first)
              .lte('date', DateTime(_focusedDay.year, _focusedDay.month + 1, 0)
                  .toIso8601String()
                  .split('T')
                  .first);
          
          final izinData = await SupabaseService.client
              .from('absensi')
              .select('id')
              .eq('user_id', guru['id'])
              .eq('user_type', 'guru')
              .eq('status', 'izin')
              .gte('date', DateTime(_focusedDay.year, _focusedDay.month, 1)
                  .toIso8601String()
                  .split('T')
                  .first)
              .lte('date', DateTime(_focusedDay.year, _focusedDay.month + 1, 0)
                  .toIso8601String()
                  .split('T')
                  .first);
          
          _summaryData.add({
            'name': guru['name'],
            'group': '-',
            'hadir': (hadirData as List).length,
            'izin': (izinData as List).length,
          });
        }
      } else {
        var query = SupabaseService.client.from('siswa').select();
        if (_selectedUnitId != null) {
          query = query.eq('unit_id', _selectedUnitId!);
        }
        if (_selectedKelasId != null && _selectedKelasId != 0) {
          query = query.eq('kelas_id', _selectedKelasId!);
        }
        final siswaList = await query;
        
        for (var siswa in siswaList) {
          final hadirData = await SupabaseService.client
              .from('absensi')
              .select('id')
              .eq('user_id', siswa['id'])
              .eq('user_type', 'siswa')
              .eq('status', 'hadir')
              .gte('date', DateTime(_focusedDay.year, _focusedDay.month, 1)
                  .toIso8601String()
                  .split('T')
                  .first)
              .lte('date', DateTime(_focusedDay.year, _focusedDay.month + 1, 0)
                  .toIso8601String()
                  .split('T')
                  .first);
          
          final izinData = await SupabaseService.client
              .from('absensi')
              .select('id')
              .eq('user_id', siswa['id'])
              .eq('user_type', 'siswa')
              .eq('status', 'izin')
              .gte('date', DateTime(_focusedDay.year, _focusedDay.month, 1)
                  .toIso8601String()
                  .split('T')
                  .first)
              .lte('date', DateTime(_focusedDay.year, _focusedDay.month + 1, 0)
                  .toIso8601String()
                  .split('T')
                  .first);
          
          _summaryData.add({
            'name': siswa['name'],
            'group': '-',
            'hadir': (hadirData as List).length,
            'izin': (izinData as List).length,
          });
        }
      }
    } catch (e) {
      print('Error loading summary: $e');
    }
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _exportLaporan() async {
    final exportHelper = ExportHelper();
    await exportHelper.exportLaporan(
      context,
      reportType: _selectedKategori ?? 'guru',
      userId: _selectedUserId,
      month: _focusedDay,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _selectedUserId != null
          ? FloatingActionButton.extended(
              onPressed: _exportLaporan,
              icon: const Icon(Icons.file_download),
              label: const Text('Export'),
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
                      await _loadGuru(v);
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
                      if (_selectedUnitId != null && v != null && v != 0) {
                        await _loadSiswa(_selectedUnitId!, v);
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
                          IconButton(
                            onPressed: _loadSummary,
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Refresh',
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
