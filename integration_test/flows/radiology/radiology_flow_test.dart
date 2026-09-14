import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/core/keys/radiology_keys.dart';

import '../../fixtures/modules/radiology_fixtures.dart';
import '../../fixtures/world_roles.dart';
import '../../robots/radiology_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerRadiologyFlows();
}

/// Imaging, end to end.
///
/// The department's own pathway is one test — a request raised, booked, done
/// and read — because each step is only correct in the presence of the one
/// before it: a study cannot be marked performed before it is booked, and a
/// report belongs to a study that happened.
///
/// The other four are the rules that exist because getting them wrong hurts
/// somebody: a critical finding nobody was told about, a signed report quietly
/// rewritten, an upload that posts under the wrong field name and silently
/// attaches nothing, and a nurse being shown a worklist she has no business
/// reading.
void registerRadiologyFlows() {
  group('imaging', () {
    testWidgets('a request is raised, booked, performed and read',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.radiologist,
        overrides: installRadiologyFixtures,
      );
      final imaging = RadiologyRobot(harness);

      await imaging.openWorklist();
      await imaging.assertOnWorklist();
      imaging.seeFigures();

      // One read in this department has found something. The banner is red and
      // it names the patient, because one name is something somebody can act
      // on where "1 study" is not.
      imaging.seeCriticalBanner(containing: 'Tom Whitfield');

      // ── Raise it ────────────────────────────────────────────────────────
      await imaging.tapNewOrder();
      await imaging.assertOnOrderForm();

      await imaging.choosePatient('Tom Whitfield');
      await imaging.chooseExam('CT Abdomen with contrast');

      // Contrast changes how the patient is prepared — consent, a cannula,
      // renal function — so the form says so before the request is sent
      // rather than the radiographer finding out at the machine.
      imaging.seeContrastNotice();

      await imaging.chooseUrgency('stat');
      await imaging.enterIndication('Query renal colic, haematuria.');
      await imaging.submitOrder();

      final raised = harness.api.requireCall('POST', '/api/radiology/orders');
      expect(raised.jsonBody['patientId'], 'p-2');
      expect(raised.jsonBody['examId'], 're-5');
      expect(raised.jsonBody['urgency'], 'stat');
      expect(raised.jsonBody['clinicalIndication'], isNotEmpty);

      await imaging.assertOnOrderDetail();
      imaging.seeTimeline();

      // A study nobody has booked cannot be marked performed, and the control
      // is absent rather than disabled.
      imaging.seeAction(RadiologyKeys.actionSchedule);
      imaging.seeNoAction(RadiologyKeys.actionPerformed);

      // ── Book it ─────────────────────────────────────────────────────────
      await imaging.scheduleForToday();

      final booked = harness.api.callsTo('PATCH', '/api/radiology/orders/:id');
      expect(booked, hasLength(1));
      expect(booked.single.jsonBody['status'], 'scheduled');
      expect(booked.single.jsonBody['scheduledDate'], isNotNull);

      // ── Do it ───────────────────────────────────────────────────────────
      await imaging.markPerformed();

      final performed =
          harness.api.callsTo('PATCH', '/api/radiology/orders/:id');
      expect(performed, hasLength(2));
      expect(performed.last.jsonBody['status'], 'completed');
      expect(performed.last.jsonBody['examPerformedAt'], isNotNull);
      // Who did it, stamped from the signed-in account rather than picked: the
      // server leaves this one to the client, so a study with nobody recorded
      // as having performed it is the alternative.
      expect(performed.last.jsonBody['performedById'], WorldRole.radiologist.id);

      // ── Read it ─────────────────────────────────────────────────────────
      await imaging.openReportForm();
      await imaging.assertOnReportForm();
      // A read being written for the first time is not an amendment.
      imaging.seeNoAmendmentField();

      await imaging.writeRead(
        technique: 'Axial CT of the abdomen and pelvis with IV contrast.',
        findings: 'A 4 mm calculus at the left vesicoureteric junction with '
            'mild proximal hydroureter.',
        impression: 'Obstructing left VUJ calculus.',
      );
      await imaging.saveReport();

      final read = harness.api.requireCall('POST', '/api/radiology/reports');
      expect(read.jsonBody['impression'], 'Obstructing left VUJ calculus.');
      expect(read.jsonBody['hasCriticalFindings'], isFalse);

      await imaging.assertOnOrderDetail();
      await imaging.letToastsExpire();
    });

    testWidgets('a critical finding needs its text and the name of who was told',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.radiologist,
        overrides: installRadiologyFixtures,
      );
      final imaging = RadiologyRobot(harness);

      await imaging.openWorklist();
      // `ro-5` is a completed study with nobody's read against it yet.
      await imaging.openOrder('ro-5');
      await imaging.openReportForm();

      await imaging.writeRead(
        technique: 'Supine abdominal radiograph.',
        findings: 'Free gas under both hemidiaphragms.',
        impression: 'Pneumoperitoneum.',
      );
      await imaging.turnOnCriticalFindings();

      // Saving now must not go anywhere. A critical finding with no text and
      // nobody recorded as having been told is the exact state a ward
      // escalates from, and it is the state this switch exists to prevent.
      await imaging.saveReport();
      harness.api.requireNoCall('POST', '/api/radiology/reports');
      imaging.seeFieldErrorSummary();

      // Half of it is still not enough.
      await imaging.enterCriticalFinding('Pneumoperitoneum');
      await imaging.saveReport();
      harness.api.requireNoCall('POST', '/api/radiology/reports');

      await imaging.enterNotifiedTo('Dr Amara Okonkwo');
      await imaging.saveReport();

      final written = harness.api.requireCall('POST', '/api/radiology/reports');
      expect(written.jsonBody['hasCriticalFindings'], isTrue);
      expect(written.jsonBody['criticalFindings'], 'Pneumoperitoneum');

      // Who and when travel together, on the PATCH that follows the create —
      // `CreateRadiologyReportDto` declares neither, so a create carrying them
      // would be a 400 for the whole report.
      final notified =
          harness.api.requireCall('PATCH', '/api/radiology/reports/:id');
      expect(notified.jsonBody['criticalNotifiedTo'], 'Dr Amara Okonkwo');
      expect(
        notified.jsonBody['criticalNotifiedAt'],
        isNotNull,
        reason: 'a name with no time against it does not prove anybody was '
            'told',
      );

      await imaging.letToastsExpire();
    });

    testWidgets('a signed report cannot be changed without a reason',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.radiologist,
        overrides: installRadiologyFixtures,
      );
      final imaging = RadiologyRobot(harness);

      // `rr-1` is final — the ward has already acted on it.
      await imaging.openReportForEditing('rr-1', orderId: 'ro-6');
      imaging.seeAmendmentField();

      await imaging.saveReport();
      harness.api.requireNoCall('PATCH', '/api/radiology/reports/:id');
      imaging.seeFieldErrorSummary();

      // Four characters is somebody getting past the field rather than
      // answering it.
      await imaging.enterAmendmentReason('typo');
      await imaging.saveReport();
      harness.api.requireNoCall('PATCH', '/api/radiology/reports/:id');

      await imaging.enterAmendmentReason('Laterality corrected: left, not '
          'right.');
      await imaging.saveReport();

      final amended =
          harness.api.requireCall('PATCH', '/api/radiology/reports/:id');
      expect(
        amended.jsonBody['status'],
        'amended',
        reason: 'a signed report that is changed becomes an amendment, never '
            'another draft',
      );
      expect(amended.jsonBody['amendmentReason'], contains('Laterality'));

      await imaging.letToastsExpire();
    });

    testWidgets('an image is posted as multipart under the field name "file"',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.radiologist,
        overrides: installRadiologyFixtures,
      );
      final imaging = RadiologyRobot(harness);

      await imaging.openWorklist();
      // `ro-7` already carries a read, which is the only place this backend
      // stores images.
      await imaging.openOrder('ro-7');
      imaging.seeAction(RadiologyKeys.actionUpload);

      await imaging.uploadImage();

      final upload = harness.api.requireCall('POST', '/api/radiology/upload');
      expect(
        upload.formFiles.keys,
        contains('file'),
        reason: "the route's FileInterceptor reads 'file' and nothing else; a "
            'part sent under any other name arrives as no file at all',
      );
      expect(upload.formFiles['file'], isNotEmpty);

      // The server files the object and answers with a URL. Attaching it to
      // the read is the PATCH that follows, and without it the upload is an
      // orphan in a bucket.
      final attached =
          harness.api.requireCall('PATCH', '/api/radiology/reports/:id');
      expect(
        attached.jsonBody['images'],
        contains('files.example.org'),
        reason: 'images are a JSON array inside a text column, so this is a '
            'string and not a list',
      );

      imaging.seeImages();
      await imaging.letToastsExpire();
    });

    testWidgets('a radiologist may write, and a nurse is not shown the board',
        (tester) async {
      final radiology = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.radiologist,
        overrides: installRadiologyFixtures,
      );
      final asRadiologist = RadiologyRobot(radiology);

      await asRadiologist.openWorklist();
      await asRadiologist.assertOnWorklist();
      asRadiologist.seeNewOrderAction();
      asRadiologist.seeOrder('ro-1');
    });

    testWidgets('a nurse asking for imaging gets a locked state', (tester) async {
      final nursing = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.nurse,
        overrides: installRadiologyFixtures,
      );
      final asNurse = RadiologyRobot(nursing);

      // The shell never offers her an Imaging tab; this is the deep link, the
      // stale shortcut, or the role an administrator changed under a running
      // session.
      await asNurse.openWorklist();
      await asNurse.assertNoAccess();
      asNurse.seeNoNewOrderAction();
    });
  });
}
