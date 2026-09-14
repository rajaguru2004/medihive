import 'package:get/get.dart';

import '../../../data/models/access_map.dart';
import '../../../data/models/invoice.dart';
import '../../../data/models/payment.dart';
import '../../../data/models/site_settings.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/billing_api.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/load_state.dart';
import '../../billing/billing_status.dart';

/// One bill, and every way it can be moved along.
///
/// Tagged by invoice id rather than registered once, because a tablet shows
/// this beside the ledger: two invoices can be alive at the same time, and one
/// controller between them would show the second bill's payments under the
/// first bill's header.
class InvoiceDetailController extends GetxController with LoadStateMixin {
  InvoiceDetailController({required this.invoiceId});

  final String invoiceId;

  static const BillingApi _billing = BillingApi();

  final invoice = Invoice.empty.obs;
  final payments = <Payment>[].obs;

  /// A write in flight. Separate from [rxLoading] so acting on the invoice does
  /// not collapse it back to a skeleton under the thumb that pressed it.
  final isSaving = false.obs;

  /// What went wrong with the last action, in the server's own words.
  ///
  /// A banner on the screen rather than a toast: a refused action is something
  /// somebody has to do differently, and three seconds is not long enough to
  /// read why — and the toast takes the explanation with it.
  final actionError = RxnString();

  MoneyFormat get money => SettingsService.to.settings.money;

  bool get canUpdate => AccessService.to.can(Modules.billing, AccessVerb.update);
  bool get canCreate => AccessService.to.can(Modules.billing, AccessVerb.create);
  bool get canRead => AccessService.to.canRead(Modules.billing);

  /// The document state, corrected for a due date the nightly sweep has not
  /// reached yet. See `BillingController.statusOf`.
  String get status =>
      invoice.value.overdue() ? InvoiceStatus.overdue : invoice.value.status;

  /// What is still owed.
  double get outstanding => invoice.value.outstanding;

  /// Paid against total, for the bar. Never NaN and never past one: a zero
  /// total is a real invoice — every line was discounted to nothing — and
  /// dividing by it would paint the bar as a rendering fault.
  double get paidFraction {
    final total = invoice.value.totalAmount;
    if (total <= 0) return invoice.value.amountPaid > 0 ? 1 : 0;
    final fraction = invoice.value.amountPaid / total;
    return fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0;
  }

  /// Whether money can still be taken. Both halves matter: the document may be
  /// cancelled, and a settled invoice has nothing left to pay.
  bool get canRecordPayment =>
      canCreate &&
      InvoiceStatus.acceptsPayment(invoice.value.status) &&
      outstanding > 0;

  /// A draft is the only thing that can be *sent*. An invoice already out with
  /// the patient does not get sent twice.
  bool get canMarkSent =>
      canUpdate && invoice.value.status == InvoiceStatus.draft;

  /// Cancelling is off once anything has been paid: the money would have to be
  /// refunded first, and this app has no refund route.
  bool get canCancel =>
      canUpdate &&
      !invoice.value.isCancelled &&
      invoice.value.amountPaid <= 0;

  /// The controller for one invoice, created if this is the first view of it.
  static InvoiceDetailController forInvoice(String id) {
    if (Get.isRegistered<InvoiceDetailController>(tag: id) ||
        Get.isPrepared<InvoiceDetailController>(tag: id)) {
      return Get.find<InvoiceDetailController>(tag: id);
    }
    return Get.put(InvoiceDetailController(invoiceId: id), tag: id);
  }

  /// The invoice id this screen was opened for.
  ///
  /// `Get.arguments` wins over the path so a caller that already holds the
  /// record does not have to round-trip it through a URL; the path is what a
  /// deep link and the route table carry.
  static String routeInvoiceId() {
    final args = Get.arguments;
    if (args is Map && args['invoiceId'] is String) {
      return args['invoiceId'] as String;
    }
    return Get.parameters['id'] ?? '';
  }

  @override
  void onReady() {
    super.onReady();
    load();

    if (Get.isRegistered<DataBus>()) {
      // A payment recorded on the screen this one pushed writes a payment and
      // updates the invoice. Both ticks land here, and neither controller has
      // to know the other exists.
      for (final entity in [
        BillingEntities.invoices,
        BillingEntities.payments,
      ]) {
        ever<int>(DataBus.to.tick(entity), (_) {
          if (!isLoading && !isSaving.value) load(silent: true);
        });
      }
    }
  }

  Future<void> load({bool silent = false}) async {
    if (!canRead) {
      rxNoAccess.value = true;
      rxFirstLoad.value = false;
      return;
    }
    if (invoiceId.isEmpty) return;

    await runGuarded(
      () async {
        final record = await _billing.invoices.read(invoiceId);
        invoice.value = record;
        // `GET /billing/invoices/:id` includes `payments`, so the usual case
        // costs one request. The list route is the fallback for a payload that
        // arrived without them — an invoice whose history renders empty reads
        // as "nobody has paid", which is the one thing it must never say by
        // accident.
        payments.assignAll(
          record.payments.isNotEmpty
              ? record.payments
              : await _billing.payments.forInvoice(invoiceId),
        );
      },
      fallback: "Couldn't load that invoice.",
      silent: silent,
    );
  }

  Future<void> reload() => load(silent: true);

  /// Marks the bill sent. Returns true when the server took it.
  Future<bool> markSent() => _move(
        status: InvoiceStatus.sent,
        failure: "Couldn't mark that invoice sent.",
      );

  /// Cancels the bill. The reason is required — a cancelled invoice with no
  /// reason on it is a number somebody has to reconstruct from an audit log.
  Future<bool> cancel(String reason) => _move(
        status: InvoiceStatus.cancelled,
        cancellationReason: reason,
        failure: "Couldn't cancel that invoice.",
      );

  Future<bool> _move({
    required String status,
    required String failure,
    String? cancellationReason,
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    actionError.value = null;
    try {
      // The response carries the updated row, so the screen does not wait for
      // a second round trip to show what it just did.
      invoice.value = await _billing.invoices.setStatus(
        invoiceId,
        status: status,
        cancellationReason: cancellationReason,
      );
      return true;
    } catch (e) {
      // Every failure lands here as a sentence, including the 403 the access
      // map did not predict: the map in hand can be a minute older than the
      // role it describes, so a control being present is never proof the write
      // is allowed.
      actionError.value = parseErrorMessage(e, failure);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  void clearActionError() => actionError.value = null;
}
