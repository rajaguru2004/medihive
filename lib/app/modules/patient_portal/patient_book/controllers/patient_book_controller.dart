import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/app_clock.dart';
import '../../../../core/app_log.dart';
import '../../../../data/models/doctor_model.dart';
import '../../../../data/models/drafts/appointment_draft.dart';
import '../../../../data/models/site_settings.dart';
import '../../../../data/repositories/clinical_repository.dart';
import '../../../../data/repositories/patient_portal_repository.dart';
import '../../../../data/services/settings_service.dart';
import '../../../../data/utils/api_envelope.dart';
import '../../../../data/utils/error_handler.dart';
import '../../../../data/utils/formatters.dart';
import '../../../../data/utils/load_state.dart';
import '../../../../theme/theme.dart';
import '../../patient_dashboard/controllers/patient_dashboard_controller.dart';
import '../../patient_portal_navigation.dart';

/// A patient booking their own appointment.
///
/// Deliberately not `AppointmentFormController` with a flag. That screen is a
/// desk booking somebody in: it chooses the patient, sets a duration, and
/// offers `emergency` as a visit type. Every one of those is wrong here — the
/// patient is the caller, the length of a clinic slot is the site's decision
/// and not theirs, and a person who is having an emergency must be told to
/// come in rather than offered a slot on Thursday. What the two share is the
/// draft and the repository, which is where the shape of the request lives.
///
/// ## Three answers, and only three
///
/// Who they want to see, when, and what it is about. The site's own slot
/// length and working hours supply the rest, exactly as they do for the desk.
class PatientBookController extends GetxController with LoadStateMixin {
  static PatientBookController get to => Get.find<PatientBookController>();

  static const AppointmentRepository _appointments = AppointmentRepository();
  static const PatientPortalRepository _portal = PatientPortalRepository();

  final formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();

  final doctors = <DoctorModel>[].obs;
  final doctor = Rxn<DoctorModel>();
  final date = Rx<DateTime>(_today());
  final time = RxnString();
  final visitType = firstVisit.obs;

  /// The start times this clinician's day has already given away.
  ///
  /// A set of `09:30`-shaped strings, which is what the slot grid is made of
  /// too, so the comparison is exact rather than a parse on both sides.
  final taken = <String>{}.obs;

  /// The patient this booking is for, from their own record.
  ///
  /// The server overwrites it with the id on the bearer token — a patient
  /// books for themselves and for nobody else — but the create DTO declares
  /// `patientId` as required, so a request without one is a 400 before the
  /// scoping ever runs.
  final patientId = ''.obs;

  final isSubmitting = false.obs;

  /// The availability read, which has its own spinner and its own silence.
  ///
  /// Kept apart from [isLoading]: it re-runs every time the clinician or the
  /// day changes, and driving the screen's load state from it would blank a
  /// form somebody is halfway through filling in.
  final isLoadingSlots = false.obs;

  final errorMessage = RxnString();

  /// True once somebody has tried to book. Until then a blank field is a form
  /// nobody has filled in yet, not an error.
  final showErrors = false.obs;

  /// The two reasons a patient books a clinic slot for themselves.
  ///
  /// `emergency` is the third visit type this backend stores and it is
  /// deliberately not offered. It means "came through the ED" — a category
  /// recorded about somebody who is already in the building — and a patient
  /// who picked it here would have described an emergency to a screen and
  /// then waited at home for a Thursday appointment. The screen says where to
  /// go instead.
  static const String firstVisit = 'new_patient';
  static const String followUp = 'follow_up';

  static const Map<String, String> visitTypes = {
    firstVisit: 'First visit',
    followUp: 'Follow-up',
  };

  /// How far ahead a patient may book.
  ///
  /// A bound rather than an open calendar: a clinic's diary that far out is
  /// not yet a diary, and a booking made a year ahead is one nobody will
  /// honour. Ninety days is what the date picker offers and what
  /// [dateError] refuses past.
  static const int bookableDays = 90;

  // ── The site's day ────────────────────────────────────────────────────────

  static SiteSettings get _site => Get.isRegistered<SettingsService>()
      ? SettingsService.to.settings
      : SiteSettings.empty;

  /// Every slot this site's diary has, before anything is taken out of it.
  ///
  /// The same generator the desk's booking form uses, for the reason its
  /// comment gives: a clinic whose two ways of choosing a slot offer different
  /// slots is a clinic that double-books.
  List<String> get _allSlots => ClinicSchedule.slots(
    start: _site.workingHoursStart,
    end: _site.workingHoursEnd,
    minutes: _site.appointmentDuration,
  );

