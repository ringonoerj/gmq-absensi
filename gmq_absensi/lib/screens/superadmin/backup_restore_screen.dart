import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/supabase_service.dart';
import '../../utils/backup_save_stub.dart'
    if (dart.library.html) '../../utils/backup_save_web.dart'
    if (dart.library.io) '../../utils/backup_save_io.dart';
import '../../widgets/confetti_overlay.dart';


class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _isLoading = false;
  String? _lastBackupInfo;
  
  final List<String> _tables = [
    'unit_pendidikan',
    'kelas',
    'kategori',
    'guru',
    'siswa',
    'tahun_ajaran',
    'libur_nasional',
    'users',
    'absensi',
  ];

  // Order of deletion to avoid foreign key constraint violations
  final List<String> _deleteOrder = [
    'backup_logs',
    'absensi',
    'siswa',
    'guru',
    'kelas',
    'users',
    'unit_pendidikan',
    'kategori',
    'libur_nasional',
    'tahun_ajaran',
  ];

  // Order of insertion to ensure parent records exist first
  final List<String> _insertOrder = [
    'tahun_ajaran',
    'libur_nasional',
    'kategori',
    'unit_pendidikan',
    'users',
    'kelas',
    'guru',
    'siswa',
    'absensi',
  ];
  
  @override
  void initState() {
    super.initState();
    _loadLastBackupInfo();
  }
  
  Future<void> _loadLastBackupInfo() async {
    try {
      final response = await SupabaseService.client
          .from('backup_logs')
          .select()
          .eq('action', 'backup')
          .order('created_at', ascending: false)
          .limit(1);
          
      if (response.isNotEmpty) {
        setState(() {
          _lastBackupInfo = response[0]['filename'];
        });
      }
    } catch (e) {
      print('Error loading backup info: $e');
    }
  }
  
  Future<void> _backupData() async {
    setState(() => _isLoading = true);
    
    try {
      final Map<String, dynamic> backupData = {};
      
      for (var table in _tables) {
        final response = await SupabaseService.client.from(table).select();
        backupData[table] = response;
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'backup_gmq_$timestamp.json';
      final jsonString = jsonEncode(backupData);
      
      // Save file platform-independently
      await saveBackupFile(filename, jsonString);
      
      // Log backup
      await SupabaseService.client.from('backup_logs').insert({
        'action': 'backup',
        'filename': filename,
        'performed_by': SupabaseService.currentUserId,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup berhasil!'),
            backgroundColor: Colors.green,
          ),
        );
        ConfettiOverlay.of(context)?.play();
        await _loadLastBackupInfo();
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup gagal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _restoreData() async {
    setState(() => _isLoading = true);
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (result == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      String jsonString;
      if (kIsWeb) {
        final fileBytes = result.files.first.bytes;
        if (fileBytes == null) throw Exception('Gagal membaca data file');
        jsonString = utf8.decode(fileBytes);
      } else {
        final path = result.files.first.path;
        if (path == null) throw Exception('File path tidak ditemukan');
        final file = File(path);
        jsonString = await file.readAsString();
      }
      
      final backupData = jsonDecode(jsonString);
      
      // 1. Clear existing data in reverse relation order
      final activeId = SupabaseService.currentUserId;
      for (var table in _deleteOrder) {
        try {
          if (table == 'users' && activeId != null) {
            // Preserve the active user to avoid session issues and foreign key violations during restore
            await SupabaseService.client.from(table).delete().neq('id', activeId);
          } else {
            await SupabaseService.client.from(table).delete().not('id', 'is', null);
          }
        } catch (e) {
          print('Error clearing table $table: $e');
        }
      }
      
      // 2. Insert backup data in correct forward relation order
      for (var table in _insertOrder) {
        if (backupData.containsKey(table)) {
          final data = backupData[table];
          if (data is List && data.isNotEmpty) {
            for (var item in data) {
              if (table == 'users') {
                await SupabaseService.client.from(table).upsert(item);
              } else {
                await SupabaseService.client.from(table).insert(item);
              }
            }
          }
        }
      }
      
      // Log restore
      await SupabaseService.client.from('backup_logs').insert({
        'action': 'restore',
        'filename': result.files.first.name,
        'performed_by': SupabaseService.currentUserId,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restore berhasil!'),
            backgroundColor: Colors.green,
          ),
        );
        ConfettiOverlay.of(context)?.play();
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore gagal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    
    setState(() => _isLoading = false);
  }
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.backup,
                        size: 80,
                        color: Colors.teal,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'BACKUP & RESTORE DATA',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Backup seluruh database atau restore dari file backup',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      
                      if (_lastBackupInfo != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Backup Terakhir:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(_lastBackupInfo!),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 24),
                      
                      if (_isLoading)
                        const CircularProgressIndicator()
                      else ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _backupData,
                            icon: const Icon(Icons.cloud_upload),
                            label: const Text(
                              'BACKUP DATA',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _restoreData,
                            icon: const Icon(Icons.cloud_download),
                            label: const Text(
                              'RESTORE DATA',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.teal,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Backup akan menyimpan semua data: Unit, Kelas, Guru, Siswa, Users, dan Absensi.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
