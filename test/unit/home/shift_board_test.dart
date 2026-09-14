import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/data/models/access_map.dart';
import 'package:medihive/app/data/models/dashboard_model.dart';
import 'package:medihive/app/modules/dashboard/chart_palette.dart';
import 'package:medihive/app/modules/dashboard/shift_board.dart';
import 'package:medihive/app/theme/theme.dart';

/// The board's own logic, beside `shift_sections_test.dart` which owns the
/// catalogue it is built from.
///
/// Everything here is pure: which bands exist, which shortcuts an account is
/// offered, and what the two charts are made of. The parts that need a server
/// are in `integration_test/flows/dashboard/shift_flow_test.dart`.
const _perms = <String, List<String>>{
  'DOCTOR': [
    'PATIENT_CREATE', 'PATIENT_READ', 'APPOINTMENT_CREATE',
    'APPOINTMENT_READ', 'APPOINTMENT_UPDATE', 'CONSULTATION_CREATE',
    'CONSULTATION_READ', 'INPATIENT_CREATE', 'INPATIENT_READ',
    'INPATIENT_UPDATE', 'LABORATORY_CREATE', 'LABORATORY_READ',
    'RADIOLOGY_CREATE', 'RADIOLOGY_READ', 'PHARMACY_CREATE', 'PHARMACY_READ',
    'PRE_TRIAGE_CREATE', 'PRE_TRIAGE_READ', 'QUEUE_CREATE', 'QUEUE_READ',
    'QUEUE_UPDATE', 'DASHBOARD_READ',
  ],
  'NURSE': [
    'PATIENT_READ', 'APPOINTMENT_READ', 'CONSULTATION_READ',
    'INPATIENT_CREATE', 'INPATIENT_READ', 'INPATIENT_UPDATE',
    'PRE_TRIAGE_CREATE', 'PRE_TRIAGE_READ', 'PRE_TRIAGE_UPDATE',
    'QUEUE_CREATE', 'QUEUE_READ', 'QUEUE_UPDATE', 'DASHBOARD_READ',
  ],
  'LAB_TECHNICIAN': [
    'LABORATORY_CREATE', 'LABORATORY_READ', 'LABORATORY_UPDATE',
    'LABORATORY_DELETE', 'PATIENT_READ', 'DASHBOARD_READ',
  ],
  'BILLING_STAFF': [
    'BILLING_CREATE', 'BILLING_READ', 'BILLING_UPDATE', 'BILLING_DELETE',
    'PATIENT_READ', 'DASHBOARD_READ',
  ],
  'RECEPTIONIST': [
    'PATIENT_CREATE', 'PATIENT_READ', 'PATIENT_UPDATE',
    'APPOINTMENT_CREATE', 'APPOINTMENT_READ', 'APPOINTMENT_UPDATE',
    'APPOINTMENT_DELETE', 'QUEUE_CREATE', 'QUEUE_READ', 'QUEUE_UPDATE',
    'QUEUE_DELETE', 'BILLING_READ', 'DASHBOARD_READ',
  ],
};

AccessMap _access(String role) => AccessMap.fromPermissions(_perms[role]!);

