import 'json.dart';
import 'site_settings.dart';

/// One entry in a test's reference ranges.
///
/// The backend stores the whole set as JSON inside a text column and has
/// written it two ways over its life: keyed by sex — `{"male": {...},
/// "female": {...}}` — and as a flat array of `{label, min, max}`. Both are
/// read here, because a range this app fails to show is a result nobody can
/// judge.
class LabReferenceRange {
  const LabReferenceRange({
    this.label = '',
    this.min,
    this.max,
    this.text,
  });

  /// `male`, `female`, `0-2y` — whatever the site keyed the range by. Empty
  /// when the site stores a single range for everybody.
  final String label;

  final double? min;
  final double? max;

  /// A range no pair of numbers expresses — `Negative`, `< 0.5`.
  final String? text;

  bool get isEmpty => min == null && max == null && (text ?? '').isEmpty;

  /// `3.5 – 5.1`, or the free text when that is all the site recorded.
  String get display {
    final free = text ?? '';
    if (free.isNotEmpty) return free;
    if (min != null && max != null) return '$min – $max';
    if (min != null) return '≥ $min';
    if (max != null) return '≤ $max';
    return '—';
  }

  factory LabReferenceRange.fromJson(Map<String, dynamic> json, {String label = ''}) =>
      LabReferenceRange(
        label: asString(json['label'] ?? json['sex'] ?? json['gender'], fallback: label),
        min: json['min'] == null ? null : asDouble(json['min']),
        max: json['max'] == null ? null : asDouble(json['max']),
        text: asStringOrNull(json['text'] ?? json['value']),
      );

  /// Reads either stored shape, from either a list or the JSON string this
  /// backend usually hands back.
  static List<LabReferenceRange> listOf(dynamic value) {
    final entries = asJsonList(value);
    final out = <LabReferenceRange>[];
    for (final entry in entries) {
      if (entry is! Map) continue;
      final map = entry.cast<String, dynamic>();

      // The sex-keyed shape: every value is itself an object, so the outer
      // keys are labels rather than fields.
      final nested = map.values.whereType<Map>().length == map.length &&
          map.isNotEmpty;
      if (nested) {
        map.forEach((label, range) {
          out.add(
            LabReferenceRange.fromJson(
              (range as Map).cast<String, dynamic>(),
              label: label,
            ),
          );
        });
        continue;
      }
      out.add(LabReferenceRange.fromJson(map));
    }
    return out.where((r) => !r.isEmpty).toList();
  }
}

/// A test in the laboratory catalogue — what can be ordered, not what was.
class LabTest {
  const LabTest({
    this.id = '',
    this.organizationId = '',
    this.testName = '',
    this.testCode,
    this.testCategory,
    this.testType,
    this.specimenType,
    this.specimenVolume,
    this.specimenContainer,
    this.resultType,
    this.unit,
    this.referenceRanges = const [],
    this.referenceRangesRaw,
    this.price,
    this.turnaroundTime,
    this.department,
    this.preparationInstructions,
    this.clinicalSignificance,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String organizationId;

  final String testName;
  final String? testCode;

  /// `hematology`, `chemistry`, `microbiology`, `serology`.
  final String? testCategory;

  /// `quantitative` or `qualitative`.
  final String? testType;

  final String? specimenType;
  final String? specimenVolume;
  final String? specimenContainer;

  /// `numeric`, `text`, `positive_negative`, `select` — what shape a result
  /// entry field should take.
  final String? resultType;

  final String? unit;

  final List<LabReferenceRange> referenceRanges;

  /// The ranges exactly as stored. The write DTO types this field as a
  /// **string**, so an edit round-trips this rather than the parsed list.
  final String? referenceRangesRaw;

  final double? price;

  /// Hours, not minutes — the schema says so and the console shows "h".
  final int? turnaroundTime;

  final String? department;
  final String? preparationInstructions;
  final String? clinicalSignificance;

  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const LabTest empty = LabTest();

  bool get isEmpty => id.isEmpty && testName.isEmpty;

  /// The code where a site keeps one, the name otherwise — never a blank cell.
  String get displayCode =>
      (testCode ?? '').isNotEmpty ? testCode! : testName;

  /// Priced in the site's convention. A bare number with no currency on it is
  /// how a price list ships to the wrong country.
  String priceLabel(MoneyFormat money) =>
      price == null ? '—' : money(price);

  factory LabTest.fromJson(Map<String, dynamic> json) => LabTest(
        id: asString(json['id'] ?? json['_id']),
        organizationId: asString(json['organizationId']),
        testName: asString(json['testName']),
        testCode: asStringOrNull(json['testCode']),
        testCategory: asStringOrNull(json['testCategory']),
        testType: asStringOrNull(json['testType']),
        specimenType: asStringOrNull(json['specimenType']),
        specimenVolume: asStringOrNull(json['specimenVolume']),
        specimenContainer: asStringOrNull(json['specimenContainer']),
        resultType: asStringOrNull(json['resultType']),
        unit: asStringOrNull(json['unit']),
        referenceRanges: LabReferenceRange.listOf(json['referenceRanges']),
        referenceRangesRaw: json['referenceRanges'] is String
            ? asStringOrNull(json['referenceRanges'])
            : null,
        price: json['price'] == null ? null : asDouble(json['price']),
        turnaroundTime:
            json['turnaroundTime'] == null ? null : asInt(json['turnaroundTime']),
        department: asStringOrNull(json['department']),
        preparationInstructions: asStringOrNull(json['preparationInstructions']),
        clinicalSignificance: asStringOrNull(json['clinicalSignificance']),
        isActive: asBool(json['isActive'], fallback: true),
        createdAt: asDate(json['createdAt']),
        updatedAt: asDate(json['updatedAt']),
      );

  factory LabTest.of(dynamic value) =>
      value is Map ? LabTest.fromJson(value.cast<String, dynamic>()) : empty;
}
