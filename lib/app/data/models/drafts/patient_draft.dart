import '../patient.dart';
import 'draft_json.dart';

/// A patient registration or edit, in flight.
///
/// DTO: `hms_v2/src/modules/patients/dto/create-patient.dto.ts` and
/// `update-patient.dto.ts` (`UpdatePatientDto extends PartialType(Create)` and
/// adds `isActive`).
///
/// `insuranceCoverageDetails` is stored and returned by the backend but is on
/// neither write DTO, so it is deliberately absent here: a form that collects
/// it would 400 the whole registration.
class PatientDraft {
  const PatientDraft({
    this.firstName,
    this.middleName,
    this.lastName,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.phonePrimary,
    this.phoneSecondary,
    this.email,
    this.region,
    this.zone,
    this.woreda,
    this.kebele,
    this.houseNumber,
    this.addressDescription,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactRelationship,
    this.allergies,
    this.chronicConditions,
    this.currentMedications,
    this.hasInsurance,
    this.insuranceProvider,
    this.insuranceId,
    this.insuranceExpiryDate,
    this.photoUrl,
    this.maritalStatus,
    this.occupation,
    this.educationLevel,
    this.isVip,
    this.notes,
    this.externalId,
    this.isActive,
  });

  final String? firstName;
  final String? middleName;
  final String? lastName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final String? phonePrimary;
  final String? phoneSecondary;
  final String? email;
  final String? region;
  final String? zone;
  final String? woreda;
  final String? kebele;
  final String? houseNumber;
  final String? addressDescription;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactRelationship;

  /// Sent as an array of strings, which is what the DTO validates. The column
  /// behind it holds JSON text, so a read comes back as a string — the
  /// asymmetry is the backend's, not this app's.
  final List<String>? allergies;
  final List<String>? chronicConditions;
  final List<String>? currentMedications;

  final bool? hasInsurance;
  final String? insuranceProvider;
  final String? insuranceId;
  final DateTime? insuranceExpiryDate;
  final String? photoUrl;
  final String? maritalStatus;
  final String? occupation;
  final String? educationLevel;
  final bool? isVip;
  final String? notes;
  final String? externalId;

  /// Update only. Deactivating a patient is not a delete, and the create route
  /// has no such key.
  final bool? isActive;

  /// Pre-fills an edit from the record being edited.
  factory PatientDraft.of(Patient patient) => PatientDraft(
        firstName: patient.firstName,
        middleName: patient.middleName,
        lastName: patient.lastName,
        dateOfBirth: patient.dateOfBirth,
        gender: patient.gender,
        bloodGroup: patient.bloodGroup,
        phonePrimary: patient.phonePrimary,
        phoneSecondary: patient.phoneSecondary,
        email: patient.email,
        region: patient.region,
        zone: patient.zone,
        woreda: patient.woreda,
        kebele: patient.kebele,
        houseNumber: patient.houseNumber,
        addressDescription: patient.addressDescription,
        emergencyContactName: patient.emergencyContactName,
        emergencyContactPhone: patient.emergencyContactPhone,
        emergencyContactRelationship: patient.emergencyContactRelationship,
        allergies: patient.allergies,
        chronicConditions: patient.chronicConditions,
        currentMedications: patient.currentMedications,
        hasInsurance: patient.hasInsurance,
        insuranceProvider: patient.insuranceProvider,
        insuranceId: patient.insuranceId,
        insuranceExpiryDate: patient.insuranceExpiryDate,
        photoUrl: patient.photoUrl,
        maritalStatus: patient.maritalStatus,
        occupation: patient.occupation,
        educationLevel: patient.educationLevel,
        isVip: patient.isVip,
        notes: patient.notes,
        externalId: patient.externalId,
        isActive: patient.isActive,
      );

