import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/app_log.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../data/models/patient_portal_state.dart';
import '../../../../data/repositories/patient_portal_repository.dart';
import '../../../../data/services/session_manager.dart';
import '../../../../data/utils/error_handler.dart';
import '../../../../data/utils/load_state.dart';
import '../../patient_portal_navigation.dart';

/// The patient's own screen.
///
/// Two requests, and they are deliberately not one `Future.wait`: the second
/// needs the patient id the first brings back. `GET /api/appointments` is a
/// **staff** route — asked without a `patientId` it answers with every
/// appointment in the hospital, and a portal account is granted the read — so
/// the id is not an optimisation here, it is the scope.
class PatientDashboardController extends GetxController with LoadStateMixin {
  final PatientPortalRepository _repository = const PatientPortalRepository();

  final Rx<PatientPortalState> portal = PatientPortalState.empty.obs;
  final RxList<AppointmentModel> appointments = <AppointmentModel>[].obs;

  /// The appointments section's own failure, kept apart from the screen's.
  ///
  /// A patient whose appointment list is refused should still see their record
  /// and still be able to start telling their story. One load state for the
  /// whole screen would blank both because a list route was slow.
  final RxnString appointmentsError = RxnString();

  PortalPatient get patient => portal.value.patient;

  @override
  void onReady() {
    super.onReady();
    // onReady, not onInit: the first widget to touch `controller` constructs
    // it, and a write during that build marks the building `Obx` dirty.
    unawaited(reload());
  }

  /// Re-reads the record and the appointments.
  ///
  /// **Not `refresh()`.** `GetxController` already declares that name and it
  /// returns void, so an `onRefresh:` callback wired to it silently never
  /// awaits and the pull-to-refresh spinner snaps back before the request has
  /// left.
  Future<void> reload() async {
    await runGuarded(
      () async {
        portal.value = await _repository.portalState();
      },
      fallback: "We couldn't load your record just now.",
    );
    await _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    final id = patient.id;
    if (id.isEmpty) {
      appointments.clear();
      return;
    }
    appointmentsError.value = null;
    try {
      appointments.value = await _repository.myAppointments(id);
    } catch (e, stack) {
      appointmentsError.value = parseErrorMessage(
        e,
        "We couldn't load your appointments.",
      );
      AppLog.error('PatientDashboardController', 'appointments failed', e, stack);
    }
  }

  /// Their appointments, soonest first, with anything already past at the end.
  ///
  /// A patient opening this wants to know when they are next expected. The
  /// history matters too — it is how they recognise the clinic they are being
  /// sent back to — but it does not go first.
  List<AppointmentModel> get ordered {
    final rows = [...appointments];
    rows.sort((a, b) {
      final left = _at(a);
      final right = _at(b);
      final leftPast = left.isBefore(_startOfToday);
      final rightPast = right.isBefore(_startOfToday);
      if (leftPast != rightPast) return leftPast ? 1 : -1;
      return leftPast ? right.compareTo(left) : left.compareTo(right);
    });
    return rows;
  }

  /// The appointment's day and its clock time as one moment, so two on the
  /// same morning sort in the order they will actually happen.
  DateTime _at(AppointmentModel appointment) {
    final parts = appointment.appointmentTime.split(':');
    final hour = parts.isEmpty ? 0 : int.tryParse(parts.first) ?? 0;
    final minute = parts.length < 2 ? 0 : int.tryParse(parts[1]) ?? 0;
    final day = appointment.appointmentDate;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  DateTime get _startOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Starts the entry sequence: language, then consent, then the interview.
  ///
  /// Not awaited anywhere. `Get.toNamed` completes when the route is *popped*,
  /// so a caller that awaits it waits for the patient to come back — which on
  /// a sequence they are meant to finish is never.
  void startCaseTaking() => PatientPortalNavigation.beginEntry();

  /// Hands the device back.
  ///
  /// Through `SessionManager` rather than `AuthService.clearSession`, like
  /// every other sign-out in the app: teardown has to happen once, in one
  /// order, and this screen is more likely than most to be running on a device
  /// that belongs to the hospital rather than to the person holding it.
  Future<void> signOut() => SessionManager.to.endSession(
        reason: SessionEndReason.userLogout,
        revokeToken: true,
      );
}
