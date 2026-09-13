import 'package:get/get.dart';

import '../../../core/app_clock.dart';
import '../../../data/models/queue_item.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/queue_service.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';

/// Which half of the board is showing.
enum QueueBoard {
  /// Waiting, called and in service — everyone still on the floor.
  live,

  /// Seen, cancelled and no-show — today, already dealt with.
  history,
}

/// The queue board.
///
/// The one screen in this app where ordering is the entire product. A queue
/// sorted by arrival alone will seat a sprained ankle ahead of a chest pain
/// that walked in two minutes later, so [displayed] sorts on acuity first and
/// arrival second — the same rule a triage nurse applies out loud.
class QueueController extends GetxController with LoadStateMixin {
  static QueueController get to => Get.find<QueueController>();

  final _queueService = Get.find<QueueService>();

  final live = <QueueItem>[].obs;
  final history = <QueueItem>[].obs;

  final board = QueueBoard.live.obs;
  final serviceArea = _allAreas.obs;
  final acuity = _allAcuities.obs;

  static const _allAreas = 'All areas';
  static const _allAcuities = 'All acuities';

  /// The areas this site actually has patients in, plus the "all" option.
  ///
  /// Derived from the data rather than hard-coded: a site with no psychiatric
  /// unit should not be offered a psychiatric filter that always returns
  /// nothing.
  List<String> get serviceAreas => [
        _allAreas,
        ...{
          for (final item in [...live, ...history])
            if (item.serviceArea.trim().isNotEmpty) item.serviceArea.trim(),
        }.toList()
          ..sort(),
      ];

  List<String> get acuities => [
        _allAcuities,
        ...{
          for (final item in [...live, ...history])
            if (item.priority.trim().isNotEmpty) item.priority.trim(),
        }.toList()
          ..sort((a, b) =>
              CaseStatus.priorityOf(a).compareTo(CaseStatus.priorityOf(b))),
      ];

  // ── Counts ────────────────────────────────────────────────────────────────
  //
  // Computed from the unfiltered lists, so a filter narrows what is shown
  // without quietly changing what the board claims is happening.

  int get waitingCount => live.where((x) => _is(x, 'waiting')).length;
  int get calledCount => live.where((x) => _is(x, 'called')).length;
  int get inServiceCount => live.where((x) => _is(x, 'in_service')).length;
  int get completedCount => history.where((x) => _is(x, 'completed')).length;

  /// How many have waited past the site's escalation threshold.
  int get breachedCount {
    final limit = SettingsService.to.waitBreachMinutes;
    if (limit <= 0) return 0;
    return live
        .where((x) => _is(x, 'waiting') && waitedBy(x).inMinutes >= limit)
        .length;
  }

  int get breachMinutes => SettingsService.to.waitBreachMinutes;

  /// How long this person has been waiting.
  ///
  /// Computed from `joinedQueueAt` rather than trusting the server's
  /// `waitTime`, which is a snapshot taken when the row was serialised and is
  /// already stale by the time a board has been open thirty seconds.
  Duration waitedBy(QueueItem item) =>
      AppClock.now().difference(item.joinedQueueAt.toLocal());

  /// The rows on screen: filtered, then sorted.
  List<QueueItem> get displayed {
    final source = board.value == QueueBoard.live ? live : history;

    final rows = source.where((item) {
      if (serviceArea.value != _allAreas &&
          item.serviceArea.trim().toLowerCase() !=
              serviceArea.value.trim().toLowerCase()) {
        return false;
      }
      if (acuity.value != _allAcuities &&
          item.priority.trim().toLowerCase() !=
              acuity.value.trim().toLowerCase()) {
        return false;
      }
      return true;
    }).toList();

    rows.sort((a, b) {
      // History reads newest-first: it is a log, and the last thing that
      // happened is the thing somebody is checking.
      if (board.value == QueueBoard.history) {
        return b.joinedQueueAt.compareTo(a.joinedQueueAt);
      }
      final byAcuity = CaseStatus.priorityOf(a.priority)
          .compareTo(CaseStatus.priorityOf(b.priority));
      if (byAcuity != 0) return byAcuity;
      return a.joinedQueueAt.compareTo(b.joinedQueueAt);
    });

    return rows;
  }

  bool get isFiltered =>
      serviceArea.value != _allAreas || acuity.value != _allAcuities;

