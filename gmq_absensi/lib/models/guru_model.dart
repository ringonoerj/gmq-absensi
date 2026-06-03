class GuruModel {
  final int id;
  final String? nip;
  final String name;
  final String? email;
  final String? noTelp;
  final int unitId;
  final int kategoriId;
  final DateTime createdAt;
  
  GuruModel({
    required this.id,
    this.nip,
    required this.name,
    this.email,
    this.noTelp,
    required this.unitId,
    required this.kategoriId,
    required this.createdAt,
  });
  
  factory GuruModel.fromJson(Map<String, dynamic> json) {
    return GuruModel(
      id: json['id'],
      nip: json['nip'],
      name: json['name'] ?? '',
      email: json['email'],
      noTelp: json['no_telp'],
      unitId: json['unit_id'] ?? 0,
      kategoriId: json['kategori_id'] ?? 0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'nip': nip,
      'name': name,
      'email': email,
      'no_telp': noTelp,
      'unit_id': unitId,
      'kategori_id': kategoriId,
    };
  }
}
