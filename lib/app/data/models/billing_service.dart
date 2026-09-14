import 'json.dart';
import 'site_settings.dart';

/// A billable item in the service catalogue — a consultation, a procedure, a
/// night on a ward.
class BillingService {
  const BillingService({
    this.id = '',
    this.organizationId = '',
    this.serviceName = '',
    this.serviceCode,
    this.serviceCategory,
    this.department,
    this.unitPrice = 0,
    this.isTaxable = false,
    this.taxPercentage = 0,
    this.isCoveredByInsurance = true,
    this.insuranceCopayPercentage,
    this.description,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String organizationId;

  final String serviceName;
  final String? serviceCode;

  /// `consultation`, `procedure`, `accommodation`.
  final String? serviceCategory;

  final String? department;

  final double unitPrice;

  final bool isTaxable;

  /// Percent, not a fraction — `15`, not `0.15`.
  final double taxPercentage;

  /// Defaults true, matching the column's default. A service that silently
  /// reads as uncovered quotes a patient the full price.
  final bool isCoveredByInsurance;

  final double? insuranceCopayPercentage;

  final String? description;

  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const BillingService empty = BillingService();

  bool get isEmpty => id.isEmpty && serviceName.isEmpty;

  /// The tax this line would add, in money rather than percent.
  double get taxAmount => isTaxable ? unitPrice * taxPercentage / 100 : 0;

  /// What the patient pays including tax.
  double get grossPrice => unitPrice + taxAmount;

  String priceLabel(MoneyFormat money) => money(unitPrice);

  factory BillingService.fromJson(Map<String, dynamic> json) => BillingService(
        id: asString(json['id'] ?? json['_id']),
        organizationId: asString(json['organizationId']),
        serviceName: asString(json['serviceName']),
        serviceCode: asStringOrNull(json['serviceCode']),
        serviceCategory: asStringOrNull(json['serviceCategory']),
        department: asStringOrNull(json['department']),
        unitPrice: asDouble(json['unitPrice']),
        isTaxable: asBool(json['isTaxable']),
        taxPercentage: asDouble(json['taxPercentage']),
        isCoveredByInsurance:
            asBool(json['isCoveredByInsurance'], fallback: true),
        insuranceCopayPercentage: json['insuranceCopayPercentage'] == null
            ? null
            : asDouble(json['insuranceCopayPercentage']),
        description: asStringOrNull(json['description']),
        isActive: asBool(json['isActive'], fallback: true),
        createdAt: asDate(json['createdAt']),
        updatedAt: asDate(json['updatedAt']),
      );

  factory BillingService.of(dynamic value) => value is Map
      ? BillingService.fromJson(value.cast<String, dynamic>())
      : empty;
}
