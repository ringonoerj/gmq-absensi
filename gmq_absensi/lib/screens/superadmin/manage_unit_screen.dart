import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/master_provider.dart';

class ManageUnitScreen extends StatefulWidget {
  const ManageUnitScreen({super.key});

  @override
  State<ManageUnitScreen> createState() => _ManageUnitScreenState();
}

class _ManageUnitScreenState extends State<ManageUnitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _alamatController = TextEditingController();
  final _kontakController = TextEditingController();
  int? _editingId;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }
  
  Future<void> _loadData() async {
    await Provider.of<MasterProvider>(context, listen: false)
        .fetchData('unit_pendidikan', orderBy: 'name');
  }
  
  void _showForm({Map<String, dynamic>? unit}) {
    if (unit != null) {
      _editingId = unit['id'];
      _nameController.text = unit['name'];
      _alamatController.text = unit['alamat'] ?? '';
      _kontakController.text = unit['kontak'] ?? '';
    } else {
      _editingId = null;
      _nameController.clear();
      _alamatController.clear();
      _kontakController.clear();
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
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
                _editingId == null ? 'Tambah Unit' : 'Edit Unit',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Unit *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Nama unit wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _alamatController,
                decoration: const InputDecoration(
                  labelText: 'Alamat',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _kontakController,
                decoration: const InputDecoration(
                  labelText: 'Kontak',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          final provider = Provider.of<MasterProvider>(
                            context,
                            listen: false,
                          );
                          final data = {
                            'name': _nameController.text.trim(),
                            'alamat': _alamatController.text.isEmpty
                                ? null
                                : _alamatController.text,
                            'kontak': _kontakController.text.isEmpty
                                ? null
                                : _kontakController.text,
                          };
                          
                          bool success;
                          if (_editingId == null) {
                            success = await provider.addData('unit_pendidikan', data);
                          } else {
                            success = await provider.updateData(
                              'unit_pendidikan',
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
                                      ? 'Unit ditambahkan'
                                      : 'Unit diupdate',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadData();
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Gagal menyimpan unit'),
                                backgroundColor: Colors.red,
                              ),
                            );
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
                        Icon(Icons.business, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Belum ada data unit'),
                        SizedBox(height: 8),
                        Text('Tekan tombol + untuk menambah'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: provider.data.length,
                    itemBuilder: (context, index) {
                      final unit = provider.data[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            child: const Icon(
                              Icons.business,
                              color: Colors.teal,
                            ),
                          ),
                          title: Text(
                            unit['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (unit['alamat'] != null)
                                Text('Alamat: ${unit['alamat']}'),
                              if (unit['kontak'] != null)
                                Text('Kontak: ${unit['kontak']}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showForm(unit: unit),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Hapus Unit'),
                                      content: Text(
                                        'Yakin hapus ${unit['name']}?\n\nData terkait (kelas, guru, siswa) akan ikut terhapus.',
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
                                      'unit_pendidikan',
                                      unit['id'],
                                    );
                                    if (success && mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Unit dihapus'),
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
