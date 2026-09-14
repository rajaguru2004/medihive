import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../fixtures/modules/clinical_fixtures.dart';
import '../../fixtures/world_roles.dart';
import '../../robots/appointment_detail_robot.dart';
import '../../robots/appointment_form_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerAppointmentFlows();
}

/// Booking a clinic slot, and everything a desk does to a booking afterwards.
void registerAppointmentFlows() {
  group('booking a slot', () {
    testWidgets('the slots on offer are this site’s own clinic hours',
        (tester) async {
      // A short morning on twenty-minute appointments — nothing like the
      // 08:00–17:00 default, which is exactly the point: a hard-coded grid
      // passes against the default site and is wrong for every other one.
      final harness = await AppHarness.bootSignedIn(
        tester,
        overrides: (api) => installClinicHours(
          api,
          start: '07:00',
          end: '09:00',
          minutes: 20,
        ),
      );
      final form = AppointmentFormRobot(harness);

      await form.open();
      await form.assertVisible();

      await form.openSlots();
      expect(
        form.offeredSlots,
        ['07:00', '07:20', '07:40', '08:00', '08:20', '08:40'],
        reason: 'the grid is generated from working hours and the appointment '
            'length, and the closing time is not itself a slot',
      );

      await form.closeSheet();
    });

    testWidgets('a booking sends the day, the slot, and nothing the DTO would '
        'refuse', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final form = AppointmentFormRobot(harness);

      await form.open();
      await form.assertVisible();

      await form.choosePatient(ClinicalWorld.scheduledPatient);
      await form.chooseClinician(ClinicalWorld.doctorName);
      await form.chooseSlot('09:00');
      await form.chooseDuration(45);
      await form.enterComplaint('Persistent headache for three weeks');
      await form.save();

      final post = harness.api.requireCall('POST', '/api/appointments');
      // The whole map, not a spot check. `priority` is the key the web console
      // strips and this backend rejects, and the only assertion that proves it
      // is absent is one that lists everything else.
      expect(post.jsonBody, {
        'patientId': 'p-1',
        'doctorId': ClinicalWorld.doctorId,
        'appointmentDate': '2026-03-12',
        'appointmentTime': '09:00',
        'durationMinutes': 45,
        'appointmentType': 'new_patient',
        'chiefComplaint': 'Persistent headache for three weeks',
      });

      await form.letToastsExpire();
    });

    testWidgets('a complaint of four characters is not a complaint',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final form = AppointmentFormRobot(harness);

      await form.open();
      await form.assertVisible();

      await form.choosePatient(ClinicalWorld.scheduledPatient);
      await form.chooseClinician(ClinicalWorld.doctorName);
      await form.chooseSlot('09:00');
      await form.enterComplaint('pain');
      await form.save();

      harness.api.requireNoCall('POST', '/api/appointments');
      form.seeSaveBlocked();
    });
  });

  group('one booking', () {
    testWidgets('offers only the step it can actually take', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final detail = AppointmentDetailRobot(harness);

      await detail.open(ClinicalWorld.scheduledAppointment);
      await detail.assertVisible();
      detail.seeOpenOn(ClinicalWorld.scheduledAppointment);
      detail.seeTimeline();

      detail.seeStep('confirmed');
      detail.seeStep('checked_in');
      detail.seeStep('no_show');
      // Completing somebody who has not arrived is how a clinic's figures stop
      // meaning anything.
      detail.seeNoStep('in_progress');
      detail.seeNoStep('completed');

      await detail.moveTo('checked_in');
      final patch = harness.api.requireCall(
        'PATCH',
        '/api/appointments/:id',
      );
      expect(patch.jsonBody, {'status': 'checked_in'});

      // The ladder moved with it: arriving unlocks starting and closes
      // confirming.
      detail.seeStep('in_progress');
      detail.seeNoStep('confirmed');

      await detail.letToastsExpire();
    });

    testWidgets('one that is finished with offers nothing at all',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final detail = AppointmentDetailRobot(harness);

      await detail.open(ClinicalWorld.completedAppointment);
      await detail.assertVisible();

      detail.seeClosedNotice();
      detail.seeNoStep('completed');
      detail.seeNoReschedule();
      detail.seeNoCancel();
    });

    testWidgets('a reschedule sends the new day, the new time and the new '
        'status together', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final detail = AppointmentDetailRobot(harness);

      await detail.open(ClinicalWorld.scheduledAppointment);
      await detail.assertVisible();

      await detail.reschedule(slot: '10:00');

      final patch = harness.api.requireCall('PATCH', '/api/appointments/:id');
      // All three in one request. The date without the status leaves a booking
      // that reads "scheduled" on a day nobody agreed to; the status without
      // the date leaves one marked "rescheduled" that never moved.
      expect(patch.jsonBody, {
        'appointmentDate': '2026-03-19',
        'appointmentTime': '10:00',
        'status': 'rescheduled',
      });

      await detail.letToastsExpire();
    });

    testWidgets('a cancellation will not go through without a reason',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final detail = AppointmentDetailRobot(harness);

      await detail.open(ClinicalWorld.scheduledAppointment);
      await detail.assertVisible();

      await detail.openCancel();
      await detail.continueWithoutReason();
      expect(
        detail.cancelSheetIsOpen,
        isTrue,
        reason: 'a released slot with no reason on it is a slot nobody can '
            'audit',
      );
      harness.api.requireNoCall('PATCH', '/api/appointments/:id');

      await detail.submitCancelReason('Patient telephoned to postpone');
      // The confirm names the person, not "this record": a ward tablet is
      // shared, and the booking on screen is not always the one in mind.
      detail.seeConfirmNames(ClinicalWorld.scheduledPatient);
      await detail.confirmCancel();

      final patch = harness.api.requireCall('PATCH', '/api/appointments/:id');
      expect(patch.jsonBody, {
        'status': 'cancelled',
        'cancellationReason': 'Patient telephoned to postpone',
      });

      await detail.letToastsExpire();
    });

    testWidgets('deleting one answers 204 and counts as done', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final detail = AppointmentDetailRobot(harness);

      await detail.open(ClinicalWorld.noShowAppointment);
      await detail.assertVisible();

      await detail.deleteBooking();

      harness.api.requireCall('DELETE', '/api/appointments/:id');
      // An empty 204 used to read as a failure, which left the row on screen
      // and the toast saying it had not worked.
      detail.seeToast(containing: 'deleted');
      await detail.letToastsExpire();
    });

    testWidgets('a read-only account is offered nothing to do', (tester) async {
      // A nurse holds APPOINTMENT_READ and nothing else on this module.
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.nurse,
      );
      final detail = AppointmentDetailRobot(harness);

      await detail.open(ClinicalWorld.scheduledAppointment);
      await detail.assertVisible();

      detail.seeNoEdit();
      detail.seeNoDelete();
      detail.seeNoReschedule();
      detail.seeNoCancel();
      detail.seeNoStep('checked_in');
      // Absent, and said out loud — not a row of greyed-out buttons somebody
      // presses twice.
      detail.seeLocked();
    });
  });
}
