import 'package:get/get.dart';

import '../../../core/app_clock.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/models/site_settings.dart';
import '../../../data/repositories/clinical_repository.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/formatters.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';
import '../../appointments/appointment_routes.dart';

/// One step of a booking's life, as the detail screen draws it.
class AppointmentStep {
  const AppointmentStep({
    required this.label,
    required this.done,
    this.at,
    this.terminal = false,
  });

  final String label;

  /// Whether the booking has reached this step.
  final bool done;

  /// When it did, where the server stamped it. Null for the steps this backend
  /// does not timestamp — booking and confirmation — which is why the ladder
  /// shows the word and not only the time.
  final DateTime? at;

  /// A step the booking ends on rather than passes through: cancelled, or did
  /// not attend.
  final bool terminal;
}

/// One booking, and everything a clinic desk can do to it.
class AppointmentDetailController extends GetxController with LoadStateMixin {
  static AppointmentDetailController get to =>
      Get.find<AppointmentDetailController>();

  static const _appointments = AppointmentRepository();

  final appointment = Rxn<AppointmentModel>();

  /// True while a status change, a reschedule or a delete is in flight. One
  /// flag rather than one per action: only one of them can be running, and a
  /// screen that lets a second start has recorded one arrival as two.
  final isActing = false.obs;

  String _id = '';

  String get id => _id;

  // ── Access ────────────────────────────────────────────────────────────────
  //
  // Hints, not permissions. The server authorises every request on its own and
  // the map in hand can be a minute older than the role it describes, so every
  // action below still handles the 403 that arrives anyway.

  bool _can(AccessVerb verb) => !Get.isRegistered<AccessService>() ||
      AccessService.to.can(Modules.appointments, verb);

  bool get canUpdate => _can(AccessVerb.update);
  bool get canDelete => _can(AccessVerb.delete);

  // ── The site's day ────────────────────────────────────────────────────────

  static SiteSettings get _site => Get.isRegistered<SettingsService>()
      ? SettingsService.to.settings
      : SiteSettings.empty;

  /// The same slots the booking form offers, from the same settings. Two ways
  /// of choosing a time that disagree is a clinic that double-books.
  List<String> get slots => ClinicSchedule.slots(
        start: _site.workingHoursStart,
        end: _site.workingHoursEnd,
        minutes: _site.appointmentDuration,
      );

  String formatDate(DateTime value) =>
      Formatters.date(value, pattern: _site.dateFormat);

  String formatSlot(String? value) =>
      Formatters.clockTime(value, use24Hour: _site.use24HourClock);

  // ── What is on offer ──────────────────────────────────────────────────────

  String get status => AppointmentStatus.normalise(appointment.value?.status);

  bool get isFinishedWith => AppointmentStatus.isClosed(status);

  /// The steps along the ladder this booking may still be moved to.
  ///
  /// Empty on a booking that is finished with, which is what makes the screen
  /// show a sentence instead of five buttons that 400.
  List<String> get nextSteps =>
      canUpdate ? AppointmentStatus.nextFrom(status) : const [];

  bool get canReschedule =>
      canUpdate && AppointmentStatus.canReschedule(status);

  bool get canCancel => canUpdate && !isFinishedWith;

  /// What the patient is called, for a confirm that names them rather than
  /// asking about "this record".
  String get patientName =>
      appointment.value?.patient.displayName ?? 'this patient';

  /// The ladder, for the timeline.
  List<AppointmentStep> get timeline {
    final booking = appointment.value;
    if (booking == null) return const [];

    final rank = _rankOf(status);
    return [
      const AppointmentStep(label: 'Booked', done: true),
      AppointmentStep(label: 'Confirmed', done: rank >= 1),
      AppointmentStep(
        label: 'Arrived',
        done: rank >= 2 || booking.checkedInAt != null,
        at: booking.checkedInAt,
      ),
      AppointmentStep(
        label: 'With the clinician',
        done: rank >= 3 || booking.startedAt != null,
        at: booking.startedAt,
      ),
      AppointmentStep(
        label: 'Seen',
        done: rank >= 4 || booking.completedAt != null,
        at: booking.completedAt,
      ),
      if (status == AppointmentStatus.cancelled)
        AppointmentStep(
          label: 'Cancelled',
          done: true,
          at: booking.cancelledAt,
          terminal: true,
        ),
      if (status == AppointmentStatus.noShow)
        const AppointmentStep(
          label: 'Did not attend',
          done: true,
          terminal: true,
        ),
    ];
  }

  /// How far along the ladder a status sits. `-1` for the two that leave it —
  /// a cancelled booking has not "reached" confirmation, it stopped.
  static int _rankOf(String status) => switch (status) {
        AppointmentStatus.scheduled ||
        AppointmentStatus.rescheduled =>
          0,
        AppointmentStatus.confirmed => 1,
        AppointmentStatus.checkedIn => 2,
        AppointmentStatus.inProgress => 3,
        AppointmentStatus.completed => 4,
        _ => -1,
      };

