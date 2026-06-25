// lib/app/modules/inpatient/models/inpatient_models.dart

// ─── Stats ────────────────────────────────────────────────────────────────────

class InpatientStats {
  final int totalBeds;
  final int occupiedBeds;
  final int availableBeds;
  final int todayAdmissions;
  final int todayDischarges;
  final num occupancyRate;

  const InpatientStats({
    required this.totalBeds,
    required this.occupiedBeds,
    required this.availableBeds,
    required this.todayAdmissions,
    required this.todayDischarges,
    required this.occupancyRate,
  });

  factory InpatientStats.fromJson(Map<String, dynamic> j) => InpatientStats(
        totalBeds: j['totalBeds'] as int? ?? 0,
        occupiedBeds: j['occupiedBeds'] as int? ?? 0,
        availableBeds: j['availableBeds'] as int? ?? 0,
        todayAdmissions: j['todayAdmissions'] as int? ?? 0,
        todayDischarges: j['todayDischarges'] as int? ?? 0,
        occupancyRate: j['occupancyRate'] as num? ?? 0,
      );

  factory InpatientStats.empty() => const InpatientStats(
        totalBeds: 0,
        occupiedBeds: 0,
        availableBeds: 0,
        todayAdmissions: 0,
        todayDischarges: 0,
        occupancyRate: 0,
      );

  int get activePatientsCount => occupiedBeds;
}

// ─── Bed ──────────────────────────────────────────────────────────────────────

class BedModel {
  final String id;
  final String wardId;
  final String bedNumber;
  final String type;
  final String status;
  final String? currentPatientId;

  const BedModel({
    required this.id,
    required this.wardId,
    required this.bedNumber,
    required this.type,
    required this.status,
    this.currentPatientId,
  });

  factory BedModel.fromJson(Map<String, dynamic> j) => BedModel(
        id: j['id'] as String? ?? '',
        wardId: j['wardId'] as String? ?? '',
        bedNumber: j['bedNumber'] as String? ?? '',
        type: j['type'] as String? ?? '',
        status: j['status'] as String? ?? 'available',
        currentPatientId: j['currentPatientId'] as String?,
      );

  bool get isAvailable => status == 'available';
  bool get isOccupied => status == 'occupied';
  bool get isMaintenance => status == 'maintenance';

  String get displayType {
    switch (type.toLowerCase()) {
      case 'icu': return 'ICU';
      case 'electric': return 'Electric';
      case 'pediatric': return 'Pediatric';
      case 'standard': return 'Standard';
      default: return type.isNotEmpty
          ? '${type[0].toUpperCase()}${type.substring(1)}'
          : 'Standard';
    }
  }

  String get statusMessage {
    switch (status) {
      case 'available': return 'Available for use';
      case 'occupied': return 'Currently occupied';
      case 'maintenance': return 'Under maintenance';
      default: return status;
    }
  }
}

// ─── Ward ─────────────────────────────────────────────────────────────────────

class WardModel {
  final String id;
  final String name;
  final String code;
  final String type;
  final int capacity;
  final bool isActive;
  final List<BedModel> beds;
  final int occupiedBeds;
  final int availableBeds;
  final num occupancyRate;

  const WardModel({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.capacity,
    required this.isActive,
    required this.beds,
    required this.occupiedBeds,
    required this.availableBeds,
    required this.occupancyRate,
  });

  factory WardModel.fromJson(Map<String, dynamic> j) => WardModel(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        code: j['code'] as String? ?? '',
        type: j['type'] as String? ?? '',
        capacity: j['capacity'] as int? ?? 0,
        isActive: j['isActive'] as bool? ?? true,
        beds: (j['beds'] as List<dynamic>? ?? [])
            .map((b) => BedModel.fromJson(b as Map<String, dynamic>))
            .toList(),
        occupiedBeds: j['occupiedBeds'] as int? ?? 0,
        availableBeds: j['availableBeds'] as int? ?? 0,
        occupancyRate: j['occupancyRate'] as num? ?? 0,
      );

  String get displayType {
    switch (type.toLowerCase()) {
      case 'icu': return 'ICU';
      case 'general': return 'General';
      case 'pediatric': return 'Pediatric';
      case 'maternity': return 'Maternity';
      default: return type.isNotEmpty
          ? '${type[0].toUpperCase()}${type.substring(1)}'
          : 'General';
    }
  }

  List<BedModel> get availableBedsList =>
      beds.where((b) => b.isAvailable).toList();
}

// ─── Patient (minimal) ────────────────────────────────────────────────────────

class AdmissionPatient {
  final String id;
  final String mrn;
  final String firstName;
  final String lastName;
  final String gender;
  final DateTime? dateOfBirth;
  final String? phonePrimary;

  const AdmissionPatient({
    required this.id,
    required this.mrn,
    required this.firstName,
    required this.lastName,
    required this.gender,
    this.dateOfBirth,
    this.phonePrimary,
  });

  factory AdmissionPatient.fromJson(Map<String, dynamic> j) => AdmissionPatient(
        id: j['id'] as String? ?? '',
        mrn: j['mrn'] as String? ?? '',
        firstName: j['firstName'] as String? ?? '',
        lastName: j['lastName'] as String? ?? '',
        gender: j['gender'] as String? ?? '',
        dateOfBirth: j['dateOfBirth'] != null
            ? DateTime.tryParse(j['dateOfBirth'] as String)
            : null,
        phonePrimary: j['phonePrimary'] as String?,
      );

