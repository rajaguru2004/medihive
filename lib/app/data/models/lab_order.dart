import 'json.dart';
import 'lab_result.dart';
import 'patient_ref.dart';

/// One test on an order, as it was ordered.
///
/// A copy rather than a reference: the name and code are denormalised into the
/// order so a test later renamed in the catalogue does not silently rewrite
/// what a clinician actually asked for.
class LabOrderTest {
  const LabOrderTest({
    this.testId = '',
    this.testName = '',
    this.testCode,
    this.urgency,
  });

  final String testId;
  final String testName;
  final String? testCode;

  /// `routine`, `urgent`, `stat` — per test, above the order's own priority.
  final String? urgency;

  factory LabOrderTest.fromJson(Map<String, dynamic> json) => LabOrderTest(
        testId: asString(json['testId'] ?? json['id']),
        testName: asString(json['testName'] ?? json['name']),
        testCode: asStringOrNull(json['testCode'] ?? json['code']),
        urgency: asStringOrNull(json['urgency']),
      );

  Map<String, dynamic> toJson() => {
        'testId': testId,
        'testName': testName,
        'urgency': ?urgency,
      };
}

/// A request for laboratory work on one patient.
class LabOrder {
  const LabOrder({
    this.id = '',
    this.organizationId = '',
    this.patientId = '',
    this.consultationId,
    this.requestedById,
    this.orderDate,
    this.orderNumber = '',
    this.tests = const [],
    this.clinicalIndication,
    this.provisionalDiagnosis,
    this.priority = 'routine',
    this.status = 'pending',
    this.sampleCollectedAt,
    this.sampleCollectedById,
    this.accessionNumber,
    this.resultsEnteredAt,
    this.resultsEnteredById,
    this.resultsVerifiedAt,
    this.resultsVerifiedById,
    this.resultsReportedAt,
    this.notes,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
    this.patient = PatientRef.empty,
    this.results = const [],
  });

  final String id;
  final String organizationId;
  final String patientId;
  final String? consultationId;
  final String? requestedById;

  final DateTime? orderDate;
  final String orderNumber;

  /// Stored by the backend as a JSON array inside a text column. A model that
  /// reads this with `value is List` sees a String, returns empty, and the
  /// screen shows an order with no tests on it against a perfectly good 200.
  final List<LabOrderTest> tests;

  final String? clinicalIndication;
  final String? provisionalDiagnosis;

  /// `routine`, `urgent`, `stat`.
  final String priority;

  /// `pending`, `sample_collected`, `in_progress`, `completed`, `cancelled`,
  /// `rejected`.
  final String status;

  final DateTime? sampleCollectedAt;
  final String? sampleCollectedById;

  /// The barcode on the tube. What a bench technician searches by.
  final String? accessionNumber;

  final DateTime? resultsEnteredAt;
  final String? resultsEnteredById;
  final DateTime? resultsVerifiedAt;
  final String? resultsVerifiedById;
  final DateTime? resultsReportedAt;

  final String? notes;
  final String? rejectionReason;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// `PatientRef.empty` when the route did not populate one — a row renders
  /// the MRN it has rather than throwing.
  final PatientRef patient;

  final List<LabResult> results;

  static const LabOrder empty = LabOrder();

  bool get isEmpty => id.isEmpty && orderNumber.isEmpty;

  bool get isStat => priority.toLowerCase() == 'stat';

  /// Whether any result on this order needs telling somebody about.
  bool get hasCriticalResult => results.any((r) => r.isCritical);

  /// Results entered but not yet signed off — the queue a senior works.
  int get unverifiedCount => results.where((r) => !r.isVerified).length;

  bool get sampleCollected => sampleCollectedAt != null;

  /// `CBC, LFT, U&E` — what a row says the order is for.
  String get testSummary =>
      tests.map((t) => t.testName).where((n) => n.isNotEmpty).join(', ');

  factory LabOrder.fromJson(Map<String, dynamic> json) {
    // The populated block is parsed first so its id can stand in when the
    // route sent only the object. `asRefId` would not do: it reads Mongo's
    // `_id`, and this backend is Prisma and spells it `id`.
    final patient = PatientRef.of(json['patient']);
    return LabOrder(
        id: asString(json['id'] ?? json['_id']),
        organizationId: asString(json['organizationId']),
        patientId: asString(json['patientId'], fallback: patient.id),
        consultationId: asStringOrNull(json['consultationId']),
        requestedById: asStringOrNull(json['requestedById']),
        orderDate: asDate(json['orderDate']),
        orderNumber: asString(json['orderNumber']),
        tests: asModelList(json['tests'], LabOrderTest.fromJson),
        clinicalIndication: asStringOrNull(json['clinicalIndication']),
        provisionalDiagnosis: asStringOrNull(json['provisionalDiagnosis']),
        priority: asString(json['priority'], fallback: 'routine'),
        status: asString(json['status'], fallback: 'pending'),
        sampleCollectedAt: asDate(json['sampleCollectedAt']),
        sampleCollectedById: asStringOrNull(json['sampleCollectedById']),
        accessionNumber: asStringOrNull(json['accessionNumber']),
        resultsEnteredAt: asDate(json['resultsEnteredAt']),
        resultsEnteredById: asStringOrNull(json['resultsEnteredById']),
        resultsVerifiedAt: asDate(json['resultsVerifiedAt']),
        resultsVerifiedById: asStringOrNull(json['resultsVerifiedById']),
        resultsReportedAt: asDate(json['resultsReportedAt']),
        notes: asStringOrNull(json['notes']),
        rejectionReason: asStringOrNull(json['rejectionReason']),
        createdAt: asDate(json['createdAt']),
        updatedAt: asDate(json['updatedAt']),
        patient: patient,
        results: asModelList(json['results'], LabResult.fromJson),
    );
  }

  factory LabOrder.of(dynamic value) =>
      value is Map ? LabOrder.fromJson(value.cast<String, dynamic>()) : empty;
}
