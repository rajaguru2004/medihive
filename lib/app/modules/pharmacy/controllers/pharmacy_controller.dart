import 'package:get/get.dart';

import '../../../core/app_clock.dart';
import '../../../core/app_log.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/drug.dart';
import '../../../data/models/pharmacy_sale.dart';
import '../../../data/models/prescription.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/pharmacy_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/load_state.dart';

/// The three things a counter is ever doing.
enum PharmacyCounter {
  /// Prescriptions waiting to be handed over.
  dispense,

  /// The shelf.
  inventory,

  /// What went over the counter today.
  sales,
}

/// The dispensing counter.
///
/// Everything the hub shows is fetched once on arrival and kept, because the
/// three segments are one screen to the person using them: a pharmacist checks
/// a queue, walks to the shelf and comes back, and a segment that refetched on
/// every tap would cost a round trip for each of those glances.
///
/// Filters are the exception. Search and category are answered by the server —
/// `search` matches a generic name and a drug code, which an in-memory filter
/// could not — so changing one refetches that list and nothing else.
class PharmacyController extends GetxController with LoadStateMixin {
  static PharmacyController get to => Get.find<PharmacyController>();

  final _service = PharmacyService.instance;

  final counter = PharmacyCounter.dispense.obs;

  final stats = PharmacyStats.empty.obs;
  final prescriptions = <Prescription>[].obs;
  final drugs = <Drug>[].obs;
  final sales = <PharmacySale>[].obs;

  /// The shelf's search term and category, as the server was last asked for
  /// them.
  final search = ''.obs;
  final category = RxnString();

  /// Which day's takings are on screen. Today, until somebody asks otherwise.
  late final Rx<DateTime> salesDate = Rx<DateTime>(_today());

  /// The categories the shelf actually uses, captured from the first
  /// unfiltered load.
  ///
  /// Derived from the filtered list instead, the chips would disappear as soon
  /// as one was chosen — leaving a pharmacist filtered into a category with no
  /// way back out of it.
  final categories = <String>[].obs;

  /// Bumped whenever the search term is changed from somewhere other than the
  /// search box itself. See [clearFilters].
  final searchEpoch = 0.obs;

  /// True while a filtered refetch is in flight. Separate from [rxLoading],
  /// which drives the first-load skeleton: a search that blanked the shelf on
  /// every keystroke would be unusable.
  final filtering = false.obs;

  bool get canCreate =>
      AccessService.to.can(Modules.pharmacy, AccessVerb.create);

  bool get canUpdate =>
      AccessService.to.can(Modules.pharmacy, AccessVerb.update);

  /// Whether a filter is narrowing the shelf — what tells an empty list apart
  /// from an empty catalogue.
  bool get isFiltered => search.value.trim().isNotEmpty || category.value != null;

  @override
  void onReady() {
    super.onReady();
    load();
    if (Get.isRegistered<DataBus>()) {
      for (final entity in const [
        PharmacyService.drugsEntity,
        PharmacyService.prescriptionsEntity,
        PharmacyService.salesEntity,
      ]) {
        // Silent: the counter a pharmacist is reading stays on screen rather
        // than collapsing to a skeleton under their thumb. [load] drops a
        // reload that arrives while one is already running.
        ever<int>(DataBus.to.tick(entity), (_) => load(silent: true));
      }
    }
  }

