
import 'draft_json.dart';

/// One test on a lab order.
///
/// DTO: `OrderTestItemDto` in `hms_v2/src/modules/laboratory/dto/lab-
/// order.dto.ts`.
///
/// Three keys and no more. The schema comment on `LabOrder.tests` documents a
/// stored `testCode` as well, but the DTO has no such field, so sending one
/// fails the whole order. Followed the DTO: a rejected order is a test nobody
/// runs.
class LabOrderTestDraft {
  const LabOrderTestDraft({
    this.testId,
    this.testName,
    this.urgency,
  });

  final String? testId;

  /// Denormalised on purpose, by the backend as well as here: a test later
  /// renamed in the catalogue must not rewrite what a clinician asked for.
  final String? testName;

  /// `routine`, `urgent`, `stat` — per test, above the order priority.
  final String? urgency;

  LabOrderTestDraft copyWith({
    String? testId,
    String? testName,
    String? urgency,
  }) =>
      LabOrderTestDraft(
        testId: testId ?? this.testId,
        testName: testName ?? this.testName,
        urgency: urgency ?? this.urgency,
      );

  Map<String, dynamic> toJson() => draftBody({
        'testId': testId,
        'testName': testName,
        'urgency': urgency,
      });
}

/// A lab request being written, or an order being worked.
///
/// DTO: `hms_v2/src/modules/laboratory/dto/lab-order.dto.ts`
/// (`CreateLabOrderDto` / `UpdateLabOrderDto`).
///
/// The two halves barely overlap: a create says who and what, an update says
/// where the sample got to. Only `priority` and `notes` are on both.
class LabOrderDraft {
  const LabOrderDraft({
    this.patientId,
    this.consultationId,
    this.tests,
    this.clinicalIndication,
    this.provisionalDiagnosis,
    this.priority,
    this.notes,
    this.status,
    this.sampleCollectedAt,
    this.sampleCollectedById,
    this.accessionNumber,
    this.rejectionReason,
  });

  /// Create only.
  final String? patientId;

  /// Create only.
  final String? consultationId;

  /// Create only. An empty list is dropped rather than sent: the DTO would
  /// accept `tests: []` and store an order with nothing on it.
  final List<LabOrderTestDraft>? tests;

  /// Create only.
  final String? clinicalIndication;

  /// Create only.
  final String? provisionalDiagnosis;

  /// `routine`, `urgent`, `stat`.
  final String? priority;
  final String? notes;

  /// Update only. `pending`, `sample_collected`, `in_progress`, `completed`,
  /// `cancelled`, `rejected`.
  final String? status;

  /// Update only. An instant, in UTC — a sample taken at 00:30 local belongs to
  /// the night it was taken on.
  final DateTime? sampleCollectedAt;

  /// Update only.
  final String? sampleCollectedById;

  /// Update only. The barcode the tube carries.
  final String? accessionNumber;

  /// Update only. Why a sample could not be run — haemolysed, insufficient,
  /// unlabelled.
  final String? rejectionReason;

  LabOrderDraft copyWith({
    String? patientId,
    String? consultationId,
    List<LabOrderTestDraft>? tests,
    String? clinicalIndication,
    String? provisionalDiagnosis,
    String? priority,
    String? notes,
    String? status,
    DateTime? sampleCollectedAt,
    String? sampleCollectedById,
    String? accessionNumber,
    String? rejectionReason,
  }) =>
      LabOrderDraft(
        patientId: patientId ?? this.patientId,
        consultationId: consultationId ?? this.consultationId,
        tests: tests ?? this.tests,
        clinicalIndication: clinicalIndication ?? this.clinicalIndication,
        provisionalDiagnosis: provisionalDiagnosis ?? this.provisionalDiagnosis,
        priority: priority ?? this.priority,
        notes: notes ?? this.notes,
        status: status ?? this.status,
        sampleCollectedAt: sampleCollectedAt ?? this.sampleCollectedAt,
        sampleCollectedById: sampleCollectedById ?? this.sampleCollectedById,
        accessionNumber: accessionNumber ?? this.accessionNumber,
        rejectionReason: rejectionReason ?? this.rejectionReason,
      );

  Map<String, dynamic> toCreateJson() => draftBody({
        'patientId': patientId,
        'consultationId': consultationId,
        'tests': tests?.map((test) => test.toJson()).toList(),
        'clinicalIndication': clinicalIndication,
        'provisionalDiagnosis': provisionalDiagnosis,
        'priority': priority,
        'notes': notes,
      });

  Map<String, dynamic> toUpdateJson() => draftBody({
        'status': status,
        'priority': priority,
        'sampleCollectedAt': isoInstant(sampleCollectedAt),
        'sampleCollectedById': sampleCollectedById,
        'accessionNumber': accessionNumber,
        'notes': notes,
        'rejectionReason': rejectionReason,
      });
}

/// A result being entered or verified.
///
/// DTO: `hms_v2/src/modules/laboratory/dto/lab-result.dto.ts`
/// (`CreateLabResultDto` / `UpdateLabResultDto`).
class LabResultDraft {
  const LabResultDraft({
    this.orderId,
    this.testId,
    this.resultValue,
    this.resultUnit,
    this.isAbnormal,
    this.isCritical,
    this.flag,
    this.comment,
    this.verifiedAt,
    this.verifiedById,
  });

  /// Create only.
  final String? orderId;

  /// Create only.
  final String? testId;

  /// Text, not a number: this column holds `7.2`, `Negative` and `>1000` alike.
  final String? resultValue;
  final String? resultUnit;
  final bool? isAbnormal;