  String get fullName => '$firstName $lastName'.trim();
  String get displayMrn => mrn;
}

// ─── Admission Ward/Bed (nested) ──────────────────────────────────────────────

class AdmissionWard {
  final String id;
  final String name;
  final String code;
  final String type;

  const AdmissionWard({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
  });

  factory AdmissionWard.fromJson(Map<String, dynamic> j) => AdmissionWard(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        code: j['code'] as String? ?? '',
        type: j['type'] as String? ?? '',
      );
}

class AdmissionBed {
  final String id;
  final String bedNumber;
  final String type;
  final String status;
  final AdmissionWard? ward;

  const AdmissionBed({
    required this.id,
    required this.bedNumber,
    required this.type,
    required this.status,
    this.ward,
  });

  factory AdmissionBed.fromJson(Map<String, dynamic> j) => AdmissionBed(
        id: j['id'] as String? ?? '',
        bedNumber: j['bedNumber'] as String? ?? '',
        type: j['type'] as String? ?? '',
        status: j['status'] as String? ?? '',
        ward: j['ward'] != null
            ? AdmissionWard.fromJson(j['ward'] as Map<String, dynamic>)
            : null,
      );
}

// ─── Admission ────────────────────────────────────────────────────────────────

class AdmissionModel {
  final String id;
  final String patientId;
  final String bedId;
  final DateTime admissionDate;
  final String admissionType;
  final String admissionReason;
  final String? admittingDoctorId;
  final String? attendingDoctorId;
  final String status;
  final DateTime? dischargeDate;
  final AdmissionPatient patient;
  final AdmissionBed bed;

  const AdmissionModel({
    required this.id,
    required this.patientId,
    required this.bedId,
    required this.admissionDate,
    required this.admissionType,
    required this.admissionReason,
    this.admittingDoctorId,
    this.attendingDoctorId,
    required this.status,
    this.dischargeDate,
    required this.patient,
    required this.bed,
  });

  factory AdmissionModel.fromJson(Map<String, dynamic> j) => AdmissionModel(
        id: j['id'] as String? ?? '',
        patientId: j['patientId'] as String? ?? '',
        bedId: j['bedId'] as String? ?? '',
        admissionDate: DateTime.tryParse(j['admissionDate'] as String? ?? '') ??
            DateTime.now(),
        admissionType: j['admissionType'] as String? ?? '',
        admissionReason: j['admissionReason'] as String? ?? '',
        admittingDoctorId: j['admittingDoctorId'] as String?,
        attendingDoctorId: j['attendingDoctorId'] as String?,
        status: j['status'] as String? ?? 'admitted',
        dischargeDate: j['dischargeDate'] != null
            ? DateTime.tryParse(j['dischargeDate'] as String)
            : null,
        patient: AdmissionPatient.fromJson(
            j['patient'] as Map<String, dynamic>? ?? {}),
        bed: AdmissionBed.fromJson(
            j['bed'] as Map<String, dynamic>? ?? {}),
      );

  bool get isActive => status == 'admitted';
  bool get isDischarged => status == 'discharged';

  String get displayAdmissionType {
    switch (admissionType.toLowerCase()) {
      case 'emergency': return 'Emergency';
      case 'routine': return 'Routine';
      case 'ward_transfer': return 'Ward Transfer';
      default: return admissionType.isNotEmpty
          ? '${admissionType[0].toUpperCase()}${admissionType.substring(1)}'
          : 'Routine';
    }
  }

  String get wardAndBed {
    final ward = bed.ward;
    if (ward != null) return '${ward.name} - ${bed.bedNumber}';
    return 'Bed ${bed.bedNumber}';
  }
}

// ─── Doctor ───────────────────────────────────────────────────────────────────

class DoctorModel {
  final String id;
  final String fullName;
  final String email;
  final String? specialization;

  const DoctorModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.specialization,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> j) => DoctorModel(
        id: j['id'] as String? ?? '',
        fullName: j['fullName'] as String? ?? '',
        email: j['email'] as String? ?? '',
        specialization: j['specialization'] as String?,
      );

  String get displayName {
    if (specialization != null && specialization!.isNotEmpty) {
      return '$fullName ($specialization)';
    }
    return fullName;
  }
}

// ─── Patient (full list) ──────────────────────────────────────────────────────

class PatientModel {
  final String id;
  final String mrn;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String gender;
  final DateTime? dateOfBirth;
  final String? phonePrimary;
  final bool isActive;

  const PatientModel({
    required this.id,
    required this.mrn,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.gender,
    this.dateOfBirth,
    this.phonePrimary,
    required this.isActive,
  });

  factory PatientModel.fromJson(Map<String, dynamic> j) => PatientModel(
        id: j['id'] as String? ?? '',
        mrn: j['mrn'] as String? ?? '',
        firstName: j['firstName'] as String? ?? '',
        middleName: j['middleName'] as String?,
        lastName: j['lastName'] as String? ?? '',
        gender: j['gender'] as String? ?? '',
        dateOfBirth: j['dateOfBirth'] != null
            ? DateTime.tryParse(j['dateOfBirth'] as String)
            : null,
        phonePrimary: j['phonePrimary'] as String?,
        isActive: j['isActive'] as bool? ?? true,
      );

  String get fullName => '$firstName $lastName'.trim();
  String get displayLabel => '$fullName • $mrn';
}
