import 'dart:async';

import 'package:get/get.dart';

import '../../../data/models/access_map.dart';
import '../../../data/models/drafts/drafts.dart';
import '../../../data/models/organization.dart';
import '../../../data/network/endpoints.dart';
import '../../../data/services/access_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../settings/controllers/settings_form_controller.dart';

/// One licensable part of the system.
class SiteModule {
  const SiteModule({
    required this.key,
    required this.title,
    required this.subtitle,
    this.tab,
  });

  /// The key stored in `modulesEnabled` and read back by the shell.
  final String key;

  final String title;

  /// What the site loses by turning it off, in the site's own language.
  final String subtitle;

  /// The tab this module puts in the shell, where it has one.
  ///
  /// Null for a module this build has no screen for yet: it is still a real
  /// licence flag on the record, and a switch that pretends otherwise is a
  /// switch somebody flips looking for a tab that was never there.
  final String? tab;
}

/// Which parts of the system this site runs.
///
/// Two things make this screen different from the other settings forms, and
/// both of them bite:
///
///   * **`PUT /settings/modules` replaces the whole map.** The handler does
///     `JSON.stringify(dto.modulesEnabled)` — there is no merge. A save that
///     sent only the six switches below would delete every other key the
///     column holds, so the six are laid *over* whatever was loaded.
///   * **the DTO wants `organizationId`.** It is the one settings write that
///     does, which is why this controller loads the organisation rather than
///     reading `SettingsService`.
class SettingsModulesController extends SettingsFormController {
  static SettingsModulesController get to =>
      Get.find<SettingsModulesController>();

  /// The six keys the organisation column ships with — see the
  /// `modulesEnabled` default in `hms_v2/prisma/schema.prisma`.
  ///
  /// The list is the column's, not the shell's, on purpose: a screen that
  /// offered only the four with tabs would drop `inventory` and `accounting`
  /// on the first save, because the route below replaces rather than merges.
  static const List<SiteModule> modules = [
    SiteModule(
      key: 'inpatient',
      title: 'Wards and beds',
      subtitle: 'Admissions, the bed map and the ward round.',
      tab: 'Wards',
    ),
    SiteModule(
      key: 'laboratory',
      title: 'Laboratory',
      subtitle: 'Test catalogue, orders and results.',
      tab: 'Lab',
    ),
    SiteModule(
      key: 'radiology',
      title: 'Radiology',
      subtitle: 'Imaging requests, studies and reports.',
      tab: 'Imaging',
    ),
    SiteModule(
      key: 'pharmacy',
      title: 'Pharmacy',
      subtitle: 'Drug list, prescriptions and dispensing.',
      tab: 'Pharmacy',
    ),
    SiteModule(
      key: 'inventory',
      title: 'Inventory',
      subtitle: 'Stock and consumables. Managed in the web console for now — '
          'this app has no screen for it yet.',
    ),
    SiteModule(
      key: 'accounting',
      title: 'Accounting',
      subtitle: 'The ledger beyond patient billing. Web console only for now.',
    ),
  ];

  /// What the site has switched on, as loaded — every key, not only the six.
  final _stored = <String, dynamic>{}.obs;

  /// The six switches, as they stand on screen.
  final _pending = <String, bool>{}.obs;

  final _initial = <String, bool>{};

  String _organizationId = '';

  bool get canWrite => AccessService.to.can(Modules.settings, AccessVerb.update);

  /// A module absent from the map is **on**.
  ///
  /// The server's stored default carries `inpatient: false` and plenty of
  /// sites have never opened this screen, so treating a missing key as off
  /// would hide the ward board from all of them. Only an explicit `false`
  /// turns anything off.
  bool isOn(String key) => _pending[key] ?? true;

  void setModule(String key, {required bool on}) => _pending[key] = on;

  /// The modules about to be switched off — what the confirm has to name.
  List<SiteModule> get turningOff => [
        for (final module in modules)
          if ((_initial[module.key] ?? true) && !isOn(module.key)) module,
      ];

  /// The tabs that will be gone after the next start.
  List<String> get tabsLost => [
        for (final module in turningOff)
          if (module.tab != null) module.tab!,
      ];

  @override
  void onReady() {
    super.onReady();
    unawaited(load());
  }

  Future<void> load({bool silent = false}) async {
    await runGuarded(
      () async {
        final response = await client.get(Endpoints.organization);
        final organization =
            Organization.fromJson(ApiEnvelope.of(response).orThrow().object);

        _organizationId = organization.id;
        _stored
          ..clear()
          ..addAll(organization.modulesEnabled);

        _initial
          ..clear()
          ..addEntries(
            modules.map(
              (m) => MapEntry(m.key, organization.moduleEnabled(m.key)),
            ),
          );
        _pending
          ..clear()
          ..addAll(_initial);
      },
      fallback: "Couldn't load this site's modules.",
      silent: silent,
    );
  }

  Future<void> reload() => load(silent: true);

  /// Every key the column held, with the six switches laid over it.
  Map<String, bool> _merged() {
    final out = <String, bool>{
      for (final entry in _stored.entries)
        entry.key: entry.value is bool ? entry.value as bool : true,
    };
    out.addAll(_pending);
    return out;
  }

  @override
  bool get isDirty =>
      modules.any((m) => (_initial[m.key] ?? true) != isOn(m.key));

  /// `PUT /settings/modules`, not the organisation route.
  @override
  String get saveEndpoint => Endpoints.settingsModules;

  /// `UpdateModulesDto`: both keys required, and `modulesEnabled` replaces the
  /// column whole.
  @override
  Map<String, dynamic> buildBody() => {
        'organizationId': _organizationId,
        'modulesEnabled': _merged(),
      };

  /// Never sent on the route above, which takes its own DTO.
  ///
  /// Kept honest anyway: it is the same switches as an organisation write, so
  /// if the dedicated route is ever retired this screen needs one line changed
  /// rather than a rewrite.
  @override
  OrganizationSettingsDraft buildDraft() =>
      OrganizationSettingsDraft(modulesEnabled: _merged());

  @override
  bool get canSave => super.canSave && _organizationId.isNotEmpty;

  @override
  void onSaved() {
    _initial
      ..clear()
      ..addAll(_pending);
  }
}
