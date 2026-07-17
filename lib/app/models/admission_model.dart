import 'bed_model.dart';

class AdmissionPatient {
  final String id;
  final String mrn;
  final String firstName;
  final String lastName;
  final String gender;
  final DateTime? dateOfBirth;
  final String? phonePrimary;

  AdmissionPatient({
    required this.id,
    required this.mrn,
    required this.firstName,
    required this.lastName,
    required this.gender,
    this.dateOfBirth,
    this.phonePrimary,
  });

  factory AdmissionPatient.fromJson(Map<String, dynamic> json) =>
      AdmissionPatient(
        id: json['id'] as String? ?? '',
        mrn: json['mrn'] as String? ?? '',
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        gender: json['gender'] as String? ?? 'other',
        dateOfBirth: json['dateOfBirth'] != null
            ? DateTime.tryParse(json['dateOfBirth'] as String)
            : null,
        phonePrimary: json['phonePrimary'] as String?,
      );

  String get fullName => '$firstName $lastName'.trim();
}

class AdmissionModel {
  final String id;
  final String organizationId;
  final String patientId;
  final String bedId;
  final DateTime admissionDate;
  final String admissionType;
  final String admissionReason;
  final String? admittingDoctorId;
  final String? attendingDoctorId;
  final String status;
  final DateTime? dischargeDate;
  final String? dischargeReason;
  final String? dischargeSummary;
  final String? dischargeDoctorId;
  final AdmissionPatient patient;
  final BedModel bed;

  AdmissionModel({
    required this.id,
    required this.organizationId,
    required this.patientId,
    required this.bedId,
    required this.admissionDate,
    required this.admissionType,
    required this.admissionReason,
    this.admittingDoctorId,
    this.attendingDoctorId,
    required this.status,
    this.dischargeDate,
    this.dischargeReason,
    this.dischargeSummary,
    this.dischargeDoctorId,
    required this.patient,
    required this.bed,
  });

  factory AdmissionModel.fromJson(Map<String, dynamic> json) => AdmissionModel(
        id: json['id'] as String? ?? '',
        organizationId: json['organizationId'] as String? ?? '',
        patientId: json['patientId'] as String? ?? '',
        bedId: json['bedId'] as String? ?? '',
        admissionDate: DateTime.parse(json['admissionDate'] as String),
        admissionType: json['admissionType'] as String? ?? '',
        admissionReason: json['admissionReason'] as String? ?? '',
        admittingDoctorId: json['admittingDoctorId'] as String?,
        attendingDoctorId: json['attendingDoctorId'] as String?,
        status: json['status'] as String? ?? '',
        dischargeDate: json['dischargeDate'] != null
            ? DateTime.tryParse(json['dischargeDate'] as String)
            : null,
        dischargeReason: json['dischargeReason'] as String?,
        dischargeSummary: json['dischargeSummary'] as String?,
        dischargeDoctorId: json['dischargeDoctorId'] as String?,
        patient: AdmissionPatient.fromJson(
            json['patient'] as Map<String, dynamic>? ?? {}),
        bed: BedModel.fromJson(json['bed'] as Map<String, dynamic>? ?? {}),
      );
}
