import 'dart:async';

// `Color` only — `VitalRange` answers with one, and the banner above the
// vitals grid needs its tint. No widget in this file.
import 'package:flutter/painting.dart' show Color;
import 'package:get/get.dart';

import '../../../core/app_clock.dart';
import '../../../core/app_log.dart';
import '../../../data/models/admission_model.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/models/consultation_model.dart';
import '../../../data/models/invoice.dart';
import '../../../data/models/lab_order.dart';
import '../../../data/models/lab_result.dart';
import '../../../data/models/patient.dart';
import '../../../data/models/prescription.dart';
import '../../../data/models/queue_item.dart';
import '../../../data/models/radiology_order.dart';
import '../../../data/repositories/patient_repository.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/formatters.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';
import '../../patients/patient_routes.dart';

/// The seven faces of one patient record.
enum PatientHubTab {
  summary,
  visits,
  vitals,
  orders,
  results,
  prescriptions,
  billing,
}

extension PatientHubTabLabel on PatientHubTab {
  String get label => switch (this) {
        PatientHubTab.summary => 'Summary',
        PatientHubTab.visits => 'Visits',
        PatientHubTab.vitals => 'Vitals',
        PatientHubTab.orders => 'Orders',
        PatientHubTab.results => 'Results',
        PatientHubTab.prescriptions => 'Scripts',
        PatientHubTab.billing => 'Billing',
      };
}

/// One sibling collection, with the load state that belongs to it alone.
///
/// The whole point of the hub is that these do not share a spinner. A site
/// where a nurse may read the ward but not the ledger answers the billing
/// route with a 403 and everything else with a 200 — and a hub with one load
/// state shows her a locked screen for a record she is entitled to read.
class HubSection<T> {
  HubSection(this.label);

  /// What this collection is called in a sentence — "Imaging orders are not
  /// available to your role." Lower-cased at the point of use.
  final String label;

  final items = <T>[].obs;
  final loading = false.obs;
  final error = RxnString();
  final noAccess = false.obs;

  /// True once a fetch has finished, however it finished. What keeps a tab
  /// from refetching every time it is selected, and what tells an empty list
  /// apart from one that has not run yet.
  final loaded = false.obs;
}

/// One visit, whichever of the two collections it came from.
///
/// Appointments and consultations are one history to a clinician and two
/// tables to the server. Merging them here rather than in the view is what
/// lets the tab sort them together — a consultation on Tuesday belongs above
/// an appointment booked for Monday, and two lists side by side cannot say so.
class PatientVisit {
  const PatientVisit({
    required this.id,
    required this.kind,
    required this.when,
    required this.title,
    this.subtitle,
    this.status,
  });

  final String id;
  final VisitKind kind;
  final DateTime when;
  final String title;
  final String? subtitle;

  /// The record's own state, and only when it has one. A consultation has no
  /// status column: it either happened or does not exist, and inventing a
  /// pill for it would put a state on a fact.
  final String? status;
}

/// Which table a visit came from. A **category**, not a state — it gets a
/// glyph and a word, never a colour off the acuity ramp.
enum VisitKind { appointment, consultation }

/// The patient hub.
///
/// Loads in two waves. The identity band's facts — who, and where they are
/// right now — are fetched on open, because every tab shows the band. The
/// tabs themselves load the first time they are looked at, and each owns its
/// own state, so a slow laboratory or a refused ledger costs one tab and not
/// the screen.
class PatientHubController extends GetxController with LoadStateMixin {
  PatientHubController({this.forPatientId, this.seed});

  /// Supplied by the tablet's detail pane, which has no route arguments of its
  /// own. Null on the pushed screen, where the id arrives in `Get.arguments`.
  final String? forPatientId;

  /// The row the caller already had. Paints the band on the first frame rather
  /// than after a round trip; the record is refetched regardless, because a
  /// row carries seven fields and the hub shows forty.
  final Patient? seed;

  final PatientRepository _repository = patientRepository;

  final patient = Patient.empty.obs;
  final tab = PatientHubTab.summary.obs;

  String _id = '';
  String get id => _id;

  // ── Sections ──────────────────────────────────────────────────────────────
  //
  // Eight collections, seven tabs. `consultations` feeds three of them and
  // `labOrders` two, and each is fetched once: the tabs share the section, not
  // the load state, so Results opening after Orders costs nothing and a
  // laboratory 403 still shows in both — which is correct, because it is one
  // module refusing.

