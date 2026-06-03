import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/absensi_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/cache_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/greeting_card.dart';
import '../../widgets/dashboard_chart.dart';
import '../../widgets/confetti_overlay.dart';
import '../../widgets/dashboard_banner_card.dart';
import '../shared/input_screen.dart';
import '../shared/laporan_screen_mobile.dart';
import '../shared/laporan_insentif_screen.dart';
import '../superadmin/pengaturan_akun_screen.dart';


import 'package:supabase_flutter/supabase_flutter.dart';


class DashboardOperator extends StatefulWidget {
  const DashboardOperator({super.key});

  @override
  State<DashboardOperator> createState() => _DashboardOperatorState();
}

class _DashboardOperatorState extends State<DashboardOperator> {
  int _selectedIndex = 0;

  void _showChangePasswordDialog(BuildContext context) {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti Password'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passwordController,
            decoration: const InputDecoration(
              labelText: 'Password Baru',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password tidak boleh kosong';
              if (v.length < 6) return 'Password minimal 6 karakter';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await SupabaseService.client.auth.updateUser(
                    UserAttributes(password: passwordController.text),
                  );
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password berhasil diubah'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gagal mengubah password: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  bool _isOnline = true;
  int _offlineCount = 0;
  
  final List<Widget> _screens = [
    const HomeOperatorScreen(), // 0
    const InputScreen(), // 1
    const LaporanScreenMobile(), // 2
    const LaporanInsentifGuruScreen(), // 3
    const PengaturanAkunScreen(), // 4
  ];
  
  final List<String> _titles = [
    'Dashboard',
    'Input Absen',
    'Laporan Absensi',
    'Laporan Insentif Guru',
    'Pengaturan Akun',
  ];
  
  @override
  void initState() {
    super.initState();
    _checkOfflineData();
    _syncOfflineData();
    _checkConnectivity();
  }
  
  Future<void> _checkConnectivity() async {
    final online = await CacheService.hasConnection();
    setState(() {
      _isOnline = online;
    });
  }
  
  Future<void> _checkOfflineData() async {
    final offlineEntries = CacheService.getOfflineAttendance();
    setState(() {
      _offlineCount = offlineEntries.length;
    });
  }
  
  Future<void> _syncOfflineData() async {
    await CacheService.syncOfflineData();
    await _checkOfflineData();
    await _checkConnectivity();
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? null : Colors.teal,
        foregroundColor: Theme.of(context).brightness == Brightness.dark ? null : Colors.white,
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return IconButton(
                icon: Icon(
                  themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                onPressed: themeProvider.toggleTheme,
              );
            },
          ),
          // Offline indicator
          if (_offlineCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Stack(
                  children: [
                    const Icon(Icons.sync_problem, color: Colors.orange, size: 28),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$_offlineCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncOfflineData,
            tooltip: 'Sinkronisasi Data Offline',
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              _checkConnectivity();
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Profil Pengguna'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nama: ${authProvider.currentUser?.name ?? '-'}'),
                      Text('Email: ${authProvider.currentUser?.email ?? '-'}'),
                      Text('Role: ${authProvider.currentUser?.role ?? '-'}'),
                      const Divider(),
                      Row(
                        children: [
                          Icon(
                            _isOnline ? Icons.wifi : Icons.wifi_off,
                            color: _isOnline ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(_isOnline ? 'Online' : 'Offline'),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(_);
                        _showChangePasswordDialog(context);
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.orange),
                      child: const Text('Ganti Password'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(_),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Konfirmasi Logout'),
                  content: const Text('Apakah Anda yakin ingin logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(_, false),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(_, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await authProvider.logout();
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.teal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'GMQ ABSENSI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authProvider.currentUser?.name ?? '',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const Text(
                    'Operator',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                _checkOfflineData();
                _checkConnectivity();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Input Absen'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                _checkOfflineData();
                _checkConnectivity();
                Navigator.pop(context);
              },
            ),
            
            // Laporan Parent
            ExpansionTile(
              leading: const Icon(Icons.assessment),
              title: const Text('Laporan'),
              initiallyExpanded: _selectedIndex == 2 || _selectedIndex == 3,
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('Laporan Absensi'),
                  selected: _selectedIndex == 2,
                  contentPadding: const EdgeInsets.only(left: 32),
                  onTap: () {
                    setState(() => _selectedIndex = 2);
                    _checkOfflineData();
                    _checkConnectivity();
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.payments),
                  title: const Text('Laporan Insentif Guru'),
                  selected: _selectedIndex == 3,
                  contentPadding: const EdgeInsets.only(left: 32),
                  onTap: () {
                    setState(() => _selectedIndex = 3);
                    _checkOfflineData();
                    _checkConnectivity();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            
            // Pengaturan Parent
            ExpansionTile(
              leading: const Icon(Icons.settings),
              title: const Text('Pengaturan'),
              initiallyExpanded: _selectedIndex == 4,
              children: [
                ListTile(
                  leading: const Icon(Icons.manage_accounts),
                  title: const Text('Pengaturan Akun'),
                  selected: _selectedIndex == 4,
                  contentPadding: const EdgeInsets.only(left: 32),
                  onTap: () {
                    setState(() => _selectedIndex = 4);
                    _checkOfflineData();
                    _checkConnectivity();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      body: _screens[_selectedIndex],
    );
  }
}

class HomeOperatorScreen extends StatefulWidget {
  const HomeOperatorScreen({super.key});

  @override
  State<HomeOperatorScreen> createState() => _HomeOperatorScreenState();
}

class _HomeOperatorScreenState extends State<HomeOperatorScreen> {
  Map<String, int> _stats = {'hadir': 0, 'izin': 0, 'sakit': 0, 'alpha': 0};
  Map<String, int> _guruStats = {'hadir': 0, 'izin': 0};
  Map<String, int> _siswaStats = {'hadir': 0, 'izin': 0};
  bool _isLoading = true;
  List<Map<String, dynamic>> _kelasList = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final absensiProvider = Provider.of<AbsensiProvider>(context, listen: false);
    final today = DateTime.now();
    
    // Load all stats
    final stats = await absensiProvider.getStatistikHariIni(today);
    
    // Load guru stats
    final guruStats = await absensiProvider.getStatistikHariIni(today, userType: 'guru');
    
    // Load siswa stats
    final siswaStats = await absensiProvider.getStatistikHariIni(today, userType: 'siswa');
    
    // Load kelas list
    List<Map<String, dynamic>> kelasWithStats = [];
    try {
      final kelasResponse = await SupabaseService.client.from('kelas').select();
      
      for (var kelas in kelasResponse) {
        final siswaInKelas = await SupabaseService.client
            .from('siswa')
            .select('id')
            .eq('kelas_id', kelas['id']);
        
        final siswaIds = siswaInKelas.map((s) => s['id'] as int).toList();
        
        int hadirCount = 0;
        int izinCount = 0;
        
        if (siswaIds.isNotEmpty) {
          final absensi = await SupabaseService.client
              .from('absensi')
              .select('status')
              .eq('user_type', 'siswa')
              .inFilter('user_id', siswaIds)
              .eq('date', today.toIso8601String().split('T').first);
          
          for (var a in absensi) {
            if (a['status'] == 'hadir') hadirCount++;
            if (a['status'] == 'izin') izinCount++;
          }
        }
        
        kelasWithStats.add({
          'id': kelas['id'],
          'name': kelas['name'],
          'siswa_count': siswaInKelas.length,
          'hadir': hadirCount,
          'izin': izinCount,
        });
      }
    } catch (e) {
      print('Error loading stats details: $e');
    }
    
    setState(() {
      _stats = stats;
      _guruStats = guruStats;
      _siswaStats = siswaStats;
      _kelasList = kelasWithStats;
      _isLoading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final weekdays = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Consumer<AuthProvider>(
              builder: (context, auth, _) => GreetingCard(
                userName: auth.currentUser?.name ?? 'Operator',
              ),
            ),
            
            const SizedBox(height: 16),
            const DashboardBannerCard(),
            
            // Section Guru
            const Text(
              '👨🏫 GURU',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMiniStatCard(
                            'Hadir',
                            _guruStats['hadir'] ?? 0,
                            Colors.green,
                            Icons.check_circle,
                          ),
                        ),
                        Expanded(
                          child: _buildMiniStatCard(
                            'Izin',
                            _guruStats['izin'] ?? 0,
                            Colors.orange,
                            Icons.event_busy,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Section Kelas
            const Text(
              '🏫 KELAS & SANTRI',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            _isLoading
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ))
                : _kelasList.isEmpty
                    ? const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('Belum ada data kelas'),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _kelasList.length,
                        itemBuilder: (context, index) {
                          final kelas = _kelasList[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        kelas['name'],
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${kelas['siswa_count']} Santri',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildMiniStatCard(
                                          'Hadir',
                                          kelas['hadir'],
                                          Colors.green,
                                          Icons.check_circle,
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildMiniStatCard(
                                          'Izin',
                                          kelas['izin'],
                                          Colors.orange,
                                          Icons.event_busy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            
            const SizedBox(height: 16),
            
            // Total Statistik
            const Text(
              '📊 TOTAL RINGKASAN HARI INI',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.teal.shade900.withOpacity(0.3) : Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMiniStatCard(
                        'Hadir',
                        _stats['hadir'] ?? 0,
                        Colors.green,
                        Icons.check_circle,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniStatCard(
                        'Izin',
                        _stats['izin'] ?? 0,
                        Colors.orange,
                        Icons.event_busy,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniStatCard(
                        'Sakit',
                        _stats['sakit'] ?? 0,
                        Colors.blue,
                        Icons.medical_services,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniStatCard(
                        'Alpha',
                        _stats['alpha'] ?? 0,
                        Colors.red,
                        Icons.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            DashboardChart(
              values: [
                (_stats['hadir'] ?? 0).toDouble(),
                (_stats['izin'] ?? 0).toDouble(),
                (_stats['sakit'] ?? 0).toDouble(),
                (_stats['alpha'] ?? 0).toDouble(),
              ],
              labels: const ['Hadir', 'Izin', 'Sakit', 'Alpha'],
              colors: const [
                Colors.green,
                Colors.orange,
                Colors.blue,
                Colors.red,
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMiniStatCard(String title, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
    return months[month - 1];
  }
}
