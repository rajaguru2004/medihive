
import 'draft_json.dart';

/// A pre-triage screening — the Ethiopian workflow's first contact, taken
/// before a patient record exists.
///
/// DTO: `hms_v2/src/modules/pre-triage/dto/create-pre-triage.dto.ts` and
/// `update-pre-triage.dto.ts` (`UpdatePreTriageDto extends PartialType(Create)`
/// and adds `status` and `patientId`).
///
/// Every field is optional, including the name: somebody arriving unable to
/// give one is exactly the patient this screen exists for.
class ScreeningDraft {
  const ScreeningDraft({
    this.firstName,
    this.lastName,
    this.age,
    this.gender,
    this.phone,
    this.chiefComplaint,
    this.briefHistory,
    this.temperature,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.pulseRate,
    this.routedTo,
    this.status,
    this.patientId,
  });

  final String? firstName;
  final String? lastName;

  /// Years, 0 to 150. An age rather than a date of birth, because the person in
  /// front of the screener often does not know one.
  final int? age;
  final String? gender;
  final String? phone;
  final String? chiefComplaint;
  final String? briefHistory;

  /// Celsius. Null when unrecorded, never 0.
  final double? temperature;
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final int? pulseRate;

  /// Where the screener sent them — `adult_triage`, `maternity`.
  final String? routedTo;

  /// Update only. `screening`, `routed`, `registered_as_patient`.
  final String? status;

  /// Update only. Set when the screening becomes a registered patient.
  final String? patientId;

  ScreeningDraft copyWith({
    String? firstName,
    String? lastName,
    int? age,
    String? gender,
    String? phone,
    String? chiefComplaint,
    String? briefHistory,
    double? temperature,
    int? bloodPressureSystolic,
    int? bloodPressureDiastolic,
    int? pulseRate,
    String? routedTo,
    String? status,
    String? patientId,
  }) =>
      ScreeningDraft(
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        phone: phone ?? this.phone,
        chiefComplaint: chiefComplaint ?? this.chiefComplaint,
        briefHistory: briefHistory ?? this.briefHistory,
        temperature: temperature ?? this.temperature,
        bloodPressureSystolic: bloodPressureSystolic ?? this.bloodPressureSystolic,
        bloodPressureDiastolic: bloodPressureDiastolic ?? this.bloodPressureDiastolic,
        pulseRate: pulseRate ?? this.pulseRate,
        routedTo: routedTo ?? this.routedTo,
        status: status ?? this.status,
        patientId: patientId ?? this.patientId,
      );

  Map<String, dynamic> _shared() => {
        'firstName': firstName,
        'lastName': lastName,
        'age': age,
        'gender': gender,
        'phone': phone,
        'chiefComplaint': chiefComplaint,
        'briefHistory': briefHistory,
        'temperature': temperature,
        'bloodPressureSystolic': bloodPressureSystolic,
        'bloodPressureDiastolic': bloodPressureDiastolic,
        'pulseRate': pulseRate,
        'routedTo': routedTo,
      };

  Map<String, dynamic> toCreateJson() => draftBody(_shared());

  Map<String, dynamic> toUpdateJson() => draftBody({
        ..._shared(),
        'status': status,
        'patientId': patientId,
      });
}
