class KelasModel {
  final int id;
  final String name;
  final int unitId;
  final String? tingkat;
  final String? jurusan;
  final DateTime createdAt;
  
  KelasModel({
    required this.id,
    required this.name,
    required this.unitId,
    this.tingkat,
    this.jurusan,
    required this.createdAt,
  });
  
  factory KelasModel.fromJson(Map<String, dynamic> json) {
    return KelasModel(
      id: json['id'],
      name: json['name'] ?? '',
      unitId: json['unit_id'] ?? 0,
      tingkat: json['tingkat'],
      jurusan: json['jurusan'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unit_id': unitId,
      'tingkat': tingkat,
      'jurusan': jurusan,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
