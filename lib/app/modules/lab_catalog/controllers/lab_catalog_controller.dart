import 'package:get/get.dart';

import '../../../core/paged_list_controller.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/lab_test.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/laboratory_service.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../theme/theme.dart';

/// The test catalogue: what this site can be asked to run.
class LabCatalogController extends PagedListController<LabTest> {
  LabCatalogController()
      : super(
          repository: const LabTestRepository(),
          // One order, and no sort control: `getTests` orders by category then
          // name unconditionally and reads no `orderBy`.
          sortOptions: const [
            SortOption(field: 'testName', label: 'Name', descending: false),
          ],
          // `GET /laboratory/tests` is a bare array with no `meta` — the whole
          // active catalogue arrives in one response, so there is no second
          // page to ask for.
          pageSize: 100,
        );

  static LabCatalogController get to => Get.find<LabCatalogController>();

  /// The field the category filter is held under, in the base class's own
  /// filter map — so the count on the filter button comes for free.
  static const String categoryField = 'category';

  @override
  String idOf(LabTest item) => item.id;

  @override
  String get couldNotLoadMessage => "Couldn't load the test catalogue.";

  bool get canCreate =>
      AccessService.to.can(Modules.laboratory, AccessVerb.create);

  bool get canUpdate =>
      AccessService.to.can(Modules.laboratory, AccessVerb.update);

  bool get canDelete =>
      AccessService.to.can(Modules.laboratory, AccessVerb.delete);

  /// The whole catalogue, in one request and with nothing the route ignores.
  ///
  /// The base class would add `search`, `orderBy` and `orderDir`; this route
  /// reads only `category`, so all three would change the request and not the
  /// answer — which is the definition of a control that lies.
  @override
  PagedQuery queryFor(int page) =>
      PagedQuery(page: page, limit: pageSize);

  /// Filtered in memory, because the whole catalogue is already here.
  ///
  /// `GET /laboratory/tests` has no `search` parameter at all, so a term sent
  /// to the server would come back with every row — a search box that reads as
  /// broken rather than as unsupported.
  @override
  Future<void> search(String value) async {
    query.value = value;
  }

  /// Applied in memory, for the same reason [search] is. The base class would
  /// refetch a collection that is already complete.
  @override
  Future<void> applyFilters(Map<String, List<String>> next) async {
    filters
      ..clear()
      ..addAll(next);
  }

  @override
  Future<void> clearFilters() async {
    query.value = '';
    await applyFilters(const {});
  }

  bool get isFiltered => query.value.trim().isNotEmpty || filterCount > 0;

  List<String> get selectedCategories => filters[categoryField] ?? const [];

  /// Every category the catalogue actually uses.
  ///
  /// Read off the loaded rows rather than off a hard-coded list: a site that
  /// runs immunology gets an Immunology filter without an app release, and one
  /// that does not is not offered an empty one.
  List<String> get categories {
    final found = <String>{
      for (final test in items)
        if ((test.testCategory ?? '').trim().isNotEmpty)
          test.testCategory!.trim(),
    }.toList()
      ..sort();
    return found;
  }

  List<LabTest> get visible {
    final needle = query.value.trim().toLowerCase();
    final wanted = [
      for (final value in selectedCategories) value.trim().toLowerCase(),
    ];

    return items.where((test) {
      final category = (test.testCategory ?? '').trim().toLowerCase();
      if (wanted.isNotEmpty && !wanted.contains(category)) return false;
      if (needle.isEmpty) return true;
      return test.testName.toLowerCase().contains(needle) ||
          (test.testCode ?? '').toLowerCase().contains(needle) ||
          (test.specimenType ?? '').toLowerCase().contains(needle);
    }).toList();
  }

  /// The site's own money convention. A price list with a bare number on it is
  /// how one ships to the wrong country.
  String priceOf(LabTest test) =>
      test.priceLabel(SettingsService.to.settings.money);

  /// Takes a test out of the catalogue.
  ///
  /// A soft delete on this backend — the row keeps its id and drops out of
  /// `isActive`, which is what keeps every order that already names it
  /// readable.
  Future<void> remove(LabTest test) async {
    final failure = await delete(test.id);
    if (failure != null) {
      showBentoToast(failure, tone: ToastTone.failure);
      return;
    }
    showBentoToast('${test.testName} is no longer orderable.');
  }
}
