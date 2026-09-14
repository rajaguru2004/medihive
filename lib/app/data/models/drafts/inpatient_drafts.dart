
import 'draft_json.dart';

/// A patient being admitted, or an admission being corrected.
///
/// DTO: `hms_v2/src/modules/inpatient/dto/admission.dto.ts`
/// (`CreateAdmissionDto` / `UpdateAdmissionDto`).
///
/// The discharge half of `UpdateAdmissionDto` lives in [DischargeDraft]: the
/// two are different acts done by different people at different times, and a
/// single draft holding both invites a ward transfer that also sets a discharge
/// date.
class AdmissionDraft {
  const AdmissionDraft({
    this.patientId,
    this.bedId,
    this.admissionType,
    this.admissionReason,
    this.admittingDoctorId,
    this.attendingDoctorId,
    this.status,
  });

  final String? patientId;

  /// Optional: a patient can be admitted before a bed is free, which is the
  /// state a bed manager works from.
  final String? bedId;

  /// `emergency`, `elective`, `transfer`. The DTO also accepts the capitalised
  /// forms the web console posts. A category, not an acuity — `emergency` here
  /// means "came through the ED".
  final String? admissionType;
  final String? admissionReason;
  final String? admittingDoctorId;
  final String? attendingDoctorId;

  /// Update only. `admitted`, `discharged`, `transferred`.
  final String? status;

  AdmissionDraft copyWith({
    String? patientId,
    String? bedId,
    String? admissionType,
    String? admissionReason,
    String? admittingDoctorId,
    String? attendingDoctorId,
    String? status,
  }) =>
      AdmissionDraft(
        patientId: patientId ?? this.patientId,
        bedId: bedId ?? this.bedId,
        admissionType: admissionType ?? this.admissionType,
        admissionReason: admissionReason ?? this.admissionReason,
        admittingDoctorId: admittingDoctorId ?? this.admittingDoctorId,
        attendingDoctorId: attendingDoctorId ?? this.attendingDoctorId,
        status: status ?? this.status,
      );

  Map<String, dynamic> _shared() => {
        'patientId': patientId,
        'bedId': bedId,
        'admissionType': admissionType,
        'admissionReason': admissionReason,
        'admittingDoctorId': admittingDoctorId,
        'attendingDoctorId': attendingDoctorId,
      };

  Map<String, dynamic> toCreateJson() => draftBody(_shared());

  Map<String, dynamic> toUpdateJson() => draftBody({
        ..._shared(),
        'status': status,
      });
}

/// A discharge being recorded.
///
/// DTO: `UpdateAdmissionDto` in
/// `hms_v2/src/modules/inpatient/dto/admission.dto.ts`.
///
/// There is no discharge endpoint: a discharge is a PATCH on the admission, so
/// [toCreateJson] and [toUpdateJson] are the same body. Kept as two names
/// because every other draft has both, and a caller that has to remember which
/// one this class answers to is a caller that eventually picks wrong.
class DischargeDraft {
  const DischargeDraft({
    this.status,
    this.dischargeDate,
    this.dischargeReason,
    this.dischargeSummary,
    this.dischargeDoctorId,
    this.followUpDate,
    this.followUpNotes,
  });

  /// Usually `discharged`; `transferred` where the patient went to another
  /// facility.
  final String? status;

  /// An instant, in UTC. A discharge happens at a time, and a length of stay
  /// computed from a date alone is wrong by up to a day.
  final DateTime? dischargeDate;
  final String? dischargeReason;
  final String? dischargeSummary;
  final String? dischargeDoctorId;

  /// A calendar day: an outpatient appointment is booked on a date, not at an
  /// instant.
  final DateTime? followUpDate;
  final String? followUpNotes;

