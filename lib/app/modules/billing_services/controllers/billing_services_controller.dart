import 'dart:async';

import 'package:get/get.dart';

import '../../../data/models/access_map.dart';
import '../../../data/models/billing_service.dart';
import '../../../data/models/site_settings.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/billing_api.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';

/// The service catalogue: everything this site can put on a bill.
///
/// Not a [PagedListController] on purpose. `GET /billing/services` has no
/// pagination DTO at all — it answers a bare array however it is asked, filters
/// to `isActive` server-side, and reads only `category`. A paged controller over
/// it would send `page`, `limit`, `orderBy` and `search` to a route that
/// declares none of them, and `forbidNonWhitelisted` makes every one of those a
/// 400 for the whole request.
class BillingServicesController extends GetxController with LoadStateMixin {
  static BillingServicesController get to =>
      Get.find<BillingServicesController>();

  static const BillingApi _billing = BillingApi();

  final services = <BillingService>[].obs;
  final query = ''.obs;

  MoneyFormat get money => SettingsService.to.settings.money;

  bool get canCreate => AccessService.to.can(Modules.billing, AccessVerb.create);
  bool get canUpdate => AccessService.to.can(Modules.billing, AccessVerb.update);
  bool get canRead => AccessService.to.canRead(Modules.billing);

  /// Filtered in memory, because the route has no `search` parameter to send it
  /// to. The catalogue is tens of rows, not thousands.
  List<BillingService> get rows {
    final needle = query.value.trim().toLowerCase();
    if (needle.isEmpty) return services;
    return services
        .where((service) =>
            service.serviceName.toLowerCase().contains(needle) ||
            (service.serviceCode ?? '').toLowerCase().contains(needle) ||
            (service.serviceCategory ?? '').toLowerCase().contains(needle) ||
            (service.department ?? '').toLowerCase().contains(needle))
        .toList();
  }

  /// Which of the five states the list is in.
  ListPhase get phase {
    if (hasNoAccess) return ListPhase.forbidden;
    if (rxFirstLoad.value && isLoading) return ListPhase.firstLoad;
    if (hasLoadError) return ListPhase.error;
    return ListPhase.ready;
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(load());

    if (Get.isRegistered<DataBus>()) {
      ever<int>(DataBus.to.tick(BillingEntities.services), (_) {
        if (!isLoading) unawaited(load(silent: true));
      });
    }
  }

  Future<void> load({bool silent = false}) async {
    if (!canRead) {
      rxNoAccess.value = true;
      rxFirstLoad.value = false;
      return;
    }
    await runGuarded(
      () async => services.assignAll(await _billing.catalogue.entries()),
      fallback: "Couldn't load the service catalogue.",
      silent: silent,
    );
  }

  Future<void> reload() => load(silent: true);

  void search(String value) => query.value = value;
}
