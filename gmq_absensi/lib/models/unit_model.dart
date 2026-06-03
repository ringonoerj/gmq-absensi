class UnitModel {
  final int id;
  final String name;
  final String? alamat;
  final String? kontak;
  final String? logoUrl;
  final DateTime createdAt;
  
  UnitModel({
    required this.id,
    required this.name,
    this.alamat,
    this.kontak,
    this.logoUrl,
    required this.createdAt,
  });
  
  factory UnitModel.fromJson(Map<String, dynamic> json) {
    return UnitModel(
      id: json['id'],
      name: json['name'] ?? '',
      alamat: json['alamat'],
      kontak: json['kontak'],
      logoUrl: json['logo_url'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'alamat': alamat,
      'kontak': kontak,
      'logo_url': logoUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