  final appointments = HubSection<AppointmentModel>('Appointments');
  final consultations = HubSection<ConsultationModel>('Consultations');
  final labOrders = HubSection<LabOrder>('Lab orders');
  final radiologyOrders = HubSection<RadiologyOrder>('Imaging orders');
  final prescriptions = HubSection<Prescription>('Prescriptions');
  final invoices = HubSection<Invoice>('Invoices');

  /// The two the identity band is built from, fetched on open.
  final queueEntries = HubSection<QueueItem>('The queue');
  final admissions = HubSection<AdmissionModel>('Admissions');

  @override
  void onInit() {
    super.onInit();
    _id = forPatientId ?? PatientRoutes.idFrom(Get.arguments);

    final handed = seed ?? _seedFromArguments();
    if (handed != null) patient.value = handed;
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(reload());
  }

  Patient? _seedFromArguments() {
    final arguments = Get.arguments;
    if (arguments is Map && arguments['patient'] is Patient) {
      return arguments['patient'] as Patient;
    }
    return null;
  }

  /// The record, where the patient is right now, and the tab on screen.
  ///
  /// Named `reload` and not `refresh`: `GetxController.refresh()` already
  /// exists and returns void, so an `onRefresh:` wired to it silently never
  /// awaits and the pull-to-refresh spinner vanishes before anything arrives.
  ///
  /// Concurrently, and that is the point: five requests that each own their
  /// own piece of the screen, rather than one `await` chain where a slow
  /// laboratory holds up the identity band.
  Future<void> reload() {
    // A hub opened with no id — a deep link that lost its arguments, a caller
    // that passed the patient and forgot the key. Eight requests to
    // `/api/<thing>?patientId=` would each come back with somebody else's
    // rows, which is the one failure mode worse than an empty screen.
    if (_id.isEmpty) {
      rxLoadError.value = 'That link did not say which patient.';
      rxFirstLoad.value = false;
      return Future<void>.value();
    }

    return Future.wait([
      loadPatient(),
      loadSection(queueEntries, () => _repository.queueEntriesFor(_id)),
      loadSection(admissions, () => _repository.admissionsFor(_id)),
      ..._loadTab(tab.value, force: true),
    ]);
  }

  Future<void> loadPatient() => runGuarded(
        () async => patient.value = await _repository.read(_id),
        fallback: "Couldn't load that patient.",
        // Silent when the caller handed over a row: the band is already
        // painted, and collapsing it to a skeleton to fetch the rest of the
        // record reads as having lost the patient.
        silent: !patient.value.isEmpty,
      );

  // ── Tabs ──────────────────────────────────────────────────────────────────

  /// Selects a tab and fetches whatever it still needs.
  ///
  /// Only what it *still* needs: a section that has already answered is not
  /// asked again on every tap of its tab, which is what makes the shared
  /// collections — consultations feeds three tabs, lab orders two — cost one
  /// request rather than five.
  void showTab(PatientHubTab next, {bool force = false}) {
    tab.value = next;
    for (final pending in _loadTab(next, force: force)) {
      unawaited(pending);
    }
  }

  List<Future<void>> _loadTab(PatientHubTab which, {bool force = false}) => [
        for (final section in sectionsFor(which))
          if (force || !section.loaded.value) _reloadSection(section),
      ];

  /// Which collections a tab is built from.
  List<HubSection<dynamic>> sectionsFor(PatientHubTab which) =>
      switch (which) {
        // The summary's own facts come off the record; what it fetches is the
        // last visit, which is the first question anybody asks.
        PatientHubTab.summary => [appointments, consultations],
        PatientHubTab.visits => [appointments, consultations],
        PatientHubTab.vitals => [consultations],
        PatientHubTab.orders => [labOrders, radiologyOrders],
        // Results come **inside** the orders: `/api/laboratory/results` takes
        // only an `orderId`, and the orders route already includes them.
        PatientHubTab.results => [labOrders],
        PatientHubTab.prescriptions => [prescriptions],
        PatientHubTab.billing => [invoices],
      };

  /// True while any collection this tab needs is still in flight.
  bool isTabLoading(PatientHubTab which) =>
      sectionsFor(which).any((section) => section.loading.value);

  /// True when **every** collection behind this tab was refused.
  ///
  /// Not "any": a tab built from two modules where one is refused still has
  /// something true to show, and hiding it behind a locked panel would be the
  /// app deciding a clinician may not see what the server just sent them.
  bool isTabDenied(PatientHubTab which) {
    final sections = sectionsFor(which);
    return sections.every((section) => section.noAccess.value);
  }