  PatientDraft copyWith({
    String? firstName,
    String? middleName,
    String? lastName,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    String? phonePrimary,
    String? phoneSecondary,
    String? email,
    String? region,
    String? zone,
    String? woreda,
    String? kebele,
    String? houseNumber,
    String? addressDescription,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelationship,
    List<String>? allergies,
    List<String>? chronicConditions,
    List<String>? currentMedications,
    bool? hasInsurance,
    String? insuranceProvider,
    String? insuranceId,
    DateTime? insuranceExpiryDate,
    String? photoUrl,
    String? maritalStatus,
    String? occupation,
    String? educationLevel,
    bool? isVip,
    String? notes,
    String? externalId,
    bool? isActive,
  }) =>
      PatientDraft(
        firstName: firstName ?? this.firstName,
        middleName: middleName ?? this.middleName,
        lastName: lastName ?? this.lastName,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        gender: gender ?? this.gender,
        bloodGroup: bloodGroup ?? this.bloodGroup,
        phonePrimary: phonePrimary ?? this.phonePrimary,
        phoneSecondary: phoneSecondary ?? this.phoneSecondary,
        email: email ?? this.email,
        region: region ?? this.region,
        zone: zone ?? this.zone,
        woreda: woreda ?? this.woreda,
        kebele: kebele ?? this.kebele,
        houseNumber: houseNumber ?? this.houseNumber,
        addressDescription: addressDescription ?? this.addressDescription,
        emergencyContactName: emergencyContactName ?? this.emergencyContactName,
        emergencyContactPhone:
            emergencyContactPhone ?? this.emergencyContactPhone,
        emergencyContactRelationship:
            emergencyContactRelationship ?? this.emergencyContactRelationship,
        allergies: allergies ?? this.allergies,
        chronicConditions: chronicConditions ?? this.chronicConditions,
        currentMedications: currentMedications ?? this.currentMedications,
        hasInsurance: hasInsurance ?? this.hasInsurance,
        insuranceProvider: insuranceProvider ?? this.insuranceProvider,
        insuranceId: insuranceId ?? this.insuranceId,
        insuranceExpiryDate: insuranceExpiryDate ?? this.insuranceExpiryDate,
        photoUrl: photoUrl ?? this.photoUrl,
        maritalStatus: maritalStatus ?? this.maritalStatus,
        occupation: occupation ?? this.occupation,
        educationLevel: educationLevel ?? this.educationLevel,
        isVip: isVip ?? this.isVip,
        notes: notes ?? this.notes,
        externalId: externalId ?? this.externalId,
        isActive: isActive ?? this.isActive,
      );

  /// The fields both routes share. Listed once so a key added to the DTO is
  /// added here once rather than in two lists that drift apart.
  Map<String, dynamic> _shared() => {
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'dateOfBirth': isoDay(dateOfBirth),
        'gender': gender,
        'bloodGroup': bloodGroup,
        'phonePrimary': phonePrimary,
        'phoneSecondary': phoneSecondary,
        'email': email,
        'region': region,
        'zone': zone,
        'woreda': woreda,
        'kebele': kebele,
        'houseNumber': houseNumber,
        'addressDescription': addressDescription,
        'emergencyContactName': emergencyContactName,
        'emergencyContactPhone': emergencyContactPhone,
        'emergencyContactRelationship': emergencyContactRelationship,
        'allergies': allergies,
        'chronicConditions': chronicConditions,
        'currentMedications': currentMedications,
        'hasInsurance': hasInsurance,
        'insuranceProvider': insuranceProvider,
        'insuranceId': insuranceId,
        'insuranceExpiryDate': isoDay(insuranceExpiryDate),
        'photoUrl': photoUrl,
        'maritalStatus': maritalStatus,
        'occupation': occupation,
        'educationLevel': educationLevel,
        'isVip': isVip,
        'notes': notes,
        'externalId': externalId,
      };

  Map<String, dynamic> toCreateJson() => draftBody(_shared());

  Map<String, dynamic> toUpdateJson() => draftBody({
        ..._shared(),
        'isActive': isActive,
      });
}
