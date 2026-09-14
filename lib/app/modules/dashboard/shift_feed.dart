import '../../core/app_clock.dart';
import '../../data/models/admission_model.dart';
import '../../data/models/appointment_model.dart';
import '../../data/models/invoice.dart';
import '../../data/models/lab_order.dart';
import '../../data/models/pre_triage_model.dart';
import '../../data/models/prescription.dart';
import '../../data/models/queue_item.dart';
import '../../data/models/radiology_order.dart';
import '../../data/models/site_settings.dart';
import '../../data/network/endpoints.dart';
import '../../data/repositories/crud_repository.dart';
import '../../data/utils/api_envelope.dart';
import '../../data/utils/formatters.dart';
import '../../routes/app_pages.dart';
import '../../theme/theme.dart';
import '../appointments/appointment_routes.dart';
import '../billing/billing_routes.dart';
import '../laboratory/lab_status.dart';
import '../laboratory/laboratory_routes.dart';
import '../pharmacy/pharmacy_routes.dart';
import '../radiology/radiology_routes.dart';
import 'shift_board.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — what each band on the shift board asks the server
///
/// Eight collections, each reduced to a count and the three rows worth
/// glancing at. One method per band rather than one clever generic one: the
/// filters are the interesting part and they are all different — "still to be
/// seen" is today's clinic minus the people already seen, "to dispense" is
/// every prescription nobody has handed over, and neither is expressible as a
/// query parameter this backend accepts.
///
/// **Filtered here rather than on the server** for the same reason. The list
/// DTOs run `forbidNonWhitelisted`, so a parameter a route does not declare is
/// a 400 rather than an ignored key — and `status=pending,in_progress` is not
/// a shape any of these routes accept. So each band reads one scan's worth and
/// narrows it in Dart, which is why [ShiftBandData.capped] exists: a count
/// taken from a truncated scan is a floor, and a floor drawn as a total is a
/// board under-reporting how much work is waiting.
///
/// Every method throws. The controller catches, because a lab outage must not
/// blank a nurse's bed counts and only the controller knows which band it was
/// asking for.
/// ─────────────────────────────────────────────────────────────────────────────
class ShiftFeed {
  const ShiftFeed({required this.money});

  /// The site's money convention. Injected rather than read from
  /// `SettingsService` here so a band's rows can be built in a unit test
  /// without standing up the container.
  final MoneyFormat money;

  /// How many rows a band shows. A board is scanned between patients; the
  /// count above the rows is what answers "how much", and the rows answer
  /// "who".
  static const int rowsPerBand = 3;

  /// How far a band reads before it stops counting.
  ///
  /// Fifty rather than everything: four bands each following `hasMore` against
  /// a busy department is a phone paging a queue that grows while it reads it.
  static const int scanLimit = 50;

  Future<ShiftBandData> fetch(String sectionId) async => switch (sectionId) {
        ShiftBandId.waiting => await _waiting(),
        ShiftBandId.screenings => await _screenings(),
        ShiftBandId.clinic => await _clinic(),
        ShiftBandId.ward => await _ward(),
        ShiftBandId.lab => await _lab(),
        ShiftBandId.imaging => await _imaging(),
        ShiftBandId.dispense => await _dispense(),
        ShiftBandId.unpaid => await _unpaid(),
        // A band this file has no reader for is a band that renders empty
        // rather than one that throws: the catalogue can grow before the feed
        // does, and an unread band must not take the other three down.
        _ => const ShiftBandData(rows: [], total: 0),
      };

  // ── Waiting now ───────────────────────────────────────────────────────────

  Future<ShiftBandData> _waiting() async {
    const repository =
        CrudRepository<QueueItem>(Endpoints.queue, QueueItem.fromJson, 'queue');
    final page = await repository.list(
      const PagedQuery(
        limit: scanLimit,
        // The comma list `QueueService` already sends. Called counts as
        // waiting here: somebody called who has not walked in yet is still in
        // the room.
        params: {'status': 'waiting,called'},
      ),
    );

    final rows = [...page.items]..sort(_byAcuityThenWait);

    return _band(
      total: rows.length,
      scanned: page.items.length,
      rows: [
        for (final item in rows.take(rowsPerBand))
          ShiftRow(
            id: item.id,
            lead: item.displayQueueNumber,
            title: item.patient.fullName.isEmpty
                ? 'Patient ${item.patient.mrn}'
                : item.patient.fullName,
            subtitle: ShiftBoard.areaLabel(item.serviceArea),
            trailing: Formatters.elapsed(item.joinedQueueAt),
            status: item.priority,
            route: Routes.QUEUE,
          ),
      ],
    );
  }

