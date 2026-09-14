import 'package:get/get.dart';

import '../../data/models/access_map.dart';
import '../../routes/middlewares/auth_middleware.dart';
import '../radiology_catalog/bindings/radiology_catalog_binding.dart';
import '../radiology_catalog/views/radiology_catalog_view.dart';
import '../radiology_exam_form/bindings/radiology_exam_form_binding.dart';
import '../radiology_exam_form/views/radiology_exam_form_view.dart';
import '../radiology_order_detail/bindings/radiology_order_detail_binding.dart';
import '../radiology_order_detail/views/radiology_order_detail_view.dart';
import '../radiology_order_form/bindings/radiology_order_form_binding.dart';
import '../radiology_order_form/views/radiology_order_form_view.dart';
import '../radiology_report_form/bindings/radiology_report_form_binding.dart';
import '../radiology_report_form/views/radiology_report_form_view.dart';
import 'bindings/radiology_binding.dart';
import 'views/radiology_view.dart';

/// Route names for imaging's six screens.
///
/// Held here rather than in `Routes` because this module was built alongside
/// the route table rather than into it. They are plain strings and they match
/// the paths [RadiologyPages] registers, so a screen can navigate today and
/// the constants can move into `Routes` without a single call site changing.
abstract final class RadiologyRoutes {
  /// The worklist. The same path the app's own `Routes.RADIOLOGY` holds, and
  /// the shell's Imaging tab.
  static const String worklist = '/radiology';

  static const String orderNew = '/radiology/orders/new';

  /// The pattern, with its parameter. Use [orderFor] to build one.
  static const String orderDetail = '/radiology/orders/:id';

  static const String reportNew = '/radiology/reports/new';
  static const String reportEdit = '/radiology/reports/edit';

  static const String catalog = '/radiology/exams';

  /// The catalogue form, for a new entry and for an existing one. Which it is
  /// comes from `Get.arguments`, because an exam being created has no id to
  /// put in a path.
  static const String examForm = '/radiology/exams/edit';

  /// The detail path for one order.
  static String orderFor(String id) => '/radiology/orders/$id';
}

/// The pages, ready to splice into `AppPages.routes`.
///
/// **Registration order is load-bearing.** `ParseRouteTree._findRoute` takes
/// the *first* registered pattern that matches, and `/radiology/orders/new`
/// also matches `/radiology/orders/:id` — so the order form has to come first
/// or raising a request opens a detail screen for an order called "new". The
/// list below is already in that order: splice it whole rather than sorting
/// it.
abstract final class RadiologyPages {
  static List<GetPage<dynamic>> get pages => [
        GetPage(
          name: RadiologyRoutes.worklist,
          // Pushed rather than hosted in the shell, so it draws its own
          // header. The shell's Imaging tab builds `RadiologyView()` with the
          // default `embedded: true` instead.
          page: () => const RadiologyView(embedded: false),
          binding: RadiologyBinding(),
          middlewares: _gate,
          transition: _push,
        ),
        GetPage(
          name: RadiologyRoutes.catalog,
          page: () => const RadiologyCatalogView(),
          binding: RadiologyCatalogBinding(),
          middlewares: _gate,
          transition: _push,
        ),
        GetPage(
          name: RadiologyRoutes.examForm,
          page: () => const RadiologyExamFormView(),
          binding: RadiologyExamFormBinding(),
          middlewares: _gate,
          transition: _push,
        ),
        GetPage(
          name: RadiologyRoutes.reportNew,
          page: () => const RadiologyReportFormView(),
          binding: RadiologyReportFormBinding(),
          middlewares: _gate,
          transition: _push,
        ),
        GetPage(
          name: RadiologyRoutes.reportEdit,
          page: () => const RadiologyReportFormView(),
          binding: RadiologyReportFormBinding(),
          middlewares: _gate,
          transition: _push,
        ),
        GetPage(
          name: RadiologyRoutes.orderNew,
          page: () => const RadiologyOrderFormView(),
          binding: RadiologyOrderFormBinding(),
          middlewares: _gate,
          transition: _push,
        ),
        // Last of the six: its `:id` swallows every path above it.
        GetPage(
          name: RadiologyRoutes.orderDetail,
          page: () => const RadiologyOrderDetailView(),
          binding: RadiologyOrderDetailBinding(),
          middlewares: _gate,
          transition: _push,
        ),
      ];

  /// One transition, matching `AppPages._push`.
  static const _push = Transition.cupertino;

  /// The same gate every other module route carries: signed in, and granted
  /// the radiology module. The screens still handle a 403 of their own — an
  /// access map in hand can be a minute older than the role it describes.
  static List<GetMiddleware> get _gate =>
      [AuthMiddleware(module: Modules.radiology, moduleName: 'Radiology')];
}
