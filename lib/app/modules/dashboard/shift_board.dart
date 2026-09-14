import 'package:flutter/material.dart';

import '../../data/models/access_map.dart';
import '../../data/utils/formatters.dart';
import '../../routes/app_pages.dart';
import '../appointments/appointment_routes.dart';
import '../billing/billing_routes.dart';
import '../laboratory/laboratory_routes.dart';
import '../patients/patient_routes.dart';
import '../pharmacy/pharmacy_routes.dart';
import '../radiology/radiology_routes.dart';
import 'shift_sections.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the shift board, as data
///
/// Everything the board decides before it draws anything: which bands this
/// account gets, what each band currently knows, and which shortcuts open a
/// screen rather than a refusal.
///
/// It is all pure so it can be argued with in a unit test. The catalogue in
/// `shift_sections.dart` is the contract for *which* bands exist; this file is
/// the contract for what a band is made of and where its rows go.
/// ─────────────────────────────────────────────────────────────────────────────

/// The ids `ShiftSections.catalogue` gives its bands.
///
/// Spelled here as well, because the feed switches on them and a switch on a
/// string literal is a switch that goes silently unreachable the day a band is
/// renamed. `shift_board_test.dart` asserts the two lists are the same set, so
/// a rename over there fails a test rather than emptying a band.
abstract final class ShiftBandId {
  static const String waiting = 'waiting';
  static const String screenings = 'screenings';
  static const String clinic = 'clinic';
  static const String ward = 'ward';
  static const String lab = 'lab';
  static const String imaging = 'imaging';
  static const String dispense = 'dispense';
  static const String unpaid = 'unpaid';

  static const List<String> all = [
    waiting,
    screenings,
    clinic,
    ward,
    lab,
    imaging,
    dispense,
    unpaid,
  ];
}

/// What a band is doing right now.
///
/// Five, not four, and each one is drawn: a band whose module answered 403 is
/// not an error — nothing is broken, a retry cannot help, and a red banner over
/// it sends a nurse to IT for a role she was never meant to have.
enum ShiftBandPhase { loading, ready, empty, failed, locked }

/// One line inside a band.
///
/// Deliberately flat strings rather than a model: eight different collections
/// feed these, and a band that held a `LabOrder` on one row and an `Invoice` on
/// the next would push that union into the widget.
@immutable
class ShiftRow {
  const ShiftRow({
    required this.id,
    required this.title,
    this.subtitle,
    this.lead,
    this.trailing,
    this.status,
    this.critical = false,
    this.route,
    this.arguments,
  });

  final String id;

  /// Who this row is about. A patient's name, nearly always.
  final String title;

  final String? subtitle;

  /// The first column — a queue number, a bed, an order number, a clock time.
  final String? lead;

  /// The figure on the right: a wait, an amount, a length of stay.
  ///
  /// **Never ellipsised by the widget that draws it.** `16…` could be 160.
  final String? trailing;

  /// The **stored** state, not a label.
  ///
  /// Resolved to colour and words by the band that draws it, through whichever
  /// vocabulary owns it — `LabOrderStatus`, `InvoiceStatus`, `CaseStatus`. A
  /// feed that resolved them itself would be a fourth screen deciding what
  /// `in_progress` looks like, and the three that already do would eventually
  /// disagree with it.
  final String? status;

  /// True when this row is about a patient who is deteriorating, and the one
  /// thing on a band allowed to be red.
  final bool critical;

  final String? route;
  final Object? arguments;
}

/// One band's state, as one immutable value.
///
/// One value rather than four observables per band, so a rebuild cannot catch
/// a band halfway between "loading" and "has rows".
@immutable
class ShiftBand {
  const ShiftBand({
    required this.phase,
    this.rows = const [],
    this.total = 0,
    this.capped = false,
    this.error,
  });

  final ShiftBandPhase phase;

  /// The handful the band shows. A board is scanned, not read.
  final List<ShiftRow> rows;

  /// How many there are altogether — which is not `rows.length`.
  final int total;

  /// True when [total] is a floor rather than a count, because the band
  /// stopped counting at its scan limit. Drawn as `50+`, never as `50`: a
  /// figure a clinician acts on must not quietly under-report.
  final bool capped;

  final String? error;

  static const ShiftBand loading = ShiftBand(phase: ShiftBandPhase.loading);
  static const ShiftBand locked = ShiftBand(phase: ShiftBandPhase.locked);

  /// A loaded band. Empty is its own phase, because "nobody is waiting" is
  /// information and a blank card is a bug.
  factory ShiftBand.ready({
    required List<ShiftRow> rows,
    required int total,
    bool capped = false,
  }) =>
      ShiftBand(
        phase: total <= 0 && rows.isEmpty
            ? ShiftBandPhase.empty
            : ShiftBandPhase.ready,
        rows: rows,
        total: total,
        capped: capped,
      );

  bool get isLoading => phase == ShiftBandPhase.loading;
  bool get hasRows => rows.isNotEmpty;

  /// The count, as a word. `50+` when the band stopped counting.
  String get countLabel => capped ? '$total+' : '$total';

  /// Failed, with whatever it was already showing kept.
  ///
  /// The last good rows are still true of four minutes ago; blanking them
  /// turns "this did not reload" into "there is nobody waiting".
  ShiftBand asFailed(String message) => ShiftBand(
        phase: ShiftBandPhase.failed,
        rows: rows,
        total: total,
        capped: capped,
        error: message,
      );
}

