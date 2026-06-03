import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/master_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/unit_model.dart';
import '../../models/kelas_model.dart';

class ManageSiswaScreen extends StatefulWidget {
  const ManageSiswaScreen({super.key});

  @override
  State<ManageSiswaScreen> createState() => _ManageSiswaScreenState();
}

class _ManageSiswaScreenState extends State<ManageSiswaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nisController = TextEditingController();
  final _emailController = TextEditingController();
  final _noTelpController = TextEditingController();
  int? _selectedUnitId;
  int? _selectedKelasId;
  int? _selectedKategoriId;
  int? _editingId;
  List<UnitModel> _unitList = [];
  List<KelasModel> _allKelasList = []; // For rendering correct class name in list view
  List<KelasModel> _kelasListForModal = []; // For bottom sheet dropdown selection
  List<Map<String, dynamic>> _kategoriList = [];
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }
  
  Future<void> _loadData() async {
    await Future.wait([
      Provider.of<MasterProvider>(context, listen: false)
          .fetchData('siswa', orderBy: 'name'),
      _loadUnits(),
      _loadAllKelas(),
      _loadKategori(),
    ]);
  }
  
  Future<void> _loadUnits() async {
    try {
      final response = await SupabaseService.client
          .from('unit_pendidikan')
          .select();
      _unitList = (response as List).map((j) => UnitModel.fromJson(j as Map<String, dynamic>)).toList();
      setState(() {});
    } catch (e) {
      print('Error loading units: $e');
    }
  }
  
  Future<void> _loadAllKelas() async {
    try {
      final response = await SupabaseService.client
          .from('kelas')
          .select();
      _allKelasList = (response as List).map((j) => KelasModel.fromJson(j as Map<String, dynamic>)).toList();
      setState(() {});
    } catch (e) {
      print('Error loading all classes: $e');
    }
  }
  
  Future<List<KelasModel>> _loadKelasForUnit(int unitId) async {
    try {
      final response = await SupabaseService.client
          .from('kelas')
          .select()
          .eq('unit_id', unitId);
      return (response as List).map((j) => KelasModel.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error loading kelas for unit: $e');
      return [];
    }
  }
  
  Future<void> _loadKategori() async {
    try {
      final response = await SupabaseService.client
          .from('kategori')
          .select()
          .eq('tipe', 'siswa');
      _kategoriList = List<Map<String, dynamic>>.from(response);
      if (_kategoriList.isNotEmpty && _selectedKategoriId == null) {
        _selectedKategoriId = _kategoriList[0]['id'];
      }
      setState(() {});
    } catch (e) {
      print('Error loading categories: $e');
    }
  }
  
  void _showForm({Map<String, dynamic>? siswa}) async {
    if (siswa != null) {
      _editingId = siswa['id'];
      _nameController.text = siswa['name'];
      _nisController.text = siswa['nis'] ?? '';
      _emailController.text = siswa['email'] ?? '';
      _noTelpController.text = siswa['no_telp'] ?? '';
      _selectedUnitId = siswa['unit_id'];
      _selectedKelasId = siswa['kelas_id'];
      _selectedKategoriId = siswa['kategori_id'];
      
      // Pre-load classes for the selected unit
      _kelasListForModal = await _loadKelasForUnit(_selectedUnitId!);
    } else {
      _editingId = null;
      _nameController.clear();
      _nisController.clear();
      _emailController.clear();
      _noTelpController.clear();
      _selectedUnitId = null;
      _selectedKelasId = null;
      _kelasListForModal = [];
      if (_kategoriList.isNotEmpty) {
        _selectedKategoriId = _kategoriList[0]['id'];
      }
    }
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setStateBottomSheet) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _editingId == null ? 'Tambah Siswa' : 'Edit Siswa',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Unit Pendidikan *',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedUnitId,
                      items: _unitList.map((unit) {
                        return DropdownMenuItem(
                          value: unit.id,
                          child: Text(unit.name),
                        );
                      }).toList(),
                      onChanged: (v) async {
                        setStateBottomSheet(() {
                          _selectedUnitId = v;
                          _selectedKelasId = null;
                        });
                        if (v != null) {
                          final kelas = await _loadKelasForUnit(v);
                          setStateBottomSheet(() {
                            _kelasListForModal = kelas;
                          });
                        }
                      },
                      validator: (v) => v == null ? 'Pilih unit pendidikan' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Kelas *',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedKelasId,
                      items: _kelasListForModal.map((kelas) {
                        return DropdownMenuItem(
                          value: kelas.id,
                          child: Text(kelas.name),
                        );
                      }).toList(),
                      onChanged: (v) => setStateBottomSheet(() => _selectedKelasId = v),
                      validator: (v) => v == null ? 'Pilih kelas' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Siswa *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Nama siswa wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nisController,
                      decoration: const InputDecoration(
                        labelText: 'NIS',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noTelpController,
                      decoration: const InputDecoration(
                        labelText: 'No. Telepon',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate() && 
                                  _selectedUnitId != null && 
                                  _selectedKelasId != null) {
                                final provider = Provider.of<MasterProvider>(
                                  context,
                                  listen: false,
                                );
                                final data = {
                                  'name': _nameController.text.trim(),
                                  'nis': _nisController.text.isEmpty ? null : _nisController.text,
                                  'email': _emailController.text.isEmpty ? null : _emailController.text,
                                  'no_telp': _noTelpController.text.isEmpty ? null : _noTelpController.text,
                                  'unit_id': _selectedUnitId,
                                  'kelas_id': _selectedKelasId,
                                  'kategori_id': _selectedKategoriId,
                                };
                                
                                bool success;
                                if (_editingId == null) {
                                  success = await provider.addData('siswa', data);
                                } else {
                                  success = await provider.updateData(
                                    'siswa',
                                    _editingId!,
                                    data,
                                  );
                                }
                                
                                if (success && mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _editingId == null
                                            ? 'Siswa ditambahkan'
                                            : 'Siswa diupdate',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  _loadData();
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(_editingId == null ? 'SIMPAN' : 'UPDATE'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MasterProvider>(context);
    
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.teal,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : provider.data.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Belum ada data siswa'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: provider.data.length,
                    itemBuilder: (context, index) {
                      final siswa = provider.data[index];
                      final unit = _unitList.firstWhere(
                        (u) => u.id == siswa['unit_id'],
                        orElse: () => UnitModel(
                          id: 0,
                          name: '-',
                          createdAt: DateTime.now(),
                        ),
                      );
                      final kelas = _allKelasList.firstWhere(
                        (k) => k.id == siswa['kelas_id'],
                        orElse: () => KelasModel(
                          id: 0,
                          name: '-',
                          unitId: 0,
                          createdAt: DateTime.now(),
                        ),
                      );
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple.shade100,
                            child: const Icon(
                              Icons.people,
                              color: Colors.purple,
                            ),
                          ),
                          title: Text(
                            siswa['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Unit: ${unit.name} | Kelas: ${kelas.name}'),
                              if (siswa['nis'] != null) Text('NIS: ${siswa['nis']}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showForm(siswa: siswa),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Hapus Siswa'),
                                      content: Text(
                                        'Yakin hapus ${siswa['name']}?\n\nData absensi siswa ini akan ikut terhapus.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(_, false),
                                          child: const Text('Batal'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(_, true),
                                          child: const Text('Hapus'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    final success = await provider.deleteData(
                                      'siswa',
                                      siswa['id'],
                                    );
                                    if (success && mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Siswa dihapus'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      _loadData();
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