void main() {
  group('the catalogue, wired to the real route table', () {
    test('the feed knows every band the catalogue defines, and no others', () {
      // The feed switches on these ids. A band renamed in the catalogue and
      // not here would render empty for ever, with nothing to say it had.
      final catalogue = ShiftBoard.catalogue().map((s) => s.id).toSet();
      expect(catalogue, ShiftBandId.all.toSet());
    });

    test('every band points somewhere', () {
      for (final section in ShiftBoard.catalogue()) {
        expect(section.route.startsWith('/'), isTrue, reason: section.id);
      }
    });

    test('no two bands share a route', () {
      // Two bands opening the same screen is two bands doing one job, and the
      // board is capped at four.
      final routes = ShiftBoard.catalogue().map((s) => s.route).toList();
      expect(routes.toSet().length, routes.length);
    });

    test('a board is at most four bands, whoever is looking', () {
      for (final role in _perms.keys) {
        expect(ShiftBoard.bandsFor(_access(role)).length,
            lessThanOrEqualTo(4), reason: role);
      }
      expect(
        ShiftBoard.bandsFor(const AccessMap(isSuperAdmin: true)).length,
        4,
      );
    });

    test('bands arrive most urgent first', () {
      final ranks =
          ShiftBoard.bandsFor(const AccessMap(isSuperAdmin: true))
              .map((s) => s.rank)
              .toList();
      final sorted = [...ranks]..sort();
      expect(ranks, sorted);
    });
  });

  group('quick actions', () {
    test('every shortcut is gated on the module the screen it opens needs',
        () {
      for (final role in _perms.keys) {
        final access = _access(role);
        for (final action in ShiftBoard.actionsFor(access)) {
          expect(
            access.can(action.module, action.verb),
            isTrue,
            reason: '$role was offered ${action.id}, which opens '
                '${action.route}',
          );
        }
      }
    });

    test('a lab technician is offered lab work and nothing else', () {
      // The screenshot round that prompted this found the row offering a lab
      // technician four shortcuts that all landed on the refusal screen.
      final actions = ShiftBoard.actionsFor(_access('LAB_TECHNICIAN'));
      expect(actions.map((a) => a.id), ['lab-order', 'lab-result']);
    });

    test('an account with no create grant is offered nothing at all', () {
      // Nothing, rather than a row of tiles that refuse. A shortcut that
      // refuses teaches a clinician the app's shortcuts cannot be trusted.
      final readOnly = AccessMap.fromPermissions(
        const ['PATIENT_READ', 'QUEUE_READ', 'DASHBOARD_READ'],
      );
      expect(ShiftBoard.actionsFor(readOnly), isEmpty);
    });

    test('never more than the row has slots for', () {
      for (final role in _perms.keys) {
        expect(
          ShiftBoard.actionsFor(_access(role)).length,
          lessThanOrEqualTo(ShiftBoard.quickActionSlots),
          reason: role,
        );
      }
      expect(
        ShiftBoard.actionsFor(const AccessMap(isSuperAdmin: true)).length,
        ShiftBoard.quickActionSlots,
      );
    });

    test('shortcuts arrive in the order somebody at a desk reaches for them',
        () {
      final ranks = ShiftBoard.actionsFor(
        const AccessMap(isSuperAdmin: true),
        limit: ShiftBoard.quickActions.length,
      ).map((a) => a.rank).toList();
      expect(ranks, [...ranks]..sort());
    });

    test('ids and ranks are unique, and every label is a verb and an object',
        () {
      final ids = ShiftBoard.quickActions.map((a) => a.id).toList();
      final ranks = ShiftBoard.quickActions.map((a) => a.rank).toList();
      expect(ids.toSet().length, ids.length);
      expect(ranks.toSet().length, ranks.length);
      for (final action in ShiftBoard.quickActions) {
        // `QuickActionTile` breaks the label after its first word so a row of
        // them is one height. A one-word label leaves a tile a line short of
        // its neighbours.
        expect(action.label.trim().contains(' '), isTrue,
            reason: action.id);
      }
    });
  });

  group('a band, as a state', () {
    test('a load that came back with nothing is empty, not ready', () {
      final band = ShiftBand.ready(rows: const [], total: 0);
      expect(band.phase, ShiftBandPhase.empty);
    });

    test('a failure keeps the rows it was already showing', () {
      // Those rows were true four minutes ago. Blanking them turns "this did
      // not reload" into "there is nobody waiting".
      final loaded = ShiftBand.ready(
        rows: const [ShiftRow(id: 'q-1', title: 'Tom Whitfield')],
        total: 6,
      );
      final failed = loaded.asFailed('Nothing came back.');

      expect(failed.phase, ShiftBandPhase.failed);
      expect(failed.rows, hasLength(1));
      expect(failed.total, 6);
      expect(failed.error, 'Nothing came back.');
    });

    test('a truncated count reads as a floor, never as a total', () {
      final capped = ShiftBand.ready(rows: const [], total: 50, capped: true);
      expect(capped.countLabel, '50+');
      expect(ShiftBand.ready(rows: const [], total: 6).countLabel, '6');
    });
  });

  group('the chart palette', () {
    /// The hues this app has already spent. A series that borrowed one would
    /// tell a reader something about a category that is not true of it.
    const forbidden = [
      AppColors.error,
      AppColors.acuityCritical,
      AppColors.acuityUrgent,
      AppColors.warning,
    ];

    test('no series is red, and none is amber', () {
      for (final color in ShiftChartPalette.series) {
        final hue = HSLColor.fromColor(color).hue;
        expect(
          hue,
          inInclusiveRange(45, 330),
          reason: '$color sits in the red-to-amber arc',
        );
      }
    });

    test('no series is any colour this app has already given a meaning', () {
      for (final color in ShiftChartPalette.series) {
        expect(forbidden, isNot(contains(color)));
      }
    });

    test('the series are distinct, and wrap rather than run out', () {
      expect(
        ShiftChartPalette.series.toSet().length,
        ShiftChartPalette.series.length,
      );
      expect(
        ShiftChartPalette.of(ShiftChartPalette.series.length),
        ShiftChartPalette.of(0),
      );
    });
  });

  group('what the two charts are made of', () {
    test('the clinic reads in lifecycle order, not by size', () {
      const statuses = AppointmentStatuses(
        completed: 7,
        confirmed: 5,
        scheduled: 4,
        cancelled: 2,
      );
      expect(
        ShiftCharts.appointments(statuses).map((s) => s.label),
        ['Scheduled', 'Confirmed', 'Seen', 'Cancelled'],
      );
    });

    test('a status nobody is in draws no bar', () {
      // `<= 0`, not `== 0`: this backend stores an uncounted figure as zero,
      // and a stats route subtracting two counts taken a second apart has
      // answered a negative one.
      const statuses = AppointmentStatuses(scheduled: 3, confirmed: 0);
      final series = ShiftCharts.appointments(statuses);
      expect(series.map((s) => s.label), ['Scheduled']);
      expect(series.single.value, 3);
    });

    test('a status that drops to zero does not recolour the ones after it', () {
      const full = AppointmentStatuses(
        scheduled: 1,
        confirmed: 1,
        completed: 1,
        cancelled: 1,
      );
      const gap = AppointmentStatuses(scheduled: 1, completed: 1, cancelled: 1);

      Color colorOf(List<ShiftSeries> series, String label) =>
          series.firstWhere((s) => s.label == label).color;

      for (final label in ['Scheduled', 'Seen', 'Cancelled']) {
        expect(
          colorOf(ShiftCharts.appointments(gap), label),
          colorOf(ShiftCharts.appointments(full), label),
          reason: '$label changed colour when Confirmed emptied',
        );
      }
    });

    test('the queue reads biggest first, because the question is the backlog',
        () {
      final series = ShiftCharts.queue(const [
        QueueServiceCount(name: 'Emergency', count: 4),
        QueueServiceCount(name: 'OPD', count: 6),
        QueueServiceCount(name: 'Radiology', count: 0),
        QueueServiceCount(name: 'Laboratory', count: 3),
      ]);

      expect(series.map((s) => s.label), ['OPD', 'Emergency', 'Laboratory']);
      expect(ShiftCharts.total(series), 13);
    });

    test('a stored service key is shown as a word, and an acronym is left '
        'alone', () {
      // `Formatters.label` lower-cases before it capitalises, so `OPD` through
      // it is `Opd`. A service area is free text a site configures, and an
      // acronym a ward says out loud is not a word to be title-cased.
      expect(
        ShiftCharts.queue(
          const [QueueServiceCount(name: 'OUT_PATIENT', count: 2)],
        ).single.label,
        'Out patient',
      );
      expect(
        ShiftCharts.queue(
          const [QueueServiceCount(name: 'OPD', count: 2)],
        ).single.label,
        'OPD',
      );
    });

    test('an empty breakdown is an empty chart, not a zero-sized one', () {
      expect(ShiftCharts.queue(const []), isEmpty);
      expect(
        ShiftCharts.queue(const [QueueServiceCount(name: 'OPD', count: 0)]),
        isEmpty,
      );
      expect(ShiftCharts.total(const []), 0);
    });
  });
}
