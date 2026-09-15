import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/routes/app_pages.dart';

import '../../fixtures/modules/patient_portal_fixtures.dart';
import '../../fixtures/world_roles.dart';
import '../../robots/login_robot.dart';
import '../../robots/patient_portal_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerPatientPortalFlows();
}

/// The patient portal: where a patient's session opens, what they can see of
/// their own record, and the two screens that get somebody with a hospital
/// card an account.
void registerPatientPortalFlows() {
  group('patient portal', () {
    testWidgets('a patient signs in to their own screen, not the ward board',
        (tester) async {
      final harness = await AppHarness.bootSignedOut(
        tester,
        role: WorldRole.patient,
      );
      final login = LoginRobot(harness);
      final portal = PatientPortalRobot(harness);

      await login.assertVisible();
      await login.signIn(
        email: 'i.balogun@example.org',
        password: 'correct-horse',
      );

      // The headline requirement of this phase. Both halves: on the portal,
      // and the staff shell not built underneath it — a ward board one
      // back-gesture away is the same defect as landing on one.
      await portal.assertOnPortal();
      portal.seeGreeting('Ifeoma');
    });

    testWidgets('a clinician signing in still lands on the shell',
        (tester) async {
      // The other side of the same decision. Without this, a landing resolver
      // that answered "portal" for everybody would pass the test above.
      final harness = await AppHarness.bootSignedOut(
        tester,
        role: WorldRole.doctor,
      );
      final login = LoginRobot(harness);
      final portal = PatientPortalRobot(harness);

      await login.assertVisible();
      await login.signIn(
        email: 'a.okonkwo@example.org',
        password: 'correct-horse',
      );

      await portal.assertOnStaffShell();
    });

    testWidgets('a deep link to the staff shell lands on the portal instead',
        (tester) async {
      // Sign-in and the splash screen both resolve their own landing, so this
      // is the net underneath: every `RouteSettings(name: Routes.HOME)` in the
      // app was written before there were two shells.
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.patient,
      );
      final portal = PatientPortalRobot(harness);

      await portal.assertOnPortal();
      await portal.openRoute(Routes.HOME);
      await portal.assertOnPortal();
    });

    testWidgets("the dashboard shows this patient's appointments and no others",
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.patient,
      );
      final portal = PatientPortalRobot(harness);

      await portal.assertOnPortal();

      // `a-1` is Ifeoma Balogun's. `a-4` is Tom Whitfield's, and it is on the
      // same clinic board — so a screen that asked for the collection instead
      // of for one patient's rows would show it.
      await portal.seeAppointment('a-1');
      await portal.seeNoAppointment('a-4');
      await portal.seeRecord();
      await portal.seeDocuments();

      // The scoping is the app's to get right on this route: `/api/appointments`
      // is a staff route, a portal account is granted the read, and asked
      // without a `patientId` the live API really does answer with the whole
      // hospital's day.
      final request = harness.api.requireCall('GET', '/api/appointments');
      expect(
        request.query['patientId'],
        'p-1',
        reason: 'the portal asked the clinic list for everybody',
      );

      // And it never touches the staff dashboard, which answers a patient
      // account with the hospital's census, revenue and critical-alert count.
      harness.api.requireNoCall('GET', '/api/dashboard');
    });

    testWidgets('the entry sequence chooses a language and then asks',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.patient,
      );
      final portal = PatientPortalRobot(harness);

      await portal.assertOnPortal();
      await portal.startCaseTaking();

      await portal.assertOnLanguage();
      // Twelve rows, each one real. The three checked by hand are the three
      // that carry a different property: English is what ships and must not
      // regress, Tamil is a script with no glyph in any bundled face, and Odia
      // is the one the transcriber cannot hear.
      portal.seeLanguages(const ['en', 'ta', 'or']);

      // Choosing it says so, on the screen where it is chosen. Then choosing
      // one that works takes the warning away again — a notice that stuck would
      // withdraw the microphone from an interview that could have used it.
      await portal.chooseLanguage('or');
      portal.seeLanguageCannotBeSpoken();
      await portal.chooseLanguage('en');
      portal.seeLanguageCanBeSpoken();

      await portal.continueFromLanguage();

      await portal.assertOnConsent();
      // Told, and then asked. The four statements are above the question and
      // both answers are real controls.
      portal.seeConsentTold();
      portal.seeConsentAsksRatherThanAssumes();

      await portal.agreeToConsent();
      await portal.assertOnCaseHandoff();
    });

    testWidgets('declining leaves the patient on their own screen',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.patient,
      );
      final portal = PatientPortalRobot(harness);

      await portal.assertOnPortal();
      await portal.startCaseTaking();
      await portal.continueFromLanguage();
      await portal.assertOnConsent();

      // "Not now" is a real answer and it costs nothing — including not
      // dropping them back on the language question they already answered.
      await portal.declineConsent();
      await portal.assertOnPortal();
    });

    testWidgets('a hospital card sets a password and opens the portal',
        (tester) async {
      final harness = await AppHarness.bootSignedOut(
        tester,
        role: WorldRole.patient,
      );
      final login = LoginRobot(harness);
      final portal = PatientPortalRobot(harness);

      await login.assertVisible();
      await portal.openClaimFromSignIn();
      await portal.assertOnClaim();

      await portal.enterCard(mrn: kPortalMrn);
      await portal.assertOnActivate();
      portal.seePasswordRule();

      await portal.setPassword(
        password: 'Portal@12345',
        email: 'i.balogun@example.org',
      );
      await portal.assertOnPortal();

      final claim = harness.api.requireCall('POST', '/api/patient-auth/claim');
      expect(claim.jsonBody['mrn'], kPortalMrn);
      expect(
        claim.jsonBody.containsKey('dateOfBirth'),
        isTrue,
        reason: 'the card is the pair, and a claim without the date of birth '
            'is a record number anybody could be holding',
      );
      expect(
        claim.isAuthenticated,
        isFalse,
        reason: 'claiming a record is how somebody with no account gets one, '
            'so it must go out without a bearer token',
      );

      final activate =
          harness.api.requireCall('POST', '/api/patient-auth/activate');
      expect(activate.jsonBody.keys.toSet(), {
        'claimToken',
        'password',
        'email',
      });
    });

    testWidgets('a card that matches nothing is refused without saying so',
        (tester) async {
      final harness = await AppHarness.bootSignedOut(
        tester,
        role: WorldRole.patient,
      );
      final login = LoginRobot(harness);
      final portal = PatientPortalRobot(harness);

      await login.assertVisible();
      await portal.openClaimFromSignIn();

      // The claim itself succeeds — it succeeds for **everything**, which is
      // the property the copy has to survive. The refusal arrives one screen
      // later, and it must not tell somebody probing this route whether the
      // record exists.
      await portal.enterCard(mrn: kUnknownMrn);
      await portal.assertOnActivate();

      await portal.setPassword(
        password: 'Portal@12345',
        email: 'nobody@example.org',
      );

      await portal.seeRefusedWithoutLeaking();
      // Still here. A 401 from this route must not be mistaken for an expired
      // session and torn down through `SessionManager`.
      await portal.assertOnActivate();
      portal.seeNavigatorIntact();
    });

    testWidgets('a password that does not match itself never leaves the phone',
        (tester) async {
      final harness = await AppHarness.bootSignedOut(
        tester,
        role: WorldRole.patient,
      );
      final login = LoginRobot(harness);
      final portal = PatientPortalRobot(harness);

      await login.assertVisible();
      await portal.openClaimFromSignIn();
      await portal.enterCard(mrn: kPortalMrn);
      await portal.assertOnActivate();

      await portal.setPassword(password: 'Portal@12345', confirm: 'Portal@123');
      await portal.seeFieldError('The two do not match');
      harness.api.requireNoCall('POST', '/api/patient-auth/activate');

      await portal.setPassword(password: 'short');
      await portal.seeFieldError('Use at least 8 characters');
      harness.api.requireNoCall('POST', '/api/patient-auth/activate');
    });
  });
}
