import 'package:get/get.dart';

import '../controllers/invoice_detail_controller.dart';

/// Prepares the controller for the invoice this route names.
///
/// Tagged by invoice id, because the same screen is also the ledger's second
/// pane on a tablet — two bills can be alive at once, and one untagged
/// controller between them answers for whichever was opened last.
class BillingInvoiceDetailBinding extends Bindings {
  @override
  void dependencies() {
    final id = InvoiceDetailController.routeInvoiceId();
    Get.lazyPut<InvoiceDetailController>(
      () => InvoiceDetailController(invoiceId: id),
      tag: id,
    );
  }
}