  /// What this patient can actually tap.
  ///
  /// Two removals, and the second is the one worth stating: a slot earlier
  /// today is not a slot. A grid that still offers 09:00 at half past ten is a
  /// grid whose first row is a refusal waiting to happen, and the refusal
  /// arrives from the server after the patient has already chosen.
  List<String> get slots {
    final all = _allSlots.where((slot) => !taken.contains(slot));
    if (!_isToday(date.value)) return all.toList();

    final now = AppClock.now();
    final minutesNow = now.hour * 60 + now.minute;
    return all
        .where((slot) => (ClinicSchedule.minutesOf(slot) ?? 0) > minutesNow)
        .toList();
  }

  /// Whether the day on screen has nothing left in it.
  ///
  /// Distinct from "the availability call failed", which leaves the grid full
  /// rather than empty — the screen must not tell somebody a clinic is full
  /// because a request timed out.
  bool get isDayFull => !isLoadingSlots.value && slots.isEmpty;

  String formatDate(DateTime value) =>
      Formatters.date(value, pattern: _site.dateFormat);

  /// A slot as this site writes the time — `15:30`, or `3:30 PM`.
  String formatSlot(String? value) =>
      Formatters.clockTime(value, use24Hour: _site.use24HourClock);

  DateTime get firstBookableDay => _today();
  DateTime get lastBookableDay =>
      _today().add(const Duration(days: bookableDays));

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// True when the reason in the box came from the interview rather than from
  /// this patient typing it here.
  ///
  /// Only changes what is said above the field. The text itself is ordinary
  /// editable text either way — a reason a patient cannot change would be the
  /// app putting words in their mouth at the one point a clinician reads them
  /// as the patient's own.
  final reasonFromCase = false.obs;

  @override
  void onInit() {
    super.onInit();
    // A booking started from the end of an interview. `onInit` and not
    // `onReady`: the field has to hold the text before the first build reads
    // it, and this writes no observable the build is already watching.
    final arguments = Get.arguments;
    final carried = arguments is Map ? '${arguments['reason'] ?? ''}'.trim() : '';
    if (carried.isEmpty) return;
    reasonController.text = carried;
    reasonFromCase.value = true;
    // The visit type is deliberately left alone. Having answered an interview
    // says nothing about whether this is somebody's first visit — the intake
    // is taken from new patients and returning ones alike — and a segmented
    // control that arrives pre-answered is one nobody reads before booking.
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(load());
  }

  /// The clinicians, the patient's own id, and the first day's availability.
  Future<void> load() => runGuarded(() async {
    doctors.assignAll(await _appointments.bookableDoctors());
    await _resolvePatient();
    // Only once a clinician is chosen is there a day to ask about, so
    // nothing is fetched here. A single-clinician site is the exception
    // and it is the common one in a small clinic: choosing for them
    // saves a tap and makes the slot grid appear with the screen.
    if (doctors.length == 1) chooseDoctor(doctors.first);
  }, fallback: "We couldn't open the booking screen just now.");

  /// Which record this booking belongs to.
  ///
  /// Read from the dashboard when it is still in memory — it is the screen
  /// underneath this one and it has just fetched the same record — and asked
  /// for only when it is not, which is the deep-link case.
  Future<void> _resolvePatient() async {
    if (Get.isRegistered<PatientDashboardController>()) {
      final known = Get.find<PatientDashboardController>().patient.id;
      if (known.isNotEmpty) {
        patientId.value = known;
        return;
      }
    }
    patientId.value = (await _portal.portalState()).patient.id;
  }

  // ── Choosing ──────────────────────────────────────────────────────────────

  void chooseDoctor(DoctorModel value) {
    doctor.value = value;
    errorMessage.value = null;
    unawaited(_loadTaken());
  }

  void chooseDate(DateTime? value) {
    if (value == null) return;
    date.value = DateTime(value.year, value.month, value.day);
    errorMessage.value = null;
    unawaited(_loadTaken());
  }

  void chooseSlot(String value) {
    time.value = value;
    errorMessage.value = null;
  }

  void setVisitType(String value) => visitType.value = value;