  /// Acuity first, then the longest wait.
  ///
  /// Arrival order alone seats a sprained ankle ahead of a chest pain that
  /// walked in two minutes later. `CaseStatus.priorityOf` is the one ranking
  /// in this app; only its ordering is read, never its number.
  static int _byAcuityThenWait(QueueItem a, QueueItem b) {
    final acuity = CaseStatus.priorityOf(a.priority)
        .compareTo(CaseStatus.priorityOf(b.priority));
    return acuity != 0 ? acuity : b.waitTime.compareTo(a.waitTime);
  }

  // ── Screenings to route ───────────────────────────────────────────────────

  Future<ShiftBandData> _screenings() async {
    const repository = CrudRepository<PreTriageModel>(
      Endpoints.preTriage,
      PreTriageModel.fromJson,
      'pre-triage',
    );
    final page = await repository.list(const PagedQuery(limit: scanLimit));

    // `screening` is the state before anybody has decided where this person
    // goes — the only one that is work.
    final open = page.items.where((s) => s.status == 'screening').toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return _band(
      total: open.length,
      scanned: page.items.length,
      rows: [
        for (final screening in open.take(rowsPerBand))
          ShiftRow(
            id: screening.id,
            title: screening.fullName,
            subtitle: screening.chiefComplaint,
            trailing: Formatters.elapsed(screening.createdAt),
            status: screening.status,
            route: Routes.PRE_TRIAGE_DETAILS,
            arguments: {'id': screening.id},
          ),
      ],
    );
  }

  // ── Still to be seen ──────────────────────────────────────────────────────

  Future<ShiftBandData> _clinic() async {
    const repository = CrudRepository<AppointmentModel>(
      Endpoints.appointments,
      AppointmentModel.fromJson,
      'appointments',
    );
    final page = await repository.list(const PagedQuery(limit: scanLimit));

    final today = AppClock.now();
    final due = page.items
        .where((a) => _isSameDay(a.appointmentDate, today))
        .where((a) => !_seen.contains(a.status.trim().toLowerCase()))
        .toList()
      ..sort((a, b) => a.appointmentTime.compareTo(b.appointmentTime));

    return _band(
      total: due.length,
      scanned: page.items.length,
      rows: [
        for (final appointment in due.take(rowsPerBand))
          ShiftRow(
            id: appointment.id,
            // The time, not an icon: a clinic list is read down its time
            // column.
            lead: Formatters.clockTime(appointment.appointmentTime),
            title: appointment.patient.displayName,
            subtitle: appointment.chiefComplaint.isEmpty
                ? appointment.doctor.fullName
                : appointment.chiefComplaint,
            status: appointment.status,
            route: AppointmentRoutes.detailFor(appointment.id),
          ),
      ],
    );
  }

  /// The states that mean this booking is no longer today's work.
  static const Set<String> _seen = {'completed', 'cancelled', 'no_show'};

  // ── On the ward ───────────────────────────────────────────────────────────

  Future<ShiftBandData> _ward() async {
    const repository = CrudRepository<AdmissionModel>(
      Endpoints.admissions,
      AdmissionModel.fromJson,
      'admissions',
    );
    final page = await repository.list(const PagedQuery(limit: scanLimit));

    final live = page.items
        .where((a) => a.status.trim().toLowerCase() == 'active')
        .toList()
      // By bed, because that is the order a ward round walks in.
      ..sort((a, b) => a.bed.bedNumber.compareTo(b.bed.bedNumber));

    return _band(
      total: live.length,
      scanned: page.items.length,
      rows: [
        for (final admission in live.take(rowsPerBand))
          ShiftRow(
            id: admission.id,
            lead: admission.bed.bedNumber,
            title: admission.patient.fullName,
            subtitle: admission.admissionReason,
            // Day three, counted in calendar days the way a ward round counts
            // it — not in 24-hour blocks.
            trailing:
                'Day ${Formatters.lengthOfStayDays(admission.admissionDate) + 1}',
            status: admission.status,
            route: Routes.INPATIENT_ADMISSIONS,
          ),
      ],
    );
  }

  // ── Samples and results ───────────────────────────────────────────────────

  Future<ShiftBandData> _lab() async {
    const repository = CrudRepository<LabOrder>(
      Endpoints.labOrders,
      LabOrder.fromJson,
      'lab-orders',
    );
    final page = await repository.list(const PagedQuery(limit: scanLimit));

    final open = page.items.where((o) => LabOrderStatus.isOpen(o.status)).toList()
      ..sort((a, b) {
        // STAT first, then the oldest request. STAT is how fast the bench was
        // asked to work, and it is the whole reason the word exists.
        if (a.isStat != b.isStat) return a.isStat ? -1 : 1;
        return _byDate(a.orderDate, b.orderDate);
      });

    return _band(
      total: open.length,
      scanned: page.items.length,
      rows: [
        for (final order in open.take(rowsPerBand))
          ShiftRow(
            id: order.id,
            lead: order.orderNumber,
            title: order.patient.displayName,
            subtitle: order.testSummary,
            trailing: order.isStat ? 'STAT' : null,
            status: order.status,
            // A result flagged critical that nobody has signed off is the one
            // thing on this band that outranks the order's own state.
            critical: order.hasCriticalResult && order.unverifiedCount > 0,
            route: LabRoutes.order(order.id),
          ),
      ],
    );
  }

