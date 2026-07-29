import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import '../services/supabase_service.dart';
import '../models/unit_model.dart';
import '../models/kelas_model.dart';
import '../utils/bytes_saver_stub.dart'
    if (dart.library.html) '../utils/bytes_saver_web.dart'
    if (dart.library.io) '../utils/bytes_saver_io.dart';

class ExportHelper {
  Future<void> exportLaporan(
    BuildContext context, {
    required String reportType,
    int? userId,
    required DateTime month,
    int? unitId,
    int? kelasId,
  }) async {
    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Build query
      var query = SupabaseService.client
          .from('absensi')
          .select()
          .gte('date', DateTime(month.year, month.month, 1).toIso8601String().split('T').first)
          .lte('date', DateTime(month.year, month.month + 1, 0).toIso8601String().split('T').first);
      
      if (userId != null) {
        query = query.eq('user_id', userId).eq('user_type', reportType);
      }
      if (unitId != null) {
        query = query.eq('unit_id', unitId);
      }
      if (kelasId != null && kelasId != 0) {
        query = query.eq('kelas_id', kelasId);
      }
      
      final absensiData = await query;
      final absensiList = absensiData as List;
      
      // Bulk fetch user names to avoid N+1 query performance problems
      final Map<int, String> guruNames = {};
      final Map<int, String> siswaNames = {};
      
      final guruIds = absensiList
          .where((e) => e['user_type'] == 'guru')
          .map<int>((e) => e['user_id'] as int)
          .toSet()
          .toList();
          
      final siswaIds = absensiList
          .where((e) => e['user_type'] == 'siswa')
          .map<int>((e) => e['user_id'] as int)
          .toSet()
          .toList();
      
      if (guruIds.isNotEmpty) {
        final gurus = await SupabaseService.client
            .from('guru')
            .select('id, name')
            .inFilter('id', guruIds);
        for (var g in (gurus as List)) {
          guruNames[g['id'] as int] = g['name'] as String;
        }
      }
      
      if (siswaIds.isNotEmpty) {
        final siswas = await SupabaseService.client
            .from('siswa')
            .select('id, name')
            .inFilter('id', siswaIds);
        for (var s in (siswas as List)) {
          siswaNames[s['id'] as int] = s['name'] as String;
        }
      }
      
      // Construct data
      List<Map<String, dynamic>> dataWithNames = [];
      for (var item in absensiList) {
        final uId = item['user_id'] as int;
        final uType = item['user_type'] as String;
        final name = (uType == 'guru' ? guruNames[uId] : siswaNames[uId]) ?? '-';
        
        dataWithNames.add({
          'name': name,
          'date': item['date'],
          'status': item['status'],
          'reason': item['izin_reason'] ?? '-',
        });
      }
      
      // Create Excel
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Laporan Absensi'];
      
      // Header
      sheetObject.appendRow([
        'No',
        'Nama',
        'Tanggal',
        'Status',
        'Alasan Izin',
      ]);
      
      // Data rows
      int no = 1;
      for (var item in dataWithNames) {
        sheetObject.appendRow([
          no++,
          item['name']?.toString() ?? '',
          item['date']?.toString() ?? '',
          item['status']?.toString() ?? '',
          item['reason']?.toString() ?? '',
        ]);
      }
      
      // Auto-fit columns manually for excel package v2.x
      for (var columnIndex = 0; columnIndex < sheetObject.maxCols; columnIndex++) {
        int maxLength = 0;
        for (var rowIndex = 0; rowIndex < sheetObject.maxRows; rowIndex++) {
          var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex));
          String val = cell.value?.toString() ?? "";
          if (val.length > maxLength) {
            maxLength = val.length;
          }
        }
        sheetObject.setColWidth(columnIndex, (maxLength + 3).toDouble());
      }
      
      // Save file platform-independently
      final fileName = 'laporan_absensi_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final bytes = excel.encode();
      if (bytes != null) {
        await saveBytesFile(fileName, bytes);
      } else {
        throw Exception('Gagal mengencode data Excel');
      }
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Laporan berhasil diexport: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error export: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> exportLaporanInsentif(
    BuildContext context, {
    required DateTime month,
    required List<Map<String, dynamic>> processedData,
  }) async {
    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Laporan Insentif Guru'];
      
      // Title
      sheetObject.appendRow([
        'LAPORAN INSENTIF GURU - BULAN ${month.month}/${month.year}'
      ]);
      sheetObject.appendRow([]); // empty row
      
      // Header
      sheetObject.appendRow([
        'Unit Pendidikan',
        'Nama Guru',
        'Jumlah Kehadiran',
        'Insentif per Hari (Rp)',
        'Total Insentif (Rp)'
      ]);
      
      for (var unitData in processedData) {
        final String unitName = unitData['unit_name'];
        final teachers = unitData['teachers'] as List;
        
        for (var t in teachers) {
          sheetObject.appendRow([
            unitName,
            t['guru_name'],
            t['hadir_count'],
            t['rate'],
            t['total_incentive']
          ]);
        }
      }
      
      // Auto-fit columns
      for (var columnIndex = 0; columnIndex < sheetObject.maxCols; columnIndex++) {
        int maxLength = 0;
        for (var rowIndex = 0; rowIndex < sheetObject.maxRows; rowIndex++) {
          var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex));
          String val = cell.value?.toString() ?? "";
          if (val.length > maxLength) {
            maxLength = val.length;
          }
        }
        sheetObject.setColWidth(columnIndex, (maxLength + 3).toDouble());
      }
      
      final fileName = 'laporan_insentif_guru_${month.year}_${month.month}.xlsx';
      final bytes = excel.encode();
      if (bytes != null) {
        await saveBytesFile(fileName, bytes);
      } else {
        throw Exception('Gagal mengencode data Excel');
      }
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Laporan insentif berhasil diexport: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal export insentif: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> exportKelas(
    BuildContext context, {
    required List<Map<String, dynamic>> data,
    required List<UnitModel> unitList,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Data Kelas'];

      sheetObject.appendRow([
        'No',
        'Nama Kelas',
        'Unit Pendidikan',
        'Tingkat',
        'Jurusan',
      ]);

      int no = 1;
      for (var item in data) {
        final unit = unitList.firstWhere(
          (u) => u.id == item['unit_id'],
          orElse: () => UnitModel(id: 0, name: '-', createdAt: DateTime.now()),
        );
        sheetObject.appendRow([
          no++,
          item['name']?.toString() ?? '',
          unit.name,
          item['tingkat']?.toString() ?? '-',
          item['jurusan']?.toString() ?? '-',
        ]);
      }

      // Auto-fit columns
      for (var columnIndex = 0; columnIndex < sheetObject.maxCols; columnIndex++) {
        int maxLength = 0;
        for (var rowIndex = 0; rowIndex < sheetObject.maxRows; rowIndex++) {
          var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex));
          String val = cell.value?.toString() ?? "";
          if (val.length > maxLength) {
            maxLength = val.length;
          }
        }
        sheetObject.setColWidth(columnIndex, (maxLength + 3).toDouble());
      }

      final fileName = 'data_kelas_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final bytes = excel.encode();
      if (bytes != null) {
        await saveBytesFile(fileName, bytes);
      } else {
        throw Exception('Gagal mengencode data Excel');
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data kelas berhasil diexport: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal export data kelas: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> exportGuru(
    BuildContext context, {
    required List<Map<String, dynamic>> data,
    required List<UnitModel> unitList,
    required List<KelasModel> kelasList,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Data Guru'];

      sheetObject.appendRow([
        'No',
        'Nama Guru',
        'NIP',
        'Email',
        'No. Telepon',
        'Unit Pendidikan',
        'Kelas Terkait',
      ]);

      int no = 1;
      for (var item in data) {
        final List<int> uIds = [];
        if (item['unit_ids'] != null) {
          uIds.addAll(List<int>.from(item['unit_ids']));
        } else if (item['unit_id'] != null) {
          uIds.add(item['unit_id'] as int);
        }

        final unitNames = uIds.map((uid) {
          return unitList.firstWhere(
            (u) => u.id == uid,
            orElse: () => UnitModel(id: 0, name: '-', createdAt: DateTime.now()),
          ).name;
        }).join(', ');

        final List<int> kIds = [];
        if (item['kelas_ids'] != null) {
          kIds.addAll(List<int>.from(item['kelas_ids']));
        }

        final kelasNames = kIds.isNotEmpty
            ? kIds.map((kid) {
                return kelasList.firstWhere(
                  (c) => c.id == kid,
                  orElse: () => KelasModel(id: 0, name: '-', unitId: 0, createdAt: DateTime.now()),
                ).name;
              }).join(', ')
            : '-';

        sheetObject.appendRow([
          no++,
          item['name']?.toString() ?? '',
          item['nip']?.toString() ?? '-',
          item['email']?.toString() ?? '-',
          item['no_telp']?.toString() ?? '-',
          unitNames,
          kelasNames,
        ]);
      }

      // Auto-fit columns
      for (var columnIndex = 0; columnIndex < sheetObject.maxCols; columnIndex++) {
        int maxLength = 0;
        for (var rowIndex = 0; rowIndex < sheetObject.maxRows; rowIndex++) {
          var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex));
          String val = cell.value?.toString() ?? "";
          if (val.length > maxLength) {
            maxLength = val.length;
          }
        }
        sheetObject.setColWidth(columnIndex, (maxLength + 3).toDouble());
      }

      final fileName = 'data_guru_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final bytes = excel.encode();
      if (bytes != null) {
        await saveBytesFile(fileName, bytes);
      } else {
        throw Exception('Gagal mengencode data Excel');
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data guru berhasil diexport: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal export data guru: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> exportSiswa(
    BuildContext context, {
    required List<Map<String, dynamic>> data,
    required List<UnitModel> unitList,
    required List<KelasModel> kelasList,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Data Siswa'];

      sheetObject.appendRow([
        'No',
        'Nama Siswa',
        'NIS',
        'Wali Siswa/Santri',
        'Email',
        'No. Telepon',
        'Unit Pendidikan',
        'Kelas',
      ]);

      int no = 1;
      for (var item in data) {
        final unit = unitList.firstWhere(
          (u) => u.id == item['unit_id'],
          orElse: () => UnitModel(id: 0, name: '-', createdAt: DateTime.now()),
        );
        final kelas = kelasList.firstWhere(
          (k) => k.id == item['kelas_id'],
          orElse: () => KelasModel(id: 0, name: '-', unitId: 0, createdAt: DateTime.now()),
        );
        sheetObject.appendRow([
          no++,
          item['name']?.toString() ?? '',
          item['nis']?.toString() ?? '-',
          item['nama_wali']?.toString() ?? '-',
          item['email']?.toString() ?? '-',
          item['no_telp']?.toString() ?? '-',
          unit.name,
          kelas.name,
        ]);
      }

      // Auto-fit columns
      for (var columnIndex = 0; columnIndex < sheetObject.maxCols; columnIndex++) {
        int maxLength = 0;
        for (var rowIndex = 0; rowIndex < sheetObject.maxRows; rowIndex++) {
          var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex));
          String val = cell.value?.toString() ?? "";
          if (val.length > maxLength) {
            maxLength = val.length;
          }
        }
        sheetObject.setColWidth(columnIndex, (maxLength + 3).toDouble());
      }

      final fileName = 'data_siswa_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final bytes = excel.encode();
      if (bytes != null) {
        await saveBytesFile(fileName, bytes);
      } else {
        throw Exception('Gagal mengencode data Excel');
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data siswa berhasil diexport: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal export data siswa: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> exportUser(
    BuildContext context, {
    required List<Map<String, dynamic>> data,
    required List<UnitModel> unitList,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Data User'];

      sheetObject.appendRow([
        'No',
        'Nama Lengkap',
        'Email',
        'Role',
        'Unit Pendidikan',
        'Status',
      ]);

      int no = 1;
      for (var item in data) {
        final unit = unitList.firstWhere(
          (u) => u.id == item['unit_id'],
          orElse: () => UnitModel(id: 0, name: 'Semua Unit', createdAt: DateTime.now()),
        );
        final isActiveStr = (item['is_active'] ?? true) ? 'Aktif' : 'Tidak Aktif';
        sheetObject.appendRow([
          no++,
          item['name']?.toString() ?? '',
          item['email']?.toString() ?? '',
          item['role']?.toString() ?? 'operator',
          unit.name,
          isActiveStr,
        ]);
      }

      // Auto-fit columns
      for (var columnIndex = 0; columnIndex < sheetObject.maxCols; columnIndex++) {
        int maxLength = 0;
        for (var rowIndex = 0; rowIndex < sheetObject.maxRows; rowIndex++) {
          var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex));
          String val = cell.value?.toString() ?? "";
          if (val.length > maxLength) {
            maxLength = val.length;
          }
        }
        sheetObject.setColWidth(columnIndex, (maxLength + 3).toDouble());
      }

      final fileName = 'data_user_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final bytes = excel.encode();
      if (bytes != null) {
        await saveBytesFile(fileName, bytes);
      } else {
        throw Exception('Gagal mengencode data Excel');
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data user berhasil diexport: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal export data user: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
