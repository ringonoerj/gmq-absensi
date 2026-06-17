import 'package:flutter/material.dart';

class AbsensiModel {
  final int? id;
  final String userType;
  final int userId;
  final DateTime date;
  final String status;
  final String? izinReason;
  final String? recordedBy;
  final DateTime createdAt;
  final int? unitId;
  final int? kelasId;
  
  AbsensiModel({
    this.id,
    required this.userType,
    required this.userId,
    required this.date,
    required this.status,
    this.izinReason,
    this.recordedBy,
    required this.createdAt,
    this.unitId,
    this.kelasId,
  });
  
  factory AbsensiModel.fromJson(Map<String, dynamic> json) {
    return AbsensiModel(
      id: json['id'],
      userType: json['user_type'] ?? 'student',
      userId: json['user_id'] ?? 0,
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      status: json['status'] ?? 'alpha',
      izinReason: json['izin_reason'],
      recordedBy: json['recorded_by'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      unitId: json['unit_id'],
      kelasId: json['kelas_id'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'user_type': userType,
      'user_id': userId,
      'date': date.toIso8601String().split('T').first,
      'status': status,
      'izin_reason': izinReason,
      'recorded_by': recordedBy,
      'unit_id': unitId,
      'kelas_id': kelasId,
    };
  }
  
  bool get isHadir => status == 'hadir';
  bool get isIzin => status == 'izin';
  bool get isSakit => status == 'sakit';
  bool get isAlpha => status == 'alpha';
  
  Color get statusColor {
    switch (status) {
      case 'hadir': return Colors.green;
      case 'izin': return Colors.orange;
      case 'sakit': return Colors.blue;
      default: return Colors.red;
    }
  }
}