  /// Everything the counter shows, in one round of requests.
  ///
  /// Guarded against re-entry, and that is not belt and braces: one sale ticks
  /// three entities this screen listens to, and without the guard a single
  /// dispense would set off three overlapping reloads of four endpoints each.
  Future<void> load({bool silent = false}) async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      await _load(silent: silent);
    } finally {
      _inFlight = false;
    }
  }

  bool _inFlight = false;

  Future<void> _load({required bool silent}) => runGuarded(
        () async {
          final results = await Future.wait([
            _service.stats(),
            _service.prescriptions(status: pendingStatus),
            _service.drugs(
              category: category.value,
              search: search.value,
            ),
            _service.sales(date: salesDate.value),
          ]);

          stats.value = results[0] as PharmacyStats;
          prescriptions.assignAll(results[1] as List<Prescription>);
          final shelf = results[2] as List<Drug>;
          drugs.assignAll(shelf);
          sales.assignAll(results[3] as List<PharmacySale>);

          if (!isFiltered) _rememberCategories(shelf);
        },
        fallback: "Couldn't load the pharmacy.",
        silent: silent,
      );

  /// A silent refetch. Never named `refresh()` — `GetxController` already has
  /// one that returns void, so an `onRefresh:` wired to it never awaits.
  Future<void> reload() => load(silent: true);

  // ── The shelf's filters ───────────────────────────────────────────────────

  Future<void> searchDrugs(String term) {
    if (term.trim() == search.value.trim()) return Future<void>.value();
    search.value = term;
    return _reloadDrugs();
  }

  /// Drops the search term and the category in one request.
  ///
  /// [searchEpoch] moves with them: `SearchField` keeps its text in its own
  /// `State` and nothing outside it can reach that, so a "clear filters" that
  /// only cleared the controller would leave the box still reading the term it
  /// had just stopped filtering on.
  Future<void> clearFilters() {
    if (!isFiltered) return Future<void>.value();
    search.value = '';
    category.value = null;
    searchEpoch.value++;
    return _reloadDrugs();
  }

  /// Null is "every category", which is what the first chip sets.
  Future<void> filterByCategory(String? next) {
    if (next == category.value) return Future<void>.value();
    category.value = next;
    return _reloadDrugs();
  }

  Future<void> _reloadDrugs() async {
    filtering.value = true;
    try {
      final shelf = await _service.drugs(
        category: category.value,
        search: search.value,
      );
      drugs.assignAll(shelf);
      if (!isFiltered) _rememberCategories(shelf);
    } catch (e, stack) {
      // Inline, not a toast: the shelf on screen is now older than the filter
      // above it, and a message that vanishes in three seconds leaves somebody
      // reading the wrong list without knowing.
      _recordFailure(e, stack, "Couldn't search the shelf.");
    } finally {
      filtering.value = false;
    }
  }

  // ── Sales ─────────────────────────────────────────────────────────────────

  Future<void> showSalesFor(DateTime? day) async {
    final next = day == null ? _today() : _dayOnly(day);
    if (next == salesDate.value) return;
    salesDate.value = next;
    filtering.value = true;
    try {
      sales.assignAll(await _service.sales(date: next));
    } catch (e, stack) {
      _recordFailure(e, stack, "Couldn't load that day's sales.");
    } finally {
      filtering.value = false;
    }
  }

  /// Today's takings, as the counter's own total rather than the server's.
  ///
  /// The `todaySales` figure in `stats` is today whatever day the list is
  /// showing, so the two would disagree the moment somebody looked back at
  /// yesterday.
  double get salesTotal =>
      sales.fold<double>(0, (sum, sale) => sum + sale.totalAmount);

  void _rememberCategories(List<Drug> shelf) {
    final found = <String>{
      for (final drug in shelf)
        if ((drug.drugCategory ?? '').trim().isNotEmpty)
          drug.drugCategory!.trim(),
    }.toList()
      ..sort();
    categories.assignAll(found);
  }

  /// The queue this screen exists to clear.
  static const String pendingStatus = 'pending';

  /// Records a failure from a filtered refetch the way [runGuarded] records one
  /// from a full load, so both land in the same inline banner.
  ///
  /// A 403 here is the server answering correctly rather than a fault — the
  /// same distinction `LoadStateMixin` draws — so it locks the panel instead of
  /// raising a retry nobody's role can satisfy.
  void _recordFailure(Object error, StackTrace stack, String fallback) {
    if (error is ApiForbiddenException) {
      rxNoAccess.value = true;
      AppLog.info('$runtimeType', 'access refused: ${error.message}');
      return;
    }
    rxLoadError.value = parseErrorMessage(error, fallback);
    AppLog.error('$runtimeType', fallback, error, stack);
  }

  static DateTime _today() => _dayOnly(AppClock.now());

  static DateTime _dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