  /// What a step along the ladder is called, in the words a desk uses.
  static String labelOfStep(String status) => switch (status) {
        AppointmentStatus.confirmed => 'Confirm',
        AppointmentStatus.checkedIn => 'Check in',
        AppointmentStatus.inProgress => 'Start',
        AppointmentStatus.completed => 'Complete',
        AppointmentStatus.noShow => 'Did not attend',
        _ => Formatters.label(status),
      };

  static String captionOfStep(String status) => switch (status) {
        AppointmentStatus.confirmed => 'The patient has confirmed they will '
            'come',
        AppointmentStatus.checkedIn => 'The patient has arrived',
        AppointmentStatus.inProgress => 'With the clinician now',
        AppointmentStatus.completed => 'Seen, and done with',
        AppointmentStatus.noShow => 'Nobody came, and the slot is gone',
        _ => '',
      };

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _id = AppointmentRoutes.idFrom(Get.arguments, Get.parameters);

    // A caller that already has the record paints the header on the first
    // frame rather than after a round trip. It is replaced by [load]'s answer,
    // which is the one the actions act on.
    final passed = Get.arguments is Map
        ? (Get.arguments as Map)['appointment']
        : null;
    if (passed is AppointmentModel) {
      appointment.value = passed;
      if (_id.isEmpty) _id = passed.id;
    }
  }

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() => runGuarded(
        () async {
          appointment.value = await _appointments.read(_id);
        },
        fallback: "Couldn't open that booking.",
      );

  /// Never `refresh()` — `GetxController.refresh()` exists and returns void, so
  /// an `onRefresh:` wired to it silently never awaits.
  Future<void> reload() => load();

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Moves the booking one step along the ladder.
  Future<void> moveTo(String next) => _act(
        () => _appointments.setStatus(_id, next),
        success: switch (next) {
          AppointmentStatus.confirmed => '$patientName is confirmed.',
          AppointmentStatus.checkedIn => '$patientName has arrived.',
          AppointmentStatus.inProgress => '$patientName is with the clinician.',
          AppointmentStatus.completed => '$patientName has been seen.',
          AppointmentStatus.noShow => '$patientName did not attend.',
          _ => 'Updated.',
        },
        failure: "Couldn't update that booking.",
      );

  /// Moves the booking to another slot.
  ///
  /// Date, time and `rescheduled` together, in one request. A reschedule that
  /// sends the pair without the status leaves a booking that reads `scheduled`
  /// on a day nobody agreed to.
  Future<void> reschedule({required DateTime date, required String time}) =>
      _act(
        () => _appointments.reschedule(_id, date: date, time: time),
        success: '$patientName is moved to ${formatSlot(time)} on '
            '${formatDate(date)}.',
        failure: "Couldn't move that booking.",
      );

  /// Cancels the booking, with the reason the server stores beside it.
  Future<void> cancel(String reason) => _act(
        () => _appointments.setStatus(
          _id,
          AppointmentStatus.cancelled,
          cancellationReason: reason,
        ),
        success: "$patientName's appointment is cancelled.",
        failure: "Couldn't cancel that booking.",
      );

  /// Removes the booking entirely.
  ///
  /// The route answers **204 with an empty body**, which `ApiEnvelope` reads as
  /// a success with a null payload — that is what makes this not throw on every
  /// successful delete.
  Future<void> remove() async {
    if (isActing.value) return;
    isActing.value = true;
    try {
      await _appointments.delete(_id);
      Get.back<void>();
      showBentoToast("$patientName's appointment is deleted.");
    } on ApiForbiddenException catch (e) {
      showBentoToast(e.message, tone: ToastTone.failure);
    } catch (e) {
      showBentoToast(
        parseErrorMessage(e, "Couldn't delete that booking."),
        tone: ToastTone.failure,
      );
    } finally {
      isActing.value = false;
    }
  }

  /// Runs a write, shows what it did, and leaves the record on screen.
  ///
  /// The updated booking is adopted from the response rather than re-fetched:
  /// the PATCH answers with the whole record, and a second GET is a round trip
  /// that can disagree with the one that just succeeded.
  Future<void> _act(
    Future<AppointmentModel> Function() write, {
    required String success,
    required String failure,
  }) async {
    if (isActing.value) return;
    isActing.value = true;
    try {
      final updated = await write();
      // A 200 carrying nothing usable — which a couple of handlers still do —
      // must not blank a record that is on screen.
      if (updated.id.isNotEmpty) {
        appointment.value = updated;
      } else {
        await load();
      }
      showBentoToast(success);
    } on ApiForbiddenException catch (e) {
      showBentoToast(e.message, tone: ToastTone.failure);
    } catch (e) {
      showBentoToast(
        parseErrorMessage(e, failure),
        tone: ToastTone.failure,
      );
    } finally {
      isActing.value = false;
    }
  }

  /// Today, floored, for the reschedule sheet's opening date.
  static DateTime today() {
    final now = AppClock.now();
    return DateTime(now.year, now.month, now.day);
  }
}
