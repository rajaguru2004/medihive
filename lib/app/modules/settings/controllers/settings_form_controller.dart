import 'package:get/get.dart';

import '../../../data/models/drafts/drafts.dart';
import '../../../data/models/site_settings.dart';
import '../../../data/network/dio_client.dart';
import '../../../data/network/endpoints.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';

/// Shared behaviour for every settings screen that saves.
///
/// They all do the same three things and each of them is easy to get wrong
/// alone: send a **partial** draft, adopt the answer so the app re-themes
/// without a restart, and tell the rest of the app something moved.
///
/// The partial matters most. `PUT /settings/organization` writes the whole
/// column, and the backend merges leaf by leaf — but only for the keys it is
/// sent. A screen that helpfully posts every field it can see would overwrite
/// the working hours a receptionist set on the web an hour earlier with
/// whatever it happened to have loaded.
abstract class SettingsFormController extends GetxController
    with LoadStateMixin {
  DioClient get client => Get.find<DioClient>();

  /// What this screen changes, and nothing else.
  OrganizationSettingsDraft buildDraft();

  /// Whether anything on this screen has actually been edited.
  bool get isDirty;

  bool get canSave =>
      AccessService.to.canWrite('settings') && isDirty && !rxLoading.value;

  Future<void> save() async {
    if (!canSave) return;

    await runGuarded(
      () async {
        final response = await client.put(
          Endpoints.organization,
          data: buildDraft().toUpdateJson(),
        );
        final envelope = ApiEnvelope.of(response).orThrow();

        // Adopt the server's answer rather than the draft. The merge happened
        // there, and a screen that trusts what it sent shows a state the
        // database does not have.
        final organization = envelope.object;
        SettingsService.to.adopt(SiteSettings.fromOrganization(organization));
        final modules = organization['modulesEnabled'];
        if (modules is Map) {
          SettingsService.to.adoptModules(modules.cast<String, dynamic>());
        }

        DataBus.to.changedRecord('organization');
        showBentoToast('Saved.');
        onSaved();
      },
      fallback: 'That did not save. Check your connection and try again.',
    );
  }

  /// Hook for a screen that needs to resync its fields after a save.
  void onSaved() {}
}
