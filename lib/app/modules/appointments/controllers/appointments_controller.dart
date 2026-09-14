import 'package:get/get.dart';

import '../../../core/app_clock.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/services/appointment_service.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/utils/load_state.dart';

/// Which cut of the clinic is showing.
enum ClinicView {
  /// Everything booked for today, in time order. What a clinic desk opens on.
  today,

  /// One chosen day, picked from a month.
  day,

  /// Everything, searchable.
  all,
}

class AppointmentsController extends GetxController with LoadStateMixin {
  static AppointmentsController get to => Get.find<AppointmentsController>();

  final _service = Get.find<AppointmentService>();

  final appointments = <AppointmentModel>[].obs;
  final doctors = <AppointmentDoctor>[].obs;

  final view = ClinicView.today.obs;
  final query = ''.obs;
  final statusFilter = allStatuses.obs;
  final doctorFilter = allDoctors.obs;
  final selectedDay = Rx<DateTime>(AppClock.now());

  static const allStatuses = 'All statuses';
  static const allDoctors = 'All clinicians';

  // ── Today ─────────────────────────────────────────────────────────────────

  List<AppointmentModel> get today => appointments
      .where((a) => _sameDay(a.appointmentDate, AppClock.now()))
      .toList();

  int countToday(String? status) => status == null
      ? today.length
      : today.where((a) => _is(a, status)).length;

  /// Still to happen: booked, arrived, or with the clinician now.
  ///
  /// The distinction matters because a clinic desk is only ever asked one
  /// question — who is still to be seen — and a list that mixes the seen in
  /// with the waiting cannot answer it.
  List<AppointmentModel> get todayOpen {
    final rows = today
        .where((a) => const {
              'scheduled',
              'confirmed',
              'checked_in',
              'in_progress',
            }.contains(a.status.trim().toLowerCase()))
        .toList()
      ..sort(_byTime);
    return rows;
  }

  /// Dealt with: seen, cancelled, or did not attend.
  List<AppointmentModel> get todayClosed {
    final rows = today
        .where((a) => !todayOpen.contains(a))
        .toList()
      ..sort(_byTime);
    return rows;
  }

  // ── Filters ───────────────────────────────────────────────────────────────

  /// Statuses actually present, so a filter never offers an empty result.
  List<String> get statuses => [
        allStatuses,
        ...{
          for (final a in appointments)
            if (a.status.trim().isNotEmpty) a.status.trim(),
        }.toList()
          ..sort(),
      ];

  List<AppointmentModel> get displayed {
    final rows = switch (view.value) {
      ClinicView.today => today,
      ClinicView.day => appointments
          .where((a) => _sameDay(a.appointmentDate, selectedDay.value))
          .toList(),
      ClinicView.all => appointments.toList(),
    };

    final text = query.value.trim().toLowerCase();

    final filtered = rows.where((a) {
      if (text.isNotEmpty) {
        final haystack = [
          a.patient.fullName,
          a.patient.mrn,
          a.doctor.fullName,
          a.chiefComplaint,
        ].join(' ').toLowerCase();
        if (!haystack.contains(text)) return false;
      }
      if (statusFilter.value != allStatuses &&
          a.status.trim().toLowerCase() !=
              statusFilter.value.trim().toLowerCase()) {
        return false;
      }
      if (doctorFilter.value != allDoctors && a.doctorId != doctorFilter.value) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort(view.value == ClinicView.all
        ? (a, b) {
            final byDate = b.appointmentDate.compareTo(a.appointmentDate);
            return byDate != 0 ? byDate : _byTime(a, b);
          }
        : _byTime);

    return filtered;
  }

  bool get isFiltered =>
      query.value.trim().isNotEmpty ||
      statusFilter.value != allStatuses ||
      doctorFilter.value != allDoctors;

  /// How many appointments each day of [month] holds, for the month grid.
  Map<int, int> countsForMonth(DateTime month) {
    final counts = <int, int>{};
    for (final a in appointments) {
      final date = a.appointmentDate.toLocal();
      if (date.year != month.year || date.month != month.month) continue;
      counts[date.day] = (counts[date.day] ?? 0) + 1;
    }
    return counts;
  }

  @override
  void onReady() {
    super.onReady();
    load();
    if (Get.isRegistered<DataBus>()) {
      ever<int>(DataBus.to.tick('appointments'), (_) {
        if (!isLoading) load(silent: true);
      });
    }
  }

  Future<void> load({bool silent = false}) => runGuarded(
        () async {
          final results = await Future.wait([
            _service.fetchAppointments(),
            _service.fetchDoctors(),
          ]);

          appointments.assignAll(
            _rowsFrom(results[0].data)
                .map(AppointmentModel.fromJson)
                .toList(),
          );
          doctors.assignAll(
            _rowsFrom(results[1].data)
                .map(AppointmentDoctor.fromJson)
                .toList(),
          );
        },
        fallback: "Couldn't load the clinic list.",
        silent: silent,
      );

  Future<void> reload() => load(silent: true);

  void showView(ClinicView next) => view.value = next;
  void search(String text) => query.value = text;
  void filterByStatus(String status) => statusFilter.value = status;
  void filterByDoctor(String id) => doctorFilter.value = id;

  void selectDay(DateTime date) {
    selectedDay.value = date;
    view.value = ClinicView.day;
  }

  void clearFilters() {
    query.value = '';
    statusFilter.value = allStatuses;
    doctorFilter.value = allDoctors;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _is(AppointmentModel a, String status) =>
      a.status.trim().toLowerCase() == status;

  static bool _sameDay(DateTime a, DateTime b) {
    final x = a.toLocal();
    final y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  /// Sorts on the stored `"HH:mm"` string.
  ///
  /// Lexicographic, which is correct only because the backend zero-pads the
  /// hour — `"09:30"`, never `"9:30"`. Parsed rather than trusted, so a row
  /// that is not padded sorts by its number instead of landing after `"1:00"`.
  static int _byTime(AppointmentModel a, AppointmentModel b) =>
      _minutes(a.appointmentTime).compareTo(_minutes(b.appointmentTime));

  static int _minutes(String time) {
    final parts = time.trim().split(':');
    if (parts.length < 2) return 0;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    return hours * 60 + minutes;
  }

  /// Pulls rows out of the shapes this API answers with: `data.data` for a
  /// paged collection, `data` for a plain list.
  List<Map<String, dynamic>> _rowsFrom(dynamic body) {
    if (body is! Map || body['success'] != true) return const [];
    final payload = body['data'];
    final rows = payload is Map ? payload['data'] : payload;
    if (rows is! List) return const [];
    return rows.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }
}
