import 'json.dart';
import 'patient_ref.dart';

/// A result an instrument sent in, waiting to be matched to a patient.
///
/// The queue exists because matching is not always possible: an analyser
/// identifies a sample by whatever the bench typed onto the tube, and this app
/// must show an unmatched result rather than drop it. A result silently
/// discarded is a test the ward believes was run.
class ResultsQueueItem {
  const ResultsQueueItem({
    this.id = '',
    this.organizationId = '',
    this.machineIntegrationId = '',
    this.machineName = '',
    this.machineType = '',
    this.rawData = '',
    this.parsedData = const {},
    this.patientIdentifier,
    this.matchedPatientId,
    this.testResults = const [],
    this.status = 'pending',
    this.errorMessage,
    this.receivedAt,
    this.processedAt,
    this.patient = PatientRef.empty,
  });

  final String id;
  final String organizationId;

  final String machineIntegrationId;

  /// From the populated machine block, where the route sent one.
  final String machineName;
  final String machineType;

  /// The HL7 or ASTM message, verbatim. Kept so a technician can read what the
  /// instrument actually said when the parse disagrees with the printout.
  final String rawData;

  final Map<String, dynamic> parsedData;

  /// What the machine called the patient — an MRN, a name, an accession.
  final String? patientIdentifier;

  final String? matchedPatientId;

  /// One entry per analyte. Free-form: the keys differ by instrument, and a
  /// typed class here would drop the columns a new analyser adds.
  final List<Map<String, dynamic>> testResults;

  /// `pending`, `matched`, `imported`, `failed`, `manual_review`.
  final String status;

  final String? errorMessage;

  final DateTime? receivedAt;
  final DateTime? processedAt;

  /// The matched patient, when the route populated one.
  final PatientRef patient;

  static const ResultsQueueItem empty = ResultsQueueItem();

  bool get isEmpty => id.isEmpty && rawData.isEmpty;

  bool get isMatched => matchedPatientId != null || !patient.isEmpty;

  bool get isImported => status.toLowerCase() == 'imported';

  /// Work for a person: a failure, or a match the machine would not make on
  /// its own.
  bool get needsReview =>
      status.toLowerCase() == 'failed' ||
      status.toLowerCase() == 'manual_review';

  int get resultCount => testResults.length;

  /// Who the result is for: the matched patient where there is one, otherwise
  /// whatever the instrument was told — never a blank, because a blank reads
  /// as a rendering fault rather than as an unmatched sample.
  String get subjectLabel {
    if (!patient.isEmpty) return patient.displayName;
    final identifier = patientIdentifier ?? '';
    return identifier.isNotEmpty ? identifier : 'Unidentified sample';
  }

  factory ResultsQueueItem.fromJson(Map<String, dynamic> json) {
    final machine = asMap(json['machineIntegration'] ?? json['machine']);
    final patient = PatientRef.of(json['patient']);
    final parsed = asMapList(json['parsedData']);

    return ResultsQueueItem(
      id: asString(json['id'] ?? json['_id']),
      organizationId: asString(json['organizationId']),
      machineIntegrationId: asString(
        json['machineIntegrationId'],
        fallback: asString(machine['id']),
      ),
      machineName: asString(machine['machineName']),
      machineType: asString(machine['machineType']),
      rawData: asString(json['rawData']),
      parsedData: parsed.isEmpty ? const {} : parsed.first,
      patientIdentifier: asStringOrNull(json['patientIdentifier']),
      matchedPatientId: asStringOrNull(json['matchedPatientId']) ??
          (patient.isEmpty ? null : patient.id),
      testResults: asMapList(json['testResults']),
      status: asString(json['status'], fallback: 'pending'),
      errorMessage: asStringOrNull(json['errorMessage']),
      receivedAt: asDate(json['receivedAt']),
      processedAt: asDate(json['processedAt']),
      patient: patient,
    );
  }

  factory ResultsQueueItem.of(dynamic value) => value is Map
      ? ResultsQueueItem.fromJson(value.cast<String, dynamic>())
      : empty;
}
