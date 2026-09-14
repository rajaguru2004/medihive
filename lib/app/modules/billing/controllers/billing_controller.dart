import 'dart:async';

import 'package:get/get.dart';

import '../../../data/models/access_map.dart';
import '../../../data/models/billing_service.dart';
import '../../../data/models/invoice.dart';
import '../../../data/models/site_settings.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/billing_api.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/load_state.dart';
import '../billing_status.dart';

/// Which half of the ledger is on screen.
enum BillingTab {
  /// Bills raised, filtered by status.
  invoices,

  /// The catalogue of what can be charged.
  services,
}

/// The ledger: five figures, the invoices under them, and the catalogue
/// alongside.
///
/// One controller for the screen rather than one per segment: the two halves
/// share the stats block above them and the account's grants, and splitting
/// them would mean two controllers reading the same access map and refetching
/// it when the other one wrote.
class BillingController extends GetxController with LoadStateMixin {
  static BillingController get to => Get.find<BillingController>();

  static const BillingApi _billing = BillingApi();

  final tab = BillingTab.invoices.obs;

  final stats = BillingStats.empty.obs;
  final invoices = <Invoice>[].obs;
  final services = <BillingService>[].obs;

  /// Null means every status. A stored value otherwise — `overdue`, `paid`.
  final statusFilter = RxnString();

  final query = ''.obs;

  /// The row a two-pane window is showing on the right. Null on a phone, where
  /// the detail is a pushed screen instead.
  final selectedId = RxnString();

  Timer? _debounce;

  bool get canCreate =>
      AccessService.to.can(Modules.billing, AccessVerb.create);

  bool get canRead => AccessService.to.canRead(Modules.billing);

  /// Invoices as the list shows them.
  ///
  /// The status filter is applied server-side; the search term is too. This
  /// narrows nothing further — it exists so the view has one name for "the
  /// rows", and so a future client-side sort has somewhere to live.
  List<Invoice> get rows => invoices;

  /// The catalogue, grouped the way a price list is laid out.
  Map<String, List<BillingService>> get servicesByCategory {
    final groups = <String, List<BillingService>>{};
    for (final service in services) {
      final category = (service.serviceCategory ?? '').trim();
      groups
          .putIfAbsent(category.isEmpty ? 'Other' : category, () => [])
          .add(service);
    }
    return groups;
  }

  /// The site's money convention. Read here rather than in the view so no
  /// widget ever concatenates a currency symbol itself.
  MoneyFormat get money => SettingsService.to.settings.money;

  @override
  void onReady() {
    super.onReady();
    unawaited(load());

    if (Get.isRegistered<DataBus>()) {
      // Payments move an invoice's balance and its status, so this list has to
      // hear about both. No controller here reaches into a sibling to refresh
      // it — the bus is how a payment recorded two screens away lands on this
      // row.
      for (final entity in [
        BillingEntities.invoices,
        BillingEntities.payments,
      ]) {
        ever<int>(DataBus.to.tick(entity), (_) {
          if (!isLoading) unawaited(load(silent: true));
        });
      }
      ever<int>(DataBus.to.tick(BillingEntities.services), (_) {
        if (!isLoading) unawaited(loadServices(silent: true));
      });
    }
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  /// The stats and whichever half is on screen.
  ///
  /// Named `load`, and the public reload is [reload] — never `refresh()`, which
  /// `GetxController` already defines as "mark builders dirty" and which
  /// returns void, so an `onRefresh:` callback would silently never await it.
  Future<void> load({bool silent = false}) async {
    // A grant this account does not hold is not an error and has nothing to
    // retry. The screen shows a locked panel; the request is never made.
    if (!canRead) {
      rxNoAccess.value = true;
      rxFirstLoad.value = false;
      return;
    }

    await runGuarded(
      () async {
        final results = await Future.wait([
          _billing.stats(),
          _billing.invoices.list(
            PagedQuery(
              limit: 50,
              search: query.value.trim().isEmpty ? null : query.value.trim(),
              params: {if (statusFilter.value != null) 'status': statusFilter.value},
            ),
          ),
          _billing.catalogue.entries(),
        ]);

        stats.value = results[0] as BillingStats;
        invoices.assignAll((results[1] as PagedResult<Invoice>).items);
        services.assignAll(results[2] as List<BillingService>);
      },
      fallback: "Couldn't load billing.",
      silent: silent,
    );
  }

  /// The catalogue on its own, for a write that touched only it.
  Future<void> loadServices({bool silent = false}) => runGuarded(
        () async => services.assignAll(await _billing.catalogue.entries()),
        fallback: "Couldn't load the service catalogue.",
        silent: silent,
      );

  Future<void> reload() => load(silent: true);

  void showTab(BillingTab value) => tab.value = value;

  /// Tapping the chip that is already on takes the filter off — the same
  /// behaviour every other board in this app has.
  Future<void> filterByStatus(String? status) async {
    statusFilter.value = statusFilter.value == status ? null : status;
    selectedId.value = null;
    await load(silent: true);
  }

  /// Debounced, because this reaches the server: the route matches the term
  /// against the invoice number, the patient's name and their MRN, and a
  /// request per keystroke is six requests to type "Mwangi".
  void search(String value) {
    query.value = value;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(load(silent: true)),
    );
  }

  void select(String? id) => selectedId.value = id;

  /// What to say on a row beneath the patient's name.
  ///
  /// Never just the total: a bill that is half paid and one that is untouched
  /// read identically otherwise, and the difference is the whole reason
  /// somebody is looking at this list.
  String outstandingHint(Invoice invoice) {
    if (invoice.isCancelled) return 'Cancelled';
    final owed = invoice.outstanding;
    if (owed <= 0) return 'Settled in full';
    if (invoice.amountPaid > 0) {
      return '${money(owed)} still owed of ${money(invoice.totalAmount)}';
    }
    return '${money(owed)} owed';
  }

  /// The document state, corrected for a due date the server has not caught up
  /// with.
  ///
  /// The backend sets `overdue` on a nightly sweep, so an invoice that fell due
  /// this morning still reads `sent` until it runs. [Invoice.overdue] answers
  /// from the due date itself, which is what the person chasing it is looking
  /// at.
  String statusOf(Invoice invoice) =>
      invoice.overdue() ? InvoiceStatus.overdue : invoice.status;
}