  String? tabError(PatientHubTab which) {
    for (final section in sectionsFor(which)) {
      if (section.error.value != null) return section.error.value;
    }
    return null;
  }

  /// "Imaging orders are not available to your role." — said in the tab that
  /// is missing half its content, rather than left as a silently shorter list.
  String? tabNotice(PatientHubTab which) {
    final sections = sectionsFor(which);
    final denied =
        sections.where((section) => section.noAccess.value).toList();
    if (denied.isEmpty || denied.length == sections.length) return null;
    final names = denied.map((section) => section.label).join(' and ');
    return '$names ${denied.length == 1 ? 'is' : 'are'} not available to your '
        'role, so this list is incomplete.';
  }

  /// Matched on identity rather than carried as a closure on the section,
  /// because a `HubSection` that held its own fetcher would have to be built
  /// after the id is resolved — and a `late final` section is a section a
  /// getter can read before `onInit` has run.
  Future<void> _reloadSection(HubSection<dynamic> section) {
    if (section == appointments) {
      return loadSection(appointments, () => _repository.appointmentsFor(_id));
    }
    if (section == consultations) {
      return loadSection(consultations, () => _repository.consultationsFor(_id));
    }
    if (section == labOrders) {
      return loadSection(labOrders, () => _repository.labOrdersFor(_id));
    }
    if (section == radiologyOrders) {
      return loadSection(
        radiologyOrders,
        () => _repository.radiologyOrdersFor(_id),
      );
    }
    if (section == prescriptions) {
      return loadSection(prescriptions, () => _repository.prescriptionsFor(_id));
    }
    if (section == invoices) {
      return loadSection(invoices, () => _repository.invoicesFor(_id));
    }
    return Future<void>.value();
  }

  /// Fills one section, recording the two failures separately.
  ///
  /// A 403 is not an error here and must not offer a retry: nothing is broken,
  /// the answer will not change, and "something went wrong" over a ledger a
  /// nurse was never granted sends her to IT for a role she is not meant to
  /// have.
  Future<void> loadSection<T>(
    HubSection<T> section,
    Future<List<T>> Function() fetch,
  ) async {
    if (section.loading.value) return;
    section.loading.value = true;
    section.error.value = null;
    section.noAccess.value = false;
    try {
      section.items.assignAll(await fetch());
    } on ApiForbiddenException catch (e) {
      section.noAccess.value = true;
      AppLog.info('PatientHubController', '${section.label} refused: ${e.message}');
    } catch (e, stack) {
      section.error.value = parseErrorMessage(
        e,
        "Couldn't load ${section.label.toLowerCase()}.",
      );
      // No patient identifier in the line: the interceptor redacts tokens and
      // passwords and has no idea what a patient is.
      AppLog.error('PatientHubController', 'hub section load failed', e, stack);
    } finally {
      section.loading.value = false;
      section.loaded.value = true;
    }
  }

  // ── The identity band ─────────────────────────────────────────────────────

  /// The name, or what stands in for it where the site has turned names off.
  ///
  /// `show_patient_names` exists for screens read from a corridor or a waiting
  /// area. The MRN underneath still identifies the record — it is the
  /// identifier staff say out loud anyway — so the band stays usable without
  /// putting a name on a screen the site has asked to keep anonymous.
  String get bandName => SettingsService.to.settings.showPatientNames
      ? patient.value.displayName
      : 'Patient';

  /// The live queue ticket this patient holds, if any.
  QueueItem? get queueTicket =>
      queueEntries.items.isEmpty ? null : queueEntries.items.first;

  /// The admission they are currently on, if any.
  ///
  /// `admissionsFor` already sorts newest first; anything not discharged or
  /// transferred is the one they are on now.
  AdmissionModel? get currentAdmission => admissions.items.firstWhereOrNull(
        (row) => !const {'discharged', 'transferred', 'cancelled'}
            .contains(row.status.trim().toLowerCase()),
      );

  /// The band's rank glyph: the triage code they are queued under, `ADM` when
  /// they are in a bed, and nothing at all when neither is true.
  ///
  /// Nothing, rather than a neutral pill: a patient who is simply registered
  /// has no clinical state, and a pill saying so is one more thing to read on
  /// a screen where the pills are supposed to mean something.
  String? get bandAcuityCode {
    final ticket = queueTicket;
    if (ticket != null && ticket.priority.trim().isNotEmpty) {
      return ticket.priority.trim().toUpperCase();
    }
    return currentAdmission == null ? null : 'ADM';
  }

