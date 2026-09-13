import 'package:get/get.dart';

import '../../../core/app_clock.dart';
import '../../../data/models/admission_model.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/services/inpatient_service.dart';
import '../../../data/utils/formatters.dart';
import '../../../data/utils/legacy_envelope.dart';
import '../../../data/utils/load_state.dart';

/// Who is in a bed right now.
///
/// The admissions screen is the register; this is the ward round — live
/// admissions only, longest stay first, because length of stay is the thing a
/// consultant scans a list like this for.
class InpatientOverviewController extends GetxController with LoadStateMixin {
  static InpatientOverviewController get to =>
      Get.find<InpatientOverviewController>();

  final _service = Get.find<InpatientService>();

  final admissions = <AdmissionModel>[].obs;
  final query = ''.obs;

  List<AdmissionModel> get active =>
      admissions.where((a) => a.status.trim().toLowerCase() == 'active').toList();

  List<AdmissionModel> get displayed {
    final text = query.value.trim().toLowerCase();

    final rows = active.where((a) {
      if (text.isEmpty) return true;
      final haystack = [
        a.patient.fullName,
        a.patient.mrn,
        a.bed.bedNumber,
        a.bed.ward?.name ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(text);
    }).toList();

    rows.sort((a, b) => a.admissionDate.compareTo(b.admissionDate));
    return rows;
  }

  /// Stays past a week. Not an alarm — a prompt to check whether a discharge
  /// plan exists.
  int get longStayCount => active
      .where((a) => Formatters.lengthOfStayDays(a.admissionDate) >= 7)
      .length;

  /// Admitted since midnight.
  int get admittedToday {
    final today = AppClock.now();
    return active.where((a) {
      final date = a.admissionDate.toLocal();
      return date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
    }).length;
  }

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
        fallback: "Couldn't load the ward round.",
        silent: silent,
      );

  Future<void> reload() => load(silent: true);

  void search(String text) => query.value = text;
}
