import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../helpers/export_helper.dart';

class LaporanInsentifGuruScreen extends StatefulWidget {
  const LaporanInsentifGuruScreen({super.key});

  @override
  State<LaporanInsentifGuruScreen> createState() => _LaporanInsentifGuruScreenState();
}

class _LaporanInsentifGuruScreenState extends State<LaporanInsentifGuruScreen> {
  bool _isLoading = false;
  DateTime _selectedMonth = DateTime.now();
  
  // Stored raw data
  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _gurus = [];
  List<Map<String, dynamic>> _rates = [];
  List<Map<String, dynamic>> _absensiList = [];
  
  // Processed display data
  List<Map<String, dynamic>> _reportData = [];
  int _grandTotalIncentive = 0;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

      final String startDateStr = startOfMonth.toIso8601String().split('T').first;
      final String endDateStr = endOfMonth.toIso8601String().split('T').first;

      // 1. Fetch units, gurus, rates, and absensi in parallel
      final results = await Future.wait([
        SupabaseService.client.from('unit_pendidikan').select().order('name'),
        SupabaseService.client.from('guru').select(),
        SupabaseService.client.from('insentif_guru').select(),
        SupabaseService.client
            .from('absensi')
            .select()
            .eq('user_type', 'guru')
            .eq('status', 'hadir')
            .gte('date', startDateStr)
            .lte('date', endDateStr),
      ]);

      _units = List<Map<String, dynamic>>.from(results[0] as List);
      _gurus = List<Map<String, dynamic>>.from(results[1] as List);
      _rates = List<Map<String, dynamic>>.from(results[2] as List);
      _absensiList = List<Map<String, dynamic>>.from(results[3] as List);

      // 2. Process data in memory
      _processData();
    } catch (e) {
      print('Error loading incentive report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat laporan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _processData() {
    _reportData = [];
    _grandTotalIncentive = 0;

    // Create rate mapping for quick lookup: { "guru_id_unit_id": nominal }
    final Map<String, int> rateMap = {};
    for (var r in _rates) {
      final int gId = r['guru_id'] as int;
      final int uId = r['unit_id'] as int;
      final int nominal = r['nominal'] as int;
      rateMap['${gId}_$uId'] = nominal;
    }

    // Create attendance mapping count: { guru_id: count_hadir }
    final Map<int, int> attendanceMap = {};
    for (var a in _absensiList) {
      final int guruId = a['user_id'] as int;
      attendanceMap[guruId] = (attendanceMap[guruId] ?? 0) + 1;
    }

    // Process per Unit
    for (var unit in _units) {
      final int unitId = unit['id'] as int;
      final String unitName = unit['name'] as String;

      // Find all teachers assigned to this unit
      // Since unit_ids is stored as Postgres integer array (int[])
      final List<Map<String, dynamic>> unitTeachers = [];
      int unitTotalIncentive = 0;

      for (var guru in _gurus) {
        final List<dynamic>? uIds = guru['unit_ids'] as List<dynamic>?;
        final int? legacyUnitId = guru['unit_id'] as int?;
        
        bool belongsToUnit = false;
        if (uIds != null && uIds.contains(unitId)) {
          belongsToUnit = true;
        } else if (legacyUnitId == unitId) {
          belongsToUnit = true;
        }

        if (belongsToUnit) {
          final int guruId = guru['id'] as int;
          final String guruName = guru['name'] as String;
          
          final int hadirCount = attendanceMap[guruId] ?? 0;
          final int rate = rateMap['${guruId}_$unitId'] ?? 0;
          final int totalIncentive = hadirCount * rate;

          unitTeachers.add({
            'guru_id': guruId,
            'guru_name': guruName,
            'hadir_count': hadirCount,
            'rate': rate,
            'total_incentive': totalIncentive,
          });

          unitTotalIncentive += totalIncentive;
        }
      }

      // Sort teachers by name
      unitTeachers.sort((a, b) => (a['guru_name'] as String).compareTo(b['guru_name'] as String));

      _reportData.add({
        'unit_id': unitId,
        'unit_name': unitName,
        'teachers': unitTeachers,
        'total_incentive': unitTotalIncentive,
      });

      _grandTotalIncentive += unitTotalIncentive;
    }
  }

  void _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Pilih Bulan Laporan',
    );
    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
      _loadReportData();
    }
  }

  String _formatRupiah(int amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  String _getMonthName(DateTime date) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Insentif Guru'),
        backgroundColor: isDark ? null : Colors.teal,
        foregroundColor: isDark ? null : Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export ke Excel',
            onPressed: _reportData.isEmpty ? null : () async {
              await ExportHelper().exportLaporanInsentif(
                context,
                month: _selectedMonth,
                processedData: _reportData,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Month Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.teal.shade50,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.teal.shade100,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Periode Laporan:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getMonthName(_selectedMonth),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _selectMonth,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('Pilih Bulan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          
          // Grand Total Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [Colors.blueGrey.shade800, Colors.blueGrey.shade900] 
                    : [Colors.teal.shade700, Colors.teal.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Insentif Seluruh Unit',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Bulan Berjalan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatRupiah(_grandTotalIncentive),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Main Report List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reportData.isEmpty
                    ? const Center(child: Text('Tidak ada data unit pendidikan ditemukan.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _reportData.length,
                        itemBuilder: (context, index) {
                          final unit = _reportData[index];
                          final String unitName = unit['unit_name'];
                          final List teachers = unit['teachers'] as List;
                          final int totalUnitIncentive = unit['total_incentive'] as int;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                dividerColor: Colors.transparent,
                              ),
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.teal.shade100,
                                  child: const Icon(Icons.school, color: Colors.teal),
                                ),
                                title: Text(
                                  unitName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: Text(
                                  'Total: ${_formatRupiah(totalUnitIncentive)} (${teachers.length} Guru)',
                                  style: TextStyle(
                                    color: Colors.teal.shade700,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                                children: [
                                  const Divider(height: 1),
                                  if (teachers.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text(
                                        'Tidak ada guru di unit ini.',
                                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                      ),
                                    )
                                  else
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: teachers.length,
                                      itemBuilder: (context, idx) {
                                        final t = teachers[idx];
                                        return Container(
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                              ),
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      t['guru_name'],
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.green.shade50,
                                                            borderRadius: BorderRadius.circular(4),
                                                            border: Border.all(color: Colors.green.shade200),
                                                          ),
                                                          child: Text(
                                                            '${t['hadir_count']} Kehadiran',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors.green.shade800,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          'Rate: ${_formatRupiah(t['rate'])}/hari',
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                _formatRupiah(t['total_incentive']),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
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
    );
  }
}
