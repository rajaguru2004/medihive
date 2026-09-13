import 'package:get/get.dart';

import '../../../data/models/pre_triage_model.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/pre_triage_service.dart';
import '../../../data/utils/legacy_envelope.dart';
import '../../../data/utils/load_state.dart';

/// The screening board.
///
/// A screening is what exists before a patient record does: somebody walked
/// in, a nurse took their complaint and their observations, and nothing has
/// been registered yet. The board's job is to show which of those are still
/// waiting to be turned into something.
class PreTriageController extends GetxController with LoadStateMixin {
  static PreTriageController get to => Get.find<PreTriageController>();

  final _service = PreTriageService.to;

  final screenings = <PreTriageModel>[].obs;
  final query = ''.obs;
  final statusFilter = allScreenings.obs;

  static const allScreenings = 'All';
  static const screening = 'Screening';
  static const routed = 'Routed';
  static const registered = 'Registered';

  static const filters = [allScreenings, screening, routed, registered];

  /// The stored status behind each filter label.
  static const _statusFor = <String, String>{
    screening: 'screening',
    routed: 'routed',
    registered: 'registered_as_patient',
  };

  int countOf(String filter) => filter == allScreenings
      ? screenings.length
      : screenings.where((s) => s.status == _statusFor[filter]).length;

  /// Still waiting to be routed or registered. The number that matters.
  int get openCount => countOf(screening);

  List<PreTriageModel> get displayed {
    final status = _statusFor[statusFilter.value];
    final text = query.value.trim().toLowerCase();

    final rows = screenings.where((s) {
      if (status != null && s.status != status) return false;
      if (text.isNotEmpty) {
        final haystack = [
          s.fullName,
          s.screeningId,
          s.phone ?? '',
          s.chiefComplaint,
          s.mrn ?? '',
        ].join(' ').toLowerCase();
        if (!haystack.contains(text)) return false;
      }
      return true;
    }).toList();

    // Open screenings first, then newest. A screening nobody has acted on is
    // somebody sitting in a waiting room.
    rows.sort((a, b) {
      final aOpen = a.status == 'screening';
      final bOpen = b.status == 'screening';
      if (aOpen != bOpen) return aOpen ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return rows;
  }

  bool get isFiltered =>
      query.value.trim().isNotEmpty || statusFilter.value != allScreenings;

  @override
  void onReady() {
    super.onReady();
    load();
    if (Get.isRegistered<DataBus>()) {
      ever<int>(DataBus.to.tick('pre-triage'), (_) {
        if (!isLoading) load(silent: true);
      });
    }
  }

  Future<void> load({bool silent = false}) => runGuarded(
        () async {
          final response = await _service.fetchScreenings();
          screenings.assignAll(
            envelopeRows(response.data).map(PreTriageModel.fromJson).toList(),
          );
        },
        fallback: "Couldn't load screenings.",
        silent: silent,
      );

  Future<void> reload() => load(silent: true);

  void search(String text) => query.value = text;
  void filterBy(String filter) => statusFilter.value = filter;

  void clearFilters() {
    query.value = '';
    statusFilter.value = allScreenings;
  }
}
