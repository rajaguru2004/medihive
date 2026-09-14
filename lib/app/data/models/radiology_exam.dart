import 'json.dart';
import 'site_settings.dart';

/// An exam in the imaging catalogue — what can be ordered, not what was.
class RadiologyExam {
  const RadiologyExam({
    this.id = '',
    this.organizationId = '',
    this.examName = '',
    this.examCode,
    this.examCategory,
    this.bodyPart,
    this.modality,
    this.price,
    this.estimatedDuration,
    this.preparationInstructions,
    this.contrastRequired = false,
    this.description,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String organizationId;

  final String examName;
  final String? examCode;

  /// `x-ray`, `ct`, `mri`, `ultrasound`, `mammography`.
  final String? examCategory;

  final String? bodyPart;

  /// The DICOM modality code — `CR`, `DR`, `CT`, `MRI`, `US`, `MG`.
  final String? modality;

  final double? price;

  /// Minutes on the machine, which is what a scheduler books against.
  final int? estimatedDuration;

  final String? preparationInstructions;

  /// Drives the consent and renal-function prompts on the order form, so it is
  /// a fact about the exam rather than a note on it.
  final bool contrastRequired;

  final String? description;

  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const RadiologyExam empty = RadiologyExam();

  bool get isEmpty => id.isEmpty && examName.isEmpty;

  /// `CT Head` — the exam and the part it covers, without repeating a part
  /// the name already carries.
  String get displayName {
    final part = bodyPart ?? '';
    if (part.isEmpty) return examName;
    if (examName.toLowerCase().contains(part.toLowerCase())) return examName;
    return '$examName — $part';
  }

  String priceLabel(MoneyFormat money) => price == null ? '—' : money(price);

  factory RadiologyExam.fromJson(Map<String, dynamic> json) => RadiologyExam(
        id: asString(json['id'] ?? json['_id']),
        organizationId: asString(json['organizationId']),
        examName: asString(json['examName']),
        examCode: asStringOrNull(json['examCode']),
        examCategory: asStringOrNull(json['examCategory']),
        bodyPart: asStringOrNull(json['bodyPart']),
        modality: asStringOrNull(json['modality']),
        price: json['price'] == null ? null : asDouble(json['price']),
        estimatedDuration: json['estimatedDuration'] == null
            ? null
            : asInt(json['estimatedDuration']),
        preparationInstructions: asStringOrNull(json['preparationInstructions']),
        contrastRequired: asBool(json['contrastRequired']),
        description: asStringOrNull(json['description']),
        isActive: asBool(json['isActive'], fallback: true),
        createdAt: asDate(json['createdAt']),
        updatedAt: asDate(json['updatedAt']),
      );

  factory RadiologyExam.of(dynamic value) => value is Map
      ? RadiologyExam.fromJson(value.cast<String, dynamic>())
      : empty;
}
