import 'json.dart';
import 'patient_ref.dart';
import 'site_settings.dart';

/// Money received against an invoice.
class Payment {
  const Payment({
    this.id = '',
    this.organizationId = '',
    this.invoiceId = '',
    this.patientId,
    this.paymentDate,
    this.receiptNumber = '',
    this.amount = 0,
    this.paymentMethod = '',
    this.paymentReference,
    this.cardLastFour,
    this.mobileMoneyProvider,
    this.bankName,
    this.chequeNumber,
    this.chequeDate,
    this.processedById,
    this.isRefund = false,
    this.refundReason,
    this.originalPaymentId,
    this.notes,
    this.createdAt,
    this.patient = PatientRef.empty,
  });

  final String id;
  final String organizationId;
  final String invoiceId;
  final String? patientId;

  final DateTime? paymentDate;

  /// What the payer holds. The number a dispute is resolved by.
  final String receiptNumber;

  final double amount;

  /// `cash`, `credit_card`, `debit_card`, `mobile_money`, `insurance`,
  /// `bank_transfer`, `cheque`.
  final String paymentMethod;

  final String? paymentReference;

  /// Read-only from this app: `CreatePaymentDto` has no such key, so a client
  /// that sends one gets a 400 rather than a stored value.
  final String? cardLastFour;

  final String? mobileMoneyProvider;
  final String? bankName;
  final String? chequeNumber;

  /// Read-only from this app, like [cardLastFour].
  final DateTime? chequeDate;

  final String? processedById;

  final bool isRefund;
  final String? refundReason;
  final String? originalPaymentId;

  final String? notes;

  final DateTime? createdAt;

  final PatientRef patient;

  static const Payment empty = Payment();

  bool get isEmpty => id.isEmpty && receiptNumber.isEmpty;

  /// A refund counts against the ledger, so it is negative wherever a total is
  /// being summed. Kept out of [amount] so the receipt still prints what was
  /// handed over.
  double get signedAmount => isRefund ? -amount : amount;

  /// `Cash`, `Mobile money` — the stored token made readable, without a
  /// switch in every screen that shows one.
  String get methodLabel {
    final method = paymentMethod.trim();
    if (method.isEmpty) return '—';
    final words = method.replaceAll('_', ' ');
    return words[0].toUpperCase() + words.substring(1);
  }

  String amountLabel(MoneyFormat money) => money(signedAmount);

  factory Payment.fromJson(Map<String, dynamic> json) {
    final patient = PatientRef.of(json['patient']);
    return Payment(
      id: asString(json['id'] ?? json['_id']),
      organizationId: asString(json['organizationId']),
      invoiceId: asString(json['invoiceId']),
      patientId: asStringOrNull(json['patientId']) ??
          (patient.isEmpty ? null : patient.id),
      paymentDate: asDate(json['paymentDate']),
      receiptNumber: asString(json['receiptNumber']),
      amount: asDouble(json['amount']),
      paymentMethod: asString(json['paymentMethod']),
      paymentReference: asStringOrNull(json['paymentReference']),
      cardLastFour: asStringOrNull(json['cardLastFour']),
      mobileMoneyProvider: asStringOrNull(json['mobileMoneyProvider']),
      bankName: asStringOrNull(json['bankName']),
      chequeNumber: asStringOrNull(json['chequeNumber']),
      chequeDate: asDate(json['chequeDate']),
      processedById: asStringOrNull(json['processedById']),
      isRefund: asBool(json['isRefund']),
      refundReason: asStringOrNull(json['refundReason']),
      originalPaymentId: asStringOrNull(json['originalPaymentId']),
      notes: asStringOrNull(json['notes']),
      createdAt: asDate(json['createdAt']),
      patient: patient,
    );
  }

  factory Payment.of(dynamic value) =>
      value is Map ? Payment.fromJson(value.cast<String, dynamic>()) : empty;
}
