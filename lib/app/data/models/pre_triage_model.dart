class PreTriageModel {
  final String id;
  final String screeningId;
  final String firstName;
  final String? lastName;
  final int? age;
  final String? gender;
  final String? phone;
  final String chiefComplaint;
  final String? briefHistory;
  final double? temperature;
  final int? pulse;
  final int? bpSystolic;
  final int? bpDiastolic;
  final String? route;
  final String status; // "screening", "routed", "registered_as_patient"
  final String? mrn;
  final DateTime createdAt;

  const PreTriageModel({
    required this.id,
    required this.screeningId,
    required this.firstName,
    this.lastName,
    this.age,
    this.gender,
    this.phone,
    required this.chiefComplaint,
    this.briefHistory,
    this.temperature,
    this.pulse,
    this.bpSystolic,
    this.bpDiastolic,
    this.route,
    required this.status,
    this.mrn,
    required this.createdAt,
  });

  factory PreTriageModel.fromJson(Map<String, dynamic> json) {
    // The MRN, when the route populated the patient rather than sending an id.
    final patient = json['patient'];
    final parsedMrn =
        patient is Map ? patient['mrn'] as String? : null;

    return PreTriageModel(
      id: json['id'] as String? ?? '',
      screeningId: json['screeningNumber'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      phone: json['phone'] as String?,
      chiefComplaint: json['chiefComplaint'] as String? ?? '',
      briefHistory: json['briefHistory'] as String?,
      temperature: json['temperature'] != null
          ? (json['temperature'] as num).toDouble()
          : null,
      pulse: json['pulseRate'] as int?,
      bpSystolic: json['bloodPressureSystolic'] as int?,
      bpDiastolic: json['bloodPressureDiastolic'] as int?,
      route: json['routedTo'] as String?,
      status: json['status'] as String? ?? 'screening',
      mrn: parsedMrn,
      createdAt: json['screenedAt'] != null
          ? DateTime.tryParse(json['screenedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'screeningNumber': screeningId,
      'firstName': firstName,
      'lastName': lastName,
      'age': age,
      'gender': gender,
      'phone': phone,
      'chiefComplaint': chiefComplaint,
      'briefHistory': briefHistory,
      'temperature': temperature,
      'pulseRate': pulse,
      'bloodPressureSystolic': bpSystolic,
      'bloodPressureDiastolic': bpDiastolic,
      'routedTo': route,
      'status': status,
      'screenedAt': createdAt.toIso8601String(),
    };
  }

  String get fullName => '$firstName ${lastName ?? ""}'.trim();

  String get initials {
    final f =
        firstName.trim().isNotEmpty ? firstName.trim()[0].toUpperCase() : '';
    final l = lastName != null && lastName!.trim().isNotEmpty
        ? lastName!.trim()[0].toUpperCase()
        : '';
    return f.isNotEmpty || l.isNotEmpty ? '$f$l' : '?';
  }
}
