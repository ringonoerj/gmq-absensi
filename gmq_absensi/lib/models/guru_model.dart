class GuruModel {
  final int id;
  final String? nip;
  final String name;
  final String? email;
  final String? noTelp;
  final List<int> unitIds;
  final List<int> kelasIds;
  final int kategoriId;
  final DateTime createdAt;
  
  // Backward compatibility getter
  int get unitId => unitIds.isNotEmpty ? unitIds.first : 0;
  
  GuruModel({
    required this.id,
    this.nip,
    required this.name,
    this.email,
    this.noTelp,
    required this.unitIds,
    required this.kelasIds,
    required this.kategoriId,
    required this.createdAt,
  });
  
  factory GuruModel.fromJson(Map<String, dynamic> json) {
    // Handle list of unit ids
    List<int> parsedUnitIds = [];
    if (json['unit_ids'] != null) {
      parsedUnitIds = List<int>.from(json['unit_ids']);
    } else if (json['unit_id'] != null) {
      parsedUnitIds = [json['unit_id'] as int];
    }

    // Handle list of class ids
    List<int> parsedKelasIds = [];
    if (json['kelas_ids'] != null) {
      parsedKelasIds = List<int>.from(json['kelas_ids']);
    }
    
    return GuruModel(
      id: json['id'],
      nip: json['nip'],
      name: json['name'] ?? '',
      email: json['email'],
      noTelp: json['no_telp'],
      unitIds: parsedUnitIds,
      kelasIds: parsedKelasIds,
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
      'unit_ids': unitIds,
      'kelas_ids': kelasIds,
      'kategori_id': kategoriId,
      // Fallback for database integrity if single unit_id column has NOT NULL constraint
      'unit_id': unitIds.isNotEmpty ? unitIds.first : null,
    };
  }
}

