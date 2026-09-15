import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/core/keys/app_keys.dart';
import 'package:medihive/app/modules/home/controllers/home_controller.dart';
import 'package:medihive/app/routes/app_pages.dart';

import '../fixtures/modules/case_taking_fixtures.dart';
import '../fixtures/world_roles.dart';
import '../robots/case_taking_robot.dart';
import '../robots/patient_portal_robot.dart';
import '../support/app_harness.dart';
import '../support/pump.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the whole product, for a screen recording
///
/// Every role the app ships, in light mode, paced so a camera can follow it.
/// Each role is its own `testWidgets` — they run in order, and each one boots
/// fresh, which is the point: the shell is resolved from the server's access
/// map, so a nurse and a receptionist are the *same build* showing different
/// navigation.
///
/// ```sh
/// flutter test integration_test/demo/full_demo.dart \
///   -d emulator-5554 \
///   --dart-define=NEX_HIVE_WATCH=true \
///   --dart-define=NEX_HIVE_WATCH_PACE=1500 \
///   --timeout none
/// ```
///
/// Start the recording, run it, and leave it alone. Roughly six to eight
/// minutes at 1500 ms; raise the pace to 2000 if somebody is narrating.
///
/// **Light mode throughout**, forced per test rather than assumed: the harness
/// restores whatever theme was last persisted, so a run after a dark-theme test
/// would otherwise record half the product in the wrong palette.
///
/// It runs on fixtures, not the tunnel. A recording must not be at the mercy of
/// a model taking twenty seconds or a network dropping mid-take.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Boots one account in light mode.
  ///
  /// `useLightTheme` after the boot, not before: the theme is restored from
  /// storage during startup, so setting it earlier is overwritten by the
  /// restore.
  Future<AppHarness> openAs(
    WidgetTester tester,
    WorldRole role, {
    void Function(dynamic api)? overrides,
  }) async {
    final harness = await AppHarness.bootSignedIn(
      tester,
      role: role,
      fonts: true,
      overrides: overrides,
    );
    await harness.useLightTheme();
    return harness;
  }

  /// Opens a shell tab and holds it long enough to read, if this account has
  /// one.
  ///
  /// `AppHarness.showTab` asserts, and it is right to — a flow test naming a
  /// tab the account cannot reach is a test filing a screenshot of the previous
  /// screen. A recording is the other case: the bar is resolved per account, so
  /// which destinations exist is the *subject*, and stopping the take because a
  /// doctor has no Consultations tab would be the runner arguing with the
  /// product. Skipped silently, and the role's own tabs still get their time.
  Future<void> show(
    WidgetTester tester,
    AppHarness harness,
    String route,
  ) async {
    if (!HomeController.to.selectRoute(route)) return;
    await tester.pumpUntilRouteSettled();
    await tester.pumpSeconds(2);
  }

  // ── 1. The patient ─────────────────────────────────────────────────────────
  //
  // First, and given the most time. It is the new half of the product, and the
  // only screen in MediHive read by somebody who does not work here.
  group('the patient', () {
    testWidgets('signs in, is interviewed, and is kept safe', (tester) async {
      final harness = await openAs(
        tester,
        WorldRole.patient,
        overrides: (api) => installCaseTakingFixtures(api as dynamic),
      );

      final portal = PatientPortalRobot(harness);
      final interview = CaseTakingRobot(harness);

      // Their own screen — same build a clinician signs into, resolved from
      // the access map rather than from the role's name.
      await portal.assertOnPortal();
      await portal.seeRecord();
      await portal.seeDocuments();
      await tester.pumpSeconds(2);

      // Asked, not assumed.
      await portal.startCaseTaking();
      await portal.assertOnLanguage();
      await portal.chooseLanguage('en');
      await portal.continueFromLanguage();

      await portal.assertOnConsent();
      portal.seeConsentTold();
      await tester.pumpSeconds(3);
      await portal.agreeToConsent();

      // Speak, type or tap — all three on screen at once, no mode to switch.
      interview.useWorkingMicrophone();
      await interview.waitForQuestion('bothering you');
      await interview.seeAllThreeWaysToAnswer();
      await tester.pumpSeconds(2);

      await interview.typeAnswer('Pain in the middle of my chest');
      await interview.waitForQuestion('How long');
      await interview.typeAnswer('Three days');

      await interview.waitForQuestion('start suddenly');
      await interview.tapAnswer('sudden');

      await interview.waitForQuestion('scale of nothing at all');
      await interview.tapAnswer('7');

      // The safety engine. Rules are versioned data evaluated by code — the
      // model is never asked whether something is dangerous.
      await interview.waitForQuestion('short of breath');
      await interview.tapAnswer('yes');
      await interview.waitForQuestion('sweating');
      await interview.tapAnswer('yes');

      await interview.seeRedFlag();
      await tester.pumpSeconds(4);

      // The heart of it: "I don't know" is filed as itself. A chart reading
      // "no known allergies" when nobody asked is not incomplete, it is wrong.
      await interview.waitForQuestion('any allergies');
      interview.seeFourAnswers();
      await tester.pumpSeconds(2);
      await interview.tapAnswer('not_sure');

      interview.seeAnswerInTranscript('Not sure');
      interview.seeNoText('No known allergies');
      await tester.pumpSeconds(4);
    });
  });

  // ── 2. Everyone who works here ─────────────────────────────────────────────
  //
  // One test per role. Each boots its own session because the access map is
  // read from storage before the first frame, and each shows the destinations
  // that account actually has — a receptionist has no clinical controls at all,
  // and that absence is the thing worth filming.
  group('the hospital', () {
    testWidgets('the doctor', (tester) async {
      final harness = await openAs(tester, WorldRole.doctor);

      await tester.pumpUntilFound(find.byKey(HomeKeys.dashboard));
      await tester.pumpSeconds(3);

      await show(tester, harness, Routes.APPOINTMENTS);
      await show(tester, harness, Routes.CONSULTATIONS);
      await show(tester, harness, Routes.QUEUE);
    });

    testWidgets('the nurse', (tester) async {
      final harness = await openAs(tester, WorldRole.nurse);

      await tester.pumpUntilFound(find.byKey(HomeKeys.dashboard));
      await tester.pumpSeconds(3);

      // The board this app was originally built for: acuity first, then
      // arrival, with a wait that turns past the site's own threshold.
      await show(tester, harness, Routes.QUEUE);
      await show(tester, harness, Routes.PRE_TRIAGE);
      await show(tester, harness, Routes.INPATIENT);
    });

    testWidgets('the receptionist', (tester) async {
      final harness = await openAs(tester, WorldRole.receptionist);

      await tester.pumpUntilFound(find.byKey(HomeKeys.dashboard));
      await tester.pumpSeconds(3);

      await show(tester, harness, Routes.APPOINTMENTS);
      await show(tester, harness, Routes.PATIENTS);
    });

    testWidgets('the pharmacist', (tester) async {
      final harness = await openAs(tester, WorldRole.pharmacist);
      await tester.pumpUntilFound(find.byKey(HomeKeys.dashboard));
      await tester.pumpSeconds(3);
      await show(tester, harness, Routes.PHARMACY);
    });

    testWidgets('the laboratory', (tester) async {
      await openAs(tester, WorldRole.labTechnician);
      await tester.pumpUntilFound(find.byKey(HomeKeys.dashboard));
      await tester.pumpSeconds(4);
    });

    testWidgets('the radiologist', (tester) async {
      await openAs(tester, WorldRole.radiologist);
      await tester.pumpUntilFound(find.byKey(HomeKeys.dashboard));
      await tester.pumpSeconds(4);
    });

    testWidgets('billing', (tester) async {
      await openAs(tester, WorldRole.billingStaff);
      await tester.pumpUntilFound(find.byKey(HomeKeys.dashboard));
      await tester.pumpSeconds(4);
    });

    testWidgets('the administrator', (tester) async {
      final harness = await openAs(tester, WorldRole.admin);

      await tester.pumpUntilFound(find.byKey(HomeKeys.dashboard));
      await tester.pumpSeconds(3);

      // The hub is where a scoped account's navigation actually lives — the
      // bar only has room for four.
      if (HomeController.to.hasMore) {
        await show(tester, harness, Routes.MORE);
      }
      await show(tester, harness, Routes.SETTINGS);
      await tester.pumpSeconds(3);
    });
  });
}
