import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/master_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/unit_model.dart';

class ManageGuruScreen extends StatefulWidget {
  const ManageGuruScreen({super.key});

  @override
  State<ManageGuruScreen> createState() => _ManageGuruScreenState();
}

class _ManageGuruScreenState extends State<ManageGuruScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nipController = TextEditingController();
  final _emailController = TextEditingController();
  final _noTelpController = TextEditingController();
  int? _selectedUnitId;
  int? _selectedKategoriId;
  int? _editingId;
  List<UnitModel> _unitList = [];
  List<Map<String, dynamic>> _kategoriList = [];
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }
  
  Future<void> _loadData() async {
    await Future.wait([
      Provider.of<MasterProvider>(context, listen: false)
          .fetchData('guru', orderBy: 'name'),
      _loadUnits(),
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
  
  Future<void> _loadKategori() async {
    try {
      final response = await SupabaseService.client
          .from('kategori')
          .select()
          .eq('tipe', 'guru');
      _kategoriList = List<Map<String, dynamic>>.from(response);
      setState(() {});
    } catch (e) {
      print('Error loading categories: $e');
    }
  }
  
  void _showForm({Map<String, dynamic>? guru}) {
    if (guru != null) {
      _editingId = guru['id'];
      _nameController.text = guru['name'];
      _nipController.text = guru['nip'] ?? '';
      _emailController.text = guru['email'] ?? '';
      _noTelpController.text = guru['no_telp'] ?? '';
      _selectedUnitId = guru['unit_id'];
      _selectedKategoriId = guru['kategori_id'];
    } else {
      _editingId = null;
      _nameController.clear();
      _nipController.clear();
      _emailController.clear();
      _noTelpController.clear();
      _selectedUnitId = null;
      _selectedKategoriId = _kategoriList.isNotEmpty ? _kategoriList[0]['id'] : null;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
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
                      _editingId == null ? 'Tambah Guru' : 'Edit Guru',
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
                      onChanged: (v) {
                        setModalState(() {
                          _selectedUnitId = v;
                        });
                        setState(() {
                          _selectedUnitId = v;
                        });
                      },
                      validator: (v) => v == null ? 'Pilih unit pendidikan' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Guru *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Nama guru wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nipController,
                      decoration: const InputDecoration(
                        labelText: 'NIP',
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
                              if (_formKey.currentState!.validate() && _selectedUnitId != null) {
                                final provider = Provider.of<MasterProvider>(
                                  context,
                                  listen: false,
                                );
                                final data = {
                                  'name': _nameController.text.trim(),
                                  'nip': _nipController.text.isEmpty ? null : _nipController.text,
                                  'email': _emailController.text.isEmpty ? null : _emailController.text,
                                  'no_telp': _noTelpController.text.isEmpty ? null : _noTelpController.text,
                                  'unit_id': _selectedUnitId,
                                  'kategori_id': _selectedKategoriId,
                                };
                                
                                bool success;
                                if (_editingId == null) {
                                  success = await provider.addData('guru', data);
                                } else {
                                  success = await provider.updateData(
                                    'guru',
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
                                            ? 'Guru ditambahkan'
                                            : 'Guru diupdate',
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
        }
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MasterProvider>(context);
    
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showForm,
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
                        Icon(Icons.person, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Belum ada data guru'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: provider.data.length,
                    itemBuilder: (context, index) {
                      final guru = provider.data[index];
                      final unit = _unitList.firstWhere(
                        (u) => u.id == guru['unit_id'],
                        orElse: () => UnitModel(
                          id: 0,
                          name: '-',
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
                            backgroundColor: Colors.orange.shade100,
                            child: const Icon(
                              Icons.person,
                              color: Colors.orange,
                            ),
                          ),
                          title: Text(
                            guru['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Unit: ${unit.name}'),
                              if (guru['nip'] != null) Text('NIP: ${guru['nip']}'),
                              if (guru['email'] != null) Text('Email: ${guru['email']}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showForm(guru: guru),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Hapus Guru'),
                                      content: Text(
                                        'Yakin hapus ${guru['name']}?\n\nData absensi guru ini akan ikut terhapus.',
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
                                      'guru',
                                      guru['id'],
                                    );
                                    if (success && mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Guru dihapus'),
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