  /// A result somebody has to be told about, rather than one a list refresh
  /// will eventually surface.
  final bool? isCritical;

  /// `H` high, `L` low, `N` normal, `A` abnormal. The DTO rejects anything
  /// else.
  final String? flag;
  final String? comment;

  /// Update only. When a second pair of eyes signed it off.
  final DateTime? verifiedAt;

  /// Update only.
  final String? verifiedById;

  LabResultDraft copyWith({
    String? orderId,
    String? testId,
    String? resultValue,
    String? resultUnit,
    bool? isAbnormal,
    bool? isCritical,
    String? flag,
    String? comment,
    DateTime? verifiedAt,
    String? verifiedById,
  }) =>
      LabResultDraft(
        orderId: orderId ?? this.orderId,
        testId: testId ?? this.testId,
        resultValue: resultValue ?? this.resultValue,
        resultUnit: resultUnit ?? this.resultUnit,
        isAbnormal: isAbnormal ?? this.isAbnormal,
        isCritical: isCritical ?? this.isCritical,
        flag: flag ?? this.flag,
        comment: comment ?? this.comment,
        verifiedAt: verifiedAt ?? this.verifiedAt,
        verifiedById: verifiedById ?? this.verifiedById,
      );

  Map<String, dynamic> _shared() => {
        'resultValue': resultValue,
        'resultUnit': resultUnit,
        'isAbnormal': isAbnormal,
        'isCritical': isCritical,
        'flag': flag,
        'comment': comment,
      };

  Map<String, dynamic> toCreateJson() => draftBody({
        'orderId': orderId,
        'testId': testId,
        ..._shared(),
      });

  Map<String, dynamic> toUpdateJson() => draftBody({
        ..._shared(),
        'verifiedAt': isoInstant(verifiedAt),
        'verifiedById': verifiedById,
      });
}

/// A catalogue entry being added or edited.
///
/// DTO: `hms_v2/src/modules/laboratory/dto/lab-test.dto.ts` (`CreateLabTestDto`
/// / `UpdateLabTestDto`, which adds `isActive`).
class LabTestDraft {
  const LabTestDraft({
    this.testName,
    this.testCode,
    this.testCategory,
    this.testType,
    this.specimenType,
    this.specimenVolume,
    this.specimenContainer,
    this.resultType,
    this.unit,
    this.referenceRanges,
    this.price,
    this.turnaroundTime,
    this.department,
    this.preparationInstructions,
    this.clinicalSignificance,
    this.isActive,
  });

  final String? testName;
  final String? testCode;

  /// `hematology`, `chemistry`, `microbiology`, `serology`.
  final String? testCategory;

  /// `quantitative` or `qualitative`.
  final String? testType;
  final String? specimenType;
  final String? specimenVolume;
  final String? specimenContainer;

  /// `numeric`, `text`, `positive_negative`, `select` — what shape the result
  /// entry field takes.
  final String? resultType;
  final String? unit;

  /// A **string**, not a structure. The DTO types this `@IsString()` while the
  /// column holds JSON, so an editor round-trips the encoded text rather than
  /// re-encoding a parsed object and changing the shape a site has been
  /// storing.
  final String? referenceRanges;

  /// The raw amount. Formatting for display goes through the site
  /// `MoneyFormat`; what goes on the wire is a plain number.
  final double? price;

  /// Hours.
  final int? turnaroundTime;
  final String? department;
  final String? preparationInstructions;
  final String? clinicalSignificance;

  /// Update only.
  final bool? isActive;

  LabTestDraft copyWith({
    String? testName,
    String? testCode,
    String? testCategory,
    String? testType,
    String? specimenType,
    String? specimenVolume,
    String? specimenContainer,
    String? resultType,
    String? unit,
    String? referenceRanges,
    double? price,
    int? turnaroundTime,
    String? department,
    String? preparationInstructions,
    String? clinicalSignificance,
    bool? isActive,
  }) =>
      LabTestDraft(
        testName: testName ?? this.testName,
        testCode: testCode ?? this.testCode,
        testCategory: testCategory ?? this.testCategory,
        testType: testType ?? this.testType,
        specimenType: specimenType ?? this.specimenType,
        specimenVolume: specimenVolume ?? this.specimenVolume,
        specimenContainer: specimenContainer ?? this.specimenContainer,
        resultType: resultType ?? this.resultType,
        unit: unit ?? this.unit,
        referenceRanges: referenceRanges ?? this.referenceRanges,
        price: price ?? this.price,
        turnaroundTime: turnaroundTime ?? this.turnaroundTime,
        department: department ?? this.department,
        preparationInstructions: preparationInstructions ?? this.preparationInstructions,
        clinicalSignificance: clinicalSignificance ?? this.clinicalSignificance,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> _shared() => {
        'testName': testName,
        'testCode': testCode,
        'testCategory': testCategory,
        'testType': testType,
        'specimenType': specimenType,
        'specimenVolume': specimenVolume,
        'specimenContainer': specimenContainer,
        'resultType': resultType,
        'unit': unit,
        'referenceRanges': referenceRanges,
        'price': price,
        'turnaroundTime': turnaroundTime,
        'department': department,
        'preparationInstructions': preparationInstructions,
        'clinicalSignificance': clinicalSignificance,
      };

  Map<String, dynamic> toCreateJson() => draftBody(_shared());

  Map<String, dynamic> toUpdateJson() => draftBody({
        ..._shared(),
        'isActive': isActive,
      });
}
