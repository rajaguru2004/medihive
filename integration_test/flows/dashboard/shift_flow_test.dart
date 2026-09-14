import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/modules/dashboard/shift_board.dart';

import '../../fixtures/world_roles.dart';
import '../../robots/dashboard_robot.dart';
import '../../robots/patients_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerShiftFlows();
}

/// The board, once per kind of shift.
///
/// The claim under test is that the board is **shaped by the access map** and
/// that its parts fail separately. Both are invisible to a test that signs in
/// as the super admin and asserts the screen rendered: that account holds every
/// module, so it sees the first four bands whatever the resolver does, and one
/// world with every route answering proves nothing about the fifth state.
///
/// No fixtures of its own. Every band reads a list the world already serves —
/// the queue, screenings, today's clinic, live admissions, lab and imaging
/// orders, prescriptions and invoices — and a second world would be a second
/// department for the same screens to disagree about.
void registerShiftFlows() {
  group('the shift board', () {
    testWidgets("a doctor's board opens on the work waiting on them",
        (tester) async {
      final harness =
          await AppHarness.bootSignedIn(tester, role: WorldRole.doctor);
      final board = DashboardRobot(harness);

      await board.assertOnBoard();

      // Four bands, most urgent first, and the doctor's four rather than the
      // navigation's: the bar opens on Queue, the board opens on who is
      // waiting *and* on their own clinic and ward round.
      expect(board.bandIds(), [
        ShiftBandId.waiting,
        ShiftBandId.screenings,
        ShiftBandId.clinic,
        ShiftBandId.ward,
      ]);
      for (final id in board.bandIds()) {
        board.seeBandLoaded(id);
      }

      // The census is web parity: the eight figures and both charts.
      board.seeFigure('Waiting');
      board.seeFigure('Booked today');
      board.seeFigure('Beds free');
      board.seeFigure('Needs attention');
      board.seeCharts();
      board.seeUpdatedAt();
      board.seeNoStaleNotice();

      // First on the board, and only when there is something to say.
      board.seeAttention();
    });

    testWidgets("a nurse's board shows screenings and never the takings",
        (tester) async {
      final harness =
          await AppHarness.bootSignedIn(tester, role: WorldRole.nurse);
      final board = DashboardRobot(harness);

      await board.assertOnBoard();

      await board.seeBand(ShiftBandId.screenings);
      board.seeBandLoaded(ShiftBandId.screenings);
      board.seeBandLoaded(ShiftBandId.ward);

      // A nurse holds no billing grant, so the day's takings are not hers to
      // read off a ward tablet — and the band that is about money is not on
      // her board either.
      board.seeNoRevenue();
      board.seeNoBand(ShiftBandId.unpaid);
    });

    testWidgets('billing staff get what is owed, and the takings with it',
        (tester) async {
      final harness =
          await AppHarness.bootSignedIn(tester, role: WorldRole.billingStaff);
      final board = DashboardRobot(harness);

      await board.assertOnBoard();

      expect(board.bandIds(), [ShiftBandId.unpaid]);
      board.seeBandLoaded(ShiftBandId.unpaid);
      board.seeRevenue();

      // The ward is not this account's business, and a band it cannot read
      // must be absent rather than locked: a locked panel on a board is a
      // promise of something that was never going to be there.
      board.seeNoBand(ShiftBandId.ward);
      board.seeNoBand(ShiftBandId.waiting);
    });

    testWidgets('every shortcut a lab technician is offered actually opens',
        (tester) async {
      // The regression this exists for: a screenshot round found this row
      // offering a lab technician four shortcuts that every one of them landed
      // on the refusal screen. A shortcut that refuses is worse than a missing
      // one — it teaches a clinician the app's own shortcuts cannot be
      // trusted.
      final harness =
          await AppHarness.bootSignedIn(tester, role: WorldRole.labTechnician);
      final board = DashboardRobot(harness);

      await board.assertOnBoard();

      final offered = board.offeredQuickActions();
      expect(offered, isNotEmpty, reason: 'a lab technician can raise an '
          'order and enter a result, so the row should not be empty');

      for (final id in offered) {
        await board.openQuickAction(id);
        await board.back();
        await board.assertVisible();
      }

      // And the board itself is the bench's, not the ward's.
      expect(board.bandIds(), [ShiftBandId.lab]);
      board.seeNoRevenue();
    });

    testWidgets('one band failing leaves the others on screen', (tester) async {
      // The whole reason each band carries its own load state: a laboratory
      // outage must not blank a nurse's bed counts.
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.nurse,
        overrides: (api) => api.failWith('GET', '/api/pre-triage', 500),
      );
      final board = DashboardRobot(harness);

      await board.assertVisible();
      await board.seeBand(ShiftBandId.screenings);

      board.seeBandError(ShiftBandId.screenings);
      board.seeBandLoaded(ShiftBandId.waiting);
      board.seeBandLoaded(ShiftBandId.clinic);
      board.seeBandLoaded(ShiftBandId.ward);

      // The retry is attached to the band that failed, and asks again.
      final before = harness.api.callCount('GET', '/api/pre-triage');
      await board.retryBand(ShiftBandId.screenings);
      expect(
        harness.api.callCount('GET', '/api/pre-triage'),
        greaterThan(before),
        reason: 'the band\'s own retry should re-request that band and '
            'nothing else',
      );
    });

    testWidgets('a failed silent refresh keeps the last good figures',
        (tester) async {
      final harness =
          await AppHarness.bootSignedIn(tester, role: WorldRole.doctor);
      final board = DashboardRobot(harness);

      await board.assertOnBoard();
      board.seeNoStaleNotice();

      // The board is good, then the route goes down and somebody writes on
      // another tab — which is what triggers a silent refresh in production.
      harness.api.failWith('GET', '/api/dashboard', 500);
      await board.announceChangeElsewhere();

      board.seeStaleNotice();
      // The numbers stay. Blanking them would read as a department with no
      // patients, and a red retry over them would read as "these are wrong"
      // when what happened is "these are from four minutes ago".
      board.seeFigure('Waiting');
      board.seeNoErrorBanner();
    });

    testWidgets('the board opens a patient record and a booking',
        (tester) async {
      final harness =
          await AppHarness.bootSignedIn(tester, role: WorldRole.doctor);
      final board = DashboardRobot(harness);
      final hub = PatientHubRobot(harness);

      await board.assertOnBoard();
      board.seeRecentPatients();
      board.seeUpcoming();

      // `/patients/record`, with the id in `Get.arguments` — a `:id`
      // registered at that position would swallow `search` and `edit` too.
      await board.openPatient('p-1');
      await hub.assertOnHub();
      await board.back();
      await board.assertVisible();

      // The route, not the screen behind it. `openAppointment` asserts the
      // board sent the reader to that booking; what the clinic's detail screen
      // makes of the id is the clinic's flow to assert, and today the world's
      // dashboard payload and its `/appointments/:id` fixture carry different
      // ids — see the note in the module report.
      await board.openAppointment('a-1');
      await board.back();
      await board.assertVisible();
    });
  });
}
