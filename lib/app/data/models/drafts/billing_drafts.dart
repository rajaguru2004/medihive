
import 'draft_json.dart';

/// One line on an invoice.
///
/// DTO: `CreateInvoiceItemDto` in
/// `hms_v2/src/modules/billing/dto/invoice.dto.ts`.
class InvoiceItemDraft {
  const InvoiceItemDraft({
    this.type,
    this.referenceId,
    this.description,
    this.quantity,
    this.unitPrice,
    this.discount,
    this.tax,
    this.total,
  });

  /// What kind of thing is billed — `service`, `lab`, `radiology`, `pharmacy`,
  /// `bed`. Free text on the backend, so not an enum here.
  final String? type;

  /// The record this line bills for, where there is one.
  final String? referenceId;
  final String? description;
  final int? quantity;
  final double? unitPrice;

  /// Money off this line, not a percentage.
  final double? discount;
  final double? tax;

  /// Sent rather than derived: a client that recomputes a line can disagree
  /// with the invoice the patient was handed.
  final double? total;

  InvoiceItemDraft copyWith({
    String? type,
    String? referenceId,
    String? description,
    int? quantity,
    double? unitPrice,
    double? discount,
    double? tax,
    double? total,
  }) =>
      InvoiceItemDraft(
        type: type ?? this.type,
        referenceId: referenceId ?? this.referenceId,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        discount: discount ?? this.discount,
        tax: tax ?? this.tax,
        total: total ?? this.total,
      );

  Map<String, dynamic> toJson() => draftBody({
        'type': type,
        'referenceId': referenceId,
        'description': description,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discount': discount,
        'tax': tax,
        'total': total,
      });
}

/// A bill being raised, or its status being moved.
///
/// DTO: `hms_v2/src/modules/billing/dto/invoice.dto.ts` (`CreateInvoiceDto` /
/// `UpdateInvoiceDto`).
///
/// The two halves share only `notes`. A raised invoice's lines cannot be edited
/// — the update DTO has no `items` — which is the correct behaviour for a
/// document somebody has been handed.
class InvoiceDraft {
  const InvoiceDraft({
    this.patientId,
    this.consultationId,
    this.items,
    this.discountAmount,
    this.discountPercentage,
    this.dueDate,
    this.notes,
    this.status,
    this.paymentStatus,
    this.cancellationReason,
  });

  /// Create only.
  final String? patientId;

  /// Create only.
  final String? consultationId;

  /// Create only. An empty list is dropped rather than sent: the DTO accepts
  /// `items: []` and raises a zero-total invoice, which is worse than a 400
  /// because nobody notices.
  final List<InvoiceItemDraft>? items;

  /// Create only.
  final double? discountAmount;

  /// Create only.
  final double? discountPercentage;

  /// Create only. A calendar day: the DTO types it `@IsString()`, not
  /// `@IsDateString()`, and terms are counted in days.
  final DateTime? dueDate;
  final String? notes;

  /// Update only. The document state — `draft`, `sent`, `overdue`, `paid`,
  /// `cancelled`.
  final String? status;

  /// Update only. The money's state — `unpaid`, `partially_paid`, `paid`,
  /// `cancelled`, `refunded`. Separate from [status] on purpose.
  final String? paymentStatus;

  /// Update only.
  final String? cancellationReason;

  InvoiceDraft copyWith({
    String? patientId,
    String? consultationId,
    List<InvoiceItemDraft>? items,
    double? discountAmount,
    double? discountPercentage,
    DateTime? dueDate,
    String? notes,
    String? status,
    String? paymentStatus,
    String? cancellationReason,
  }) =>
      InvoiceDraft(
        patientId: patientId ?? this.patientId,
        consultationId: consultationId ?? this.consultationId,
        items: items ?? this.items,
        discountAmount: discountAmount ?? this.discountAmount,
        discountPercentage: discountPercentage ?? this.discountPercentage,
        dueDate: dueDate ?? this.dueDate,
        notes: notes ?? this.notes,
        status: status ?? this.status,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        cancellationReason: cancellationReason ?? this.cancellationReason,
      );

  Map<String, dynamic> toCreateJson() => draftBody({
        'patientId': patientId,
        'consultationId': consultationId,
        'items': items?.map((item) => item.toJson()).toList(),
        'discountAmount': discountAmount,
        'discountPercentage': discountPercentage,
        'notes': notes,
        'dueDate': isoDay(dueDate),
      });

  Map<String, dynamic> toUpdateJson() => draftBody({
        'status': status,
        'paymentStatus': paymentStatus,
        'notes': notes,
        'cancellationReason': cancellationReason,
      });
}

