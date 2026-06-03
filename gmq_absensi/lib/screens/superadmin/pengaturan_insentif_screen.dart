import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../models/unit_model.dart';

class PengaturanInsentifScreen extends StatefulWidget {
  const PengaturanInsentifScreen({super.key});

  @override
  State<PengaturanInsentifScreen> createState() => _PengaturanInsentifScreenState();
}

class _PengaturanInsentifScreenState extends State<PengaturanInsentifScreen> {
  bool _isLoading = false;
  bool _isSaving = false;
  int? _selectedUnitId;
  List<UnitModel> _unitList = [];
  
  // Teachers in the selected unit
  List<Map<String, dynamic>> _gurus = [];
  // Existing rates in the selected unit
  List<Map<String, dynamic>> _rates = [];
  
  // Map to hold controllers for each teacher rate: { guru_id: controller }
  final Map<int, TextEditingController> _controllers = {};
  
  // For search/filter
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredGurus = [];

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadUnits() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.client
          .from('unit_pendidikan')
          .select()
          .order('name');
      _unitList = (response as List).map((j) => UnitModel.fromJson(j as Map<String, dynamic>)).toList();
      if (_unitList.isNotEmpty) {
        _selectedUnitId = _unitList[0].id;
        await _loadUnitData(_selectedUnitId!);
      }
    } catch (e) {
      print('Error loading units: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUnitData(int unitId) async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch gurus
      final responseGurus = await SupabaseService.client
          .from('guru')
          .select();
      final allGurus = List<Map<String, dynamic>>.from(responseGurus as List);

      // Filter gurus that belong to this unit
      _gurus = allGurus.where((g) {
        final List<dynamic>? uIds = g['unit_ids'] as List<dynamic>?;
        final int? legacyUnitId = g['unit_id'] as int?;
        if (uIds != null && uIds.contains(unitId)) return true;
        if (legacyUnitId == unitId) return true;
        return false;
      }).toList();

      // Sort by name
      _gurus.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      // 2. Fetch current rates for this unit
      final responseRates = await SupabaseService.client
          .from('insentif_guru')
          .select()
          .eq('unit_id', unitId);
      _rates = List<Map<String, dynamic>>.from(responseRates as List);

      // Create rate map: { guru_id: nominal }
      final Map<int, int> rateMap = {};
      for (var r in _rates) {
        rateMap[r['guru_id'] as int] = r['nominal'] as int;
      }

      // Dispose existing controllers
      _controllers.forEach((_, c) => c.dispose());
      _controllers.clear();

      // Initialize controllers for each teacher
      for (var g in _gurus) {
        final int guruId = g['id'] as int;
        final int rate = rateMap[guruId] ?? 0;
        _controllers[guruId] = TextEditingController(text: rate.toString());
      }

      _applyFilter();
    } catch (e) {
      print('Error loading rates for unit: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredGurus = List.from(_gurus);
    } else {
      _filteredGurus = _gurus.where((g) {
        final String name = (g['name'] as String).toLowerCase();
        return name.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    setState(() {});
  }

  Future<void> _saveRates() async {
    if (_selectedUnitId == null) return;
    setState(() => _isSaving = true);

    try {
      final List<Map<String, dynamic>> upsertData = [];
      _controllers.forEach((guruId, controller) {
        final int rate = int.tryParse(controller.text) ?? 0;
        upsertData.add({
          'guru_id': guruId,
          'unit_id': _selectedUnitId,
          'nominal': rate,
        });
      });

      if (upsertData.isNotEmpty) {
        // Upsert rates using Supabase REST API
        await SupabaseService.client
            .from('insentif_guru')
            .upsert(
              upsertData,
              onConflict: 'guru_id,unit_id',
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nominal insentif berhasil disimpan'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Error saving rates: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Insentif'),
        backgroundColor: isDark ? null : Colors.teal,
        foregroundColor: isDark ? null : Colors.white,
      ),
      body: _isLoading && _unitList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Unit Dropdown Selector
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Pilih Unit Pendidikan',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school),
                    ),
                    value: _selectedUnitId,
                    items: _unitList.map((unit) {
                      return DropdownMenuItem(
                        value: unit.id,
                        child: Text(unit.name),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedUnitId = v);
                        _loadUnitData(v);
                      }
                    },
                  ),
                ),
                
                // Search field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Cari nama guru...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      _searchQuery = v;
                      _applyFilter();
                    },
                  ),
                ),

                const SizedBox(height: 12),
                
                // List of Teachers
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredGurus.isEmpty
                          ? const Center(child: Text('Tidak ada guru di unit ini.'))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filteredGurus.length,
                              itemBuilder: (context, index) {
                                final guru = _filteredGurus[index];
                                final int guruId = guru['id'] as int;
                                final controller = _controllers[guruId];

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.teal.shade50,
                                      child: const Icon(Icons.person, color: Colors.teal),
                                    ),
                                    title: Text(
                                      guru['name'],
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: const Text('Insentif per Kehadiran'),
                                    trailing: SizedBox(
                                      width: 150,
                                      child: TextFormField(
                                        controller: controller,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.end,
                                        decoration: const InputDecoration(
                                          prefixText: 'Rp ',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
      bottomNavigationBar: _selectedUnitId == null || _gurus.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  )
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveRates,
                  icon: _isSaving 
                      ? const SizedBox(
                          width: 20, 
                          height: 20, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Menyimpan...' : 'SIMPAN SEMUA NOMINAL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
