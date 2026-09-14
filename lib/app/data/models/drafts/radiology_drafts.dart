
import 'draft_json.dart';

/// An imaging catalogue entry being added or edited.
///
/// DTO: `hms_v2/src/modules/radiology/dto/radiology-exam.dto.ts`
/// (`CreateRadiologyExamDto`, and `UpdateRadiologyExamDto extends
/// PartialType(Create)` adding `isActive`).
class RadiologyExamDraft {
  const RadiologyExamDraft({
    this.examName,
    this.examCode,
    this.examCategory,
    this.bodyPart,
    this.modality,
    this.price,
    this.estimatedDuration,
    this.preparationInstructions,
    this.contrastRequired,
    this.description,
    this.isActive,
  });

  final String? examName;
  final String? examCode;

  /// `x-ray`, `ct`, `mri`, `ultrasound`, `mammography`.
  final String? examCategory;
  final String? bodyPart;

  /// The DICOM code — `CR`, `DR`, `CT`, `MRI`, `US`, `MG`.
  final String? modality;
  final double? price;

  /// Minutes on the machine, which is what a scheduler books against.
  final int? estimatedDuration;
  final String? preparationInstructions;

  /// Drives the consent and renal-function prompts on the order form, so it is
  /// a fact about the exam rather than a note on it.
  final bool? contrastRequired;
  final String? description;

  /// Update only.
  final bool? isActive;

  RadiologyExamDraft copyWith({
    String? examName,
    String? examCode,
    String? examCategory,
    String? bodyPart,
    String? modality,
    double? price,
    int? estimatedDuration,
    String? preparationInstructions,
    bool? contrastRequired,
    String? description,
    bool? isActive,
  }) =>
      RadiologyExamDraft(
        examName: examName ?? this.examName,
        examCode: examCode ?? this.examCode,
        examCategory: examCategory ?? this.examCategory,
        bodyPart: bodyPart ?? this.bodyPart,
        modality: modality ?? this.modality,
        price: price ?? this.price,
        estimatedDuration: estimatedDuration ?? this.estimatedDuration,
        preparationInstructions: preparationInstructions ?? this.preparationInstructions,
        contrastRequired: contrastRequired ?? this.contrastRequired,
        description: description ?? this.description,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> _shared() => {
        'examName': examName,
        'examCode': examCode,
        'examCategory': examCategory,
        'bodyPart': bodyPart,
        'modality': modality,
        'price': price,
        'estimatedDuration': estimatedDuration,
        'preparationInstructions': preparationInstructions,
        'contrastRequired': contrastRequired,
        'description': description,
      };

  Map<String, dynamic> toCreateJson() => draftBody(_shared());

  Map<String, dynamic> toUpdateJson() => draftBody({
        ..._shared(),
        'isActive': isActive,
      });
}

/// An imaging request, or an order being moved along.
///
/// DTO: `hms_v2/src/modules/radiology/dto/radiology-order.dto.ts`.
/// `UpdateRadiologyOrderDto extends PartialType(CreateRadiologyOrderDto)`, so
/// the update route also accepts every create key — including `patientId` and
/// `examId`. Not offered here: re-pointing an order at another patient is a
/// mistake with a report attached to it, and the app should cancel and re-order
/// instead.
///
/// The update DTO also accepts `performedById`, `reportedById` and
/// `verifiedById`. Left out on purpose — the server stamps those from the
/// bearer token, and a client that sends its own attributes a study to whoever
/// the form last had selected.
class RadiologyOrderDraft {
  const RadiologyOrderDraft({
    this.patientId,
    this.consultationId,
    this.examId,
    this.clinicalIndication,
    this.provisionalDiagnosis,
    this.relevantHistory,
    this.urgency,
    this.notes,
    this.status,
    this.scheduledDate,
    this.examPerformedAt,
    this.cancellationReason,
  });

  /// Create only, here.
  final String? patientId;

  /// Create only, here.
  final String? consultationId;

  /// Create only, here.
  final String? examId;
  final String? clinicalIndication;
  final String? provisionalDiagnosis;
  final String? relevantHistory;

  /// `routine`, `urgent`, `stat`. Imaging spells this `urgency`; the lab spells
  /// the same ladder `priority`. Kept as each backend names it, because a
  /// harmonised name is a 400.
  final String? urgency;
  final String? notes;

  /// Update only. `pending`, `scheduled`, `in_progress`, `completed`,
  /// `reported`, `cancelled`.
  final String? status;

  /// Update only.
  final DateTime? scheduledDate;

  /// Update only.
  final DateTime? examPerformedAt;

  /// Update only.
  final String? cancellationReason;