/// Money received against an invoice.
///
/// DTO: `CreatePaymentDto` in `hms_v2/src/modules/billing/dto/payment.dto.ts`.
///
/// **There is no update route.** `/billing/payments` answers GET and POST only,
/// so [toUpdateJson] is empty: a payment is corrected by a refund, and a ledger
/// that can be edited is not a ledger.
///
/// The stored row also carries `cardLastFour` and `chequeDate`; the DTO carries
/// neither, so both are read-only from this app.
class PaymentDraft {
  const PaymentDraft({
    this.invoiceId,
    this.patientId,
    this.amount,
    this.paymentMethod,
    this.paymentReference,
    this.mobileMoneyProvider,
    this.bankName,
    this.chequeNumber,
    this.notes,
  });

  final String? invoiceId;
  final String? patientId;

  /// The raw amount. The DTO rejects anything below 0.01, so a zero payment is
  /// not a way to mark an invoice seen.
  final double? amount;

  /// `cash`, `credit_card`, `debit_card`, `mobile_money`, `insurance`,
  /// `bank_transfer`, `cheque`. The DTO rejects anything else.
  final String? paymentMethod;
  final String? paymentReference;
  final String? mobileMoneyProvider;
  final String? bankName;
  final String? chequeNumber;
  final String? notes;

  PaymentDraft copyWith({
    String? invoiceId,
    String? patientId,
    double? amount,
    String? paymentMethod,
    String? paymentReference,
    String? mobileMoneyProvider,
    String? bankName,
    String? chequeNumber,
    String? notes,
  }) =>
      PaymentDraft(
        invoiceId: invoiceId ?? this.invoiceId,
        patientId: patientId ?? this.patientId,
        amount: amount ?? this.amount,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        paymentReference: paymentReference ?? this.paymentReference,
        mobileMoneyProvider: mobileMoneyProvider ?? this.mobileMoneyProvider,
        bankName: bankName ?? this.bankName,
        chequeNumber: chequeNumber ?? this.chequeNumber,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toCreateJson() => draftBody({
        'invoiceId': invoiceId,
        'patientId': patientId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'paymentReference': paymentReference,
        'mobileMoneyProvider': mobileMoneyProvider,
        'bankName': bankName,
        'chequeNumber': chequeNumber,
        'notes': notes,
      });

  /// Always empty: the payments route has no PATCH.
  Map<String, dynamic> toUpdateJson() => const {};
}

/// A service-catalogue entry being added or edited.
///
/// DTO: `hms_v2/src/modules/billing/dto/service.dto.ts`
/// (`CreateBillingServiceDto` / `UpdateBillingServiceDto`, which adds
/// `isActive`).
class BillingServiceDraft {
  const BillingServiceDraft({
    this.serviceName,
    this.serviceCode,
    this.serviceCategory,
    this.department,
    this.unitPrice,
    this.isTaxable,
    this.taxPercentage,
    this.isCoveredByInsurance,
    this.insuranceCopayPercentage,
    this.description,
    this.isActive,
  });

  final String? serviceName;
  final String? serviceCode;

  /// `consultation`, `procedure`, `accommodation`.
  final String? serviceCategory;
  final String? department;

  /// Required on create. Zero is a value — a free service is a real entry in a
  /// catalogue.
  final double? unitPrice;
  final bool? isTaxable;

  /// Percent, not a fraction — `15`, not `0.15`.
  final double? taxPercentage;

  /// The column defaults to true. A service that silently reads as uncovered
  /// quotes a patient the full price.
  final bool? isCoveredByInsurance;
  final double? insuranceCopayPercentage;
  final String? description;

  /// Update only.
  final bool? isActive;

  BillingServiceDraft copyWith({
    String? serviceName,
    String? serviceCode,
    String? serviceCategory,
    String? department,
    double? unitPrice,
    bool? isTaxable,
    double? taxPercentage,
    bool? isCoveredByInsurance,
    double? insuranceCopayPercentage,
    String? description,
    bool? isActive,
  }) =>
      BillingServiceDraft(
        serviceName: serviceName ?? this.serviceName,
        serviceCode: serviceCode ?? this.serviceCode,
        serviceCategory: serviceCategory ?? this.serviceCategory,
        department: department ?? this.department,
        unitPrice: unitPrice ?? this.unitPrice,
        isTaxable: isTaxable ?? this.isTaxable,
        taxPercentage: taxPercentage ?? this.taxPercentage,
        isCoveredByInsurance: isCoveredByInsurance ?? this.isCoveredByInsurance,
        insuranceCopayPercentage: insuranceCopayPercentage ?? this.insuranceCopayPercentage,
        description: description ?? this.description,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> _shared() => {
        'serviceName': serviceName,
        'serviceCode': serviceCode,
        'serviceCategory': serviceCategory,
        'department': department,
        'unitPrice': unitPrice,
        'isTaxable': isTaxable,
        'taxPercentage': taxPercentage,
        'isCoveredByInsurance': isCoveredByInsurance,
        'insuranceCopayPercentage': insuranceCopayPercentage,
        'description': description,
      };

  Map<String, dynamic> toCreateJson() => draftBody(_shared());

  Map<String, dynamic> toUpdateJson() => draftBody({
        ..._shared(),
        'isActive': isActive,
      });
}
