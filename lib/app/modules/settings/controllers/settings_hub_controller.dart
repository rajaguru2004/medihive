import 'package:get/get.dart';

import '../../../data/models/access_map.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/settings_service.dart';

/// One row in the settings hub.
class SettingsEntry {
  const SettingsEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.module,
    this.verb = AccessVerb.read,
  });

  final String id;
  final String title;

  /// What the row changes, in the site's own language. A settings list whose
  /// rows are single nouns makes somebody open each one to find out which is
  /// the one they want.
  final String subtitle;

  final String route;
  final String module;
  final AccessVerb verb;
}

/// The settings hub.
///
/// Configuration is a first-class mobile surface here, not a link to a desktop.
/// The app is the primary platform, and a hospital that can only be configured
/// from a laptop is a hospital whose settings drift out of date.
class SettingsHubController extends GetxController {
  static SettingsHubController get to => Get.find<SettingsHubController>();

  /// Every entry, before access is applied.
  static List<SettingsEntry> allEntries(
    String settingsRoute, {
    required String profile,
    required String locale,
    required String appearance,
    required String clinical,
    required String modules,
    required String departments,
    required String staff,
    required String roles,
    required String integrations,
  }) =>
      [
        SettingsEntry(
          id: 'profile',
          title: 'Hospital profile',
          subtitle: 'Name, logo, contact and brand colour',
          route: profile,
          module: Modules.settings,
          verb: AccessVerb.update,
        ),
        SettingsEntry(
          id: 'locale',
          title: 'Locale and money',
          subtitle: 'Currency, timezone, date format and clock',
          route: locale,
          module: Modules.settings,
          verb: AccessVerb.update,
        ),
        SettingsEntry(
          id: 'appearance',
          title: 'Appearance',
          subtitle: 'The site theme and typeface',
          route: appearance,
          module: Modules.settings,
          verb: AccessVerb.update,
        ),
        SettingsEntry(
          id: 'clinical',
          title: 'Clinical settings',
          subtitle: 'Wait threshold, triage scale, patient names, device lock',
          route: clinical,
          module: Modules.settings,
          verb: AccessVerb.update,
        ),
        SettingsEntry(
          id: 'modules',
          title: 'Core modules',
          subtitle: 'Which parts of the system this site runs',
          route: modules,
          module: Modules.settings,
          verb: AccessVerb.update,
        ),
        SettingsEntry(
          id: 'departments',
          title: 'Departments',
          subtitle: 'Units, their codes and who heads them',
          route: departments,
          module: Modules.settings,
        ),
        SettingsEntry(
          id: 'staff',
          title: 'Users and staff',
          subtitle: 'Accounts, roles and licences',
          route: staff,
          module: Modules.users,
        ),
        SettingsEntry(
          id: 'roles',
          title: 'Roles and access',
          subtitle: 'What each role may do',
          route: roles,
          module: Modules.roles,
        ),
        SettingsEntry(
          id: 'integrations',
          title: 'Devices',
          subtitle: 'Analysers and the results they send',
          route: integrations,
          module: Modules.integrations,
        ),
      ];

  List<SettingsEntry> entries = const [];

  /// The entries this account can actually open.
  List<SettingsEntry> get visible {
    final access = AccessService.to.map;
    return entries.where((e) => access.can(e.module, e.verb)).toList();
  }

  /// True when there is nothing here for this account at all.
  ///
  /// The route guard already keeps most people out, but an account with
  /// `settings.read` and nothing else would otherwise land on an empty list
  /// with no explanation.
  bool get isEmpty => visible.isEmpty;

  String get siteName => SettingsService.to.settings.siteName;
}
