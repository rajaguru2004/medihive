import 'package:get/get.dart';

import '../../data/models/access_map.dart';
import '../../routes/middlewares/auth_middleware.dart';
import '../billing_invoice_detail/bindings/billing_invoice_detail_binding.dart';
import '../billing_invoice_detail/views/invoice_detail_view.dart';
import '../billing_invoice_form/bindings/billing_invoice_form_binding.dart';
import '../billing_invoice_form/views/invoice_form_view.dart';
import '../billing_payment_form/bindings/billing_payment_form_binding.dart';
import '../billing_payment_form/views/payment_form_view.dart';
import '../billing_service_form/bindings/billing_service_form_binding.dart';
import '../billing_service_form/views/billing_service_form_view.dart';
import '../billing_services/bindings/billing_services_binding.dart';
import '../billing_services/views/billing_services_view.dart';
import 'bindings/billing_binding.dart';
import 'views/billing_view.dart';

/// Route names for billing's six screens.
///
/// Held here rather than in `Routes` because this module was built alongside
/// the route table rather than into it. They are plain strings and they match
/// the paths [BillingPages] registers, so a screen can navigate today and the
/// constants can move into `Routes` without a single call site changing.
abstract final class BillingRoutes {
  /// The ledger. The same path the app's own `Routes.BILLING` holds.
  static const String list = '/billing';

  static const String invoiceNew = '/billing/invoices/new';

  /// The pattern, with its parameter. Use [invoice] to build one.
  static const String invoiceDetail = '/billing/invoices/:id';

  /// The pattern. Use [pay] to build one.
  static const String invoicePay = '/billing/invoices/:id/pay';

  static const String services = '/billing/services';
  static const String serviceEdit = '/billing/services/edit';

  static String invoice(String id) => '/billing/invoices/$id';

  static String pay(String id) => '/billing/invoices/$id/pay';
}

/// The pages, ready to splice into `AppPages.routes`.
///
/// **Registration order is load-bearing, twice.** `ParseRouteTree._findRoute`
/// takes the *first* pattern that matches, so:
///
///   * `/billing/invoices/new` must come before `/billing/invoices/:id`, or the
///     new-invoice screen opens as an invoice whose id is the word "new";
///   * `/billing/services` and `/billing/services/edit` must come before
///     `/billing/invoices/:id` would ever be tried against them — they do not
///     collide today, but a future `/billing/:id` would swallow both.
///
/// The list below is already in that order. Splice it whole rather than
/// reordering it.
abstract final class BillingPages {
  static List<GetPage<dynamic>> get pages => [
        GetPage(
          name: BillingRoutes.list,
          // Pushed rather than embedded: this copy draws its own header.
          // Without the flag the screen renders with no `Scaffold` above
          // it — and a `Text` with no `Material` ancestor is drawn by
          // Flutter with a yellow underline through it, on every label on
          // the screen.
          page: () => const BillingView(embedded: false),
          binding: BillingBinding(),
          middlewares: _gate,
          transition: _push,
        ),
        GetPage(
          name: BillingRoutes.services,
          page: () => const BillingServicesView(),
          binding: BillingServicesBinding(),
          middlewares: _gate,
          transition: _push,
        ),
        GetPage(
          name: BillingRoutes.serviceEdit,
          page: () => const BillingServiceFormView(),
          binding: BillingServiceFormBinding(),
          middlewares: _gate,
          transition: _push,
        ),
        GetPage(
          name: BillingRoutes.invoiceNew,
          page: () => const InvoiceFormView(),
          binding: BillingInvoiceFormBinding(),
          middlewares: _gate,
          transition: _push,
        ),
        GetPage(
          name: BillingRoutes.invoicePay,
          page: () => const PaymentFormView(),
          binding: BillingPaymentFormBinding(),
          middlewares: _gate,
          transition: _push,
        ),
        GetPage(
          name: BillingRoutes.invoiceDetail,
          page: () => const InvoiceDetailView(),
          binding: BillingInvoiceDetailBinding(),
          middlewares: _gate,
          transition: _push,
        ),
      ];

  /// One transition, matching `AppPages._push`.
  static const _push = Transition.cupertino;

  /// The same gate every other module route carries: signed in, and granted
  /// the billing module. The screens still handle a 403 of their own — an
  /// access map in hand can be a minute older than the role it describes.
  static List<GetMiddleware> get _gate =>
      [AuthMiddleware(module: Modules.billing, moduleName: 'Billing')];
}
