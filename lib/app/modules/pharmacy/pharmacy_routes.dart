import 'package:get/get.dart';

import '../../data/models/access_map.dart';
import '../../routes/middlewares/auth_middleware.dart';
import 'bindings/dispense_binding.dart';
import 'bindings/drug_form_binding.dart';
import 'bindings/pharmacy_binding.dart';
import 'bindings/prescription_detail_binding.dart';
import 'bindings/sale_form_binding.dart';
import 'views/dispense_view.dart';
import 'views/drug_form_view.dart';
import 'views/pharmacy_view.dart';
import 'views/prescription_detail_view.dart';
import 'views/sale_form_view.dart';

/// The pharmacy's five route names.
///
/// Held here rather than in `Routes` because this module was built alongside
/// the route table rather than into it. They are plain strings and they match
/// the paths [PharmacyPages] registers, so a screen can navigate today and the
/// constants can move into `Routes` without a call site changing. `/pharmacy`
/// is deliberately the same path the app's own `Routes.PHARMACY` already holds.
///
/// The two prescription routes carry their record's id in the path, so a
/// dispense can be deep-linked out of a handover message. GetX fills
/// `Get.parameters['id']` from the `:id` segment — but only for a route pushed
/// by path, so both controllers also accept the record itself in
/// `Get.arguments`, which is how the counter hands one over without a second
/// round trip for something it is already holding.
abstract final class PharmacyRoutes {
  /// The counter: figures, the dispensing queue, the shelf, today's sales.
  static const String hub = '/pharmacy';

  /// A catalogue entry, new or edited. The drug being edited arrives in
  /// `Get.arguments`; there is no `GET /pharmacy/drugs/:id` to fall back on.
  static const String drugForm = '/pharmacy/drugs/edit';

  /// A walk-in sale.
  static const String saleForm = '/pharmacy/sales/new';

  /// The pattern. Use [prescriptionDetailFor] to build one.
  static const String prescriptionDetail = '/pharmacy/prescriptions/:id';

  /// The pattern. Use [dispenseFor] to build one.
  static const String dispense = '/pharmacy/prescriptions/:id/dispense';

  static String prescriptionDetailFor(String id) =>
      '/pharmacy/prescriptions/$id';

  static String dispenseFor(String id) => '/pharmacy/prescriptions/$id/dispense';
}

/// The pages, ready to splice into `AppPages.routes`.
///
/// `/pharmacy` replaces the placeholder `GetPage` that holds it today, and the
/// shell destination's `body:` becomes `const PharmacyView()` — embedded by
/// default, so the tab does not paint a second ground over the shell's.
///
/// **Registration order is load-bearing.** `ParseRouteTree._findRoute` takes
/// the first pattern that matches, so the literal paths come before the two
/// that carry a `:id`. They do not collide today — `/pharmacy/drugs/edit` and
/// `/pharmacy/prescriptions/:id` differ in their second segment — but a future
/// `/pharmacy/:id` would swallow both. The list below is already in that
/// order; splice it whole rather than reordering it.
abstract final class PharmacyPages {
  static List<GetPage<dynamic>> get pages => [
        GetPage(
          name: PharmacyRoutes.hub,
          // Pushed rather than embedded: the shell hosts its own instance.
          page: () => const PharmacyView(embedded: false),
          binding: PharmacyBinding(),
          middlewares: _gate,
          transition: _push,
        ),
        GetPage(
          name: PharmacyRoutes.drugForm,
          page: () => const DrugFormView(),
          binding: DrugFormBinding(),
          middlewares: _gate,
          transition: _push,
        ),
        GetPage(
          name: PharmacyRoutes.saleForm,
          page: () => const SaleFormView(),
          binding: SaleFormBinding(),
          middlewares: _gate,
          transition: _push,
        ),
        GetPage(
          name: PharmacyRoutes.dispense,
          page: () => const DispenseView(),
          binding: DispenseBinding(),
          middlewares: _gate,
          transition: _push,
        ),
        GetPage(
          name: PharmacyRoutes.prescriptionDetail,
          page: () => const PrescriptionDetailView(),
          binding: PrescriptionDetailBinding(),
          middlewares: _gate,
          transition: _push,
        ),
      ];

  /// One transition, matching `AppPages._push`.
  static const _push = Transition.cupertino;

  /// The same gate every other module route carries: signed in, and granted
  /// the pharmacy module. The screens still handle a 403 of their own — an
  /// access map in hand can be a minute older than the role it describes.
  static List<GetMiddleware> get _gate =>
      [AuthMiddleware(module: Modules.pharmacy, moduleName: 'Pharmacy')];
}
