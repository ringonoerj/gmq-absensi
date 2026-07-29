import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/greeting_card.dart';
import '../../widgets/dashboard_chart.dart';
import '../../widgets/confetti_overlay.dart';
import '../../widgets/dashboard_banner_card.dart';
import 'manage_unit_screen.dart';
import 'manage_kelas_screen.dart';
import 'manage_guru_screen.dart';
import 'manage_siswa_screen.dart';
import 'manage_users_screen.dart';
import 'backup_restore_screen.dart';
import 'manage_settings_screen.dart';
import '../shared/laporan_screen.dart';
import '../shared/laporan_insentif_screen.dart';
import 'pengaturan_akun_screen.dart';
import 'pengaturan_insentif_screen.dart';
import 'bulk_upload_screen.dart';


import 'package:supabase_flutter/supabase_flutter.dart';


class DashboardSuperadmin extends StatefulWidget {
  const DashboardSuperadmin({super.key});

  @override
  State<DashboardSuperadmin> createState() => _DashboardSuperadminState();
}

class _DashboardSuperadminState extends State<DashboardSuperadmin> {
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
  
  final List<Widget> _screens = [
    const HomeScreenSuperadmin(), // 0
    const ManageUnitScreen(), // 1
    const ManageKelasScreen(), // 2
    const ManageGuruScreen(), // 3
    const ManageSiswaScreen(), // 4
    const ManageUsersScreen(), // 5
    const LaporanScreen(), // 6
    const LaporanInsentifGuruScreen(), // 7
    const PengaturanAkunScreen(), // 8
    const ManageSettingsScreen(), // 9
    const PengaturanInsentifScreen(), // 10
    const BulkUploadScreen(), // 11
    const BackupRestoreScreen(), // 12
  ];
  
  final List<String> _titles = [
    'Dashboard',
    'Unit Pendidikan',
    'Kelas',
    'Guru',
    'Siswa',
    'Users',
    'Laporan Absensi',
    'Laporan Insentif Guru',
    'Pengaturan Akun',
    'Pengaturan Banner & Libur',
    'Pengaturan Insentif Guru',
    'Bulk Upload Data',
    'Backup & Restore Data',
  ];
  