  /// The state in words, always — colour and rank are never the whole story.
  String get stateInWords {
    final ticket = queueTicket;
    if (ticket != null) {
      final area = ticket.serviceArea.trim();
      final where = area.isEmpty ? 'the queue' : Formatters.label(area);
      return 'Waiting in $where · ${Formatters.label(ticket.status)}';
    }

    final admission = currentAdmission;
    if (admission != null) {
      final bed = admission.bed.bedNumber.trim();
      // The ward block is absent on routes that did not populate it; the bed
      // number alone still tells somebody where to go.
      final ward = (admission.bed.ward?.name ?? '').trim();
      final place = [
        if (bed.isNotEmpty) 'Bed $bed',
        if (ward.isNotEmpty) ward,
      ].join(', ');
      return place.isEmpty ? 'Admitted' : 'Admitted · $place';
    }

    // Both sections still in flight, or both refused: say nothing rather than
    // "not in the queue" about a queue nobody has read yet.
    if (queueEntries.loading.value || admissions.loading.value) return '';
    if (queueEntries.noAccess.value && admissions.noAccess.value) return '';
    return 'Not in the queue and not admitted';
  }

  // ── Visits ────────────────────────────────────────────────────────────────

  /// Appointments and consultations as one history, newest first.
  List<PatientVisit> get visits {
    final rows = <PatientVisit>[
      for (final appointment in appointments.items)
        PatientVisit(
          id: appointment.id,
          kind: VisitKind.appointment,
          when: _at(appointment.appointmentDate, appointment.appointmentTime),
          title: Formatters.label(appointment.appointmentType),
          subtitle: appointment.chiefComplaint.trim().isEmpty
              ? appointment.doctor.fullName
              : appointment.chiefComplaint,
          status: appointment.status,
        ),
      for (final consultation in consultations.items)
        PatientVisit(
          id: consultation.id,
          kind: VisitKind.consultation,
          when: consultation.visitDate,
          title: Formatters.label(consultation.visitType),
          subtitle: (consultation.diagnosis ?? '').trim().isNotEmpty
              ? consultation.diagnosis
              : consultation.chiefComplaint,
        ),
    ]..sort((a, b) => b.when.compareTo(a.when));
    return rows;
  }

  PatientVisit? get lastVisit {
    final history = visits;
    return history.isEmpty ? null : history.first;
  }

  /// A stored `"14:30"` folded onto its date.
  ///
  /// Parsed rather than trusted: the backend zero-pads the hour, so a
  /// lexicographic sort happens to work — but a row that is not padded would
  /// sort under `"1:00"`, and a visit history in the wrong order is a history
  /// nobody can read.
  static DateTime _at(DateTime day, String time) {
    final parts = time.trim().split(':');
    final hours = parts.isEmpty ? 0 : int.tryParse(parts[0]) ?? 0;
    final minutes = parts.length < 2 ? 0 : int.tryParse(parts[1]) ?? 0;
    final local = day.toLocal();
    return DateTime(local.year, local.month, local.day, hours, minutes);
  }

  // ── Vitals ────────────────────────────────────────────────────────────────

  /// The most recent consultation, which is where this backend records
  /// observations.
  ConsultationModel? get latestConsultation {
    if (consultations.items.isEmpty) return null;
    final rows = consultations.items.toList()
      ..sort((a, b) => b.visitDate.compareTo(a.visitDate));
    return rows.first;
  }

