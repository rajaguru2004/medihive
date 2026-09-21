import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/app_log.dart';
import '../../../../core/i18n/patient_text.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../data/models/case_review.dart';
import '../../../../data/models/case_session.dart';
import '../../../../data/models/patient_document.dart';
import '../../../../data/models/patient_portal_state.dart';
import '../../../../data/repositories/case_review_repository.dart';
import '../../../../data/repositories/clinical_repository.dart';
import '../../../../data/repositories/patient_documents_repository.dart';
import '../../../../data/repositories/patient_portal_repository.dart';
import '../../../../data/services/data_bus.dart';
import '../../../../data/services/patient_case_service.dart';
import '../../../../data/services/session_manager.dart';
import '../../../../data/utils/error_handler.dart';
import '../../../../data/utils/load_state.dart';
import '../../../case_review/case_review_routes.dart';
import '../../../patient_documents/patient_documents_navigation.dart';
import '../../patient_portal_navigation.dart';

/// The patient's own screen.
///
/// Two requests, and they are deliberately not one `Future.wait`: the second
/// needs the patient id the first brings back. `GET /api/appointments` is a
/// **staff** route — asked without a `patientId` it answers with every
/// appointment in the hospital, and a portal account is granted the read — so
/// the id is not an optimisation here, it is the scope.
class PatientDashboardController extends GetxController with LoadStateMixin {
  PatientDashboardController() {
    // The one thing on this screen that outlives it. See `PatientCaseService`:
    // `sessions/current` answers null for a case that has been sent, so the
    // only party that can tell "you sent this" from "you never started" is the
    // phone that pressed Send.
    if (!Get.isRegistered<PatientCaseService>()) {
      Get.put(PatientCaseService(), permanent: true);
      SessionManager.to.registerScoped<PatientCaseService>();
    }
  }

  final PatientPortalRepository _repository = const PatientPortalRepository();
  final CaseReviewRepository _cases = const CaseReviewRepository();
  final PatientDocumentsRepository _documentsRepository =
      PatientDocumentsRepositories.instance;

  final Rx<PatientPortalState> portal = PatientPortalState.empty.obs;
  final RxList<AppointmentModel> appointments = <AppointmentModel>[].obs;

  /// The prescriptions, reports and letters this patient has handed over.
  final RxList<PatientDocument> documents = <PatientDocument>[].obs;

  /// The interview they have open, if they have one. Null is an answer — and
  /// it is also the answer for a case already sent, which is why
  /// [submission] exists beside it.
  final Rxn<CaseSession> openCase = Rxn<CaseSession>();

  /// The case this device sent, for as long as this session lasts. §39.
  CaseSubmissionReceipt? get submission =>
      PatientCaseService.to.submission.value;

  /// The appointments section's own failure, kept apart from the screen's.
  ///
  /// A patient whose appointment list is refused should still see their record
  /// and still be able to start telling their story. One load state for the
  /// whole screen would blank both because a list route was slow.
  final RxnString appointmentsError = RxnString();

  /// The documents section's own failure, kept apart for the same reason.
  final RxnString documentsError = RxnString();

  PortalPatient get patient => portal.value.patient;

  @override
  void onReady() {
    super.onReady();
    // onReady, not onInit: the first widget to touch `controller` constructs
    // it, and a write during that build marks the building `Obx` dirty.
    unawaited(reload());

    // A case sent from the review screen, or a document added from the list,
    // both land here as a change to an entity this screen shows. Announced on
    // the bus rather than reached for directly: the review screen has no
    // business knowing this controller exists.
    if (Get.isRegistered<DataBus>()) {
      ever<int>(
        DataBus.to.tick(CaseReviewEntities.caseSession),
        (_) => unawaited(_loadCase()),
      );
      ever<int>(
        DataBus.to.tick(PatientDocumentEntities.documents),
        (_) => unawaited(_loadDocuments()),
      );
      // A booking made on the screen above this one. `CrudRepository.create`
      // announces it, so the booking screen never reaches back here — and the
      // list is re-read rather than having the new row pushed into it, because
      // what the server stored is what this screen shows.
      ever<int>(
        DataBus.to.tick(AppointmentRepository.entityName),
        (_) => unawaited(_loadAppointments()),
      );
    }
  }

  /// Re-reads the record and the appointments.
  ///
  /// **Not `refresh()`.** `GetxController` already declares that name and it
  /// returns void, so an `onRefresh:` callback wired to it silently never
  /// awaits and the pull-to-refresh spinner snaps back before the request has
  /// left.
  Future<void> reload() async {
    await runGuarded(() async {
      portal.value = await _repository.portalState();
    }, fallback: "We couldn't load your record just now.");
    await _loadAppointments();
    await _loadDocuments();
    await _loadCase();
  }

  /// The documents section.
  ///
  /// Its own try/catch for the same reason the appointments have one: a patient
  /// whose document list is slow should still see their record and still be
  /// able to start telling their story. One load state for the whole screen
  /// would blank all of it because one route was.
  Future<void> _loadDocuments() async {
    documentsError.value = null;
    try {
      documents.value = await _documentsRepository.mine(limit: 5);
    } catch (e, stack) {
      documentsError.value = parseErrorMessage(
        e,
        PatientText.couldNotLoadDocuments,
      );
      AppLog.error('PatientDashboardController', 'documents failed', e, stack);
    }
  }

  /// Whether there is an interview to carry on with.
  ///
  /// Silent on failure, and deliberately: this drives a card that is absent
  /// when there is nothing to say, and "we could not check whether you have an
  /// interview open" is not a sentence worth putting on a patient's first
  /// screen.
  Future<void> _loadCase() async {
    try {
      openCase.value = await _cases.currentSession();
    } catch (e, stack) {
      AppLog.error('PatientDashboardController', 'open case failed', e, stack);
      openCase.value = null;
    }
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
      AppLog.error(
        'PatientDashboardController',
        'appointments failed',
        e,
        stack,
      );
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

  /// Opens the documents they have handed over, and the three ways to add
  /// another.
  void openDocuments() => PatientDocumentsNavigation.toDocuments();

  /// Asks for an appointment.
  ///
  /// Nothing is handed over: the booking screen reads this patient's own id
  /// from the record, and the new booking comes back here on the `DataBus`
  /// rather than as a return value — `Get.toNamed` completes when the route
  /// is popped, so a caller that awaited it would be waiting for the patient.
  void bookAppointment() => PatientPortalNavigation.toBooking();

  /// Opens "here is what we understood about you".
  ///
  /// The session id is handed over when this device knows one — a case that
  /// has already been sent is only reachable that way, because
  /// `sessions/current` finds open sessions and a submitted one is not open.
  void openCaseReview() => CaseReviewNavigation.toReview(
    sessionId: submission?.sessionId ?? openCase.value?.id,
  );

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
