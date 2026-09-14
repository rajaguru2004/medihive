import 'json.dart';
import 'patient_ref.dart';
import 'site_settings.dart';

/// One line on a counter sale.
class SaleItem {
  const SaleItem({
    this.drugId = '',
    this.batchId,
    this.drugName = '',
    this.quantity = 0,
    this.unitPrice = 0,
    this.total = 0,
  });

  final String drugId;

  /// Which batch it came out of, where the site tracks lots.
  final String? batchId;

  final String drugName;
  final int quantity;
  final double unitPrice;

  /// Sent rather than derived: the server stores the line as it was rung up,
  /// and a client that recomputes it can disagree with the printed receipt.
  final double total;

  bool get isEmpty => drugId.isEmpty && drugName.isEmpty;

  /// What this line comes to if nobody overrode it.
  double get computedTotal => unitPrice * quantity;

  String totalLabel(MoneyFormat money) => money(total);

  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(
        drugId: asString(json['drugId'] ?? json['id']),
        batchId: asStringOrNull(json['batchId']),
        drugName: asString(json['drugName'] ?? json['name']),
        quantity: asInt(json['quantity']),
        unitPrice: asDouble(json['unitPrice']),
        total: asDouble(json['total']),
      );

  Map<String, dynamic> toJson() => {
        'drugId': drugId,
        'batchId': ?batchId,
        'drugName': drugName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'total': total,
      };
}

/// A pharmacy counter sale.
class PharmacySale {
  const PharmacySale({
    this.id = '',
    this.organizationId = '',
    this.patientId,
    this.prescriptionId,
    this.servedById,
    this.saleDate,
    this.saleType,
    this.items = const [],
    this.subtotal = 0,
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    this.paymentStatus = 'pending',
    this.paymentMethod,
    this.amountPaid = 0,
    this.amountDue,
    this.receiptNumber = '',
    this.createdAt,
    this.patient = PatientRef.empty,
  });

  final String id;
  final String organizationId;

  /// Null for a walk-in: an over-the-counter sale has no patient record.
  final String? patientId;

  final String? prescriptionId;
  final String? servedById;

  final DateTime? saleDate;

  /// `prescription` or `otc`.
  final String? saleType;

  /// Stored by the backend as a JSON array inside a text column.
  final List<SaleItem> items;

  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double totalAmount;

  /// `pending`, `paid`, `partially_paid`. Narrower than an invoice's: a
  /// counter sale is never refunded in place.
  final String paymentStatus;

  final String? paymentMethod;
  final double amountPaid;
  final double? amountDue;

  final String receiptNumber;

  final DateTime? createdAt;

  final PatientRef patient;

  static const PharmacySale empty = PharmacySale();

  bool get isEmpty => id.isEmpty && receiptNumber.isEmpty;

  bool get isPaid => paymentStatus.toLowerCase() == 'paid';

  /// What is still owed. Falls back to the arithmetic when the server did not
  /// send `amountDue` — a balance shown as zero on a sale that is not paid is
  /// how money walks out of a pharmacy.
  double get outstanding => amountDue ?? (totalAmount - amountPaid);

  int get itemCount => items.length;

  /// Sum of the lines, for reconciling against [subtotal] on a receipt.
  double get lineTotal =>
      items.fold<double>(0, (sum, item) => sum + item.total);

  String totalLabel(MoneyFormat money) => money(totalAmount);

  factory PharmacySale.fromJson(Map<String, dynamic> json) {
    final patient = PatientRef.of(json['patient']);
    return PharmacySale(
      id: asString(json['id'] ?? json['_id']),
      organizationId: asString(json['organizationId']),
      patientId: asStringOrNull(json['patientId']) ??
          (patient.isEmpty ? null : patient.id),
      prescriptionId: asStringOrNull(json['prescriptionId']),
      servedById: asStringOrNull(json['servedById']),
      saleDate: asDate(json['saleDate']),
      saleType: asStringOrNull(json['saleType']),
      items: asModelList(json['items'], SaleItem.fromJson),
      subtotal: asDouble(json['subtotal']),
      discountAmount: asDouble(json['discountAmount']),
      taxAmount: asDouble(json['taxAmount']),
      totalAmount: asDouble(json['totalAmount']),
      paymentStatus: asString(json['paymentStatus'], fallback: 'pending'),
      paymentMethod: asStringOrNull(json['paymentMethod']),
      amountPaid: asDouble(json['amountPaid']),
      amountDue: json['amountDue'] == null ? null : asDouble(json['amountDue']),
      receiptNumber: asString(json['receiptNumber']),
      createdAt: asDate(json['createdAt']),
      patient: patient,
    );
  }

  factory PharmacySale.of(dynamic value) => value is Map
      ? PharmacySale.fromJson(value.cast<String, dynamic>())
      : empty;
}