  RadiologyOrderDraft copyWith({
    String? patientId,
    String? consultationId,
    String? examId,
    String? clinicalIndication,
    String? provisionalDiagnosis,
    String? relevantHistory,
    String? urgency,
    String? notes,
    String? status,
    DateTime? scheduledDate,
    DateTime? examPerformedAt,
    String? cancellationReason,
  }) =>
      RadiologyOrderDraft(
        patientId: patientId ?? this.patientId,
        consultationId: consultationId ?? this.consultationId,
        examId: examId ?? this.examId,
        clinicalIndication: clinicalIndication ?? this.clinicalIndication,
        provisionalDiagnosis: provisionalDiagnosis ?? this.provisionalDiagnosis,
        relevantHistory: relevantHistory ?? this.relevantHistory,
        urgency: urgency ?? this.urgency,
        notes: notes ?? this.notes,
        status: status ?? this.status,
        scheduledDate: scheduledDate ?? this.scheduledDate,
        examPerformedAt: examPerformedAt ?? this.examPerformedAt,
        cancellationReason: cancellationReason ?? this.cancellationReason,
      );

  Map<String, dynamic> _shared() => {
        'clinicalIndication': clinicalIndication,
        'provisionalDiagnosis': provisionalDiagnosis,
        'relevantHistory': relevantHistory,
        'urgency': urgency,
        'notes': notes,
      };

  Map<String, dynamic> toCreateJson() => draftBody({
        'patientId': patientId,
        'consultationId': consultationId,
        'examId': examId,
        ..._shared(),
      });

  Map<String, dynamic> toUpdateJson() => draftBody({
        ..._shared(),
        'status': status,
        'scheduledDate': isoInstant(scheduledDate),
        'examPerformedAt': isoInstant(examPerformedAt),
        'cancellationReason': cancellationReason,
      });
}

/// A radiologist's read, in draft or being amended.
///
/// DTO: `hms_v2/src/modules/radiology/dto/radiology-report.dto.ts`.
/// `UpdateRadiologyReportDto extends PartialType(CreateRadiologyReportDto)` and
/// adds the reporting and amendment fields.
///
/// `reportedById`, `verifiedById` and `amendedById` are on the update DTO and
/// are not offered here: the server stamps them from the bearer token, and a
/// signature a client can choose is not a signature.
class RadiologyReportDraft {
  const RadiologyReportDraft({
    this.orderId,
    this.technique,
    this.findings,
    this.impression,
    this.recommendations,
    this.hasCriticalFindings,
    this.criticalFindings,
    this.comparedWithPrevious,
    this.comparisonNotes,
    this.criticalNotifiedTo,
    this.criticalNotifiedAt,
    this.status,
    this.amendmentReason,
  });

  /// Create only, here.
  final String? orderId;
  final String? technique;
  final String? findings;

  /// The one paragraph a referring clinician reads.
  final String? impression;
  final String? recommendations;
  final bool? hasCriticalFindings;
  final String? criticalFindings;
  final bool? comparedWithPrevious;
  final String? comparisonNotes;

  /// Update only. Who was told.
  final String? criticalNotifiedTo;

  /// Update only. When. A critical finding with no notification time is the
  /// state a ward escalates from, so the pair is written together.
  final DateTime? criticalNotifiedAt;

  /// Update only. `draft`, `final`, `amended`.
  final String? status;

  /// Update only.
  final String? amendmentReason;

  RadiologyReportDraft copyWith({
    String? orderId,
    String? technique,
    String? findings,
    String? impression,
    String? recommendations,
    bool? hasCriticalFindings,
    String? criticalFindings,
    bool? comparedWithPrevious,
    String? comparisonNotes,
    String? criticalNotifiedTo,
    DateTime? criticalNotifiedAt,
    String? status,
    String? amendmentReason,
  }) =>
      RadiologyReportDraft(
        orderId: orderId ?? this.orderId,
        technique: technique ?? this.technique,
        findings: findings ?? this.findings,
        impression: impression ?? this.impression,
        recommendations: recommendations ?? this.recommendations,
        hasCriticalFindings: hasCriticalFindings ?? this.hasCriticalFindings,
        criticalFindings: criticalFindings ?? this.criticalFindings,
        comparedWithPrevious: comparedWithPrevious ?? this.comparedWithPrevious,
        comparisonNotes: comparisonNotes ?? this.comparisonNotes,
        criticalNotifiedTo: criticalNotifiedTo ?? this.criticalNotifiedTo,
        criticalNotifiedAt: criticalNotifiedAt ?? this.criticalNotifiedAt,
        status: status ?? this.status,
        amendmentReason: amendmentReason ?? this.amendmentReason,
      );

  Map<String, dynamic> _shared() => {
        'technique': technique,
        'findings': findings,
        'impression': impression,
        'recommendations': recommendations,
        'hasCriticalFindings': hasCriticalFindings,
        'criticalFindings': criticalFindings,
        'comparedWithPrevious': comparedWithPrevious,
        'comparisonNotes': comparisonNotes,
      };

  Map<String, dynamic> toCreateJson() => draftBody({
        'orderId': orderId,
        ..._shared(),
      });

  Map<String, dynamic> toUpdateJson() => draftBody({
        ..._shared(),
        'criticalNotifiedTo': criticalNotifiedTo,
        'criticalNotifiedAt': isoInstant(criticalNotifiedAt),
        'status': status,
        'amendmentReason': amendmentReason,
      });
}