  /// Every observation on the latest consultation that is outside its range,
  /// named and with its figure.
  ///
  /// The words matter more than the colour. A clinician reading a ward screen
  /// across a corridor, a colour-blind reader and a black-and-white printout
  /// all get the same three facts out of this list and none of them out of a
  /// red number.
  List<String> get flaggedVitals {
    final visit = latestConsultation;
    if (visit == null) return const [];

    final flagged = <String>[];

    // Every guard is `<= 0`, not `== null`. This backend stores an unobserved
    // numeric vital as zero, and judging that as a reading paints an empty row
    // red — a red that is not a deteriorating patient, which is the one thing
    // red is not allowed to be. `VitalRange` guards it too; the tiles are
    // built from the same test so an unrecorded vital is simply absent.
    if (_recorded(visit.temperature) &&
        VitalRange.temperature(visit.temperature) != null) {
      flagged.add('Temperature ${_trim(visit.temperature!)} °C');
    }
    if (_recorded(visit.pulseRate) && VitalRange.pulse(visit.pulseRate) != null) {
      flagged.add('Pulse ${visit.pulseRate} bpm');
    }
    if (_recorded(visit.bloodPressureSystolic) &&
        VitalRange.bloodPressure(
              visit.bloodPressureSystolic,
              visit.bloodPressureDiastolic,
            ) !=
            null) {
      flagged.add(
        'Blood pressure ${visit.bloodPressureSystolic}/'
        '${visit.bloodPressureDiastolic ?? '—'} mmHg',
      );
    }
    if (_recorded(visit.oxygenSaturation) &&
        VitalRange.oxygenSaturation(visit.oxygenSaturation) != null) {
      flagged.add('Oxygen saturation ${visit.oxygenSaturation}%');
    }
    if (_recorded(visit.respiratoryRate) &&
        VitalRange.respiratoryRate(visit.respiratoryRate) != null) {
      flagged.add('Respiratory rate ${visit.respiratoryRate} /min');
    }

    return flagged;
  }

  /// The most serious flag across the latest observations, for the banner's
  /// tint. Null when everything recorded is in range.
  Color? get worstVital {
    final visit = latestConsultation;
    if (visit == null) return null;
    return VitalRange.worst([
      VitalRange.temperature(visit.temperature),
      VitalRange.pulse(visit.pulseRate),
      VitalRange.bloodPressure(
        visit.bloodPressureSystolic,
        visit.bloodPressureDiastolic,
      ),
      VitalRange.oxygenSaturation(visit.oxygenSaturation),
      VitalRange.respiratoryRate(visit.respiratoryRate),
    ]);
  }

  static bool _recorded(num? value) => value != null && value > 0;

  /// Whether the reference ranges the tiles colour by apply to this patient.
  ///
  /// `VitalRange` is explicit that its bands are **adult**. On a child they are
  /// simply wrong in both directions — a resting pulse of 120 is ordinary at
  /// two and tachycardic at twenty — so a paediatric record says so above the
  /// grid rather than letting a clinician trust a colour that was never about
  /// them. Sixteen because that is where most paediatric charts hand over.
  ///
  /// Age is computed against [AppClock], not `DateTime.now()`: a frozen clock
  /// is what makes this assertable, and three models each doing the
  /// arithmetic inline is how they came to disagree.
  bool get isPaediatric {
    final born = patient.value.dateOfBirth;
    if (born == null) return false;
    final now = AppClock.now();
    var years = now.year - born.year;
    final beforeBirthday = now.month < born.month ||
        (now.month == born.month && now.day < born.day);
    if (beforeBirthday) years--;
    return years < 16;
  }

  /// `37` rather than `37.0`, and `38.4` kept whole. Never truncated: `16…`
  /// could be 160, 168 or 16.
  static String _trim(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';

  // ── Results ───────────────────────────────────────────────────────────────

  /// Every result on every lab order, worst first.
  ///
  /// Ordered by what a reader has to act on rather than by date: a critical
  /// result nobody has verified is a phone call, and putting it below three
  /// weeks of normal chemistry is the list failing at its one job.
  List<LabResult> get results {
    final rows = [
      for (final order in labOrders.items)
        ...order.results.where((result) => result.resultValue.trim().isNotEmpty),
    ];
    rows.sort((a, b) => _resultRank(a).compareTo(_resultRank(b)));
    return rows;
  }

  static int _resultRank(LabResult result) {
    if (result.isCritical && !result.isVerified) return 0;
    if (result.isCritical) return 1;
    if (result.isAbnormal) return 2;
    return 3;
  }

  /// Critical results nobody has signed off yet.
  List<LabResult> get unverifiedCriticalResults =>
      results.where((r) => r.isCritical && !r.isVerified).toList();

  // ── Billing ───────────────────────────────────────────────────────────────

  /// What is still owed across every invoice on this record.
  double get balanceDue => invoices.items.fold<double>(
        0,
        (sum, invoice) =>
            sum + (invoice.balanceDue ?? (invoice.totalAmount - invoice.amountPaid)),
      );

  // ── Prescriptions ─────────────────────────────────────────────────────────

  List<Prescription> get outstandingPrescriptions =>
      prescriptions.items.where((script) => script.isOutstanding).toList();
}