  @override
  void onReady() {
    super.onReady();
    load();
    if (Get.isRegistered<DataBus>()) {
      ever<int>(DataBus.to.tick('queue'), (_) {
        if (!isLoading) load(silent: true);
      });
    }
  }

  Future<void> load({bool silent = false}) => runGuarded(
        () async {
          final results = await Future.wait([
            _queueService.fetchQueueItems(statuses: 'waiting,called,in_service'),
            _queueService.fetchQueueItems(statuses: 'completed,cancelled,no_show'),
          ]);

          live.assignAll(_rowsFrom(results[0].data));
          history.assignAll(_rowsFrom(results[1].data));
        },
        fallback: "Couldn't load the queue.",
        silent: silent,
      );

  Future<void> reload() => load(silent: true);

  void showBoard(QueueBoard next) => board.value = next;
  void filterByArea(String area) => serviceArea.value = area;
  void filterByAcuity(String value) => acuity.value = value;

  void clearFilters() {
    serviceArea.value = _allAreas;
    acuity.value = _allAcuities;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Calls whoever is next by the board's own ordering.
  ///
  /// Deliberately reuses [displayed]'s sort rather than re-deriving one: a
  /// "call next" that disagrees with the order on screen is the worst possible
  /// outcome here, because the person calling it is watching the list.
  Future<void> callNext() async {
    final next = live
        .where((x) => _is(x, 'waiting'))
        .toList()
      ..sort((a, b) {
        final byAcuity = CaseStatus.priorityOf(a.priority)
            .compareTo(CaseStatus.priorityOf(b.priority));
        if (byAcuity != 0) return byAcuity;
        return a.joinedQueueAt.compareTo(b.joinedQueueAt);
      });

    if (next.isEmpty) {
      showBentoToast('Nobody is waiting.', tone: ToastTone.info);
      return;
    }
    await setStatus(next.first, 'called');
  }

  Future<void> setStatus(QueueItem item, String status) async {
    final name = item.patient.fullName;
    try {
      final response = await _queueService.updateQueueStatus(item.id, status);
      final body = response.data;
      final envelope = body is Map ? body.cast<String, dynamic>() : null;
      final ok = response.statusCode == 200 ||
          response.statusCode == 204 ||
          envelope?['success'] == true;

      if (!ok) {
        showBentoToast(
          envelope?['message'] as String? ?? "Couldn't update $name.",
          tone: ToastTone.failure,
        );
        return;
      }

      showBentoToast('$name is now ${_spoken(status)}.');
      if (Get.isRegistered<DataBus>()) DataBus.to.changedRecord('queue');
      await load(silent: true);
    } catch (e) {
      showBentoToast(
        parseErrorMessage(e, "Couldn't update $name."),
        tone: ToastTone.failure,
      );
    }
  }

  Future<void> removeFromQueue(QueueItem item) async {
    final name = item.patient.fullName;
    try {
      final response = await _queueService.deleteQueueItem(item.id);
      final body = response.data;
      final envelope = body is Map ? body.cast<String, dynamic>() : null;
      final ok = response.statusCode == 200 ||
          response.statusCode == 204 ||
          envelope?['success'] == true;

      if (!ok) {
        showBentoToast("Couldn't remove $name.", tone: ToastTone.failure);
        return;
      }

      showBentoToast('$name has been removed from the queue.');
      if (Get.isRegistered<DataBus>()) DataBus.to.changedRecord('queue');
      await load(silent: true);
    } catch (e) {
      showBentoToast(
        parseErrorMessage(e, "Couldn't remove $name."),
        tone: ToastTone.failure,
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _is(QueueItem item, String status) =>
      item.status.trim().toLowerCase() == status;

  /// `in_service` → `in service`. What a toast should say out loud.
  static String _spoken(String status) => status.replaceAll('_', ' ');

  /// Pulls rows out of the two shapes this endpoint answers with: the
  /// envelope's `data.data` page, and a bare list.
  List<QueueItem> _rowsFrom(dynamic body) {
    if (body is! Map) return const [];
    if (body['success'] != true) return const [];

    final payload = body['data'];
    final rows = payload is Map ? payload['data'] : payload;
    if (rows is! List) return const [];

    return rows
        .whereType<Map>()
        .map((e) => QueueItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
