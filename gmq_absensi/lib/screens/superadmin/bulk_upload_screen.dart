import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/supabase_service.dart';

class BulkUploadScreen extends StatefulWidget {
  const BulkUploadScreen({super.key});

  @override
  State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _textController = TextEditingController();
  bool _isLoading = false;
  
  // Parsed Preview Data
  List<String> _headers = [];
  List<List<String>> _rows = [];
  String _uploadType = 'guru'; // 'guru' or 'siswa'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _uploadType = _tabController.index == 0 ? 'guru' : 'siswa';
        _clearData();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _clearData() {
    _headers = [];
    _rows = [];
    _textController.clear();
  }

  // Simple and robust CSV parsing helper
  List<List<String>> _parseCSV(String text) {
    final List<List<String>> result = [];
    // Handle both Windows (\r\n) and Unix (\n) line breaks
    final lines = text.split(RegExp(r'\r?\n'));
    
    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      
      final List<String> row = [];
      StringBuffer sb = StringBuffer();
      bool inQuotes = false;
      
      for (int i = 0; i < line.length; i++) {
        final char = line[i];
        if (char == '"') {
          inQuotes = !inQuotes;
        } else if (char == ',' && !inQuotes) {
          row.add(sb.toString().trim());
          sb.clear();
        } else {
          sb.write(char);
        }
      }
      row.add(sb.toString().trim());
      result.add(row);
    }
    return result;
  }

  void _processRawText(String text) {
    if (text.trim().isEmpty) return;
    
    try {
      final parsed = _parseCSV(text);
      if (parsed.isEmpty) return;
      
      setState(() {
        _headers = parsed.first;
        _rows = parsed.skip(1).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String csvText = '';
        
        if (file.bytes != null) {
          csvText = utf8.decode(file.bytes!);
        }
        
        if (csvText.isNotEmpty) {
          _textController.text = csvText;
          _processRawText(csvText);
        }
      }
    } catch (e) {
      print('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadData() async {
    if (_rows.isEmpty) return;

    setState(() => _isLoading = true);
    int successCount = 0;
    int errorCount = 0;
    String errorMessage = '';

    try {
      if (_uploadType == 'guru') {
        // Expected columns: name, email, no_telp, unit_ids
        final int nameIdx = _headers.indexWhere((h) => h.toLowerCase() == 'name');
        final int emailIdx = _headers.indexWhere((h) => h.toLowerCase() == 'email');
        final int telpIdx = _headers.indexWhere((h) => h.toLowerCase() == 'no_telp');
        final int unitsIdx = _headers.indexWhere((h) => h.toLowerCase() == 'unit_ids');

        if (nameIdx == -1) {
          throw Exception('Kolom "name" tidak ditemukan di baris header.');
        }

        for (var row in _rows) {
          if (row.length <= nameIdx || row[nameIdx].isEmpty) continue;
          
          final String name = row[nameIdx];
          final String? email = emailIdx != -1 && row.length > emailIdx && row[emailIdx].isNotEmpty ? row[emailIdx] : null;
          final String? telp = telpIdx != -1 && row.length > telpIdx && row[telpIdx].isNotEmpty ? row[telpIdx] : null;
          
          List<int>? unitIds;
          if (unitsIdx != -1 && row.length > unitsIdx && row[unitsIdx].isNotEmpty) {
            unitIds = row[unitsIdx]
                .split(';')
                .map((e) => int.tryParse(e.trim()))
                .where((e) => e != null)
                .cast<int>()
                .toList();
          }

          // Insert Guru
          await SupabaseService.client.from('guru').insert({
            'name': name,
            'email': email,
            'no_telp': telp,
            'unit_ids': unitIds ?? [],
            'kategori_id': 1, // Default Kategori (e.g. Guru)
          });
          successCount++;
        }
      } else {
        // Expected columns: name, nis, email, no_telp, nama_wali, unit_id, kelas_id, kategori_id
        final int nameIdx = _headers.indexWhere((h) => h.toLowerCase() == 'name');
        final int nisIdx = _headers.indexWhere((h) => h.toLowerCase() == 'nis');
        final int emailIdx = _headers.indexWhere((h) => h.toLowerCase() == 'email');
        final int telpIdx = _headers.indexWhere((h) => h.toLowerCase() == 'no_telp');
        final int waliIdx = _headers.indexWhere((h) => h.toLowerCase() == 'nama_wali');
        final int unitIdx = _headers.indexWhere((h) => h.toLowerCase() == 'unit_id');
        final int kelasIdx = _headers.indexWhere((h) => h.toLowerCase() == 'kelas_id');
        final int katIdx = _headers.indexWhere((h) => h.toLowerCase() == 'kategori_id');

        if (nameIdx == -1 || unitIdx == -1 || kelasIdx == -1) {
          throw Exception('Kolom "name", "unit_id", dan "kelas_id" wajib ada di header.');
        }

        for (var row in _rows) {
          if (row.length <= nameIdx || row[nameIdx].isEmpty) continue;
          
          final String name = row[nameIdx];
          final String? nis = nisIdx != -1 && row.length > nisIdx && row[nisIdx].isNotEmpty ? row[nisIdx] : null;
          final String? email = emailIdx != -1 && row.length > emailIdx && row[emailIdx].isNotEmpty ? row[emailIdx] : null;
          final String? telp = telpIdx != -1 && row.length > telpIdx && row[telpIdx].isNotEmpty ? row[telpIdx] : null;
          final String? wali = waliIdx != -1 && row.length > waliIdx && row[waliIdx].isNotEmpty ? row[waliIdx] : null;
          final int? unitId = unitIdx != -1 && row.length > unitIdx ? int.tryParse(row[unitIdx]) : null;
          final int? kelasId = kelasIdx != -1 && row.length > kelasIdx ? int.tryParse(row[kelasIdx]) : null;
          final int? katId = katIdx != -1 && row.length > katIdx ? int.tryParse(row[katIdx]) : 1;

          if (unitId == null || kelasId == null) {
            errorCount++;
            continue;
          }

          // Insert Siswa
          await SupabaseService.client.from('siswa').insert({
            'name': name,
            'nis': nis,
            'email': email,
            'no_telp': telp,
            'nama_wali': wali,
            'unit_id': unitId,
            'kelas_id': kelasId,
            'kategori_id': katId ?? 1,
          });
          successCount++;
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Bulk Upload Selesai'),
            content: Text(
              'Berhasil mengunggah $successCount data.\n'
              'Gagal mengunggah $errorCount data.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(_);
                  _clearData();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Bulk upload failed: $e');
      errorMessage = e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal melakukan bulk upload: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildInstructions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_uploadType == 'guru') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.blueGrey.shade900 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.blueGrey.shade800 : Colors.blue.shade200),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Format CSV Guru:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              'Header: name,email,no_telp,unit_ids\n'
              '• unit_ids diisi ID Unit dipisahkan titik koma (;)\n'
              'Contoh:\n'
              'name,email,no_telp,unit_ids\n'
              'Ustadz Rasyid,rasyid@gmq.org,081234567,1;2',
              style: TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.blueGrey.shade900 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.blueGrey.shade800 : Colors.blue.shade200),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Format CSV Siswa/Santri:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              'Header: name,nis,email,no_telp,nama_wali,unit_id,kelas_id,kategori_id\n'
              '• Kolom name, unit_id, dan kelas_id wajib diisi.\n'
              'Contoh:\n'
              'name,nis,email,no_telp,nama_wali,unit_id,kelas_id,kategori_id\n'
              'Fulan,9988,fulan@gmq.org,089999,Pak Fulan,1,2,1',
              style: TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Upload Data'),
        backgroundColor: isDark ? null : Colors.teal,
        foregroundColor: isDark ? null : Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Data Guru'),
            Tab(icon: Icon(Icons.people), text: 'Data Siswa'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Sedang mengunggah data ke database...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInstructions(),
                  const SizedBox(height: 16),
                  
                  // Text field paste input
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tempel CSV Data di bawah ini:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Pilih File CSV'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  TextField(
                    controller: _textController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Tempel baris CSV di sini (termasuk header)\n'
                          'Contoh:\n'
                          'name,email,no_telp\n'
                          'Budi,budi@gmq.org,0812345',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _processRawText,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Preview Section
                  if (_headers.isNotEmpty) ...[
                    const Text(
                      'Preview Data:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                      constraints: const BoxConstraints(maxHeight: 300),
                      width: double.infinity,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            columns: _headers.map((h) => DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                            rows: _rows.map((row) {
                              return DataRow(
                                cells: _headers.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final val = idx < row.length ? row[idx] : '';
                                  return DataCell(Text(val));
                                }).toList(),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _uploadData,
                        icon: const Icon(Icons.cloud_upload),
                        label: Text('UNGGAH ${_rows.length} BARIS DATA'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
