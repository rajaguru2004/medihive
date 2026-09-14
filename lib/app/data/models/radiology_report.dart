import 'json.dart';
import 'patient_ref.dart';
import 'radiology_exam.dart';

/// One image attached to a report.
class RadiologyImage {
  const RadiologyImage({
    this.url = '',
    this.caption,
    this.view,
  });

  final String url;
  final String? caption;

  /// `AP`, `lateral`, `axial` — the projection, which is what a clinician
  /// actually navigates a study by.
  final String? view;

  bool get isEmpty => url.isEmpty;

  factory RadiologyImage.fromJson(Map<String, dynamic> json) => RadiologyImage(
        url: asString(json['url'] ?? json['src']),
        caption: asStringOrNull(json['caption']),
        view: asStringOrNull(json['view']),
      );
}

/// The radiologist's read of a study.
///
/// Deliberately does not import `radiology_order.dart`: the read route embeds
/// the order the other way round, and one direction of the pair is enough.
/// The order's patient and exam are lifted onto this object instead, so a
/// report opened from a worklist can render a header without a second call.
class RadiologyReport {
  const RadiologyReport({
    this.id = '',
    this.organizationId,
    this.orderId = '',
    this.technique,
    this.findings,
    this.impression,
    this.recommendations,
    this.hasCriticalFindings = false,
    this.criticalFindings,
    this.criticalNotifiedTo,
    this.criticalNotifiedAt,
    this.comparedWithPrevious = false,
    this.comparisonNotes,
    this.images = const [],
    this.dicomStudyUid,
    this.templateUsed,
    this.reportedById,
    this.reportedAt,
    this.verifiedById,
    this.verifiedAt,
    this.status = 'draft',
    this.amendmentReason,
    this.amendedAt,
    this.amendedById,
    this.createdAt,
    this.updatedAt,
    this.patient = PatientRef.empty,
    this.exam = RadiologyExam.empty,
  });

  final String id;
  final String? organizationId;
  final String orderId;

  final String? technique;
  final String? findings;

  /// The one paragraph a referring clinician reads. Never truncated in a UI:
  /// an impression cut at "no evidence of" reverses its own meaning.
  final String? impression;

  final String? recommendations;

  final bool hasCriticalFindings;
  final String? criticalFindings;
  final String? criticalNotifiedTo;

  /// When somebody was actually told. A critical finding with findings text
  /// and no notification time is the state a ward escalates from.
  final DateTime? criticalNotifiedAt;

  final bool comparedWithPrevious;
  final String? comparisonNotes;

  /// Stored as a JSON array inside a text column.
  final List<RadiologyImage> images;

  final String? dicomStudyUid;
  final String? templateUsed;

  final String? reportedById;
  final DateTime? reportedAt;
  final String? verifiedById;
  final DateTime? verifiedAt;

  /// `draft`, `final`, `amended`.
  final String status;

  final String? amendmentReason;
  final DateTime? amendedAt;
  final String? amendedById;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Lifted from the embedded order when the route populated it.
  final PatientRef patient;
  final RadiologyExam exam;

  static const RadiologyReport empty = RadiologyReport();

  bool get isEmpty => id.isEmpty && orderId.isEmpty;

  bool get isDraft => status.toLowerCase() == 'draft';
  bool get isFinal => status.toLowerCase() == 'final';
  bool get isAmended => status.toLowerCase() == 'amended';

  bool get isVerified => verifiedAt != null;

  /// A critical finding nobody has been told about yet.
  bool get criticalUnnotified =>
      hasCriticalFindings && criticalNotifiedAt == null;

  factory RadiologyReport.fromJson(Map<String, dynamic> json) {
    final order = asMap(json['order']);
    return RadiologyReport(
      id: asString(json['id'] ?? json['_id']),
      organizationId: asStringOrNull(json['organizationId']),
      orderId: asString(json['orderId'], fallback: asString(order['id'])),
      technique: asStringOrNull(json['technique']),
      findings: asStringOrNull(json['findings']),
      impression: asStringOrNull(json['impression']),
      recommendations: asStringOrNull(json['recommendations']),
      hasCriticalFindings: asBool(json['hasCriticalFindings']),
      criticalFindings: asStringOrNull(json['criticalFindings']),
      criticalNotifiedTo: asStringOrNull(json['criticalNotifiedTo']),
      criticalNotifiedAt: asDate(json['criticalNotifiedAt']),
      comparedWithPrevious: asBool(json['comparedWithPrevious']),
      comparisonNotes: asStringOrNull(json['comparisonNotes']),
      images: asModelList(json['images'], RadiologyImage.fromJson),
      dicomStudyUid: asStringOrNull(json['dicomStudyUid']),
      templateUsed: asStringOrNull(json['templateUsed']),
      reportedById: asStringOrNull(json['reportedById']),
      reportedAt: asDate(json['reportedAt']),
      verifiedById: asStringOrNull(json['verifiedById']),
      verifiedAt: asDate(json['verifiedAt']),
      status: asString(json['status'], fallback: 'draft'),
      amendmentReason: asStringOrNull(json['amendmentReason']),
      amendedAt: asDate(json['amendedAt']),
      amendedById: asStringOrNull(json['amendedById']),
      createdAt: asDate(json['createdAt']),
      updatedAt: asDate(json['updatedAt']),
      patient: PatientRef.of(json['patient'] ?? order['patient']),
      exam: RadiologyExam.of(json['exam'] ?? order['exam']),
    );
  }

  factory RadiologyReport.of(dynamic value) => value is Map
      ? RadiologyReport.fromJson(value.cast<String, dynamic>())
      : empty;
}
