import '../utils/formatters.dart';
import 'json.dart';

/// The patient, as every other record refers to one.
///
/// An appointment, a queue ticket, an admission and a consultation each arrive
/// with the same nested patient block, and each used to declare its own class
/// for it. Two of them were even called the same thing — `AppointmentPatient`
/// existed twice, in `appointment_model.dart` and in `dashboard_model.dart`,
/// with different fields, so which one a file got depended on which it had
/// imported and the two could not be passed to the same widget.
///
/// One shape, read defensively: a route that populates only an id and an MRN
/// produces the same object as one that populates everything, with the absent
/// fields null rather than invented.
class PatientRef {
  const PatientRef({
    this.id = '',
    this.mrn = '',
    this.firstName = '',
    this.lastName = '',
    this.phonePrimary,
    this.gender,
    this.dateOfBirth,
  });

  final String id;

  /// The medical record number. The identifier staff say out loud, and the one
  /// a row falls back to when a site has patient names switched off.
  final String mrn;

  final String firstName;
  final String lastName;
  final String? phonePrimary;
  final String? gender;

  /// Null when the route did not send one — **not** today's date. A missing
  /// date of birth that defaults to now makes every unknown patient a neonate,
  /// and a neonate is the one age at which a weight-based dose is checked
  /// against the number on the screen.
  final DateTime? dateOfBirth;

  static const PatientRef empty = PatientRef();

  bool get isEmpty => id.isEmpty && mrn.isEmpty;

  String get fullName => '$firstName $lastName'.trim();

  /// What a row shows when there is no name to show — never a blank line,
  /// because a blank line reads as a rendering fault rather than as a patient
  /// registered without one.
  String get displayName => fullName.isEmpty ? 'Patient $mrn'.trim() : fullName;

  /// Two letters at most. Three is a monogram, and a monogram in a 34 dp
  /// circle is a smudge.
  String get initials {
    final f =
        firstName.trim().isNotEmpty ? firstName.trim()[0].toUpperCase() : '';
    final l = lastName.trim().isNotEmpty ? lastName.trim()[0].toUpperCase() : '';
    return f.isEmpty && l.isEmpty ? '?' : '$f$l';
  }

  /// The age in the unit a clinician would say it in — `42y`, `7mo`, `4d`, and
  /// `—` when there is no date of birth.
  ///
  /// Through `Formatters`, which reads `AppClock`: age arithmetic done inline
  /// against `DateTime.now()` cannot be captured in a golden, and it was done
  /// three different ways in three models.
  String get age => Formatters.age(dateOfBirth);

  factory PatientRef.fromJson(Map<String, dynamic> json) => PatientRef(
        id: asString(json['id'] ?? json['_id']),
        mrn: asString(json['mrn']),
        firstName: asString(json['firstName']),
        lastName: asString(json['lastName']),
        phonePrimary: asStringOrNull(json['phonePrimary'] ?? json['phone']),
        gender: asStringOrNull(json['gender']),
        dateOfBirth: asDate(json['dateOfBirth']),
      );

  /// A patient block that may be absent altogether — a queue entry whose
  /// patient was deleted, a route that did not populate it.
  factory PatientRef.of(dynamic value) =>
      value is Map ? PatientRef.fromJson(value.cast<String, dynamic>()) : empty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'mrn': mrn,
        'firstName': firstName,
        'lastName': lastName,
        'phonePrimary': ?phonePrimary,
        'gender': ?gender,
        'dateOfBirth': ?dateOfBirth?.toIso8601String(),
      };
}
