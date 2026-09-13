import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../robots/pre_triage_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerPreTriageFlows();
}

/// Pre-triage: the two-step form, and what the record it writes looks like when
/// somebody opens it again.
void registerPreTriageFlows() {
  group('screening', () {
    testWidgets('step one hands its answers to step two, and the pair saves',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final preTriage = PreTriageRobot(harness);

      await preTriage.openBoard();
      await preTriage.assertOnBoard();

      await preTriage.startNewScreening();
      await preTriage.assertOnStep1();
      await preTriage.enterWho(
        firstName: 'Nadia',
        lastName: 'Farouk',
        age: '34',
        sex: 'Female',
      );

      await preTriage.goToObservations();
      await preTriage.assertOnStep2();
      // The hand-off, before anything is saved: a receptionist takes the
      // identity and a nurse takes the observations, often at two desks.
      preTriage.seeCarriedIdentity('Nadia Farouk');

      await preTriage.enterObservations(
        complaint: 'Shortness of breath since this morning',
        temperature: '39.8',
        pulse: '96',
        systolic: '128',
        diastolic: '78',
      );
      // Flagged while the keyboard is still up, not after the record is saved
      // and somebody opens it again.
      preTriage.seeObservationWarning();

      await preTriage.routeTo('Emergency');
      await preTriage.saveScreening();

      final post = harness.api.requireCall('POST', '/api/pre-triage');
      expect(post.jsonBody, {
        'firstName': 'Nadia',
        'lastName': 'Farouk',
        'age': 34,
        'gender': 'Female',
        'chiefComplaint': 'Shortness of breath since this morning',
        'temperature': 39.8,
        'pulseRate': 96,
        'bloodPressureSystolic': 128,
        'bloodPressureDiastolic': 78,
        'routedTo': 'Emergency',
      });

      // The two screens are one task, so saving leaves neither of them on the
      // stack — Back from the board must not reopen a half-filled form for a
      // patient who has already been screened.
      await preTriage.assertOnBoard();
      await preTriage.letToastsExpire();
    });

    testWidgets('a screening outside the ranges is flagged on its detail',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final preTriage = PreTriageRobot(harness);

      // Tom Whitfield: pulse 128, blood pressure 168/96. Two readings outside
      // the adult range, and the reason this screen may not carry that in
      // colour alone.
      await preTriage.openScreening('s-1');
      await preTriage.assertOnDetail();
      await preTriage.seeObservationFlag(
        containing: 'outside the normal adult range',
      );
    });

    testWidgets('a screening inside the ranges is not', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester);
      final preTriage = PreTriageRobot(harness);

      // Henrik Nilsen: 36.6 °C, pulse 72, 118/74. A twisted ankle, and nothing
      // a banner should be raised about — a warning that is always up is a
      // warning nobody reads.
      await preTriage.openScreening('s-3');
      await preTriage.assertOnDetail();
      preTriage.seeNoObservationFlag();
    });
  });
}
