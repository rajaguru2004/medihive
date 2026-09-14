import 'json.dart';
import 'patient_ref.dart';
import 'payment.dart';
import 'site_settings.dart';

/// One line on an invoice.
class InvoiceItem {
  const InvoiceItem({
    this.type = '',
    this.referenceId,
    this.description = '',
    this.quantity = 0,
    this.unitPrice = 0,
    this.discount = 0,
    this.tax = 0,
    this.total = 0,
  });

  /// What kind of thing was billed — `service`, `lab`, `radiology`,
  /// `pharmacy`, `bed`. Free text on the backend, so it is not an enum here.
  final String type;

  /// The record this line bills for, where there is one.
  final String? referenceId;

  final String description;
  final int quantity;
  final double unitPrice;

  /// Money off this line, not a percentage.
  final double discount;

  final double tax;

  /// Sent rather than derived: a client that recomputes a line can disagree
  /// with the invoice the patient was handed.
  final double total;

  bool get isEmpty => description.isEmpty && total == 0;

  /// What this line comes to if nobody overrode it.
  double get computedTotal => (unitPrice * quantity) - discount + tax;

  String totalLabel(MoneyFormat money) => money(total);

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
        type: asString(json['type']),
        referenceId: asStringOrNull(json['referenceId']),
        description: asString(json['description']),
        quantity: asInt(json['quantity']),
        unitPrice: asDouble(json['unitPrice']),
        discount: asDouble(json['discount']),
        tax: asDouble(json['tax']),
        total: asDouble(json['total']),
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'referenceId': ?referenceId,
        'description': description,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discount': discount,
        'tax': tax,
        'total': total,
      };
}

/// A patient's bill.
class Invoice {
  const Invoice({
    this.id = '',
    this.organizationId = '',
    this.patientId = '',
    this.consultationId,
    this.invoiceNumber = '',
    this.invoiceDate,
    this.dueDate,
    this.items = const [],
    this.subtotal = 0,
    this.discountAmount = 0,
    this.discountPercentage = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    this.paymentStatus = 'unpaid',
    this.amountPaid = 0,
    this.balanceDue,
    this.insuranceClaimAmount = 0,
    this.insuranceClaimStatus,
    this.patientCopayAmount = 0,
    this.status = 'draft',
    this.notes,
    this.termsAndConditions,
    this.cancelledAt,
    this.cancelledById,
    this.cancellationReason,
    this.createdAt,
    this.updatedAt,
    this.patient = PatientRef.empty,
    this.payments = const [],
  });

  final String id;
  final String organizationId;
  final String patientId;
  final String? consultationId;

  final String invoiceNumber;
  final DateTime? invoiceDate;

  /// Null when the site does not set terms. **Not today's date**: an invoice
  /// issued with no due date is not an invoice that fell due this morning.
  final DateTime? dueDate;

  /// Stored by the backend as a JSON array inside a text column.
  final List<InvoiceItem> items;

  final double subtotal;
  final double discountAmount;
  final double discountPercentage;
  final double taxAmount;
  final double totalAmount;

  /// `unpaid`, `partially_paid`, `paid`, `cancelled`, `refunded`.
  final String paymentStatus;

  final double amountPaid;
  final double? balanceDue;

  final double insuranceClaimAmount;
  final String? insuranceClaimStatus;
  final double patientCopayAmount;

  /// The document's own state — `draft`, `sent`, `overdue`, `paid`,
  /// `cancelled`. Separate from [paymentStatus], which is the money's.
  final String status;

  final String? notes;
  final String? termsAndConditions;

  final DateTime? cancelledAt;
  final String? cancelledById;
  final String? cancellationReason;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final PatientRef patient;
  final List<Payment> payments;

  static const Invoice empty = Invoice();

  bool get isEmpty => id.isEmpty && invoiceNumber.isEmpty;

  bool get isPaid => paymentStatus.toLowerCase() == 'paid';
  bool get isCancelled =>
      status.toLowerCase() == 'cancelled' ||
      paymentStatus.toLowerCase() == 'cancelled';

  /// What is still owed. Falls back to the arithmetic where the server did not
  /// send `balanceDue` — a balance rendered as zero on an unpaid invoice is
  /// how a bill goes uncollected.
  double get outstanding => balanceDue ?? (totalAmount - amountPaid);

  /// Past its due date and not settled. A null due date is never overdue.
  bool overdue({DateTime? asOf}) {
    final due = dueDate;
    if (due == null || isPaid || isCancelled) return false;
    return due.isBefore(asOf ?? DateTime.now()) && outstanding > 0;
  }

  int get itemCount => items.length;

  /// Sum of the lines, for reconciling against [subtotal].
  double get lineTotal => items.fold<double>(0, (sum, item) => sum + item.total);

  /// What has actually been received, refunds netted off.
  double get paymentsTotal =>
      payments.fold<double>(0, (sum, payment) => sum + payment.signedAmount);

  String totalLabel(MoneyFormat money) => money(totalAmount);
  String outstandingLabel(MoneyFormat money) => money(outstanding);

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final patient = PatientRef.of(json['patient']);
    return Invoice(
      id: asString(json['id'] ?? json['_id']),
      organizationId: asString(json['organizationId']),
      patientId: asString(json['patientId'], fallback: patient.id),
      consultationId: asStringOrNull(json['consultationId']),
      invoiceNumber: asString(json['invoiceNumber']),
      invoiceDate: asDate(json['invoiceDate']),
      dueDate: asDate(json['dueDate']),
      items: asModelList(json['items'], InvoiceItem.fromJson),
      subtotal: asDouble(json['subtotal']),
      discountAmount: asDouble(json['discountAmount']),
      discountPercentage: asDouble(json['discountPercentage']),
      taxAmount: asDouble(json['taxAmount']),
      totalAmount: asDouble(json['totalAmount']),
      paymentStatus: asString(json['paymentStatus'], fallback: 'unpaid'),
      amountPaid: asDouble(json['amountPaid']),
      balanceDue:
          json['balanceDue'] == null ? null : asDouble(json['balanceDue']),
      insuranceClaimAmount: asDouble(json['insuranceClaimAmount']),
      insuranceClaimStatus: asStringOrNull(json['insuranceClaimStatus']),
      patientCopayAmount: asDouble(json['patientCopayAmount']),
      status: asString(json['status'], fallback: 'draft'),
      notes: asStringOrNull(json['notes']),
      termsAndConditions: asStringOrNull(json['termsAndConditions']),
      cancelledAt: asDate(json['cancelledAt']),
      cancelledById: asStringOrNull(json['cancelledById']),
      cancellationReason: asStringOrNull(json['cancellationReason']),
      createdAt: asDate(json['createdAt']),
      updatedAt: asDate(json['updatedAt']),
      patient: patient,
      payments: asModelList(json['payments'], Payment.fromJson),
    );
  }

  factory Invoice.of(dynamic value) =>
      value is Map ? Invoice.fromJson(value.cast<String, dynamic>()) : empty;
}
