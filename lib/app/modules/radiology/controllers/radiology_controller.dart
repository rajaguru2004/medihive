import 'dart:async';

import 'package:get/get.dart';

import '../../../core/app_log.dart';
import '../../../core/paged_list_controller.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/radiology_order.dart';
import '../../../data/repositories/radiology_repository.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../theme/theme.dart';

/// The imaging worklist: every order, most recent first, with the department's
/// counts above it.
///
/// Paging, searching and filtering come from [PagedListController]. What is
/// this screen's own is the pair of single-choice filters the route actually
/// honours, and the critical-findings figure — the one number on this screen
/// that is about a patient rather than about throughput.
class RadiologyController extends PagedListController<RadiologyOrder> {
  RadiologyController()
      : super(
          repository: _repository(),
          // The route orders by `orderDate desc` and offers no control over
          // it: `RadiologyOrderListQueryDto` declares `page`, `limit`,
          // `search`, `status`, `urgency` and `patientId`, and validation runs
          // `forbidNonWhitelisted` — so an `orderBy` here is a 400 for the
          // whole request. The base class requires one option; [queryFor]
          // drops it, and no sort control is offered.
          sortOptions: const [
            SortOption(field: 'orderDate', label: 'Newest first'),
          ],
        );

  static RadiologyController get to => Get.find<RadiologyController>();

  /// The repository, registering the set if nothing has yet.
  ///
  /// In the initialiser list rather than the binding because this controller is
  /// also `Get.put` straight into the shell's destination table, where there is
  /// no binding to run first — and a `Get.find` there throws before the tab has
  /// painted a frame.
  static RadiologyOrderRepository _repository() {
    RadiologyRepositories.register();
    return RadiologyRepositories.orders;
  }

  /// Either filter set to this shows everything. Not a value the server knows.
  static const String anyValue = 'all';

  final stats = RadiologyStats.empty.obs;

  final statusFilter = anyValue.obs;
  final urgencyFilter = anyValue.obs;

  /// The row the detail pane is showing, on a window wide enough to have one.
  /// Null on a phone, where choosing a row pushes a screen instead.
  final selectedId = RxnString();

  @override
  String idOf(RadiologyOrder item) => item.id;

  @override
  String get couldNotLoadMessage => "Couldn't load the imaging worklist.";

  bool get canOrder =>
      Get.isRegistered<AccessService>() &&
      AccessService.to.can(Modules.radiology, AccessVerb.create);

  bool get isFiltered =>
      query.value.trim().isNotEmpty ||
      statusFilter.value != anyValue ||
      urgencyFilter.value != anyValue;

  /// The orders on this page whose report found something the ward must be
  /// told about.
  List<RadiologyOrder> get criticalOrders =>
      items.where((order) => order.hasCriticalFindings).toList();

  /// How many critical findings are outstanding.
  ///
  /// The rows on screen when any of them carry one, and the department-wide
  /// figure otherwise — a filter that hides the critical study must not also
  /// hide the fact that there is one.
  int get criticalCount {
    final onScreen = criticalOrders.length;
    return onScreen > 0 ? onScreen : stats.value.criticalFindings;
  }

  bool get hasCriticalFindings => criticalCount > 0;

  /// What the banner says.
  ///
  /// Names the patient when there is exactly one, because a single name is
  /// something somebody can act on and "1 study" is not. Past one, the count
  /// is the actionable part and a list of names is a paragraph.
  String get criticalMessage {
    final critical = criticalOrders;
    if (critical.length == 1) {
      final order = critical.first;
      final name = order.patient.displayName;
      final exam = order.examName;
      return '$name — $exam carries a critical finding. '
          'Check the ward has been told.';
    }
    return '$criticalCount studies carry a critical finding. '
        'Check each ward has been told.';
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(loadStats());

    // A report written on a detail screen changes a row on this one, and an
    // exam added to the catalogue changes what the order form offers. Noted
    // rather than refetched here; `refreshIfStale` catches up when this screen
    // is next looked at.
    if (Get.isRegistered<DataBus>()) {
      ever<int>(DataBus.to.tick(RadiologyEntities.reports), (_) {
        unawaited(reload(silent: true));
        unawaited(loadStats());
      });
    }
  }

  /// The counts above the list.
  ///
  /// Deliberately quiet on failure. The figures are a summary of the rows
  /// below them, and a banner over a worklist that loaded perfectly well —
  /// because a separate stats route is down — would hide the work.
  Future<void> loadStats() async {
    try {
      stats.value = await RadiologyRepositories.orders.stats();
    } on ApiForbiddenException catch (e) {
      stats.value = RadiologyStats.empty;
      AppLog.info('RadiologyController', 'stats refused: ${e.message}');
    } catch (e, stack) {
      AppLog.error('RadiologyController', 'imaging stats failed', e, stack);
    }
  }

  @override
  PagedQuery queryFor(int page) {
    final term = query.value.trim();
    return PagedQuery(
      page: page,
      limit: pageSize,
      search: term.isEmpty ? null : term,
      params: {
        // One value per key, never a comma-joined set: `buildOrderWhere` does
        // an exact match on `status`, so `status=pending,scheduled` matches
        // nothing at all and reads on screen as "there is no work".
        if (statusFilter.value != anyValue) 'status': statusFilter.value,
        if (urgencyFilter.value != anyValue) 'urgency': urgencyFilter.value,
      },
    );
  }

  Future<void> filterByStatus(String status) async {
    if (statusFilter.value == status) return;
    statusFilter.value = status;
    await reload();
  }

  Future<void> filterByUrgency(String urgency) async {
    if (urgencyFilter.value == urgency) return;
    urgencyFilter.value = urgency;
    await reload();
  }

  @override
  Future<void> clearFilters() async {
    statusFilter.value = anyValue;
    urgencyFilter.value = anyValue;
    query.value = '';
    await reload();
  }

  void select(String? id) => selectedId.value = id;

  /// Reloads the list and the figures together, which is what a pull-to-refresh
  /// means on this screen: the counts are as stale as the rows.
  Future<void> reloadAll() async {
    await Future.wait([reload(silent: true), loadStats()]);
  }
}