  // ── Imaging to report ─────────────────────────────────────────────────────

  Future<ShiftBandData> _imaging() async {
    const repository = CrudRepository<RadiologyOrder>(
      Endpoints.radiologyOrders,
      RadiologyOrder.fromJson,
      'radiology-orders',
    );
    final page = await repository.list(const PagedQuery(limit: scanLimit));

    final open = page.items
        .where((o) => !o.isReported)
        .where((o) => o.status.trim().toLowerCase() != 'cancelled')
        .toList()
      ..sort((a, b) {
        if (a.isStat != b.isStat) return a.isStat ? -1 : 1;
        return _byDate(a.scheduledDate ?? a.orderDate,
            b.scheduledDate ?? b.orderDate);
      });

    return _band(
      total: open.length,
      scanned: page.items.length,
      rows: [
        for (final order in open.take(rowsPerBand))
          ShiftRow(
            id: order.id,
            lead: order.orderNumber,
            title: order.patient.displayName,
            subtitle: order.examName,
            trailing: order.isStat ? 'STAT' : null,
            status: order.status,
            critical: order.hasCriticalFindings,
            route: RadiologyRoutes.orderFor(order.id),
          ),
      ],
    );
  }

  // ── To dispense ───────────────────────────────────────────────────────────

  Future<ShiftBandData> _dispense() async {
    const repository = CrudRepository<Prescription>(
      Endpoints.prescriptions,
      Prescription.fromJson,
      'prescriptions',
    );
    final page = await repository.list(const PagedQuery(limit: scanLimit));

    final waiting = page.items.where((p) => p.isOutstanding).toList()
      ..sort((a, b) => _byDate(a.prescriptionDate, b.prescriptionDate));

    return _band(
      total: waiting.length,
      scanned: page.items.length,
      rows: [
        for (final prescription in waiting.take(rowsPerBand))
          ShiftRow(
            id: prescription.id,
            title: prescription.patient.displayName,
            subtitle: prescription.itemSummary.isEmpty
                ? 'No drugs on this prescription'
                : prescription.itemSummary,
            trailing: prescription.itemCount == 1
                ? '1 drug'
                : '${prescription.itemCount} drugs',
            status: prescription.status,
            route: PharmacyRoutes.prescriptionDetailFor(prescription.id),
          ),
      ],
    );
  }

  // ── Unpaid and overdue ────────────────────────────────────────────────────

  Future<ShiftBandData> _unpaid() async {
    const repository = CrudRepository<Invoice>(
      Endpoints.invoices,
      Invoice.fromJson,
      'invoices',
    );
    final page = await repository.list(const PagedQuery(limit: scanLimit));

    final owed = page.items
        .where((i) => !i.isCancelled)
        // `> 0`, so a bill settled to the penny leaves the band rather than
        // sitting on it at zero.
        .where((i) => i.outstanding > 0)
        .toList()
      ..sort((a, b) => _byDate(a.dueDate, b.dueDate));

    return _band(
      total: owed.length,
      scanned: page.items.length,
      rows: [
        for (final invoice in owed.take(rowsPerBand))
          ShiftRow(
            id: invoice.id,
            lead: invoice.invoiceNumber,
            title: invoice.patient.displayName,
            subtitle: invoice.dueDate == null
                ? null
                : 'Due ${Formatters.dayAndMonth(invoice.dueDate)}',
            // Never ellipsised by the row that draws it: the amount is why
            // this row exists.
            trailing: money(invoice.outstanding),
            status: invoice.status,
            route: BillingRoutes.invoice(invoice.id),
          ),
      ],
    );
  }

  // ── Shared ────────────────────────────────────────────────────────────────

  ShiftBandData _band({
    required int total,
    required int scanned,
    required List<ShiftRow> rows,
  }) =>
      ShiftBandData(
        rows: rows,
        total: total,
        // The scan came back full, so there may be more behind it and the
        // count is a floor.
        capped: scanned >= scanLimit,
      );

  static bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    final local = a.toLocal();
    return local.year == b.year && local.month == b.month && local.day == b.day;
  }

  /// Oldest first, with an absent date last rather than first: a record with
  /// no date is not the most urgent thing on the board, it is a record with no
  /// date.
  static int _byDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }
}

/// One band's answer: the rows worth showing, and how many there are.
class ShiftBandData {
  const ShiftBandData({
    required this.rows,
    required this.total,
    this.capped = false,
  });

  final List<ShiftRow> rows;
  final int total;
  final bool capped;
}