  DischargeDraft copyWith({
    String? status,
    DateTime? dischargeDate,
    String? dischargeReason,
    String? dischargeSummary,
    String? dischargeDoctorId,
    DateTime? followUpDate,
    String? followUpNotes,
  }) =>
      DischargeDraft(
        status: status ?? this.status,
        dischargeDate: dischargeDate ?? this.dischargeDate,
        dischargeReason: dischargeReason ?? this.dischargeReason,
        dischargeSummary: dischargeSummary ?? this.dischargeSummary,
        dischargeDoctorId: dischargeDoctorId ?? this.dischargeDoctorId,
        followUpDate: followUpDate ?? this.followUpDate,
        followUpNotes: followUpNotes ?? this.followUpNotes,
      );

  Map<String, dynamic> _body() => {
        'status': status,
        'dischargeDate': isoInstant(dischargeDate),
        'dischargeReason': dischargeReason,
        'dischargeSummary': dischargeSummary,
        'dischargeDoctorId': dischargeDoctorId,
        'followUpDate': isoDay(followUpDate),
        'followUpNotes': followUpNotes,
      };

  /// Identical to [toUpdateJson]: a discharge is always a PATCH.
  Map<String, dynamic> toCreateJson() => draftBody(_body());

  Map<String, dynamic> toUpdateJson() => draftBody(_body());
}

/// A ward being created or edited.
///
/// DTO: `hms_v2/src/modules/inpatient/dto/ward.dto.ts` (`CreateWardDto` /
/// `UpdateWardDto`, which adds `isActive`).
class WardDraft {
  const WardDraft({
    this.name,
    this.code,
    this.type,
    this.capacity,
    this.departmentId,
    this.isActive,
  });

  final String? name;
  final String? code;

  /// `general`, `icu`, `nicu`, `pediatric`, `maternity`. A ward type is a
  /// category, not a clinical state.
  final String? type;

  /// Beds. Zero is a value — a ward being stood up has none yet.
  final int? capacity;
  final String? departmentId;

  /// Update only.
  final bool? isActive;

  WardDraft copyWith({
    String? name,
    String? code,
    String? type,
    int? capacity,
    String? departmentId,
    bool? isActive,
  }) =>
      WardDraft(
        name: name ?? this.name,
        code: code ?? this.code,
        type: type ?? this.type,
        capacity: capacity ?? this.capacity,
        departmentId: departmentId ?? this.departmentId,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> _shared() => {
        'name': name,
        'code': code,
        'type': type,
        'capacity': capacity,
        'departmentId': departmentId,
      };

  Map<String, dynamic> toCreateJson() => draftBody(_shared());

  Map<String, dynamic> toUpdateJson() => draftBody({
        ..._shared(),
        'isActive': isActive,
      });
}

/// A bed being created, moved or re-stated.
///
/// DTO: `hms_v2/src/modules/inpatient/dto/bed.dto.ts` (`CreateBedDto` /
/// `UpdateBedDto`, which adds `currentPatientId`).
class BedDraft {
  const BedDraft({
    this.wardId,
    this.bedNumber,
    this.type,
    this.status,
    this.currentPatientId,
  });

  final String? wardId;
  final String? bedNumber;

  /// `standard`, `icu`, `special`. A bed type is a category.
  final String? type;

  /// `available`, `occupied`, `maintenance`, `reserved`. `reserved` is absent
  /// from the schema comment and accepted by the DTO; beds are already stored
  /// that way and both consoles render it.
  final String? status;

  /// Update only.
  final String? currentPatientId;

  BedDraft copyWith({
    String? wardId,
    String? bedNumber,
    String? type,
    String? status,
    String? currentPatientId,
  }) =>
      BedDraft(
        wardId: wardId ?? this.wardId,
        bedNumber: bedNumber ?? this.bedNumber,
        type: type ?? this.type,
        status: status ?? this.status,
        currentPatientId: currentPatientId ?? this.currentPatientId,
      );

  Map<String, dynamic> _shared() => {
        'wardId': wardId,
        'bedNumber': bedNumber,
        'type': type,
        'status': status,
      };

  Map<String, dynamic> toCreateJson() => draftBody(_shared());

  Map<String, dynamic> toUpdateJson() => draftBody({
        ..._shared(),
        'currentPatientId': currentPatientId,
      });
}