  final List<IconData> _icons = [
    Icons.dashboard, Icons.business, Icons.class_, Icons.person, Icons.people,
    Icons.admin_panel_settings, Icons.backup, Icons.assessment, Icons.campaign
  ];
  
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
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
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
                    'GMQ SUPER APP',
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
                    'Superadmin',
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
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Unit Pendidikan'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.class_),
              title: const Text('Kelas'),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Guru'),
              selected: _selectedIndex == 3,
              onTap: () {
                setState(() => _selectedIndex = 3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Siswa'),
              selected: _selectedIndex == 4,
              onTap: () {
                setState(() => _selectedIndex = 4);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Users'),
              selected: _selectedIndex == 5,
              onTap: () {
                setState(() => _selectedIndex = 5);
                Navigator.pop(context);
              },
            ),
            
            // Laporan Parent
            ExpansionTile(
              leading: const Icon(Icons.assessment),
              title: const Text('Laporan'),
              initiallyExpanded: _selectedIndex == 6 || _selectedIndex == 7,
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('Laporan Absensi'),
                  selected: _selectedIndex == 6,
                  contentPadding: const EdgeInsets.only(left: 32),
                  onTap: () {
                    setState(() => _selectedIndex = 6);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.payments),
                  title: const Text('Laporan Insentif Guru'),
                  selected: _selectedIndex == 7,
                  contentPadding: const EdgeInsets.only(left: 32),
                  onTap: () {
                    setState(() => _selectedIndex = 7);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            
            // Pengaturan Parent
            ExpansionTile(
              leading: const Icon(Icons.settings),
              title: const Text('Pengaturan'),
              initiallyExpanded: _selectedIndex >= 8 && _selectedIndex <= 12,
              children: [
                ListTile(
                  leading: const Icon(Icons.manage_accounts),
                  title: const Text('Pengaturan Akun'),
                  selected: _selectedIndex == 8,
                  contentPadding: const EdgeInsets.only(left: 32),
                  onTap: () {
                    setState(() => _selectedIndex = 8);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.campaign),
                  title: const Text('Pengaturan Banner & Libur'),
                  selected: _selectedIndex == 9,
                  contentPadding: const EdgeInsets.only(left: 32),
                  onTap: () {
                    setState(() => _selectedIndex = 9);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.payments),
                  title: const Text('Nominal Insentif'),
                  selected: _selectedIndex == 10,
                  contentPadding: const EdgeInsets.only(left: 32),
                  onTap: () {
                    setState(() => _selectedIndex = 10);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_upload),
                  title: const Text('Bulk Upload Data'),
                  selected: _selectedIndex == 11,
                  contentPadding: const EdgeInsets.only(left: 32),
                  onTap: () {
                    setState(() => _selectedIndex = 11);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text('Backup & Restore'),
                  selected: _selectedIndex == 12,
                  contentPadding: const EdgeInsets.only(left: 32),
                  onTap: () {
                    setState(() => _selectedIndex = 12);
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

class HomeScreenSuperadmin extends StatelessWidget {
  const HomeScreenSuperadmin({super.key});

  String _getCurrentMonthIndonesian() {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final now = DateTime.now();
    return months[now.month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = Provider.of<MasterProvider>(context);
    
    return RefreshIndicator(
      onRefresh: () async {
        await masterProvider.fetchData('unit_pendidikan');
        await masterProvider.fetchData('kelas');
        await masterProvider.fetchData('guru');
        await masterProvider.fetchData('siswa');
        if (context.mounted) {
          ConfettiOverlay.of(context)?.play();
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Consumer<AuthProvider>(
              builder: (context, auth, _) => GreetingCard(
                userName: auth.currentUser?.name ?? 'Superadmin',
              ),
            ),
            const SizedBox(height: 16),
            const DashboardBannerCard(),
            const SizedBox(height: 16),
            const Text(
              'Statistik Cepat',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<int>>(
              future: Future.wait([
                SupabaseService.client.from('unit_pendidikan').count(),
                SupabaseService.client.from('kelas').count(),
                SupabaseService.client.from('guru').count(),
                SupabaseService.client.from('siswa').count(),
                SupabaseService.client.from('users').count(),
              ]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Gagal memuat statistik: ${snapshot.error}'),
                  );
                }
                final counts = snapshot.data!;
                final width = MediaQuery.of(context).size.width;
                int crossAxisCount = 2;
                double childAspectRatio = 1.3;
                if (width > 1200) {
                  crossAxisCount = 4;
                  childAspectRatio = 2.4;
                } else if (width > 800) {
                  crossAxisCount = 3;
                  childAspectRatio = 2.1;
                } else if (width > 600) {
                  crossAxisCount = 2;
                  childAspectRatio = 1.8;
                } else {
                  crossAxisCount = 2;
                  childAspectRatio = 1.4;
                }

                return Column(
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: childAspectRatio,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _buildStatCard(
                          Icons.business,
                          'Unit',
                          '${counts[0]}',
                          Colors.blue,
                          context,
                        ),
                        _buildStatCard(
                          Icons.class_,
                          'Kelas',
                          '${counts[1]}',
                          Colors.green,
                          context,
                        ),
                        _buildStatCard(
                          Icons.person,
                          'Guru',
                          '${counts[2]}',
                          Colors.orange,
                          context,
                        ),
                        _buildStatCard(
                          Icons.people,
                          'Siswa',
                          '${counts[3]}',
                          Colors.purple,
                          context,
                        ),
                        _buildStatCard(
                          Icons.admin_panel_settings,
                          'Users',
                          '${counts[4]}',
                          Colors.teal,
                          context,
                        ),
                        _buildStatCard(
                          Icons.calendar_today,
                          'Bulan Ini',
                          _getCurrentMonthIndonesian(),
                          Colors.red,
                          context,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    DashboardChart(
                      values: [
                        counts[0].toDouble(),
                        counts[1].toDouble(),
                        counts[2].toDouble(),
                        counts[3].toDouble(),
                        counts[4].toDouble(),
                      ],
                      labels: const ['Unit', 'Kelas', 'Guru', 'Siswa', 'Users'],
                      colors: const [
                        Colors.blue,
                        Colors.green,
                        Colors.orange,
                        Colors.purple,
                        Colors.teal,
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(IconData icon, String title, String value, Color color, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