/// One shortcut on the quick-action row.
///
/// Each names **the module and verb the screen it opens actually needs**, not
/// the module it is filed under. That distinction is the whole point: a tile
/// gated on "can read laboratory" that opens a form needing "can create
/// laboratory" is a tile that lands a reader on a refusal screen, and a
/// shortcut that refuses teaches a clinician the app's shortcuts cannot be
/// trusted.
@immutable
class ShiftQuickAction {
  const ShiftQuickAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.route,
    required this.module,
    this.verb = AccessVerb.create,
    required this.rank,
  });

  final String id;
  final IconData icon;

  /// A verb and its object, always. `QuickActionTile` breaks the label after
  /// the first word so a row of them is one height.
  final String label;

  final String route;
  final String module;
  final AccessVerb verb;

  /// Lower comes first. Hand-assigned by how often somebody standing at a desk
  /// does this, which is not the order the navigation puts the modules in.
  final int rank;
}

/// Which bands and shortcuts this account gets, and where they point.
abstract final class ShiftBoard {
  /// The catalogue, wired to the routes this app actually registers.
  ///
  /// `ShiftSections.catalogue` takes its routes rather than importing them so
  /// it stays testable without the route table; this is the one place that
  /// hands it the real ones.
  static List<ShiftSection> catalogue() => ShiftSections.catalogue(
        queueRoute: Routes.QUEUE,
        clinicRoute: AppointmentRoutes.board,
        wardsRoute: Routes.INPATIENT,
        triageRoute: Routes.PRE_TRIAGE,
        labRoute: LabRoutes.worklist,
        imagingRoute: RadiologyRoutes.worklist,
        pharmacyRoute: PharmacyRoutes.hub,
        billingRoute: BillingRoutes.list,
      );

  /// The bands [access] should see, most urgent first. At most four.
  static List<ShiftSection> bandsFor(AccessMap access) =>
      ShiftSections.forAccess(access, catalogue());

  /// Everything the board could offer, before access is consulted.
  ///
  /// Every route here is registered in the table and every one of them is a
  /// screen, not a placeholder — a shortcut is a promise that something
  /// happens when it is pressed.
  static const List<ShiftQuickAction> quickActions = [
    ShiftQuickAction(
      id: 'screening',
      icon: Icons.assignment_outlined,
      label: 'New screening',
      route: Routes.NEW_SCREENING_STEP1,
      module: Modules.preTriage,
      rank: 10,
    ),
    ShiftQuickAction(
      id: 'queue',
      icon: Icons.person_add_alt_1_outlined,
      label: 'Add to queue',
      route: Routes.ADD_TO_QUEUE,
      module: Modules.queue,
      rank: 20,
    ),
    ShiftQuickAction(
      id: 'register',
      icon: Icons.badge_outlined,
      label: 'Register patient',
      route: PatientRoutes.form,
      module: Modules.patients,
      rank: 25,
    ),
    ShiftQuickAction(
      id: 'admit',
      icon: Icons.local_hotel_outlined,
      label: 'Admit patient',
      route: Routes.INPATIENT_ADMIT,
      module: Modules.inpatient,
      rank: 30,
    ),
    ShiftQuickAction(
      id: 'lab-order',
      icon: Icons.science_outlined,
      label: 'New order',
      route: LabRoutes.orderNew,
      module: Modules.laboratory,
      rank: 40,
    ),
    ShiftQuickAction(
      id: 'lab-result',
      icon: Icons.biotech_outlined,
      label: 'Enter result',
      route: LabRoutes.resultNew,
      module: Modules.laboratory,
      rank: 45,
    ),
    ShiftQuickAction(
      id: 'imaging',
      icon: Icons.monitor_heart_outlined,
      label: 'Imaging request',
      route: RadiologyRoutes.orderNew,
      module: Modules.radiology,
      rank: 50,
    ),
    ShiftQuickAction(
      id: 'sale',
      icon: Icons.medication_outlined,
      label: 'Counter sale',
      route: PharmacyRoutes.saleForm,
      module: Modules.pharmacy,
      rank: 60,
    ),
    ShiftQuickAction(
      id: 'invoice',
      icon: Icons.receipt_long_outlined,
      label: 'New invoice',
      route: BillingRoutes.invoiceNew,
      module: Modules.billing,
      rank: 70,
    ),
  ];

  /// The shortcuts [access] can actually perform, ranked, capped at [limit].
  ///
  /// Three at 411 dp: a fourth tile at the 1.3 text scale a ward tablet is
  /// usually left at wraps its label to three lines and the row stops being
  /// scannable.
  static List<ShiftQuickAction> actionsFor(
    AccessMap access, {
    int limit = 3,
  }) {
    final permitted = quickActions
        .where((action) => access.can(action.module, action.verb))
        .toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    return permitted.take(limit).toList();
  }

  /// A service area, as somebody should read it.
  ///
  /// Through `Formatters.label` **only** when it arrives as a stored key —
  /// underscored, or with no capital anywhere in it. A service area is free
  /// text a site configures, not an enum: it sends `Emergency`, and it sends
  /// `OPD` and `ICU` meaning those letters. `Formatters.label` lower-cases
  /// before it capitalises and says so in its own doc comment, so putting
  /// `OPD` through it hands back `Opd` — an acronym a ward says out loud,
  /// title-cased into a word that is not one.
  static String areaLabel(String? raw) {
    final name = (raw ?? '').trim();
    if (name.isEmpty) return '';
    final stored = name.contains('_') || name == name.toLowerCase();
    return stored ? Formatters.label(name) : name;
  }

  /// How many slots the quick-action row lays out, whatever it has to put in
  /// them.
  ///
  /// A single permitted action stretched across the whole width puts its icon
  /// adrift in the middle of a banner, which reads as a layout that broke
  /// rather than as a row with less in it.
  static const int quickActionSlots = 3;
}
