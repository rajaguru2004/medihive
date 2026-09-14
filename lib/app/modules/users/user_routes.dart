import 'package:get/get.dart';

import '../../data/models/access_map.dart';
import '../../routes/middlewares/auth_middleware.dart';
import '../role_editor/bindings/role_editor_binding.dart';
import '../role_editor/views/role_editor_view.dart';
import '../user_detail/bindings/user_detail_binding.dart';
import '../user_detail/views/user_detail_view.dart';
import '../user_form/bindings/user_form_binding.dart';
import '../user_form/views/user_form_view.dart';
import 'bindings/users_binding.dart';
import 'views/users_view.dart';

/// The four route names the staff module needs registered.
///
/// Declared here rather than in `Routes` because `lib/app/routes/` belongs to
/// another stream; these are the strings that table should carry, and every
/// navigation inside this module already reads them, so wiring them up is one
/// edit there and none here.
///
/// **`/staff/record` rather than `/staff/:id`.** GetX resolves a named route
/// against a tree of segments, and a `:id` registered at that position matches
/// the literal `edit` too — so the record screen would swallow its sibling and
/// open with `id: 'edit'`. See the same note at the top of
/// `lib/app/modules/patients/patient_routes.dart`. The id travels in
/// `Get.arguments`, which is how every other detail screen in this app
/// receives one.
abstract final class StaffRoutes {
  /// The directory. The same path the app's own `Routes.USERS_STAFF` holds.
  static const String list = '/staff';

  /// Add somebody, or edit them — `{'user': StaffUser}` for the edit.
  static const String form = '/staff/edit';

  /// One account — `{'id': …}`, optionally `{'user': StaffUser}` so the header
  /// paints before the refetch lands.
  static const String record = '/staff/record';

  /// The permission editor, opened from a card on `/settings/roles`.
  /// `{'role': Role}`, or `{'id': …}` from a deep link.
  static const String roleEditor = '/settings/roles/edit';

  /// The id, out of whatever shape a caller passed.
  ///
  /// Accepts the bare string as well as the map, because half the call sites
  /// in an app like this are written as `arguments: user.id` and a screen that
  /// only reads the map opens on a blank record with no error.
  static String idFrom(Object? arguments, {String key = 'id'}) {
    if (arguments is String) return arguments;
    if (arguments is Map && arguments[key] != null) {
      return arguments[key].toString();
    }
    return '';
  }
}

/// The pages, ready to splice into `AppPages.routes`.
///
/// Every segment here is a literal, so registration order is not load-bearing
/// the way billing's is — but the list is in the order a reader walks the
/// module, and `/staff` must come before the placeholder it replaces:
/// `ParseRouteTree._findRoute` takes the **first** pattern that matches, so a
/// stale `/staff` left above this one keeps the placeholder on screen.
abstract final class StaffPages {
  static List<GetPage<dynamic>> get pages => [
        GetPage(
          name: StaffRoutes.list,
          // Pushed rather than embedded: this copy draws its own header.
          // Without the flag there is no `Scaffold` above it, and a `Text`
          // with no `Material` ancestor is drawn with a yellow underline
          // through it.
          page: () => const UsersView(embedded: false),
          binding: UsersBinding(),
          middlewares: _staffGate,
          transition: _push,
        ),
        GetPage(
          name: StaffRoutes.form,
          page: () => const UserFormView(),
          binding: UserFormBinding(),
          middlewares: _staffGate,
          transition: _push,
        ),
        GetPage(
          name: StaffRoutes.record,
          page: () => const UserDetailView(),
          binding: UserDetailBinding(),
          middlewares: _staffGate,
          transition: _push,
        ),
        GetPage(
          name: StaffRoutes.roleEditor,
          page: () => const RoleEditorView(),
          binding: RoleEditorBinding(),
          middlewares: _rolesGate,
          transition: _push,
        ),
      ];

  /// One transition, matching `AppPages._push`.
  static const _push = Transition.cupertino;

  /// Signed in, and granted the module. The screens still handle a 403 of
  /// their own — an access map in hand can be a minute older than the role it
  /// describes, and the directory's whole fallback exists because one of these
  /// routes refuses an account the map says is allowed.
  static List<GetMiddleware> get _staffGate =>
      [AuthMiddleware(module: Modules.users, moduleName: 'Users and staff')];

  static List<GetMiddleware> get _rolesGate =>
      [AuthMiddleware(module: Modules.roles, moduleName: 'Roles and access')];
}
