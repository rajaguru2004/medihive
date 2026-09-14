
import 'draft_json.dart';

/// One drug written during a consultation.
///
/// DTO: `CreatePrescriptionItemDto` in
/// `hms_v2/src/modules/consultations/dto/create-consultation.dto.ts`.
///
/// Not the same shape as the pharmacy's `PrescriptionItemDto`: this one
/// **requires** `dosage`, `frequency`, `duration` and `quantity` and accepts
/// `genericName`; the pharmacy's makes the first three optional and has no
/// `genericName` at all. Two classes rather than one, because sharing them
/// would send a key one of the two routes rejects.
class ConsultationPrescriptionItemDraft {
  const ConsultationPrescriptionItemDraft({
    this.drugId,
    this.drugName,
    this.genericName,
    this.dosage,
    this.frequency,
    this.duration,
    this.quantity,
    this.instructions,
  });

  final String? drugId;
  final String? drugName;
  final String? genericName;
  final String? dosage;
  final String? frequency;
  final String? duration;

  /// Total units to dispense. The DTO requires at least 1.
  final int? quantity;
  final String? instructions;

  ConsultationPrescriptionItemDraft copyWith({
    String? drugId,
    String? drugName,
    String? genericName,
    String? dosage,
    String? frequency,
    String? duration,
    int? quantity,
    String? instructions,
  }) =>
      ConsultationPrescriptionItemDraft(
        drugId: drugId ?? this.drugId,
        drugName: drugName ?? this.drugName,
        genericName: genericName ?? this.genericName,
        dosage: dosage ?? this.dosage,
        frequency: frequency ?? this.frequency,
        duration: duration ?? this.duration,
        quantity: quantity ?? this.quantity,
        instructions: instructions ?? this.instructions,
      );

  Map<String, dynamic> toJson() => draftBody({
        'drugId': drugId,
        'drugName': drugName,
        'genericName': genericName,
        'dosage': dosage,
        'frequency': frequency,
        'duration': duration,
        'quantity': quantity,
        'instructions': instructions,
      });
}

/// A consultation being written up.
///
/// DTO: `hms_v2/src/modules/consultations/dto/create-consultation.dto.ts` and
/// `update-consultation.dto.ts`.
///
/// The update DTO is a separate class rather than a `PartialType`, and it drops
/// four keys: `patientId`, `doctorId`, `appointmentId` and `prescriptionItems`.
/// A consultation cannot be re-pointed at another patient, and a prescription
/// added after the fact goes to the pharmacy route instead.
class ConsultationDraft {
  const ConsultationDraft({
    this.patientId,
    this.doctorId,
    this.appointmentId,
    this.visitType,
    this.temperature,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.pulseRate,
    this.respiratoryRate,
    this.weight,
    this.height,
    this.oxygenSaturation,
    this.chiefComplaint,
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
    this.prescriptionItems,
  });

  /// Create only.
  final String? patientId;

  /// Create only.
  final String? doctorId;

  /// Create only.
  final String? appointmentId;

  /// `outpatient`, `emergency`, `follow_up`. A category, not an acuity.
  final String? visitType;

  /// Celsius. Left null when unrecorded — this backend stores an unobserved
  /// vital as `0`, and a temperature of zero renders as hypothermia.
  final double? temperature;
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final int? pulseRate;
  final int? respiratoryRate;

  /// Kilograms.
  final double? weight;

  /// Centimetres.
  final double? height;
  final int? oxygenSaturation;
  final String? chiefComplaint;
  final String? historyOfPresentIllness;
  final String? physicalExamination;
  final String? diagnosis;

  /// Sent as an array, which is what the DTO validates. The column behind it
  /// holds JSON text, so a read comes back as a string.
  final List<String>? icd10Codes;
  final String? treatmentPlan;
  final String? followUpInstructions;
  final DateTime? followUpDate;
  final String? referredTo;
  final String? referralReason;
  final String? notes;

  /// Create only. Written in the same request as the consultation, so a script
  /// cannot be orphaned by a failure between two calls.
  final List<ConsultationPrescriptionItemDraft>? prescriptionItems;

  ConsultationDraft copyWith({
    String? patientId,
    String? doctorId,
    String? appointmentId,
    String? visitType,
    double? temperature,
    int? bloodPressureSystolic,
    int? bloodPressureDiastolic,
    int? pulseRate,
    int? respiratoryRate,
    double? weight,
    double? height,
    int? oxygenSaturation,
    String? chiefComplaint,
    String? historyOfPresentIllness,
    String? physicalExamination,
    String? diagnosis,
    List<String>? icd10Codes,
    String? treatmentPlan,
    String? followUpInstructions,
    DateTime? followUpDate,
    String? referredTo,
    String? referralReason,
    String? notes,
    List<ConsultationPrescriptionItemDraft>? prescriptionItems,
  }) =>
      ConsultationDraft(
        patientId: patientId ?? this.patientId,
        doctorId: doctorId ?? this.doctorId,
        appointmentId: appointmentId ?? this.appointmentId,
        visitType: visitType ?? this.visitType,
        temperature: temperature ?? this.temperature,
        bloodPressureSystolic: bloodPressureSystolic ?? this.bloodPressureSystolic,
        bloodPressureDiastolic: bloodPressureDiastolic ?? this.bloodPressureDiastolic,
        pulseRate: pulseRate ?? this.pulseRate,
        respiratoryRate: respiratoryRate ?? this.respiratoryRate,
        weight: weight ?? this.weight,
        height: height ?? this.height,
        oxygenSaturation: oxygenSaturation ?? this.oxygenSaturation,
        chiefComplaint: chiefComplaint ?? this.chiefComplaint,
        historyOfPresentIllness: historyOfPresentIllness ?? this.historyOfPresentIllness,
        physicalExamination: physicalExamination ?? this.physicalExamination,
        diagnosis: diagnosis ?? this.diagnosis,
        icd10Codes: icd10Codes ?? this.icd10Codes,
        treatmentPlan: treatmentPlan ?? this.treatmentPlan,
        followUpInstructions: followUpInstructions ?? this.followUpInstructions,
        followUpDate: followUpDate ?? this.followUpDate,
        referredTo: referredTo ?? this.referredTo,
        referralReason: referralReason ?? this.referralReason,
        notes: notes ?? this.notes,
        prescriptionItems: prescriptionItems ?? this.prescriptionItems,
      );

  /// The clinical body both routes accept.
  Map<String, dynamic> _shared() => {
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
        'followUpDate': isoDay(followUpDate),
        'referredTo': referredTo,
        'referralReason': referralReason,
        'notes': notes,
      };

  Map<String, dynamic> toCreateJson() => draftBody({
        'patientId': patientId,
        'doctorId': doctorId,
        'appointmentId': appointmentId,
        ..._shared(),
        'prescriptionItems':
            prescriptionItems?.map((item) => item.toJson()).toList(),
      });

  Map<String, dynamic> toUpdateJson() => draftBody(_shared());
}
