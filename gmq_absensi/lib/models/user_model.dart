class UserModel {
  final String id;
  final String email;
  final String name;
  final String role;
  final int? unitId;
  final bool isActive;
  final DateTime createdAt;
  
  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.unitId,
    required this.isActive,
    required this.createdAt,
  });
  
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'operator',
      unitId: json['unit_id'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'unit_id': unitId,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  bool get isSuperadmin => role == 'superadmin';
  bool get isOperator => role == 'operator';
  bool get isSupervisor => role == 'supervisor';
}
