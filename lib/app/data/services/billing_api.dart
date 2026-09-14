import 'package:get/get.dart' hide Response;

import '../models/billing_service.dart';
import '../models/invoice.dart';
import '../models/json.dart';
import '../models/payment.dart';
import '../network/dio_client.dart';
import '../network/endpoints.dart';
import '../repositories/crud_repository.dart';
import '../utils/api_envelope.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — billing's three collections
///
/// A catalogue of what can be charged, the invoices raised against it, and the
/// payments taken against those. Each is a plain [CrudRepository]; this file
/// holds the two things that are not — the stats figures, and the fact that
/// `/billing/payments` has no PATCH.
///
/// ## The name
///
/// **`BillingApi`, not `BillingService`.** `BillingService` is already a model
/// in this app (`data/models/billing_service.dart`) — one catalogue entry, a
/// consultation or a procedure. This codebase has been bitten by exactly that
/// collision once already: `QueueService` was a service *and* a DTO, and every
/// file that needed both had to alias one of them. A screen here imports the
/// model and the repositories together on almost every route, so the two names
/// must not be the same word.
///
/// Deliberately **not** a `GetxService`, for the same reason
/// `LaboratoryService` is not: there is no state to hold — the repositories
/// read their client from the container at call time — and a service registered
/// in one binding and found in another throws the first time somebody deep
/// links past the screen that registered it.
/// ─────────────────────────────────────────────────────────────────────────────
class BillingApi {
  const BillingApi();

  InvoiceRepository get invoices => const InvoiceRepository();
  PaymentRepository get payments => const PaymentRepository();
  BillingCatalogRepository get catalogue => const BillingCatalogRepository();

  /// The five figures above the invoice list.
  Future<BillingStats> stats() async {
    final response = await Get.find<DioClient>().get(Endpoints.billingStats);
    return BillingStats.fromJson(ApiEnvelope.of(response).orThrow().object);
  }
}

/// What a billing write announces itself as on the `DataBus`.
///
/// Three names rather than one: a payment changes the invoice it was taken
/// against, so the invoice list has to hear about both, while the catalogue is
/// its own thing and does not want reloading because somebody paid a bill.
abstract final class BillingEntities {
  static const String invoices = 'invoices';
  static const String payments = 'payments';
  static const String services = 'billing-services';
}

/// Patients' bills.
///
/// `GET /api/billing/invoices` answers a **bare array** unless `page` is sent,
/// in which case it answers `{data, meta}`. `ApiEnvelope` flattens both, and
/// `PagedQuery` always sends `page`, so this list pages properly.
class InvoiceRepository extends CrudRepository<Invoice> {
  const InvoiceRepository()
      : super(Endpoints.invoices, Invoice.fromJson, BillingEntities.invoices);

  /// Moves the document along — `sent`, `overdue`, `paid`, `cancelled`.
  ///
  /// `UpdateInvoiceDto` accepts `status`, `paymentStatus`, `notes` and
  /// `cancellationReason` and nothing else. **There is no `items`**, which is
  /// correct behaviour for a document somebody has been handed: a raised
  /// invoice's lines cannot be edited, only cancelled and reissued.
  Future<Invoice> setStatus(
    String id, {
    required String status,
    String? cancellationReason,
  }) =>
      update(id, {
        'status': status,
        if (cancellationReason != null && cancellationReason.trim().isNotEmpty)
          'cancellationReason': cancellationReason.trim(),
      });
}

/// Money received.
///
/// **There is no update route.** `/billing/payments` answers GET and POST only:
/// a payment is corrected by a refund, and a ledger that can be edited is not a
/// ledger. [CrudRepository.update] and `.delete` exist on the superclass and
/// would 404 here; nothing in this module calls them.
class PaymentRepository extends CrudRepository<Payment> {
  const PaymentRepository()
      : super(Endpoints.payments, Payment.fromJson, BillingEntities.payments);

  /// Every payment against one invoice, newest first — the server orders by
  /// `paymentDate` descending.
  ///
  /// A hundred is a ceiling nothing real reaches: an invoice settled in more
  /// than a handful of instalments is a payment plan, not a bill.
  Future<List<Payment>> forInvoice(String invoiceId) async {
    final page = await list(
      PagedQuery(limit: 100, params: {'invoiceId': invoiceId}),
    );
    return page.items;
  }
}

/// The service catalogue — what a site can put on a bill.
///
/// The route reads **`category` only**: `GET /api/billing/services` has no
/// pagination DTO at all, so it answers a bare array however it is asked and
/// `listAll`'s page walk stops after one round. It also filters to
/// `isActive: true` server-side, which is why the catalogue screen cannot show
/// a retired service and the edit form's "Active" switch is one-way from here.
class BillingCatalogRepository extends CrudRepository<BillingService> {
  const BillingCatalogRepository()
      : super(
          Endpoints.billingServices,
          BillingService.fromJson,
          BillingEntities.services,
        );

  /// The whole active catalogue, optionally narrowed to one category.
  Future<List<BillingService>> entries({String? category}) => listUnpaged(
        params: {
          if (category != null && category.trim().isNotEmpty)
            'category': category.trim(),
        },
      );
}

/// The five figures from `GET /api/billing/stats`.
class BillingStats {
  const BillingStats({
    this.todayRevenue = 0,
    this.pendingInvoices = 0,
    this.collectedToday = 0,
    this.outstandingBalance = 0,
    this.totalServices = 0,
  });

  /// Money taken today. The server computes it from the same query as
  /// [collectedToday] — they are the same number, kept as two keys because the
  /// route answers with both and a client that invented one of them would
  /// disagree the day the server stops.
  final double todayRevenue;

  /// Invoices whose `paymentStatus` is `unpaid` or `partially_paid`. A count,
  /// not money.
  final int pendingInvoices;

  final double collectedToday;

  /// The sum of `balanceDue` across every unsettled invoice — what the site is
  /// owed.
  final double outstandingBalance;

  /// Active entries in the catalogue, not charges raised.
  final int totalServices;

  static const BillingStats empty = BillingStats();

  factory BillingStats.fromJson(Map<String, dynamic> json) => BillingStats(
        todayRevenue: asDouble(json['todayRevenue']),
        pendingInvoices: asInt(json['pendingInvoices']),
        collectedToday: asDouble(json['collectedToday']),
        outstandingBalance: asDouble(json['outstandingBalance']),
        totalServices: asInt(json['totalServices']),
      );
}
