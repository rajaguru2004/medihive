import 'dart:async';

import 'package:get/get.dart';

import '../data/repositories/crud_repository.dart';
import '../data/services/data_bus.dart';
import '../data/utils/api_envelope.dart';
import '../data/utils/error_handler.dart';
import '../theme/app_bento_data.dart';
import 'app_log.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the list half of every module
///
/// Every list screen in this app does the same seven things: fetch a page,
/// append the next one, search, filter, sort, refresh, and delete a row. Doing
/// them once here is what keeps eight modules from each inventing their own
/// pagination bug.
///
/// A subclass supplies its repository, its sort options and its search fields,
/// and adds only what is genuinely its own.
/// ─────────────────────────────────────────────────────────────────────────────
abstract class PagedListController<T> extends GetxController {
  PagedListController({
    required this.repository,
    required this.sortOptions,
    this.searchFields = 'name',
    this.pageSize = 20,
  })  : assert(sortOptions.isNotEmpty, 'a list needs at least one order'),
        _sort = sortOptions.first.obs;

  final CrudRepository<T> repository;

  /// The orders this list offers, most useful first.
  final List<SortOption> sortOptions;

  /// Which fields a search term is matched against.
  final String searchFields;

  final int pageSize;

  // ── State ─────────────────────────────────────────────────────────────────

  final items = <T>[].obs;
  final phase = ListPhase.firstLoad.obs;
  final loadingMore = false.obs;
  final errorMessage = RxnString();

  final query = ''.obs;
  final filters = <String, List<String>>{}.obs;
  final Rx<SortOption> _sort;

  final _pagination = Pagination.none.obs;

  SortOption get sort => _sort.value;
  Rx<SortOption> get rxSort => _sort;

  Pagination get pagination => _pagination.value;
  bool get hasMore => _pagination.value.hasMore;

  /// How many filter values are on, for the badge on the filter button.
  int get filterCount =>
      filters.values.fold(0, (sum, values) => sum + values.length);

  bool get isEmpty => items.isEmpty && phase.value == ListPhase.ready;

  /// Guards concurrent page fetches. Two `load more` calls in flight append the
  /// same page twice, and the duplicate looks exactly like bad data.
  bool _fetching = false;

  /// True when this collection changed while this screen was not being looked
  /// at. See [refreshIfStale].
  bool _stale = false;

  @override
  void onInit() {
    super.onInit();
    unawaited(reload());

    // Every tab in this shell stays alive, so a list that is not on screen
    // never notices a write made from somewhere else — raise an invoice from
    // a quote, switch to Invoices, and the list is the one from ten minutes
    // ago. Rather than refetch on every tab switch, note it and catch up the
    // next time this screen is actually looked at.
    if (Get.isRegistered<DataBus>()) {
      ever(DataBus.to.tick(repository.entity), (_) => _stale = true);
    }
  }

  /// Reloads only if this collection changed while the screen was away.
  ///
  /// Called by the shell when a destination is selected. Cheap and silent when
  /// nothing happened, which is the common case — the point is to cost a
  /// request only when there is actually something new to show.
  Future<void> refreshIfStale() async {
    if (!_stale) return;
    _stale = false;
    await reload(silent: true);
  }

  // ── Query building ────────────────────────────────────────────────────────

  /// The query for a page. Subclasses override to add their own parameters.
  PagedQuery queryFor(int page) => PagedQuery(
        page: page,
        items: pageSize,
        sortBy: sort.field,
        sortValue: sort.sortValue,
        q: query.value.trim().isEmpty ? null : query.value.trim(),
        fields: searchFields,
        filters: Map.of(filters),
      );

  // ── Loading ───────────────────────────────────────────────────────────────

  /// Fetches the first page, replacing whatever is on screen.
  ///
  /// Named `reload` rather than `refresh`: `GetxController` already has a
  /// `refresh()` with a different meaning — it marks builders dirty — and
  /// shadowing it with a network call is a trap somebody falls into once.
  ///
  /// [silent] keeps the current rows visible while it runs, which is what a
  /// pull-to-refresh wants: collapsing a list the user is looking at back to
  /// skeletons reads as having lost it.
  Future<void> reload({bool silent = false}) async {
    if (!silent) {
      phase.value = items.isEmpty ? ListPhase.firstLoad : ListPhase.ready;
    }
    errorMessage.value = null;

    try {
      _fetching = true;
      final result = await repository.list(queryFor(1));
      items.assignAll(result.items);
      _pagination.value = result.pagination;
      phase.value = ListPhase.ready;
    } catch (e, stack) {
      AppLog.error('$runtimeType', 'list load failed', e, stack);
      errorMessage.value = parseErrorMessage(e, couldNotLoadMessage);
      // A failed refresh over existing rows keeps them: the rows are still the
      // last true answer, and replacing them with an error loses the user's
      // place for a problem that may be a moment of bad signal.
      phase.value = items.isEmpty ? ListPhase.error : ListPhase.ready;
    } finally {
      _fetching = false;
    }
  }

  /// Appends the next page.
  Future<void> loadMore() async {
    if (_fetching || loadingMore.value || !hasMore) return;
    _fetching = true;
    loadingMore.value = true;
    try {
      final result = await repository.list(queryFor(pagination.page + 1));
      items.addAll(result.items);
      _pagination.value = result.pagination;
    } catch (e, stack) {
      AppLog.error('$runtimeType', 'load more failed', e, stack);
      // Deliberately quiet. The rows already on screen are still good, and a
      // banner over them for a page that did not arrive is worse than the
      // scroll simply stopping — which the user resolves by scrolling again.
    } finally {
      loadingMore.value = false;
      _fetching = false;
    }
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  /// Every one of these resets to page one: page four of the old result has
  /// nothing to do with the new one.

  Future<void> search(String value) async {
    if (value.trim() == query.value.trim()) return;
    query.value = value;
    await reload();
  }

  Future<void> applyFilters(Map<String, List<String>> next) async {
    filters
      ..clear()
      ..addAll(next);
    await reload();
  }

  Future<void> clearFilters() => applyFilters({});

  Future<void> applySort(SortOption option) async {
    if (option.matches(sort)) return;
    _sort.value = option;
    await reload();
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Removes a row.
  ///
  /// Returns the server's own words on refusal rather than a generic failure:
  /// "cannot delete an invoice that has payments against it" is actionable and
  /// "delete failed" is not.
  Future<String?> delete(String id) async {
    try {
      await repository.delete(id);
      items.removeWhere((item) => idOf(item) == id);
      // The count is now wrong by one, and the next page boundary with it.
      unawaited(reload(silent: true));
      return null;
    } catch (e, stack) {
      AppLog.error('$runtimeType', 'delete failed', e, stack);
      return parseErrorMessage(e, 'Could not delete that.');
    }
  }

  /// Puts a newly created or edited record on screen without a round trip.
  void upsert(T record) {
    final id = idOf(record);
    final index = items.indexWhere((item) => idOf(item) == id);
    if (index == -1) {
      items.insert(0, record);
    } else {
      items[index] = record;
    }
  }

  // ── To implement ──────────────────────────────────────────────────────────

  /// This entity's id, for matching a row.
  String idOf(T item);

  /// What to say when the first page fails. Named per entity, because "could
  /// not load" tells nobody which thing failed on a screen with three lists.
  String get couldNotLoadMessage;
}
