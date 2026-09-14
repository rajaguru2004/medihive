import 'json.dart';
import 'lab_test.dart';

/// One analyte's result inside a lab order.
class LabResult {
  const LabResult({
    this.id = '',
    this.organizationId,
    this.orderId = '',
    this.testId = '',
    this.resultValue = '',
    this.resultUnit,
    this.isAbnormal = false,
    this.isCritical = false,
    this.flag,
    this.referenceRangeMin,
    this.referenceRangeMax,
    this.referenceRangeText,
    this.qcLevel,
    this.qcPassed,
    this.methodUsed,
    this.instrumentUsed,
    this.enteredById,
    this.enteredAt,
    this.verifiedById,
    this.verifiedAt,
    this.comment,
    this.technicianNotes,
    this.test = LabTest.empty,
  });

  final String id;
  final String? organizationId;
  final String orderId;
  final String testId;

  /// Text, not a number: this column holds `7.2`, `Negative` and `>1000`
  /// alike, and coercing it to a double loses the two that are not numbers.
  final String resultValue;

  final String? resultUnit;

  final bool isAbnormal;

  /// A result the ward must be told about by someone, not by a list refresh.
  final bool isCritical;

  /// `H` high, `L` low, `N` normal, `A` abnormal.
  final String? flag;

  final double? referenceRangeMin;
  final double? referenceRangeMax;
  final String? referenceRangeText;

  final String? qcLevel;
  final bool? qcPassed;

  final String? methodUsed;
  final String? instrumentUsed;

  final String? enteredById;
  final DateTime? enteredAt;

  final String? verifiedById;

  /// Null until a second pair of eyes has signed it. A result rendered as
  /// final before this is set is a result acted on before it was checked.
  final DateTime? verifiedAt;

  final String? comment;
  final String? technicianNotes;

  /// The catalogue entry, when the route populated it. `LabTest.empty`
  /// otherwise — never null, so a row can read `test.unit` unguarded.
  final LabTest test;

  static const LabResult empty = LabResult();

  bool get isEmpty => id.isEmpty && resultValue.isEmpty;

  bool get isVerified => verifiedAt != null;

  /// The name to put on the row: the populated test's, falling back to the id
  /// so an unpopulated route still renders something a technician can match.
  String get testName => test.testName.isNotEmpty ? test.testName : testId;

  /// The unit the result carries, or the catalogue's where the row omitted it.
  String get unit => (resultUnit ?? '').isNotEmpty ? resultUnit! : (test.unit ?? '');

  /// `3.5 – 5.1`, from whichever of the three range columns the site filled.
  String get referenceDisplay {
    final text = referenceRangeText ?? '';
    if (text.isNotEmpty) return text;
    final min = referenceRangeMin;
    final max = referenceRangeMax;
    if (min != null && max != null) return '$min – $max';
    if (min != null) return '≥ $min';
    if (max != null) return '≤ $max';
    return test.referenceRanges.isEmpty ? '—' : test.referenceRanges.first.display;
  }

  factory LabResult.fromJson(Map<String, dynamic> json) {
    // The id of a reference, whichever way the route sent it. `asRefId` reads
    // Mongo's `_id`; this backend is Prisma and spells it `id`, so the
    // populated document is parsed first and its id used as the fallback.
    final test = LabTest.of(json['test']);
    return LabResult(
      id: asString(json['id'] ?? json['_id']),
      organizationId: asStringOrNull(json['organizationId']),
      orderId: asString(json['orderId']),
      testId: asString(json['testId'], fallback: test.id),
      resultValue: asString(json['resultValue']),
      resultUnit: asStringOrNull(json['resultUnit']),
      isAbnormal: asBool(json['isAbnormal']),
      isCritical: asBool(json['isCritical']),
      flag: asStringOrNull(json['flag']),
      referenceRangeMin: json['referenceRangeMin'] == null
          ? null
          : asDouble(json['referenceRangeMin']),
      referenceRangeMax: json['referenceRangeMax'] == null
          ? null
          : asDouble(json['referenceRangeMax']),
      referenceRangeText: asStringOrNull(json['referenceRangeText']),
      qcLevel: asStringOrNull(json['qcLevel']),
      qcPassed: json['qcPassed'] == null ? null : asBool(json['qcPassed']),
      methodUsed: asStringOrNull(json['methodUsed']),
      instrumentUsed: asStringOrNull(json['instrumentUsed']),
      enteredById: asStringOrNull(json['enteredById']),
      enteredAt: asDate(json['enteredAt']),
      verifiedById: asStringOrNull(json['verifiedById']),
      verifiedAt: asDate(json['verifiedAt']),
      comment: asStringOrNull(json['comment']),
      technicianNotes: asStringOrNull(json['technicianNotes']),
      test: test,
    );
  }

  factory LabResult.of(dynamic value) =>
      value is Map ? LabResult.fromJson(value.cast<String, dynamic>()) : empty;
}
