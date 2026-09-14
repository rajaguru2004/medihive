import 'package:get/get.dart';

import '../../../core/paged_list_controller.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/radiology_exam.dart';
import '../../../data/repositories/radiology_repository.dart';
import '../../../data/services/access_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../theme/theme.dart';

/// The imaging catalogue: what this department can be asked for.
///
/// A short list by nature — a department runs tens of exams — so the search is
/// done here rather than by the server. `GET /api/radiology/exams` takes
/// `category` and nothing else: it has no pagination DTO, so `page`, `limit`
/// and `search` are ignored rather than honoured, and a search sent there
/// would silently return the whole catalogue and look like a broken filter.
class RadiologyCatalogController extends PagedListController<RadiologyExam> {
  RadiologyCatalogController()
      : super(
          repository: _repository(),
          sortOptions: const [
            SortOption(field: 'examName', label: 'A–Z', descending: false),
          ],
        );

  static RadiologyCatalogController get to =>
      Get.find<RadiologyCatalogController>();

  /// The repository, registering the set if nothing has yet — see
  /// `RadiologyController._repository`.
  static RadiologyExamRepository _repository() {
    RadiologyRepositories.register();
    return RadiologyRepositories.exams;
  }

  @override
  String idOf(RadiologyExam item) => item.id;

  @override
  String get couldNotLoadMessage => "Couldn't load the exam catalogue.";

  bool get canAdd =>
      Get.isRegistered<AccessService>() &&
      AccessService.to.can(Modules.radiology, AccessVerb.create);

  bool get canEdit =>
      Get.isRegistered<AccessService>() &&
      AccessService.to.can(Modules.radiology, AccessVerb.update);

  /// The catalogue as the screen shows it: filtered by the search term, in
  /// category then name order.
  List<RadiologyExam> get displayed {
    final term = query.value.trim().toLowerCase();
    final rows = items.where((exam) {
      if (term.isEmpty) return true;
      return [
        exam.examName,
        exam.examCode ?? '',
        exam.examCategory ?? '',
        exam.bodyPart ?? '',
        exam.modality ?? '',
      ].join(' ').toLowerCase().contains(term);
    }).toList();

    rows.sort((a, b) {
      final byCategory =
          (a.examCategory ?? '').compareTo(b.examCategory ?? '');
      return byCategory != 0 ? byCategory : a.examName.compareTo(b.examName);
    });
    return rows;
  }

  bool get isFiltered => query.value.trim().isNotEmpty;

  @override
  PagedQuery queryFor(int page) =>
      // No `page`, no `orderBy`, no `search`: this route declares none of them.
      const PagedQuery(page: 1, limit: 100);

  /// Filters in memory rather than refetching. Overrides the base class, whose
  /// `search` reloads — which here would be a round trip that changes nothing.
  @override
  Future<void> search(String value) async {
    query.value = value;
  }
}
