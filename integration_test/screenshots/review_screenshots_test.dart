import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/core/keys/app_keys.dart';
import 'package:medihive/app/modules/home/controllers/home_controller.dart';
import 'package:medihive/app/routes/app_pages.dart';
import 'package:medihive/app/theme/theme.dart';

import '../support/app_harness.dart';
import '../support/pump.dart';

/// Captures the app's screens for a design pass.
///
/// Every screen worth looking at, in both themes, from the same fixtures the
/// flow suite uses — so a screenshot is a picture of the app under known data,
/// not a picture of whatever the server happened to hold that morning.
///
/// Fonts are loaded (`fonts: true`): without that the test font draws every
/// character as a filled box and the output is worthless for review.
///
/// ```sh
/// flutter drive \
///   --driver=test_driver/screenshot_driver.dart \
///   --target=integration_test/screenshots/review_screenshots_test.dart \
///   -d emulator-5554
/// ```
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // `convertFlutterSurfaceToImage` swaps the Android surface for one that can
  // be read back. It asserts if called twice, and the binding reverts it in
  // its own tear-down — so the right granularity is once per *test*, and both
  // halves of that are load-bearing: converting twice in one test throws
  // "Surface already converted", and assuming it survives into the next test
  // throws "Call convertFlutterSurfaceToImage() before taking a screenshot".
  var surfaceConverted = false;
  setUp(() => surfaceConverted = false);

  /// Lets the device settle, then captures.
  ///
  /// The pause before the capture is not superstition: the readback needs a
  /// frame in which nothing is animating, and a capture taken mid-transition
  /// is a blurred half-screen.
  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pumpUntilRouteSettled();
    if (!surfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      surfaceConverted = true;
    }
    await tester.pumpUntil(
      () => tester.binding.transientCallbackCount == 0,
      reason: 'the tree was still animating at capture time',
    );
    await tester.pump(const Duration(milliseconds: 120));
    await binding.takeScreenshot(name);
  }

  /// Pushes a route without waiting for it to be popped.
  ///
  /// `Get.toNamed` returns a future that completes when the route comes *off*
  /// the stack. Awaiting it in a test that only wants to photograph the screen
  /// blocks forever — the screen is never popped until the next line runs, and
  /// the next line is what is being awaited. The same trap is commented in
  /// `SessionManager.endSession`.
  void open(String route, {Object? arguments}) {
    unawaited(
      Get.toNamed<void>(route, arguments: arguments) ?? Future<void>.value(),
    );
  }

  /// Captures one screen in both themes, then restores light.
  ///
  /// Both, always: the palette derives its inks per mode, and a world that is
  /// only ever reviewed in one of them ships with the other broken.
  Future<void> shootBoth(
    WidgetTester tester,
    AppHarness harness,
    String name,
  ) async {
    await shoot(tester, '$name-light');
    await harness.useDarkTheme();
    await shoot(tester, '$name-dark');
    await harness.useLightTheme();
  }

  group('auth', () {
    testWidgets('sign-in', (tester) async {
      final harness = await AppHarness.bootSignedOut(tester, fonts: true);
      await tester.pumpUntilFound(find.byKey(LoginKeys.screen));
      await shootBoth(tester, harness, '01-signin');
    });
  });

  group('shell', () {
    testWidgets('the four tabs', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester, fonts: true);

      await tester.pumpUntilFound(find.byKey(HomeKeys.dashboard));
      await shootBoth(tester, harness, '02-today');

      await harness.showTab(Routes.QUEUE);
      await shootBoth(tester, harness, '03-queue');

      await harness.showTab(Routes.APPOINTMENTS);
      await shootBoth(tester, harness, '04-clinic');

      await harness.showTab(Routes.INPATIENT);
      await shootBoth(tester, harness, '05-inpatient');
    });
  });

  group('inpatient', () {
    testWidgets('bed map, wards, admissions and ward round', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester, fonts: true);

      open(Routes.INPATIENT_BEDS_GRID);
      await tester.pumpUntilFound(find.byKey(InpatientKeys.beds));
      await shootBoth(tester, harness, '06-bed-map');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(Routes.INPATIENT_WARDS);
      await tester.pumpUntilFound(find.byKey(InpatientKeys.wards));
      await shootBoth(tester, harness, '07-wards');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(Routes.INPATIENT_ADMISSIONS);
      await tester.pumpUntilFound(find.byKey(InpatientKeys.admissions));
      await shootBoth(tester, harness, '08-admissions');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(Routes.INPATIENT_OVERVIEW);
      await tester.pumpUntilRouteSettled();
      await shootBoth(tester, harness, '09-ward-round');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();
    });

    testWidgets('admit and discharge forms', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester, fonts: true);

      open(Routes.INPATIENT_ADMIT);
      await tester.pumpUntilFound(find.byKey(AdmitPatientKeys.screen));
      await shootBoth(tester, harness, '10-admit');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(
        Routes.DISCHARGE_PATIENT,
        arguments: {'admissionId': 'adm-1'},
      );
      await tester.pumpUntilFound(find.byKey(DischargePatientKeys.screen));
      await shootBoth(tester, harness, '11-discharge');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();
    });

    testWidgets('ward and bed forms', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester, fonts: true);

      open(Routes.INPATIENT_ADD_WARD);
      await tester.pumpUntilFound(find.byKey(InpatientKeys.wardForm));
      await shootBoth(tester, harness, '12-add-ward');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(Routes.INPATIENT_ADD_BED);
      await tester.pumpUntilFound(find.byKey(InpatientKeys.bedForm));
      await shootBoth(tester, harness, '13-add-bed');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();
    });
  });

  group('pre-triage', () {
    testWidgets('board, detail and the two-step form', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester, fonts: true);

      open(Routes.PRE_TRIAGE);
      await tester.pumpUntilFound(find.byKey(PreTriageKeys.screen));
      await shootBoth(tester, harness, '14-pre-triage');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      // The screening with the alarming observations, so the out-of-range
      // treatment is in the contact sheet.
      open(
        Routes.PRE_TRIAGE_DETAILS,
        arguments: {'id': 's-1'},
      );
      await tester.pumpUntilFound(find.byKey(PreTriageKeys.detail));
      await shootBoth(tester, harness, '15-screening-detail');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(Routes.NEW_SCREENING_STEP1);
      await tester.pumpUntilFound(find.byKey(ScreeningKeys.step1));
      await shootBoth(tester, harness, '16-screening-step1');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(
        Routes.NEW_SCREENING_STEP2,
        arguments: {
          'firstName': 'Tom',
          'lastName': 'Whitfield',
          'age': 67,
          'gender': 'Male',
          'phone': '',
        },
      );
      await tester.pumpUntilFound(find.byKey(ScreeningKeys.step2));
      await shootBoth(tester, harness, '17-screening-step2');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();
    });
  });

  group('the rest', () {
    testWidgets('queue entry, consultations and a placeholder',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(tester, fonts: true);

      open(Routes.ADD_TO_QUEUE);
      await tester.pumpUntilFound(find.byKey(AddToQueueKeys.screen));
      await shootBoth(tester, harness, '18-add-to-queue');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(Routes.CONSULTATIONS);
      await tester.pumpUntilFound(find.byKey(ConsultationsKeys.screen));
      await shootBoth(tester, harness, '19-consultations');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(Routes.PHARMACY);
      await tester.pumpUntilFound(
        find.byKey(PlaceholderKeys.screen('pharmacy')),
      );
      await shootBoth(tester, harness, '20-placeholder');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();
    });
  });

  group('sheets', () {
    // Sheets were the one surface this contact sheet did not cover, and that
    // is exactly where a defect hid: `Get.bottomSheet` ignores
    // `ThemeData.bottomSheetTheme`, so every sheet in the app rendered with no
    // surface behind it until `SheetShell` started painting its own. A screen
    // that is never captured is a screen nobody looks at.
    testWidgets('the queue actions sheet', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester, fonts: true);

      HomeController.to.selectRoute(Routes.QUEUE);
      await tester.pumpUntilRouteSettled();

      await tester.tapKey(QueueKeys.advance('q-1'));
      await tester.pumpUntilFound(find.byType(SheetShell));
      await shootBoth(tester, harness, '21-sheet');

      // Closed explicitly: a sheet owns tickers that `flutter_test` checks for
      // at the end of the test *body*, earlier than `addTearDown`.
      Get.back<void>();
      await tester.pumpUntilRouteSettled();
    });
  });
}
