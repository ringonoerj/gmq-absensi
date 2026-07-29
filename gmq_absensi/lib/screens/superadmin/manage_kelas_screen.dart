import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/master_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/unit_model.dart';
import '../../services/supabase_service.dart';
import '../../helpers/export_helper.dart';

class ManageKelasScreen extends StatefulWidget {
  const ManageKelasScreen({super.key});

  @override
  State<ManageKelasScreen> createState() => _ManageKelasScreenState();
}

class _ManageKelasScreenState extends State<ManageKelasScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _tingkatController = TextEditingController();
  final _jurusanController = TextEditingController();
  int? _selectedUnitId;
  int? _editingId;
  List<UnitModel> _unitList = [];
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }
  
  Future<void> _loadData() async {
    await Future.wait([
      Provider.of<MasterProvider>(context, listen: false)
          .fetchData('kelas', orderBy: 'name'),
      _loadUnits(),
    ]);
  }
  
  Future<void> _loadUnits() async {
    try {
      final response = await SupabaseService.client
          .from('unit_pendidikan')
          .select();
      _unitList = (response as List).map((j) => UnitModel.fromJson(j as Map<String, dynamic>)).toList();
      _unitList.sort((a, b) => a.name.compareTo(b.name));
      setState(() {});
    } catch (e) {
      print('Error loading units: $e');
    }
  }
  
  void _showForm({Map<String, dynamic>? kelas}) {
    if (kelas != null) {
      _editingId = kelas['id'];
      _nameController.text = kelas['name'];
      _tingkatController.text = kelas['tingkat'] ?? '';
      _jurusanController.text = kelas['jurusan'] ?? '';
      _selectedUnitId = kelas['unit_id'];
    } else {
      _editingId = null;
      _nameController.clear();
      _tingkatController.clear();
      _jurusanController.clear();
      _selectedUnitId = null;
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _editingId == null ? 'Tambah Kelas' : 'Edit Kelas',
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
                      labelText: 'Nama Kelas *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.isEmpty ? 'Nama kelas wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _tingkatController,
                    decoration: const InputDecoration(
                      labelText: 'Tingkat',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _jurusanController,
                    decoration: const InputDecoration(
                      labelText: 'Jurusan',
                      border: OutlineInputBorder(),
                    ),
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
                                'unit_id': _selectedUnitId,
                                'tingkat': _tingkatController.text.isEmpty
                                    ? null
                                    : _tingkatController.text,
                                'jurusan': _jurusanController.text.isEmpty
                                    ? null
                                    : _jurusanController.text,
                              };
                              
                              bool success;
                              if (_editingId == null) {
                                success = await provider.addData('kelas', data);
                              } else {
                                success = await provider.updateData(
                                  'kelas',
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
                                          ? 'Kelas ditambahkan'
                                          : 'Kelas diupdate',
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
          );
        }
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MasterProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isOperator = authProvider.currentUser?.role == 'operator';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List<_KelasListItem> listItems = [];
    if (!provider.isLoading && provider.data.isNotEmpty) {
      for (var unit in _unitList) {
        final unitClasses = provider.data.where((k) => k['unit_id'] == unit.id).toList();
        if (unitClasses.isNotEmpty) {
          listItems.add(_KelasListItem(unitName: unit.name, isHeader: true));
          for (var k in unitClasses) {
            listItems.add(_KelasListItem(kelas: k));
          }
        }
      }
      final orphanClasses = provider.data.where((k) => !_unitList.any((u) => u.id == k['unit_id'])).toList();
      if (orphanClasses.isNotEmpty) {
        listItems.add(_KelasListItem(unitName: 'Tanpa Unit', isHeader: true));
        for (var k in orphanClasses) {
          listItems.add(_KelasListItem(kelas: k));
        }
      }
    }

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
                        Icon(Icons.class_, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Belum ada data kelas'),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: isDark ? Colors.grey.shade900 : Colors.teal.shade50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total: ${provider.data.length} Kelas',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                ExportHelper().exportKelas(
                                  context,
                                  data: provider.data,
                                  unitList: _unitList,
                                );
                              },
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text('Ekspor Kelas'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: listItems.length,
                          itemBuilder: (context, index) {
                            final item = listItems[index];
                            if (item.isHeader) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                color: isDark ? Colors.grey.shade800 : Colors.teal.shade100.withOpacity(0.4),
                                width: double.infinity,
                                child: Text(
                                  item.unitName!,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.teal.shade300 : Colors.teal.shade800,
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            }

                            final kelas = item.kelas!;
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.shade100,
                                  child: const Icon(
                                    Icons.class_,
                                    color: Colors.green,
                                  ),
                                ),
                                title: Text(
                                  kelas['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (kelas['tingkat'] != null)
                                      Text('Tingkat: ${kelas['tingkat']}'),
                                    if (kelas['jurusan'] != null)
                                      Text('Jurusan: ${kelas['jurusan']}'),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _showForm(kelas: kelas),
                                    ),
                                    if (!isOperator)
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text('Hapus Kelas'),
                                              content: Text(
                                                'Yakin hapus ${kelas['name']}?\n\nSiswa di kelas ini akan ikut terhapus.',
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
                                              'kelas',
                                              kelas['id'],
                                            );
                                            if (success && mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Kelas dihapus'),
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
                    ],
                  ),
      ),
    );
  }
}

class _KelasListItem {
  final String? unitName;
  final Map<String, dynamic>? kelas;
  final bool isHeader;
  _KelasListItem({this.unitName, this.kelas, this.isHeader = false});
}
