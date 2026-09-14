import '../utils/formatters.dart';
import 'json.dart';
import 'patient_ref.dart';

/// The whole patient record, as `GET /api/patients/:id` answers it.
///
/// [PatientRef] is the shape every *other* record embeds — an appointment, a
/// queue ticket, a lab order. This is the record itself: the same identity
/// fields plus the address, the insurance and the three medical lists nothing
/// else carries. [ref] converts one to the other, so a detail screen can hand
/// a `PatientIdentityBand` the same object a queue row gives it.
///
/// `PatientLookup` in `patient_lookup.dart` is field-for-field a subset of
/// [PatientRef] and could be `typedef PatientLookup = PatientRef;` — the two
/// declare the same seven members, and `PatientRef` reads them more
/// defensively. Not changed here because the search controllers that construct
/// it are another stream's files.
class Patient {
  const Patient({
    this.id = '',
    this.organizationId = '',
    this.mrn = '',
    this.externalId,
    this.firstName = '',
    this.middleName,
    this.lastName = '',
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
    this.allergies = const [],
    this.chronicConditions = const [],
    this.currentMedications = const [],
    this.hasInsurance = false,
    this.insuranceProvider,
    this.insuranceId,
    this.insuranceExpiryDate,
    this.insuranceCoverageDetails,
    this.photoUrl,
    this.maritalStatus,
    this.occupation,
    this.educationLevel,
    this.isActive = true,
    this.isVip = false,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String organizationId;

  /// The medical record number — the identifier staff say out loud.
  final String mrn;

  /// The id this patient carries in whatever system fed them in.
  final String? externalId;

  final String firstName;
  final String? middleName;
  final String lastName;

  /// Null when the record has none. **Never today's date**: a missing date of
  /// birth that defaults to now makes every unknown patient a neonate, and a
  /// neonate is the one age at which a weight-based dose is checked against
  /// the number on the screen.
  final DateTime? dateOfBirth;

  final String? gender;
  final String? bloodGroup;

  final String? phonePrimary;
  final String? phoneSecondary;
  final String? email;

  // Ethiopian address hierarchy, widest first.
  final String? region;
  final String? zone;
  final String? woreda;
  final String? kebele;
  final String? houseNumber;
  final String? addressDescription;

  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactRelationship;

  /// Stored by the backend as a JSON array inside a text column, so it arrives
  /// as a string on some routes and as an array on others. Both read here.
  final List<String> allergies;
  final List<String> chronicConditions;
  final List<String> currentMedications;

  final bool hasInsurance;
  final String? insuranceProvider;
  final String? insuranceId;
  final DateTime? insuranceExpiryDate;

  /// Read-only from this app: the create and update DTOs have no such key, so
  /// sending one is a 400.
  final String? insuranceCoverageDetails;

  final String? photoUrl;
  final String? maritalStatus;
  final String? occupation;
  final String? educationLevel;

  final bool isActive;
  final bool isVip;
  final String? notes;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const Patient empty = Patient();

  bool get isEmpty => id.isEmpty && mrn.isEmpty;

  String get fullName =>
      [firstName, middleName ?? '', lastName].where((p) => p.isNotEmpty).join(' ');

  /// What a row shows when there is no name to show — never a blank line,
  /// because a blank line reads as a rendering fault rather than as a patient
  /// registered without one.
  String get displayName => fullName.isEmpty ? 'Patient $mrn'.trim() : fullName;

  String get initials => ref.initials;

  /// `42y`, `7mo`, `4d`, and `—` when there is no date of birth.
  String get age => Formatters.age(dateOfBirth);

  /// The address as one line, widest unit last, skipping the parts a site does
  /// not collect.
  String get addressLine => [
        houseNumber,
        kebele,
        woreda,
        zone,
        region,
      ].whereType<String>().where((p) => p.isNotEmpty).join(', ');

  /// Whether this patient has anything a prescriber must check against.
  bool get hasAllergies => allergies.isNotEmpty;

  /// Whether the cover on file has run out. Null expiry is "no date recorded",
  /// which is not the same as expired and must not render as a warning.
  bool insuranceExpired({DateTime? asOf}) {
    final expiry = insuranceExpiryDate;
    if (!hasInsurance || expiry == null) return false;
    return expiry.isBefore(asOf ?? DateTime.now());
  }

  /// This patient in the shape every other record embeds one.
  PatientRef get ref => PatientRef(
        id: id,
        mrn: mrn,
        firstName: firstName,
        lastName: lastName,
        phonePrimary: phonePrimary,
        gender: gender,
        dateOfBirth: dateOfBirth,
      );

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
        id: asString(json['id'] ?? json['_id']),
        organizationId: asString(json['organizationId']),
        mrn: asString(json['mrn']),
        externalId: asStringOrNull(json['externalId']),
        firstName: asString(json['firstName']),
        middleName: asStringOrNull(json['middleName']),
        lastName: asString(json['lastName']),
        dateOfBirth: asDate(json['dateOfBirth']),
        gender: asStringOrNull(json['gender']),
        bloodGroup: asStringOrNull(json['bloodGroup']),
        phonePrimary: asStringOrNull(json['phonePrimary'] ?? json['phone']),
        phoneSecondary: asStringOrNull(json['phoneSecondary']),
        email: asStringOrNull(json['email']),
        region: asStringOrNull(json['region']),
        zone: asStringOrNull(json['zone']),
        woreda: asStringOrNull(json['woreda']),
        kebele: asStringOrNull(json['kebele']),
        houseNumber: asStringOrNull(json['houseNumber']),
        addressDescription: asStringOrNull(json['addressDescription']),
        emergencyContactName: asStringOrNull(json['emergencyContactName']),
        emergencyContactPhone: asStringOrNull(json['emergencyContactPhone']),
        emergencyContactRelationship:
            asStringOrNull(json['emergencyContactRelationship']),
        allergies: asStringList(json['allergies']),
        chronicConditions: asStringList(json['chronicConditions']),
        currentMedications: asStringList(json['currentMedications']),
        hasInsurance: asBool(json['hasInsurance']),
        insuranceProvider: asStringOrNull(json['insuranceProvider']),
        insuranceId: asStringOrNull(json['insuranceId']),
        insuranceExpiryDate: asDate(json['insuranceExpiryDate']),
        insuranceCoverageDetails:
            asStringOrNull(json['insuranceCoverageDetails']),
        photoUrl: asStringOrNull(json['photoUrl']),
        maritalStatus: asStringOrNull(json['maritalStatus']),
        occupation: asStringOrNull(json['occupation']),
        educationLevel: asStringOrNull(json['educationLevel']),
        isActive: asBool(json['isActive'], fallback: true),
        isVip: asBool(json['isVip']),
        notes: asStringOrNull(json['notes']),
        createdAt: asDate(json['createdAt']),
        updatedAt: asDate(json['updatedAt']),
      );

  /// A patient block that may be absent altogether.
  factory Patient.of(dynamic value) =>
      value is Map ? Patient.fromJson(value.cast<String, dynamic>()) : empty;
}
