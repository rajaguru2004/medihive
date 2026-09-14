import 'json.dart';
import 'site_settings.dart';

/// The batch a dispense would come out of — the earliest to expire, which is
/// the only one of a drug's batches the list route sends.
class DrugBatch {
  const DrugBatch({
    this.id = '',
    this.batchNumber = '',
    this.expiryDate,
    this.quantityRemaining = 0,
    this.status = 'active',
  });

  final String id;
  final String batchNumber;

  /// Null when the site has not recorded one. **Not today**: a missing expiry
  /// that defaults to now marks good stock as expired and hides it from the
  /// counter.
  final DateTime? expiryDate;

  final int quantityRemaining;

  /// `active`, `expired`, `recalled`, `depleted`.
  final String status;

  bool get isEmpty => id.isEmpty && batchNumber.isEmpty;

  bool expired({DateTime? asOf}) {
    final expiry = expiryDate;
    return expiry != null && expiry.isBefore(asOf ?? DateTime.now());
  }

  factory DrugBatch.fromJson(Map<String, dynamic> json) => DrugBatch(
        id: asString(json['id'] ?? json['_id']),
        batchNumber: asString(json['batchNumber']),
        expiryDate: asDate(json['expiryDate']),
        quantityRemaining: asInt(json['quantityRemaining']),
        status: asString(json['status'], fallback: 'active'),
      );
}

/// A drug in the pharmacy catalogue, with its stock position.
class Drug {
  const Drug({
    this.id = '',
    this.organizationId = '',
    this.drugName = '',
    this.genericName,
    this.brandName,
    this.drugCode,
    this.drugCategory,
    this.dosageForm,
    this.strength,
    this.quantityInStock = 0,
    this.unitOfMeasure,
    this.reorderLevel = 0,
    this.maximumStockLevel,
    this.costPrice,
    this.sellingPrice,
    this.markupPercentage,
    this.storageLocation,
    this.requiresPrescription = false,
    this.supplierName,
    this.supplierContact,
    this.description,
    this.sideEffects,
    this.contraindications,
    this.isActive = true,
    this.batches = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String organizationId;

  final String drugName;
  final String? genericName;
  final String? brandName;
  final String? drugCode;

  /// `antibiotic`, `analgesic`, …
  final String? drugCategory;

  /// `tablet`, `capsule`, `syrup`, `injection`.
  final String? dosageForm;

  /// `500mg`, `10mg/ml`.
  final String? strength;

  final int quantityInStock;
  final String? unitOfMeasure;

  /// The count at which the counter reorders. Zero means the site never set
  /// one, so [isLowStock] stays quiet rather than flagging everything.
  final int reorderLevel;

  final int? maximumStockLevel;

  final double? costPrice;
  final double? sellingPrice;
  final double? markupPercentage;

  final String? storageLocation;
  final bool requiresPrescription;

  /// Read-only from this app: neither pharmacy write DTO carries supplier
  /// fields, so sending one is a 400.
  final String? supplierName;
  final String? supplierContact;

  final String? description;
  final String? sideEffects;
  final String? contraindications;

  final bool isActive;

  /// The earliest-expiring active batch, when the route sent one.
  final List<DrugBatch> batches;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const Drug empty = Drug();

  bool get isEmpty => id.isEmpty && drugName.isEmpty;

  /// `Amoxicillin 500mg tablet` — what a prescriber picks from a list.
  String get displayName => [
        drugName,
        strength ?? '',
        dosageForm ?? '',
      ].where((p) => p.isNotEmpty).join(' ');

  bool get isOutOfStock => quantityInStock <= 0;

  /// At or below the reorder level, and only where the site set one.
  bool get isLowStock =>
      reorderLevel > 0 && quantityInStock > 0 && quantityInStock <= reorderLevel;

  /// The batch a dispense would come from, or null when none was sent.
  DrugBatch? get nextBatch => batches.isEmpty ? null : batches.first;

  /// Stock present but past its date — worse than empty, because the shelf
  /// looks full.
  bool expiringStock({DateTime? asOf}) =>
      quantityInStock > 0 && (nextBatch?.expired(asOf: asOf) ?? false);

  String priceLabel(MoneyFormat money) =>
      sellingPrice == null ? '—' : money(sellingPrice);

  factory Drug.fromJson(Map<String, dynamic> json) => Drug(
        id: asString(json['id'] ?? json['_id']),
        organizationId: asString(json['organizationId']),
        drugName: asString(json['drugName']),
        genericName: asStringOrNull(json['genericName']),
        brandName: asStringOrNull(json['brandName']),
        drugCode: asStringOrNull(json['drugCode']),
        drugCategory: asStringOrNull(json['drugCategory']),
        dosageForm: asStringOrNull(json['dosageForm']),
        strength: asStringOrNull(json['strength']),
        quantityInStock: asInt(json['quantityInStock']),
        unitOfMeasure: asStringOrNull(json['unitOfMeasure']),
        reorderLevel: asInt(json['reorderLevel']),
        maximumStockLevel: json['maximumStockLevel'] == null
            ? null
            : asInt(json['maximumStockLevel']),
        costPrice: json['costPrice'] == null ? null : asDouble(json['costPrice']),
        sellingPrice:
            json['sellingPrice'] == null ? null : asDouble(json['sellingPrice']),
        markupPercentage: json['markupPercentage'] == null
            ? null
            : asDouble(json['markupPercentage']),
        storageLocation: asStringOrNull(json['storageLocation']),
        requiresPrescription: asBool(json['requiresPrescription']),
        supplierName: asStringOrNull(json['supplierName']),
        supplierContact: asStringOrNull(json['supplierContact']),
        description: asStringOrNull(json['description']),
        sideEffects: asStringOrNull(json['sideEffects']),
        contraindications: asStringOrNull(json['contraindications']),
        isActive: asBool(json['isActive'], fallback: true),
        batches: asModelList(json['batches'], DrugBatch.fromJson),
        createdAt: asDate(json['createdAt']),
        updatedAt: asDate(json['updatedAt']),
      );

  factory Drug.of(dynamic value) =>
      value is Map ? Drug.fromJson(value.cast<String, dynamic>()) : empty;
}