  /// What this clinician's chosen day already holds.
  ///
  /// A failure here is deliberately quiet — logged, and the grid stays as it
  /// was. The server refuses a slot that has gone in the meantime, so the
  /// worst case of an unanswered availability read is one refused booking
  /// with a sentence explaining it; the worst case of turning it into a
  /// screen-wide error is a patient who cannot book at all because a
  /// secondary request was slow.
  Future<void> _loadTaken() async {
    final chosen = doctor.value;
    if (chosen == null) {
      taken.clear();
      return;
    }

    isLoadingSlots.value = true;
    try {
      taken
        ..clear()
        ..addAll(
          await _appointments.takenSlots(doctorId: chosen.id, date: date.value),
        );

      // A time chosen before the list moved under it. Cleared rather than
      // left, because a picker showing a slot the grid no longer offers is a
      // booking that fails on send for a reason nothing on screen explains.
      final held = time.value;
      if (held != null && !slots.contains(held)) time.value = null;
    } catch (e, stack) {
      AppLog.error('PatientBookController', 'availability failed', e, stack);
    } finally {
      isLoadingSlots.value = false;
    }
  }

  // ── Validation ────────────────────────────────────────────────────────────

  /// Plain words, because a patient writes them.
  ///
  /// The desk's version of this field is a chief complaint and is validated at
  /// five characters for the same reason: "pain" tells the clinician who opens
  /// the booking nothing they did not already know.
  String? validateReason(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Tell us what the appointment is about';
    if (text.length < 5) return 'A few more words — five characters at least';
    return null;
  }

  String? get doctorError =>
      showErrors.value && doctor.value == null ? 'Choose who to see' : null;

  String? get timeError => showErrors.value && (time.value ?? '').trim().isEmpty
      ? 'Choose a time'
      : null;

  String? get dateError {
    final chosen = date.value;
    if (chosen.isBefore(firstBookableDay)) return 'Choose a day from today on';
    if (chosen.isAfter(lastBookableDay)) {
      return 'Appointments can be booked up to $bookableDays days ahead';
    }
    return null;
  }

  /// How many answers are still missing, for the line above the button. A
  /// refusal that only marks the fields is a refusal nobody can see: the field
  /// it complains about is usually scrolled off the top.
  int get missingCount {
    if (!showErrors.value) return 0;
    var count = 0;
    if (doctorError != null) count++;
    if (dateError != null) count++;
    if (timeError != null) count++;
    if (validateReason(reasonController.text) != null) count++;
    return count;
  }

  // ── The payload ───────────────────────────────────────────────────────────

  /// The booking this screen would send.
  ///
  /// No `durationMinutes` and no `notes`. The first is the site's decision and
  /// the server caps a patient's booking at an hour anyway; the second is a
  /// field the desk writes *about* a patient, and offering a patient two boxes
  /// to say the same thing in gets the important one left empty.
  AppointmentDraft get draft => AppointmentDraft(
    patientId: patientId.value,
    doctorId: doctor.value?.id,
    appointmentDate: date.value,
    appointmentTime: time.value,
    appointmentType: visitType.value,
    chiefComplaint: reasonController.text.trim(),
  );

  // ── Booking ───────────────────────────────────────────────────────────────

  Future<void> submit() async {
    if (isSubmitting.value) return;
    showErrors.value = true;

    if (doctor.value == null) {
      errorMessage.value = 'Choose who you would like to see.';
      return;
    }
    if (dateError != null) {
      errorMessage.value = dateError;
      return;
    }
    if ((time.value ?? '').trim().isEmpty) {
      errorMessage.value = 'Choose a time.';
      return;
    }
    if (!(formKey.currentState?.validate() ?? false)) return;

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    final when = '${formatSlot(time.value)} on ${formatDate(date.value)}';

    try {
      await _appointments.create(draft.toCreateJson());
      // All the way back rather than one pop: the dashboard reloads its own
      // appointments when the `DataBus` says the collection moved, and
      // `CrudRepository.create` announces that for us.
      PatientPortalNavigation.backToDashboard();
      showBentoToast('Asked for $when. The hospital will confirm it.');
    } on ApiException catch (e) {
      // 409 is the slot going while this screen held it — somebody at the desk
      // booked it, or another patient did. The grid on screen is now wrong, so
      // it is re-read before the patient is asked to choose again.
      if (e.statusCode == 409) {
        time.value = null;
        unawaited(_loadTaken());
      }
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = parseErrorMessage(
        e,
        "We couldn't book that appointment.",
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    reasonController.dispose();
    super.onClose();
  }

  bool _isToday(DateTime value) {
    final now = AppClock.now();
    return value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
  }

  static DateTime _today() {
    final now = AppClock.now();
    return DateTime(now.year, now.month, now.day);
  }
}
