import 'dart:async';

import 'package:get/get.dart';

import '../../../core/app_log.dart';
import '../../../core/paged_list_controller.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/lab_order.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/laboratory_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../theme/theme.dart';
import '../lab_status.dart';

/// The laboratory worklist: every order the bench has to move.
class LaboratoryController extends PagedListController<LabOrder> {
  LaboratoryController()
      : super(
          repository: const LabOrderRepository(),
          // One entry, and no sort control on the screen. `getOrders` orders
          // by `orderDate: 'desc'` unconditionally and reads no `orderBy`, so
          // a sort sheet here would change the request and not the answer —
          // which is a worse screen than one that admits it has one order.
          sortOptions: const [
            SortOption(field: 'orderDate', label: 'Newest first'),
          ],
        );

  static LaboratoryController get to => Get.find<LaboratoryController>();

  static const LaboratoryService _lab = LaboratoryService();

  /// Both filters offer this as "no filter". The empty string rather than a
  /// sentinel word, because it is also what the query parameter omits.
  static const String any = '';

  final stats = LabStats.empty.obs;

  /// True once a stats fetch has landed. The figures are hidden until then and
  /// hidden again if the call fails: a header of six zeroes over a worklist
  /// with rows in it is a lie, and a second error banner above the list's own
  /// would be the same news twice.
  final hasStats = false.obs;

  /// The order the detail pane is showing on a two-pane window. Null on a
  /// phone, where tapping a row pushes the full screen instead.
  final selectedId = RxnString();

  @override
  String idOf(LabOrder item) => item.id;

  @override
  String get couldNotLoadMessage => "Couldn't load the lab worklist.";

  bool get canCreate =>
      AccessService.to.can(Modules.laboratory, AccessVerb.create);

  String get statusFilter => filters['status']?.firstOrNull ?? any;
  String get priorityFilter => filters['priority']?.firstOrNull ?? any;

  bool get isFiltered =>
      query.value.trim().isNotEmpty ||
      statusFilter != any ||
      priorityFilter != any;

  /// The statuses the chip row offers, "any" first.
  static const List<String> statusOptions = [any, ...LabOrderStatus.all];

  static const List<String> priorityOptions = [any, ...LabPriority.all];

  static String statusChipLabel(String status) =>
      status == any ? 'All orders' : LabOrderStatus.labelOf(status);

  static String priorityChipLabel(String priority) =>
      priority == any ? 'Any priority' : LabPriority.labelOf(priority);

  /// The worklist as it is read: **STAT first**, then urgent, then routine,
  /// each group still in the order the server sent it.
  ///
  /// Sorted here rather than asked for, because the route has no priority
  /// order — and a lab that works its queue by request time alone runs a
  /// routine cholesterol ahead of a STAT potassium that was ordered a minute
  /// later.
  ///
  /// Decorated with the index on the way in because `List.sort` is **not
  /// stable** in Dart: without it two routine orders swap places on every
  /// rebuild, and a list that reorders under a reader's thumb is one they stop
  /// trusting.
  List<LabOrder> get visible {
    final decorated = [
      for (var i = 0; i < items.length; i++) (at: i, order: items[i]),
    ]..sort((a, b) {
        final byRank = LabPriority.rankOf(a.order.priority)
            .compareTo(LabPriority.rankOf(b.order.priority));
        return byRank != 0 ? byRank : a.at.compareTo(b.at);
      });
    return [for (final row in decorated) row.order];
  }

  @override
  void onReady() {
    super.onReady();
    // In `onReady` and not `onInit`: `runGuarded` raises its loading flag
    // synchronously, and a write to an observable while the view that reads it
    // is still building marks the building `Obx` dirty.
    unawaited(loadStats());

    if (Get.isRegistered<DataBus>()) {
      // A result entered on the order screen changes the critical count and
      // moves an order between two of these figures.
      ever<int>(DataBus.to.tick(LabResultRepository.entityName), (_) {
        unawaited(reloadAll());
      });

      // And an order raised or moved on a screen pushed over this one. The
      // base class only *marks* this list stale — it is built for a shell tab
      // that gets a `refreshIfStale` when it is next looked at, and this
      // screen is pushed, so nothing would ever ask.
      ever<int>(DataBus.to.tick(LabOrderRepository.entityName), (_) {
        unawaited(reloadAll());
      });
    }
  }

  /// Fetches the six figures above the list.
  ///
  /// Swallows a refusal into a hidden header rather than an error: this route
  /// is refused for exactly the same reason the list below it is, and the list
  /// already says so in words.
  Future<void> loadStats() async {
    try {
      stats.value = await _lab.stats();
      hasStats.value = true;
    } on ApiForbiddenException catch (e) {
      hasStats.value = false;
      AppLog.info('LaboratoryController', 'lab stats refused: ${e.message}');
    } catch (e, stack) {
      hasStats.value = false;
      AppLog.error('LaboratoryController', 'lab stats failed', e, stack);
    }
  }

  /// Pull-to-refresh. The figures count the same orders the list holds, so
  /// they move together or the header contradicts the rows under it.
  Future<void> reloadAll() async {
    await Future.wait([reload(silent: true), loadStats()]);
  }

  Future<void> filterByStatus(String status) =>
      _applyOneOf(status: status == statusFilter ? any : status);

  Future<void> filterByPriority(String priority) =>
      _applyOneOf(priority: priority == priorityFilter ? any : priority);

  @override
  Future<void> clearFilters() async {
    query.value = '';
    await super.clearFilters();
  }

  void select(String? id) => selectedId.value = id;

  /// Rebuilds the filter map with **one** value per field.
  ///
  /// `getOrders` compares `where.status = status` exactly, so the comma-joined
  /// multi-value a set-valued filter produces matches nothing at all and the
  /// board reads as "there is no work" — which is the one wrong answer a
  /// worklist can give.
  Future<void> _applyOneOf({String? status, String? priority}) {
    final nextStatus = status ?? statusFilter;
    final nextPriority = priority ?? priorityFilter;
    return applyFilters({
      if (nextStatus != any) 'status': [nextStatus],
      if (nextPriority != any) 'priority': [nextPriority],
    });
  }
}
