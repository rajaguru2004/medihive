import 'package:get/get.dart';

import '../../data/models/access_map.dart';
import '../../routes/middlewares/auth_middleware.dart';
import '../lab_catalog/bindings/lab_catalog_binding.dart';
import '../lab_catalog/views/lab_catalog_view.dart';
import '../lab_order_detail/bindings/lab_order_detail_binding.dart';
import '../lab_order_detail/views/lab_order_detail_view.dart';
import '../lab_order_form/bindings/lab_order_form_binding.dart';
import '../lab_order_form/views/lab_order_form_view.dart';
import '../lab_result_form/bindings/lab_result_form_binding.dart';
import '../lab_result_form/views/lab_result_form_view.dart';
import '../lab_test_form/bindings/lab_test_form_binding.dart';
import '../lab_test_form/views/lab_test_form_view.dart';
import 'bindings/laboratory_binding.dart';
import 'views/laboratory_view.dart';

/// Route names for the laboratory's six screens.
///
/// Held here rather than in `Routes` because this module was built alongside
/// the route table rather than into it. They are plain strings and they match
/// the paths the table registers, so a screen can navigate today and the
/// constants can move without a single call site changing.
///
/// **Registration order matters for two of them.** `/laboratory/orders/new`
/// has to be registered *before* `/laboratory/orders/:id`, or GetX matches the
/// parameterised route first and the new-order screen opens as an order whose
/// id is the word "new".
abstract final class LabRoutes {
  /// The worklist. The same path the app's own `Routes.LABORATORY` holds.
  static const String worklist = '/laboratory';

  static const String orderNew = '/laboratory/orders/new';

  /// The pattern, with its parameter. Use [order] to build one.
  static const String orderDetail = '/laboratory/orders/:id';

  static const String resultNew = '/laboratory/results/new';

  static const String catalog = '/laboratory/tests';
  static const String testEdit = '/laboratory/tests/edit';

  /// The detail path for one order.
  static String order(String id) => '/laboratory/orders/$id';
}

/// The six `GetPage`s this module needs, ready to splice into the app's own
/// route table.
///
/// Held here rather than written out in `app_pages.dart` so the wiring is one
/// line — `...LabPages.routes` — and so the two rules the registration has to
/// respect travel with it:
///
///   * `/laboratory/orders/new` is listed **before** `/laboratory/orders/:id`,
///     or GetX matches the parameterised route first and the new-order screen
///     opens as an order whose id is the word "new";
///   * only the worklist is gated on the module. The screens under it are
///     reached from it, and gating each one again would send somebody whose
///     role changed mid-order to a refusal screen with their typed notes
///     behind it.
abstract final class LabPages {
  static List<GetPage<dynamic>> get routes => [
        GetPage<dynamic>(
          name: LabRoutes.worklist,
          // Pushed rather than embedded: this copy draws its own header. The
          // shell's Lab tab builds `LaboratoryView()` with the default
          // `embedded: true` instead.
          page: () => const LaboratoryView(embedded: false),
          binding: LaboratoryBinding(),
          middlewares: [
            AuthMiddleware(module: Modules.laboratory, moduleName: 'Laboratory'),
          ],
          transition: Transition.cupertino,
        ),
        GetPage<dynamic>(
          name: LabRoutes.catalog,
          page: () => const LabCatalogView(),
          binding: LabCatalogBinding(),
          middlewares: [AuthMiddleware()],
          transition: Transition.cupertino,
        ),
        GetPage<dynamic>(
          name: LabRoutes.testEdit,
          page: () => const LabTestFormView(),
          binding: LabTestFormBinding(),
          middlewares: [AuthMiddleware()],
          transition: Transition.cupertino,
        ),
        GetPage<dynamic>(
          name: LabRoutes.resultNew,
          page: () => const LabResultFormView(),
          binding: LabResultFormBinding(),
          middlewares: [AuthMiddleware()],
          transition: Transition.cupertino,
        ),
        // Before the parameterised route below it. See the note above.
        GetPage<dynamic>(
          name: LabRoutes.orderNew,
          page: () => const LabOrderFormView(),
          binding: LabOrderFormBinding(),
          middlewares: [AuthMiddleware()],
          transition: Transition.cupertino,
        ),
        GetPage<dynamic>(
          name: LabRoutes.orderDetail,
          page: () => const LabOrderDetailView(),
          binding: LabOrderDetailBinding(),
          middlewares: [AuthMiddleware()],
          transition: Transition.cupertino,
        ),
      ];
}
