import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/greeting_card.dart';
import '../../widgets/dashboard_chart.dart';
import '../../widgets/confetti_overlay.dart';
import '../shared/laporan_screen.dart';


class DashboardSupervisor extends StatefulWidget {
  const DashboardSupervisor({super.key});

  @override
  State<DashboardSupervisor> createState() => _DashboardSupervisorState();
}

class _DashboardSupervisorState extends State<DashboardSupervisor> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    const HomeSupervisorScreen(),
    const LaporanScreen(),
  ];
  
  final List<String> _titles = ['Dashboard', 'Laporan'];
  
  void changeTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.teal,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: 'Laporan',
          ),
        ],
      ),
    );
  }
}

class HomeSupervisorScreen extends StatelessWidget {
  const HomeSupervisorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        // Trigger a rebuild of the widget to reload statistics
        (context as Element).markNeedsBuild();
        ConfettiOverlay.of(context)?.play();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Consumer<AuthProvider>(
              builder: (context, auth, _) => GreetingCard(
                userName: auth.currentUser?.name ?? 'Supervisor',
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Statistik Sistem',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<int>>(
              future: Future.wait([
                SupabaseService.client.from('unit_pendidikan').count(),
                SupabaseService.client.from('kelas').count(),
                SupabaseService.client.from('guru').count(),
                SupabaseService.client.from('siswa').count(),
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
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
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
                            _buildStatCard(Icons.business, 'Unit', '${counts[0]}', Colors.blue, context),
                            _buildStatCard(Icons.class_, 'Kelas', '${counts[1]}', Colors.green, context),
                            _buildStatCard(Icons.person, 'Guru', '${counts[2]}', Colors.orange, context),
                            _buildStatCard(Icons.people, 'Siswa', '${counts[3]}', Colors.purple, context),
                          ],
                        ),
                        const SizedBox(height: 24),
                        DashboardChart(
                          values: [
                            counts[0].toDouble(),
                            counts[1].toDouble(),
                            counts[2].toDouble(),
                            counts[3].toDouble(),
                          ],
                          labels: const ['Unit', 'Kelas', 'Guru', 'Siswa'],
                          colors: const [
                            Colors.blue,
                            Colors.green,
                            Colors.orange,
                            Colors.purple,
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Aksi Cepat',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final state = context.findAncestorStateOfType<_DashboardSupervisorState>();
                  state?.changeTab(1);
                },
                icon: const Icon(Icons.assessment),
                label: const Text('BUKA LAPORAN ABSENSI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
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
