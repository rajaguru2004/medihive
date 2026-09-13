import 'package:get/get.dart';

import '../../../data/models/admission_model.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/inpatient_service.dart';
import '../../../data/utils/legacy_envelope.dart';
import '../../../data/utils/load_state.dart';

/// Every admission, live and closed.
class InpatientAdmissionsController extends GetxController with LoadStateMixin {
  static InpatientAdmissionsController get to =>
      Get.find<InpatientAdmissionsController>();

  final _service = Get.find<InpatientService>();

  final admissions = <AdmissionModel>[].obs;
  final query = ''.obs;
  final statusFilter = allStatuses.obs;

  static const allStatuses = 'All';

  List<String> get statuses => [
        allStatuses,
        ...{
          for (final a in admissions)
            if (a.status.trim().isNotEmpty) a.status.trim(),
        }.toList()
          ..sort(),
      ];

  int get activeCount =>
      admissions.where((a) => a.status.trim().toLowerCase() == 'active').length;

  List<AdmissionModel> get displayed {
    final text = query.value.trim().toLowerCase();

    final rows = admissions.where((a) {
      if (statusFilter.value != allStatuses &&
          a.status.trim().toLowerCase() !=
              statusFilter.value.trim().toLowerCase()) {
        return false;
      }
      if (text.isNotEmpty) {
        final haystack = [
          a.patient.fullName,
          a.patient.mrn,
          a.admissionReason,
          a.bed.bedNumber,
          a.bed.ward?.name ?? '',
        ].join(' ').toLowerCase();
        if (!haystack.contains(text)) return false;
      }
      return true;
    }).toList();

    // Live admissions first, then newest. A discharged patient is history; a
    // live one is somebody in a bed right now.
    rows.sort((a, b) {
      final aLive = a.status.trim().toLowerCase() == 'active';
      final bLive = b.status.trim().toLowerCase() == 'active';
      if (aLive != bLive) return aLive ? -1 : 1;
      return b.admissionDate.compareTo(a.admissionDate);
    });
    return rows;
  }

  bool get isFiltered =>
      query.value.trim().isNotEmpty || statusFilter.value != allStatuses;

  @override
  void onReady() {
    super.onReady();
    load();
    if (Get.isRegistered<DataBus>()) {
      ever<int>(DataBus.to.tick('admissions'), (_) {
        if (!isLoading) load(silent: true);
      });
    }
  }

  Future<void> load({bool silent = false}) => runGuarded(
        () async {
          final response = await _service.fetchAdmissions();
          admissions.assignAll(
            envelopeRows(response.data).map(AdmissionModel.fromJson).toList(),
          );
        },
        fallback: "Couldn't load admissions.",
        silent: silent,
      );

  Future<void> reload() => load(silent: true);

  void search(String text) => query.value = text;
  void filterByStatus(String status) => statusFilter.value = status;

  void clearFilters() {
    query.value = '';
    statusFilter.value = allStatuses;
  }
}
