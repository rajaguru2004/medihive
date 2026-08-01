class DoctorModel {
  final String id;
  final String fullName;
  final String? email;
  final String? role;
  final String? specialization;

  const DoctorModel({
    required this.id,
    required this.fullName,
    this.email,
    this.role,
    this.specialization,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String?,
      role: json['role'] as String?,
      specialization: json['specialization'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      if (email != null) 'email': email,
      if (role != null) 'role': role,
      if (specialization != null) 'specialization': specialization,
    };
  }
}
