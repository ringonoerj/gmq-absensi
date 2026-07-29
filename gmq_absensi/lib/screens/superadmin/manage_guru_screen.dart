import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/master_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/unit_model.dart';
import '../../models/kelas_model.dart';
import '../../helpers/export_helper.dart';

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
  List<int> _selectedUnitIds = [];
  List<int> _selectedKelasIds = [];
  int? _selectedKategoriId;
  int? _editingId;
  List<UnitModel> _unitList = [];
  List<KelasModel> _allKelasList = [];
  List<Map<String, dynamic>> _kategoriList = [];
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }
  
  Future<void> _loadData() async {
    await Future.wait([
      Provider.of<MasterProvider>(context, listen: false)
          .fetchData('guru', orderBy: 'name', paginate: true),
      _loadUnits(),
      _loadKategori(),
      _loadAllKelas(),
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
  
  Future<void> _loadAllKelas() async {
    try {
      final response = await SupabaseService.client
          .from('kelas')
          .select();
      _allKelasList = (response as List).map((j) => KelasModel.fromJson(j as Map<String, dynamic>)).toList();
      _allKelasList.sort((a, b) => a.name.compareTo(b.name));
      setState(() {});
    } catch (e) {
      print('Error loading all classes: $e');
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
  
  void _showUnitSelector(StateSetter setModalState) {
    showDialog(
      context: context,
      builder: (context) {
        List<int> tempSelected = List.from(_selectedUnitIds);
        return AlertDialog(
          title: const Text('Pilih Unit Pendidikan'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: ListBody(
                  children: _unitList.map<Widget>((unit) {
                    final isChecked = tempSelected.contains(unit.id);
                    return CheckboxListTile(
                      title: Text(unit.name),
                      value: isChecked,
                      onChanged: (val) {
                        setStateDialog(() {
                          if (val == true) {
                            tempSelected.add(unit.id);
                          } else {
                            tempSelected.remove(unit.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                setModalState(() {
                  _selectedUnitIds = tempSelected;
                  // Remove classes that do not belong to the selected units
                  _selectedKelasIds.removeWhere((classId) {
                    final cls = _allKelasList.firstWhere(
                      (c) => c.id == classId,
                      orElse: () => KelasModel(id: 0, name: '', unitId: 0, createdAt: DateTime.now()),
                    );
                    return !_selectedUnitIds.contains(cls.unitId);
                  });
                });
                setState(() {});
                Navigator.pop(context);
              },
              child: const Text('Pilih'),
            ),
          ],
        );
      },
    );
  }

  void _showKelasSelector(StateSetter setModalState) {
    final availableClasses = _allKelasList.where((c) => _selectedUnitIds.contains(c.unitId)).toList();
    
    showDialog(
      context: context,
      builder: (context) {
        List<int> tempSelected = List.from(_selectedKelasIds);
        return AlertDialog(
          title: const Text('Pilih Kelas'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              if (availableClasses.isEmpty) {
                return const Center(child: Text('Pilih unit pendidikan terlebih dahulu.'));
              }
              return SingleChildScrollView(
                child: ListBody(
                  children: availableClasses.map<Widget>((kelas) {
                    final isChecked = tempSelected.contains(kelas.id);
                    final unitName = _unitList.firstWhere(
                      (u) => u.id == kelas.unitId,
                      orElse: () => UnitModel(id: 0, name: '-', createdAt: DateTime.now()),
                    ).name;
                    return CheckboxListTile(
                      title: Text(kelas.name),
                      subtitle: Text(unitName, style: const TextStyle(fontSize: 11)),
                      value: isChecked,
                      onChanged: (val) {
                        setStateDialog(() {
                          if (val == true) {
                            tempSelected.add(kelas.id);
                          } else {
                            tempSelected.remove(kelas.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                setModalState(() {
                  _selectedKelasIds = tempSelected;
                });
                setState(() {});
                Navigator.pop(context);
              },
              child: const Text('Pilih'),
            ),
          ],
        );
      },
    );
  }

  void _showForm({Map<String, dynamic>? guru}) {
    if (guru != null) {
      _editingId = guru['id'];
      _nameController.text = guru['name'];
      _nipController.text = guru['nip'] ?? '';
      _emailController.text = guru['email'] ?? '';
      _noTelpController.text = guru['no_telp'] ?? '';
      
      _selectedUnitIds = [];
      if (guru['unit_ids'] != null) {
        _selectedUnitIds = List<int>.from(guru['unit_ids']);
      } else if (guru['unit_id'] != null) {
        _selectedUnitIds = [guru['unit_id'] as int];
      }
      
      _selectedKelasIds = [];
      if (guru['kelas_ids'] != null) {
        _selectedKelasIds = List<int>.from(guru['kelas_ids']);
      }
      
      _selectedKategoriId = guru['kategori_id'];
    } else {
      _editingId = null;
      _nameController.clear();
      _nipController.clear();
      _emailController.clear();
      _noTelpController.clear();
      _selectedUnitIds = [];
      _selectedKelasIds = [];
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
                    
                    // Unit selector container
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Unit Pendidikan *',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              TextButton(
                                onPressed: () => _showUnitSelector(setModalState),
                                child: const Text('Pilih Unit'),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _selectedUnitIds.map<Widget>((id) {
                              final name = _unitList.firstWhere(
                                (u) => u.id == id,
                                orElse: () => UnitModel(id: 0, name: '-', createdAt: DateTime.now()),
                              ).name;
                              return Chip(
                                label: Text(name, style: const TextStyle(fontSize: 11)),
                                onDeleted: () {
                                  setModalState(() {
                                    _selectedUnitIds.remove(id);
                                    _selectedKelasIds.removeWhere((classId) {
                                      final cls = _allKelasList.firstWhere(
                                        (c) => c.id == classId,
                                        orElse: () => KelasModel(id: 0, name: '', unitId: 0, createdAt: DateTime.now()),
                                      );
                                      return cls.unitId == id;
                                    });
                                  });
                                  setState(() {});
                                },
                              );
                            }).toList(),
                          ),
                          if (_selectedUnitIds.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'Unit pendidikan wajib dipilih',
                                style: TextStyle(color: Colors.red, fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Kelas selector container
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Kelas (Opsional)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              TextButton(
                                onPressed: _selectedUnitIds.isEmpty
                                    ? null
                                    : () => _showKelasSelector(setModalState),
                                child: const Text('Pilih Kelas'),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _selectedKelasIds.map<Widget>((id) {
                              final name = _allKelasList.firstWhere(
                                (c) => c.id == id,
                                orElse: () => KelasModel(id: 0, name: '-', unitId: 0, createdAt: DateTime.now()),
                              ).name;
                              return Chip(
                                label: Text(name, style: const TextStyle(fontSize: 11)),
                                onDeleted: () {
                                  setModalState(() {
                                    _selectedKelasIds.remove(id);
                                  });
                                  setState(() {});
                                },
                              );
                            }).toList(),
                          ),
                          if (_selectedKelasIds.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'Belum ada kelas terpilih',
                                style: TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ),
                        ],
                      ),
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
                              if (_formKey.currentState!.validate() && _selectedUnitIds.isNotEmpty) {
                                final provider = Provider.of<MasterProvider>(
                                  context,
                                  listen: false,
                                );
                                final data = {
                                  'name': _nameController.text.trim(),
                                  'nip': _nipController.text.isEmpty ? null : _nipController.text,
                                  'email': _emailController.text.isEmpty ? null : _emailController.text,
                                  'no_telp': _noTelpController.text.isEmpty ? null : _noTelpController.text,
                                  'unit_ids': _selectedUnitIds,
                                  'kelas_ids': _selectedKelasIds,
                                  'unit_id': _selectedUnitIds.first, // fallback for legacy column constraint
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isOperator = authProvider.currentUser?.role == 'operator';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List<_GuruListItem> listItems = [];
    if (!provider.isLoading && provider.data.isNotEmpty) {
      for (var unit in _unitList) {
        final unitGurus = provider.data.where((g) {
          List<int> uIds = [];
          if (g['unit_ids'] != null) {
            uIds.addAll(List<int>.from(g['unit_ids']));
          } else if (g['unit_id'] != null) {
            uIds.add(g['unit_id'] as int);
          }
          return uIds.contains(unit.id);
        }).toList();

        if (unitGurus.isNotEmpty) {
          listItems.add(_GuruListItem(unitName: unit.name, isHeader: true));
          for (var g in unitGurus) {
            listItems.add(_GuruListItem(guru: g));
          }
        }
      }
      final orphanGurus = provider.data.where((g) {
        List<int> uIds = [];
        if (g['unit_ids'] != null) {
          uIds.addAll(List<int>.from(g['unit_ids']));
        } else if (g['unit_id'] != null) {
          uIds.add(g['unit_id'] as int);
        }
        return uIds.isEmpty || !uIds.any((id) => _unitList.any((u) => u.id == id));
      }).toList();
      if (orphanGurus.isNotEmpty) {
        listItems.add(_GuruListItem(unitName: 'Tanpa Unit', isHeader: true));
        for (var g in orphanGurus) {
          listItems.add(_GuruListItem(guru: g));
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
        child: (provider.isLoading && provider.data.isEmpty)
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
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: isDark ? Colors.grey.shade900 : Colors.teal.shade50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total: ${provider.data.length} Guru',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                ExportHelper().exportGuru(
                                  context,
                                  data: provider.data,
                                  unitList: _unitList,
                                  kelasList: _allKelasList,
                                );
                              },
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text('Ekspor Guru'),
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
                          itemCount: listItems.length + (provider.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == listItems.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: provider.isLoading
                                      ? const CircularProgressIndicator()
                                      : ElevatedButton(
                                          onPressed: () {
                                            provider.fetchData(
                                              'guru',
                                              orderBy: 'name',
                                              loadMore: true,
                                              paginate: true,
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.teal,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Muat Lebih Banyak'),
                                        ),
                                ),
                              );
                            }
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

                            final guru = item.guru!;

                            // Process unit names
                            final List<int> uIds = [];
                            if (guru['unit_ids'] != null) {
                              uIds.addAll(List<int>.from(guru['unit_ids']));
                            } else if (guru['unit_id'] != null) {
                              uIds.add(guru['unit_id'] as int);
                            }

                            final unitNames = uIds.map((uid) {
                              return _unitList.firstWhere(
                                (u) => u.id == uid,
                                orElse: () => UnitModel(id: 0, name: '-', createdAt: DateTime.now()),
                              ).name;
                            }).join(', ');

                            // Process kelas names
                            final List<int> kIds = [];
                            if (guru['kelas_ids'] != null) {
                              kIds.addAll(List<int>.from(guru['kelas_ids']));
                            }

                            final kelasNames = kIds.isNotEmpty
                                ? kIds.map((kid) {
                                    return _allKelasList.firstWhere(
                                      (c) => c.id == kid,
                                      orElse: () => KelasModel(id: 0, name: '-', unitId: 0, createdAt: DateTime.now()),
                                    ).name;
                                  }).join(', ')
                                : '-';

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
                                    Text('Unit: $unitNames'),
                                    Text('Kelas: $kelasNames'),
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
                                    if (!isOperator)
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
                    ],
                  ),
      ),
    );
  }
}

class _GuruListItem {
  final String? unitName;
  final Map<String, dynamic>? guru;
  final bool isHeader;
  _GuruListItem({this.unitName, this.guru, this.isHeader = false});
}
