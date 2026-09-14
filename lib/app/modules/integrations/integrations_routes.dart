import 'package:get/get.dart';

import '../../data/models/access_map.dart';
import '../../routes/middlewares/auth_middleware.dart';
import '../machine_form/bindings/machine_form_binding.dart';
import '../machine_form/views/machine_form_view.dart';
import 'bindings/integrations_binding.dart';
import 'views/integrations_view.dart';

/// Route names for the instrument link's two screens.
///
/// Held here rather than in `Routes` because this module was built alongside
/// the route table rather than into it. They are plain strings and [hub] is the
/// same path the app's own `Routes.INTEGRATIONS` holds, so a screen can
/// navigate today and the constants can move into `Routes` without a single
/// call site changing.
abstract final class IntegrationsRoutes {
  /// The hub. The same path `Routes.INTEGRATIONS` holds.
  static const String hub = '/integrations';

  /// One device, new or existing. The record travels in `arguments`, under the
  /// key `machine`; no argument at all means "register a new one".
  static const String machineEdit = '/integrations/machines/edit';
}

/// The pages, ready to splice into `AppPages.routes`.
///
/// **Registration order is load-bearing.** `ParseRouteTree._findRoute` takes the
/// *first* pattern that matches a path, so a literal segment has to be
/// registered before any `:id` sibling that would also match it. Nothing here
/// is parameterised yet — but `/integrations/machines/edit` is listed before
/// `/integrations/machines/:id` would be, so adding that route later is one
/// line at the end rather than a reordering that has to be reasoned about
/// again. Splice this list whole.
abstract final class IntegrationsPages {
  static List<GetPage<dynamic>> get pages => [
        GetPage<dynamic>(
          name: IntegrationsRoutes.hub,
          // Pushed rather than embedded: this copy draws its own header. The
          // shell's Devices tab builds `IntegrationsView()` with the default
          // `embedded: true` instead.
          page: () => const IntegrationsView(embedded: false),
          binding: IntegrationsBinding(),
          middlewares: _gate,
          transition: _push,
        ),
        GetPage<dynamic>(
          name: IntegrationsRoutes.machineEdit,
          page: () => const MachineFormView(),
          binding: MachineFormBinding(),
          middlewares: _gate,
          transition: _push,
        ),
      ];

  /// One transition, matching `AppPages._push`.
  static const _push = Transition.cupertino;

  /// The same gate every other module route carries: signed in, and granted the
  /// integrations module. The screens still handle a 403 of their own — an
  /// access map in hand can be a minute older than the role it describes.
  static List<GetMiddleware> get _gate => [
        AuthMiddleware(
          module: Modules.integrations,
          moduleName: 'Integrations',
        ),
      ];
}
