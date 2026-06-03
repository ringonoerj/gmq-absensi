import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../models/unit_model.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedRole;
  int? _selectedUnitId;
  String? _editingId;
  List<UnitModel> _unitList = [];
  List<Map<String, dynamic>> _usersList = [];
  
  final List<Map<String, dynamic>> _roles = [
    {'value': 'superadmin', 'label': 'Superadmin', 'color': Colors.red},
    {'value': 'operator', 'label': 'Operator', 'color': Colors.blue},
    {'value': 'supervisor', 'label': 'Supervisor', 'color': Colors.green},
  ];
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }
  
  Future<void> _loadData() async {
    await Future.wait([
      _loadUsers(),
      _loadUnits(),
    ]);
  }
  
  Future<void> _loadUsers() async {
    try {
      final response = await SupabaseService.client
          .from('users')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _usersList = List<Map<String, dynamic>>.from(response as List);
      });
    } catch (e) {
      print('Error loading users: $e');
    }
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
  
  void _showForm({Map<String, dynamic>? user}) {
    if (user != null) {
      _editingId = user['id'];
      _emailController.text = user['email'];
      _nameController.text = user['name'];
      _selectedRole = user['role'];
      _selectedUnitId = user['unit_id'];
      _passwordController.clear();
    } else {
      _editingId = null;
      _emailController.clear();
      _nameController.clear();
      _passwordController.clear();
      _selectedRole = 'operator';
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _editingId == null ? 'Tambah User' : 'Edit User',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      enabled: _editingId == null,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email wajib diisi';
                        if (!v.contains('@')) return 'Email tidak valid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Nama wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    if (_editingId == null)
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password *',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password wajib diisi';
                          if (v.length < 6) return 'Password minimal 6 karakter';
                          return null;
                        },
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Role *',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedRole,
                      items: _roles.map<DropdownMenuItem<String>>((role) {
                        return DropdownMenuItem<String>(
                          value: role['value'] as String,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: role['color'] as Color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(role['label'] as String),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setModalState(() {
                          _selectedRole = v;
                        });
                        setState(() {
                          _selectedRole = v;
                        });
                      },
                      validator: (v) => v == null ? 'Pilih role' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Unit Pendidikan',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedUnitId,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Semua Unit')),
                        ..._unitList.map((unit) {
                          return DropdownMenuItem(
                            value: unit.id,
                            child: Text(unit.name),
                          );
                        }),
                      ],
                      onChanged: (v) {
                        setModalState(() {
                          _selectedUnitId = v;
                        });
                        setState(() {
                          _selectedUnitId = v;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                if (_editingId == null) {
                                  // Create new user
                                  try {
                                    // Create a temporary client to prevent signing out the current superadmin
                                    final tempClient = SupabaseClient(
                                      SupabaseService.supabaseUrl,
                                      SupabaseService.supabaseAnonKey,
                                      authOptions: const AuthClientOptions(
                                        authFlowType: AuthFlowType.implicit,
                                      ),
                                    );
                                    final response = await tempClient.auth.signUp(
                                      email: _emailController.text.trim(),
                                      password: _passwordController.text,
                                    );
                                    
                                    if (response.user != null) {
                                      await SupabaseService.client.from('users').upsert({
                                        'id': response.user!.id,
                                        'email': _emailController.text.trim(),
                                        'name': _nameController.text.trim(),
                                        'role': _selectedRole,
                                        'unit_id': _selectedUnitId,
                                        'is_active': true,
                                      });
                                      
                                      if (mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('User berhasil ditambahkan'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        _loadData();
                                      }
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Gagal: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } else {
                                  // Update existing user
                                  try {
                                    await SupabaseService.client
                                        .from('users')
                                        .update({
                                          'name': _nameController.text.trim(),
                                          'role': _selectedRole,
                                          'unit_id': _selectedUnitId,
                                          'updated_at': DateTime.now().toIso8601String(),
                                        })
                                        .eq('id', _editingId!);
                                        
                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('User berhasil diupdate'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      _loadData();
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Gagal update: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
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
  
  Future<void> _resetPassword(String email) async {
    try {
      await SupabaseService.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email reset password telah dikirim'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _toggleUserStatus(String userId, bool currentStatus) async {
    try {
      await SupabaseService.client
          .from('users')
          .update({'is_active': !currentStatus})
          .eq('id', userId);
      _loadData();
    } catch (e) {
      print('Error toggling status: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showForm,
        child: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.teal,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _usersList.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.admin_panel_settings, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Belum ada data user'),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: _usersList.length,
                itemBuilder: (context, index) {
                  final user = _usersList[index];
                  final role = _roles.firstWhere(
                    (r) => r['value'] == user['role'],
                    orElse: () => {'label': user['role'], 'color': Colors.grey},
                  );
                  final unit = _unitList.firstWhere(
                    (u) => u.id == user['unit_id'],
                    orElse: () => UnitModel(
                      id: 0,
                      name: 'Semua Unit',
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
                        backgroundColor: (role['color'] as Color).withOpacity(0.2),
                        child: Icon(
                          Icons.person,
                          color: role['color'],
                        ),
                      ),
                      title: Text(
                        user['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email: ${user['email']}'),
                          Text('Role: ${role['label']} | Unit: ${unit.name}'),
                          Text(
                            user['is_active'] ? 'Aktif' : 'Tidak Aktif',
                            style: TextStyle(
                              color: user['is_active'] ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.password, color: Colors.orange),
                            onPressed: () => _resetPassword(user['email']),
                            tooltip: 'Reset Password',
                          ),
                          IconButton(
                            icon: Icon(
                              user['is_active'] ? Icons.block : Icons.check_circle,
                              color: user['is_active'] ? Colors.red : Colors.green,
                            ),
                            onPressed: () => _toggleUserStatus(user['id'], user['is_active']),
                            tooltip: user['is_active'] ? 'Nonaktifkan' : 'Aktifkan',
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showForm(user: user),
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
