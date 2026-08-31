import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
import '../../services/cache_service.dart';
import '../../providers/absensi_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/unit_model.dart';
import '../../models/kelas_model.dart';

class ManageAbsensiScreen extends StatefulWidget {
  const ManageAbsensiScreen({super.key});

  @override
  State<ManageAbsensiScreen> createState() => _ManageAbsensiScreenState();
}

class _ManageAbsensiScreenState extends State<ManageAbsensiScreen> {
  // Filters
  int? _selectedUnitId;
  int? _selectedKelasId;
  String _selectedKategori = 'siswa'; // default to siswa
  DateTime _selectedDate = DateTime.now();
  
  // Lists
  List<UnitModel> _unitList = [];
  List<KelasModel> _kelasList = [];
  List<Map<String, dynamic>> _userList = []; // guru or siswa list
  Map<int, Map<String, dynamic>> _existingAbsensi = {}; // userId -> absensi record
  
  bool _isLoadingFilters = false;
  bool _isLoadingUsers = false;
  
  @override
  void initState() {
    super.initState();
    _loadUnits();
  }
  
  Future<void> _loadUnits() async {
    setState(() => _isLoadingFilters = true);
    try {
      final cachedUnits = CacheService.getData('units');
      if (cachedUnits != null) {
        _unitList = (cachedUnits as List)
            .map((j) => UnitModel.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _unitList.sort((a, b) => a.name.compareTo(b.name));
      }
      
      final unitResponse = await SupabaseService.client
          .from('unit_pendidikan')
          .select()
          .order('name');
      _unitList = (unitResponse as List).map((j) => UnitModel.fromJson(j as Map<String, dynamic>)).toList();
      await CacheService.saveData('units', unitResponse);
    } catch (e) {
      print('Error loading units: $e');
    } finally {
      setState(() => _isLoadingFilters = false);
    }
  }
  
  Future<void> _loadKelas(int unitId) async {
    try {
      final cachedKelas = CacheService.getData('kelas_$unitId');
      if (cachedKelas != null) {
        setState(() {
          _kelasList = (cachedKelas as List)
              .map((j) => KelasModel.fromJson(Map<String, dynamic>.from(j as Map)))
              .toList();
          _kelasList.sort((a, b) => a.name.compareTo(b.name));
        });
      }
      
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
      print('Error loading kelas: $e');
    }
  }
  
  Future<void> _loadUsersAndAbsensi() async {
    if (_selectedUnitId == null) return;
    if (_selectedKategori == 'siswa' && _selectedKelasId == null) return;
    
    setState(() => _isLoadingUsers = true);
    
    try {
      // 1. Fetch Users (Guru or Siswa)
      List<Map<String, dynamic>> loadedUsers = [];
      if (_selectedKategori == 'guru') {
        final response = await SupabaseService.client
            .from('guru')
            .select()
            .contains('unit_ids', [_selectedUnitId!])
            .order('name');
        loadedUsers = List<Map<String, dynamic>>.from(response as List);
      } else {
        final response = await SupabaseService.client
            .from('siswa')
            .select()
            .eq('unit_id', _selectedUnitId!)
            .eq('kelas_id', _selectedKelasId!)
            .order('name');
        loadedUsers = List<Map<String, dynamic>>.from(response as List);
      }
      
      // 2. Fetch existing absensi for today
      final dateStr = _selectedDate.toIso8601String().split('T').first;
      var query = SupabaseService.client
          .from('absensi')
          .select()
          .eq('date', dateStr)
          .eq('user_type', _selectedKategori)
          .eq('unit_id', _selectedUnitId!);
          
      if (_selectedKategori == 'siswa' && _selectedKelasId != null) {
        query = query.eq('kelas_id', _selectedKelasId!);
      }
      
      final absensiRes = await query;
      final List<Map<String, dynamic>> absensiList = List<Map<String, dynamic>>.from(absensiRes as List);
      
      // Map absensi by user_id
      final Map<int, Map<String, dynamic>> mappedAbsensi = {};
      for (var record in absensiList) {
        mappedAbsensi[record['user_id'] as int] = record;
      }
      
      setState(() {
        _userList = loadedUsers;
        _existingAbsensi = mappedAbsensi;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _updateStatus({
    required int userId, 
    required String status, 
    String? currentReason,
  }) async {
    final absensiProvider = Provider.of<AbsensiProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final recordedBy = authProvider.currentUser?.id ?? '';
    
    String? reason = currentReason;
    
    // If Izin/Sakit, ask for reason
    if (status == 'izin' || status == 'sakit') {
      final inputReason = await _showReasonDialog(context, status, currentReason);
      if (inputReason == null) return; // User cancelled
      reason = inputReason;
    }
    
    final success = await absensiProvider.updateOrCreateAbsensi(
      userType: _selectedKategori,
      userId: userId,
      date: _selectedDate,
      status: status,
      izinReason: reason,
      recordedBy: recordedBy,
      unitId: _selectedUnitId,
      kelasId: _selectedKategori == 'siswa' ? _selectedKelasId : null,
    );
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status absensi berhasil diperbarui'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
      );
      _loadUsersAndAbsensi(); // Reload list to reflect database state
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(absensiProvider.errorMessage ?? 'Gagal memperbarui absensi'), backgroundColor: Colors.red),
      );
    }
  }
  
  Future<void> _clearAbsensi(int userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Absensi'),
        content: const Text('Apakah Anda yakin ingin menghapus catatan absensi hari ini untuk orang tersebut?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(_, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    final absensiProvider = Provider.of<AbsensiProvider>(context, listen: false);
    final success = await absensiProvider.deleteAbsensi(
      userType: _selectedKategori,
      userId: userId,
      date: _selectedDate,
      unitId: _selectedUnitId,
      kelasId: _selectedKategori == 'siswa' ? _selectedKelasId : null,
    );
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Catatan absensi berhasil dihapus'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
      );
      _loadUsersAndAbsensi();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(absensiProvider.errorMessage ?? 'Gagal menghapus absensi'), backgroundColor: Colors.red),
      );
    }
  }

  Future<String?> _showReasonDialog(BuildContext context, String status, String? initialValue) async {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Masukkan Keterangan ${status == 'izin' ? 'Izin' : 'Sakit'}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Alasan / Keterangan',
            border: OutlineInputBorder(),
            hintText: 'Misal: Sakit Flu, Kepentingan Keluarga',
          ),
          autofocus: true,
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(_, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadUsersAndAbsensi();
    }
  }

  String _formatDateIndonesian(DateTime date) {
    const days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${days[date.weekday % 7]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Column(
        children: [
          // Filter Panel Card
          Card(
            margin: const EdgeInsets.all(12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Pencarian',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                  ),
                  const SizedBox(height: 12),
                  
                  // Unit & Kategori Row
                  Row(
                    children: [
                      // Unit Dropdown
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Unit Pendidikan',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          value: _selectedUnitId,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Pilih Unit')),
                            ..._unitList.map((unit) {
                              return DropdownMenuItem(value: unit.id, child: Text(unit.name));
                            }),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _selectedUnitId = v;
                              _selectedKelasId = null;
                              _userList = [];
                            });
                            if (v != null) {
                              _loadKelas(v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Kategori Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          value: _selectedKategori,
                          items: const [
                            DropdownMenuItem(value: 'siswa', child: Text('Santri/Siswa')),
                            DropdownMenuItem(value: 'guru', child: Text('Tenaga Pengajar (Guru)')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _selectedKategori = v;
                                _selectedKelasId = null;
                                _userList = [];
                              });
                              _loadUsersAndAbsensi();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Kelas & Tanggal Row
                  Row(
                    children: [
                      // Kelas Dropdown (Only visible if category is Siswa)
                      if (_selectedKategori == 'siswa')
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            decoration: const InputDecoration(
                              labelText: 'Kelas',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            value: _selectedKelasId,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Pilih Kelas')),
                              ..._kelasList.map((kelas) {
                                return DropdownMenuItem(value: kelas.id, child: Text(kelas.name));
                              }),
                            ],
                            onChanged: (v) {
                              setState(() {
                                _selectedKelasId = v;
                              });
                              _loadUsersAndAbsensi();
                            },
                          ),
                        )
                      else
                        const Spacer(), // fill space if category is Guru
                      
                      const SizedBox(width: 12),
                      
                      // Date Picker Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectDate(context),
                          icon: const Icon(Icons.calendar_month, color: Colors.teal),
                          label: Text(
                            _formatDateIndonesian(_selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.teal),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.teal),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Users List Section
          Expanded(
            child: _isLoadingUsers
                ? const Center(child: CircularProgressIndicator())
                : _selectedUnitId == null
                    ? _buildNotice(Icons.info_outline, 'Pilih Unit Pendidikan terlebih dahulu')
                    : (_selectedKategori == 'siswa' && _selectedKelasId == null)
                        ? _buildNotice(Icons.class_outlined, 'Pilih Kelas siswa untuk memuat data')
                        : _userList.isEmpty
                            ? _buildNotice(Icons.group_off_outlined, 'Tidak ada anggota terdaftar pada filter ini')
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                itemCount: _userList.length,
                                itemBuilder: (context, index) {
                                  final user = _userList[index];
                                  final userId = user['id'] as int;
                                  final name = user['name'] as String;
                                  final existing = _existingAbsensi[userId];
                                  final currentStatus = existing?['status'] as String?;
                                  final currentReason = existing?['izin_reason'] as String?;
                                  
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              // User Name & Subtitle
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      name,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                    ),
                                                    if (currentStatus != null) ...[
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          _buildStatusBadge(currentStatus),
                                                          if (currentReason != null && currentReason.isNotEmpty) ...[
                                                            const SizedBox(width: 8),
                                                            Expanded(
                                                              child: Text(
                                                                '($currentReason)',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  fontStyle: FontStyle.italic,
                                                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                                                ),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ]
                                                        ],
                                                      ),
                                                    ] else ...[
                                                      const SizedBox(height: 4),
                                                      _buildStatusBadge('belum'),
                                                    ]
                                                  ],
                                                ),
                                              ),
                                              
                                              // Clear/Delete Absensi Button
                                              if (currentStatus != null)
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                                  onPressed: () => _clearAbsensi(userId),
                                                  tooltip: 'Hapus Absen',
                                                ),
                                            ],
                                          ),
                                          const Divider(height: 16),
                                          
                                          // Status Changer Buttons (Quick Action)
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                              _buildQuickStatusButton(userId, 'hadir', 'Hadir', Colors.green, currentStatus == 'hadir', currentReason),
                                              _buildQuickStatusButton(userId, 'izin', 'Izin', Colors.orange, currentStatus == 'izin', currentReason),
                                              _buildQuickStatusButton(userId, 'sakit', 'Sakit', Colors.blue, currentStatus == 'sakit', currentReason),
                                              _buildQuickStatusButton(userId, 'alpha', 'Alfa', Colors.red, currentStatus == 'alpha', currentReason),
                                            ],
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

  Widget _buildNotice(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'hadir':
        bg = Colors.green.shade100;
        fg = Colors.green.shade700;
        label = 'HADIR';
        break;
      case 'izin':
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade700;
        label = 'IZIN';
        break;
      case 'sakit':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade700;
        label = 'SAKIT';
        break;
      case 'alpha':
        bg = Colors.red.shade100;
        fg = Colors.red.shade700;
        label = 'ALFA';
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
        label = 'BELUM DIABSEN';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildQuickStatusButton(
    int userId, 
    String status, 
    String label, 
    Color color, 
    bool isActive,
    String? currentReason,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: ElevatedButton(
          onPressed: () => _updateStatus(userId: userId, status: status, currentReason: currentReason),
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive ? color : color.withOpacity(0.08),
            foregroundColor: isActive ? Colors.white : color,
            elevation: isActive ? 1 : 0,
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: color.withOpacity(0.3), width: 1),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
