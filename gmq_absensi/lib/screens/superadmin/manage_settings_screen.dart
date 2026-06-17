import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets/dashboard_banner_card.dart';
import '../../models/unit_model.dart';

class ManageSettingsScreen extends StatefulWidget {
  const ManageSettingsScreen({super.key});

  @override
  State<ManageSettingsScreen> createState() => _ManageSettingsScreenState();
}

class _ManageSettingsScreenState extends State<ManageSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Banner state
  final _formKey = GlobalKey<FormState>();
  final _bannerController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  // Holidays state
  List<Map<String, dynamic>> _holidays = [];
  List<UnitModel> _unitList = [];
  bool _isHolidaysLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();
    _loadHolidaysData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.client
          .from('app_settings')
          .select('value')
          .eq('key', 'dashboard_banner')
          .maybeSingle();

      if (response != null) {
        _bannerController.text = response['value'] as String? ?? '';
      }
    } catch (e) {
      print('Error loading settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await SupabaseService.client.from('app_settings').upsert({
        'key': 'dashboard_banner',
        'value': _bannerController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengaturan berhasil disimpan'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _loadHolidaysData() async {
    setState(() => _isHolidaysLoading = true);
    try {
      // Load units
      final unitsRes = await SupabaseService.client.from('unit_pendidikan').select().order('name');
      _unitList = (unitsRes as List).map((j) => UnitModel.fromJson(j as Map<String, dynamic>)).toList();
      
      // Load holidays
      final holidaysRes = await SupabaseService.client.from('libur_nasional').select().order('tanggal', ascending: false);
      _holidays = List<Map<String, dynamic>>.from(holidaysRes as List);
    } catch (e) {
      print('Error loading holidays: $e');
    } finally {
      setState(() => _isHolidaysLoading = false);
    }
  }

  Future<void> _deleteHoliday(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Hari Libur'),
        content: const Text('Apakah Anda yakin ingin menghapus hari libur ini?'),
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
    
    try {
      await SupabaseService.client.from('libur_nasional').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hari libur berhasil dihapus'), backgroundColor: Colors.green),
        );
      }
      _loadHolidaysData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showAddHolidayDialog() async {
    final nameController = TextEditingController();
    final ketController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    int? selectedUnitId; // null = Semua Unit
    final formKey = GlobalKey<FormState>();
    
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tambah Hari Libur'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Hari Libur',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Nama tidak boleh kosong' : null,
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Tanggal',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ketController,
                        decoration: const InputDecoration(
                          labelText: 'Keterangan (Opsional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        value: selectedUnitId,
                        decoration: const InputDecoration(
                          labelText: 'Unit Pendidikan',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Semua Unit'),
                          ),
                          ..._unitList.map((unit) {
                            return DropdownMenuItem<int?>(
                              value: unit.id,
                              child: Text(unit.name),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setDialogState(() {
                            selectedUnitId = val;
                          });
                        },
                      ),
                    ],
                  ),
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
                        final dateStr = selectedDate.toIso8601String().split('T').first;
                        await SupabaseService.client.from('libur_nasional').insert({
                          'name': nameController.text.trim(),
                          'tanggal': dateStr,
                          'keterangan': ketController.text.trim().isEmpty ? null : ketController.text.trim(),
                          'unit_id': selectedUnitId,
                        });
                        Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Hari libur berhasil ditambahkan'), backgroundColor: Colors.green),
                          );
                        }
                        _loadHolidaysData();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal menambahkan: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBannerTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.campaign, color: Colors.teal, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'Kustomisasi Banner Dashboard',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tulis pesan pengumuman yang akan ditampilkan di bagian atas dashboard seluruh user. Kosongkan isi text jika ingin menyembunyikan banner.',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bannerController,
                      maxLines: 4,
                      maxLength: 300,
                      decoration: const InputDecoration(
                        labelText: 'Isi Pengumuman',
                        hintText: 'Masukkan teks pengumuman di sini...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      validator: (v) {
                        return null; // Allowed to be empty to disable/hide
                      },
                      onChanged: (text) {
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'SIMPAN PENGATURAN',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Live Preview Banner',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_bannerController.text.trim().isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Teks kosong. Banner tersembunyi.',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              _LocalBannerPreview(text: _bannerController.text.trim()),
          ],
        ),
      ),
    );
  }

  Widget _buildHolidaysTab() {
    if (_isHolidaysLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddHolidayDialog,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadHolidaysData,
        child: _holidays.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Belum ada data hari libur'),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16, top: 16),
                itemCount: _holidays.length,
                itemBuilder: (context, index) {
                  final holiday = _holidays[index];
                  final String dateStr = holiday['tanggal'] ?? '';
                  final DateTime? parsedDate = DateTime.tryParse(dateStr);
                  final formattedDate = parsedDate != null 
                      ? '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}'
                      : dateStr;
                      
                  final int? unitId = holiday['unit_id'] as int?;
                  final unitName = unitId == null 
                      ? 'Semua Unit (Nasional)'
                      : _unitList.firstWhere((u) => u.id == unitId, orElse: () => UnitModel(id: 0, name: 'Unit Lama', createdAt: DateTime.now())).name;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.shade50,
                        child: Icon(Icons.event, color: Colors.teal.shade700),
                      ),
                      title: Text(
                        holiday['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Tanggal: $formattedDate'),
                          Text('Unit: $unitName'),
                          if (holiday['keterangan'] != null) ...[
                            const SizedBox(height: 2),
                            Text('Keterangan: ${holiday['keterangan']}'),
                          ],
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteHoliday(holiday['id']),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.teal,
          tabs: const [
            Tab(icon: Icon(Icons.campaign), text: 'Banner Dashboard'),
            Tab(icon: Icon(Icons.calendar_today), text: 'Hari Libur'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBannerTab(),
              _buildHolidaysTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocalBannerPreview extends StatefulWidget {
  final String text;
  const _LocalBannerPreview({required this.text});

  @override
  State<_LocalBannerPreview> createState() => _LocalBannerPreviewState();
}

class _LocalBannerPreviewState extends State<_LocalBannerPreview> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E3A8A), const Color(0xFF1E40AF)]
              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(isDark ? 0.25 : 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.shade900.withOpacity(0.5) : Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.campaign,
                color: isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PENGUMUMAN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.blue.shade300 : Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: isDark ? Colors.white : Colors.blue.shade900,
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
