import 'package:get/get.dart';

import '../../data/models/access_map.dart';
import '../../routes/app_pages.dart';
import '../../routes/middlewares/auth_middleware.dart';
import '../settings_departments/bindings/settings_departments_binding.dart';
import '../settings_departments/views/department_form_view.dart';
import '../settings_departments/views/settings_departments_view.dart';
import '../settings_locale/bindings/settings_locale_binding.dart';
import '../settings_locale/views/settings_locale_view.dart';
import '../settings_modules/bindings/settings_modules_binding.dart';
import '../settings_modules/views/settings_modules_view.dart';
import '../settings_profile/bindings/settings_profile_binding.dart';
import '../settings_profile/views/settings_profile_view.dart';

/// Route names for the settings screens this module adds.
///
/// The four screens the hub already points at have their constants in `Routes`
/// — `SETTINGS_PROFILE`, `SETTINGS_LOCALE`, `SETTINGS_MODULES`,
/// `SETTINGS_DEPARTMENTS` — and this file registers pages against those exact
/// strings rather than second copies of them.
///
/// [departmentForm] is the one that has no constant there yet: it is a screen
/// the hub does not link to, reached only from the department list. Held here
/// as a plain string that matches the path [SettingsPages] registers, so it can
/// move into `Routes` later without a call site changing.
abstract final class SettingsRoutes {
  static const String profile = Routes.SETTINGS_PROFILE;
  static const String locale = Routes.SETTINGS_LOCALE;
  static const String modules = Routes.SETTINGS_MODULES;
  static const String departments = Routes.SETTINGS_DEPARTMENTS;

  /// Adds one when opened with no arguments; edits the `department` it is
  /// handed otherwise.
  static const String departmentForm = '/settings/departments/edit';
}

/// The pages, ready to splice into `AppPages.routes`.
///
/// **Every one of these is a write**, so every one carries
/// `AccessVerb.update` rather than the read gate `_gate` builds. An account
/// with `settings.read` and nothing else can open the hub and see what is set;
/// it must not reach a screen that changes it. That mirrors how
/// `/settings/appearance` and `/settings/clinical` are already registered.
///
/// **Order matters.** `ParseRouteTree` takes the first pattern that matches, so
/// `/settings/departments/edit` is registered before `/settings/departments`.
/// The two differ in segment count today and would not collide — but a future
/// `/settings/departments/:id` would swallow the editor, and the fix is an
/// ordering nobody has to rediscover. Splice the list whole rather than
/// reordering it.
abstract final class SettingsPages {
  static List<GetPage<dynamic>> get pages => [
        GetPage(
          name: SettingsRoutes.profile,
          page: () => const SettingsProfileView(),
          binding: SettingsProfileBinding(),
          middlewares: _writeGate('Hospital profile'),
          transition: _push,
        ),
        GetPage(
          name: SettingsRoutes.locale,
          page: () => const SettingsLocaleView(),
          binding: SettingsLocaleBinding(),
          middlewares: _writeGate('Locale and money'),
          transition: _push,
        ),
        GetPage(
          name: SettingsRoutes.modules,
          page: () => const SettingsModulesView(),
          binding: SettingsModulesBinding(),
          middlewares: _writeGate('Core modules'),
          transition: _push,
        ),
        GetPage(
          name: SettingsRoutes.departmentForm,
          page: () => const DepartmentFormView(),
          binding: DepartmentFormBinding(),
          middlewares: _writeGate('Departments'),
          transition: _push,
        ),
        GetPage(
          name: SettingsRoutes.departments,
          page: () => const SettingsDepartmentsView(),
          binding: SettingsDepartmentsBinding(),
          middlewares: _writeGate('Departments'),
          transition: _push,
        ),
      ];

  /// One transition, matching `AppPages._push`.
  static const _push = Transition.cupertino;

  /// Signed in, granted settings, and granted the **update** verb on it.
  ///
  /// The screens still handle a 403 of their own: an access map in hand can be
  /// a minute older than the role it describes.
  static List<GetMiddleware> _writeGate(String moduleName) => [
        AuthMiddleware(
          module: Modules.settings,
          moduleName: moduleName,
          verb: AccessVerb.update,
        ),
      ];
}
