class PatientLookup {
  final String id;
  final String mrn;
  final String firstName;
  final String lastName;
  final String? phonePrimary;
  final String? gender;
  final DateTime? dateOfBirth;

  const PatientLookup({
    required this.id,
    required this.mrn,
    required this.firstName,
    required this.lastName,
    this.phonePrimary,
    this.gender,
    this.dateOfBirth,
  });

  factory PatientLookup.fromJson(Map<String, dynamic> json) {
    return PatientLookup(
      id: json['id'] as String? ?? '',
      mrn: json['mrn'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      phonePrimary: json['phonePrimary'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'] as String)
          : null,
    );
  }

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.trim().isNotEmpty ? firstName.trim()[0].toUpperCase() : '';
    final l = lastName.trim().isNotEmpty ? lastName.trim()[0].toUpperCase() : '';
    return f.isNotEmpty || l.isNotEmpty ? '$f$l' : '?';
  }
}
