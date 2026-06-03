class SiswaModel {
  final int id;
  final String? nis;
  final String name;
  final String? email;
  final String? noTelp;
  final String? namaWali;
  final int unitId;
  final int kelasId;
  final int kategoriId;
  final DateTime createdAt;
  
  SiswaModel({
    required this.id,
    this.nis,
    required this.name,
    this.email,
    this.noTelp,
    this.namaWali,
    required this.unitId,
    required this.kelasId,
    required this.kategoriId,
    required this.createdAt,
  });
  
  factory SiswaModel.fromJson(Map<String, dynamic> json) {
    return SiswaModel(
      id: json['id'],
      nis: json['nis'],
      name: json['name'] ?? '',
      email: json['email'],
      noTelp: json['no_telp'],
      namaWali: json['nama_wali'],
      unitId: json['unit_id'] ?? 0,
      kelasId: json['kelas_id'] ?? 0,
      kategoriId: json['kategori_id'] ?? 0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'nis': nis,
      'name': name,
      'email': email,
      'no_telp': noTelp,
      'nama_wali': namaWali,
      'unit_id': unitId,
      'kelas_id': kelasId,
      'kategori_id': kategoriId,
    };
  }
}
