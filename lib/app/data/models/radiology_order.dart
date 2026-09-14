import 'json.dart';
import 'patient_ref.dart';
import 'radiology_exam.dart';
import 'radiology_report.dart';

/// A request for an imaging study on one patient.
class RadiologyOrder {
  const RadiologyOrder({
    this.id = '',
    this.organizationId = '',
    this.patientId = '',
    this.consultationId,
    this.requestedById,
    this.examId = '',
    this.orderDate,
    this.orderNumber = '',
    this.clinicalIndication,
    this.provisionalDiagnosis,
    this.relevantHistory,
    this.urgency = 'routine',
    this.status = 'pending',
    this.scheduledDate,
    this.examPerformedAt,
    this.performedById,
    this.reportCreatedAt,
    this.reportedById,
    this.reportVerifiedAt,
    this.verifiedById,
    this.notes,
    this.cancellationReason,
    this.createdAt,
    this.updatedAt,
    this.patient = PatientRef.empty,
    this.exam = RadiologyExam.empty,
    this.report,
  });

  final String id;
  final String organizationId;
  final String patientId;
  final String? consultationId;
  final String? requestedById;
  final String examId;

  final DateTime? orderDate;
  final String orderNumber;

  final String? clinicalIndication;
  final String? provisionalDiagnosis;
  final String? relevantHistory;

  /// `routine`, `urgent`, `stat`. Imaging spells this `urgency`; the lab
  /// spells the same ladder `priority`. Both are kept as the backend names
  /// them rather than harmonised, because a renamed field is a 400.
  final String urgency;

  /// `pending`, `scheduled`, `in_progress`, `completed`, `reported`,
  /// `cancelled`.
  final String status;

  final DateTime? scheduledDate;

  final DateTime? examPerformedAt;
  final String? performedById;

  final DateTime? reportCreatedAt;
  final String? reportedById;
  final DateTime? reportVerifiedAt;
  final String? verifiedById;

  final String? notes;
  final String? cancellationReason;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final PatientRef patient;
  final RadiologyExam exam;

  /// Null until somebody has read the study. Nullable rather than
  /// `RadiologyReport.empty` because "not yet reported" is a state a worklist
  /// filters on, and an empty report object reads as a blank one.
  final RadiologyReport? report;

  static const RadiologyOrder empty = RadiologyOrder();

  bool get isEmpty => id.isEmpty && orderNumber.isEmpty;

  bool get isStat => urgency.toLowerCase() == 'stat';

  bool get isPerformed => examPerformedAt != null;
  bool get isReported => report != null || reportCreatedAt != null;
  bool get isVerified => reportVerifiedAt != null;

  /// A read that found something the ward must be told about.
  bool get hasCriticalFindings => report?.hasCriticalFindings ?? false;

  /// What the row says the order is for — the catalogue name where it was
  /// populated, the id otherwise.
  String get examName => exam.examName.isNotEmpty ? exam.examName : examId;

  factory RadiologyOrder.fromJson(Map<String, dynamic> json) {
    // Parsed before the record so a route that populated the block without
    // repeating its foreign key still yields an id. `asRefId` reads Mongo's
    // `_id`; this backend is Prisma and spells it `id`.
    final patient = PatientRef.of(json['patient']);
    final exam = RadiologyExam.of(json['exam']);
    final report = asMap(json['report']);
    return RadiologyOrder(
      id: asString(json['id'] ?? json['_id']),
      organizationId: asString(json['organizationId']),
      patientId: asString(json['patientId'], fallback: patient.id),
      consultationId: asStringOrNull(json['consultationId']),
      requestedById: asStringOrNull(json['requestedById']),
      examId: asString(json['examId'], fallback: exam.id),
      orderDate: asDate(json['orderDate']),
      orderNumber: asString(json['orderNumber']),
      clinicalIndication: asStringOrNull(json['clinicalIndication']),
      provisionalDiagnosis: asStringOrNull(json['provisionalDiagnosis']),
      relevantHistory: asStringOrNull(json['relevantHistory']),
      urgency: asString(json['urgency'], fallback: 'routine'),
      status: asString(json['status'], fallback: 'pending'),
      scheduledDate: asDate(json['scheduledDate']),
      examPerformedAt: asDate(json['examPerformedAt']),
      performedById: asStringOrNull(json['performedById']),
      reportCreatedAt: asDate(json['reportCreatedAt']),
      reportedById: asStringOrNull(json['reportedById']),
      reportVerifiedAt: asDate(json['reportVerifiedAt']),
      verifiedById: asStringOrNull(json['verifiedById']),
      notes: asStringOrNull(json['notes']),
      cancellationReason: asStringOrNull(json['cancellationReason']),
      createdAt: asDate(json['createdAt']),
      updatedAt: asDate(json['updatedAt']),
      patient: patient,
      exam: exam,
      report: report.isEmpty ? null : RadiologyReport.fromJson(report),
    );
  }

  factory RadiologyOrder.of(dynamic value) => value is Map
      ? RadiologyOrder.fromJson(value.cast<String, dynamic>())
      : empty;
}
