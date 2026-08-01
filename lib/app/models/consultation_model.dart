import 'doctor_model.dart';

class ConsultationPatient {
  final String id;
  final String mrn;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? phonePrimary;
  final String gender;
  final DateTime? dateOfBirth;
  final String? bloodGroup;

  const ConsultationPatient({
    required this.id,
    required this.mrn,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.phonePrimary,
    required this.gender,
    this.dateOfBirth,
    this.bloodGroup,
  });

  factory ConsultationPatient.fromJson(Map<String, dynamic> json) {
    return ConsultationPatient(
      id: json['id'] as String? ?? '',
      mrn: json['mrn'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      middleName: json['middleName'] as String?,
      lastName: json['lastName'] as String? ?? '',
      phonePrimary: json['phonePrimary'] as String?,
      gender: json['gender'] as String? ?? 'unknown',
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'] as String)
          : null,
      bloodGroup: json['bloodGroup'] as String?,
    );
  }

  String get fullName {
    final parts = [
      firstName,
      if (middleName != null && middleName!.isNotEmpty) middleName,
      lastName
    ];
    return parts.join(' ').trim();
  }
}

class ConsultationModel {
  final String id;
  final String organizationId;
  final String patientId;
  final String? appointmentId;
  final String doctorId;
  final DateTime visitDate;
  final String visitType;
  final double? temperature;
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final int? pulseRate;
  final int? respiratoryRate;
  final double? weight;
  final double? height;
  final int? oxygenSaturation;
  final String chiefComplaint;
  final String? historyOfPresentIllness;
  final String? physicalExamination;
  final String? diagnosis;
  final String? icd10Codes;
  final String? treatmentPlan;
  final String? followUpInstructions;
  final DateTime? followUpDate;
  final String? referredTo;
  final String? referralReason;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final ConsultationPatient patient;
  final DoctorModel doctor;

  const ConsultationModel({
    required this.id,
    required this.organizationId,
    required this.patientId,
    this.appointmentId,
    required this.doctorId,
    required this.visitDate,
    required this.visitType,
    this.temperature,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.pulseRate,
    this.respiratoryRate,
    this.weight,
    this.height,
    this.oxygenSaturation,
    required this.chiefComplaint,
    this.historyOfPresentIllness,
    this.physicalExamination,
    this.diagnosis,
    this.icd10Codes,
    this.treatmentPlan,
    this.followUpInstructions,
    this.followUpDate,
    this.referredTo,
    this.referralReason,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
    required this.patient,
    required this.doctor,
  });

  factory ConsultationModel.fromJson(Map<String, dynamic> json) {
    return ConsultationModel(
      id: json['id'] as String? ?? '',
      organizationId: json['organizationId'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      appointmentId: json['appointmentId'] as String?,
      doctorId: json['doctorId'] as String? ?? '',
      visitDate: DateTime.tryParse(json['visitDate'] as String? ?? '') ?? DateTime.now(),
      visitType: json['visitType'] as String? ?? 'outpatient',
      temperature: (json['temperature'] as num?)?.toDouble(),
      bloodPressureSystolic: (json['bloodPressureSystolic'] as num?)?.toInt(),
      bloodPressureDiastolic: (json['bloodPressureDiastolic'] as num?)?.toInt(),
      pulseRate: (json['pulseRate'] as num?)?.toInt(),
      respiratoryRate: (json['respiratoryRate'] as num?)?.toInt(),
      weight: (json['weight'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      oxygenSaturation: (json['oxygenSaturation'] as num?)?.toInt(),
      chiefComplaint: json['chiefComplaint'] as String? ?? '',
      historyOfPresentIllness: json['historyOfPresentIllness'] as String?,
      physicalExamination: json['physicalExamination'] as String?,
      diagnosis: json['diagnosis'] as String?,
      icd10Codes: json['icd10Codes'] as String?,
      treatmentPlan: json['treatmentPlan'] as String?,
      followUpInstructions: json['followUpInstructions'] as String?,
      followUpDate: json['followUpDate'] != null
          ? DateTime.tryParse(json['followUpDate'] as String)
          : null,
      referredTo: json['referredTo'] as String?,
      referralReason: json['referralReason'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      isDeleted: json['isDeleted'] as bool? ?? false,
      patient: ConsultationPatient.fromJson(
          (json['patient'] as Map<String, dynamic>?) ?? {}),
      doctor: DoctorModel.fromJson(
          (json['doctor'] as Map<String, dynamic>?) ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationId': organizationId,
      'patientId': patientId,
      'appointmentId': appointmentId,
      'doctorId': doctorId,
      'visitDate': visitDate.toIso8601String(),
      'visitType': visitType,
      'temperature': temperature,
      'bloodPressureSystolic': bloodPressureSystolic,
      'bloodPressureDiastolic': bloodPressureDiastolic,
      'pulseRate': pulseRate,
      'respiratoryRate': respiratoryRate,
      'weight': weight,
      'height': height,
      'oxygenSaturation': oxygenSaturation,
      'chiefComplaint': chiefComplaint,
      'historyOfPresentIllness': historyOfPresentIllness,
      'physicalExamination': physicalExamination,
      'diagnosis': diagnosis,
      'icd10Codes': icd10Codes,
      'treatmentPlan': treatmentPlan,
      'followUpInstructions': followUpInstructions,
      'followUpDate': followUpDate?.toIso8601String(),
      'referredTo': referredTo,
      'referralReason': referralReason,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }
}
