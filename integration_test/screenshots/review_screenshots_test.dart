import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/core/keys/app_keys.dart';
import 'package:medihive/app/routes/app_pages.dart';

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

  /// Lets the device settle, then captures.
  ///
  /// The delay is not superstition: `convertFlutterSurfaceToImage` needs a
  /// frame in which nothing is animating, and a capture taken mid-transition
  /// is a blurred half-screen.
  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pumpUntilRouteSettled();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpUntil(
      () => tester.binding.transientCallbackCount == 0,
      reason: 'the tree was still animating at capture time',
    );
    await tester.pump(const Duration(milliseconds: 120));
    await binding.takeScreenshot(name);
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

      await Get.toNamed<void>(Routes.INPATIENT_BEDS_GRID);
      await tester.pumpUntilFound(find.byKey(InpatientKeys.beds));
      await shootBoth(tester, harness, '06-bed-map');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      await Get.toNamed<void>(Routes.INPATIENT_WARDS);
      await tester.pumpUntilFound(find.byKey(InpatientKeys.wards));
      await shootBoth(tester, harness, '07-wards');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      await Get.toNamed<void>(Routes.INPATIENT_ADMISSIONS);
      await tester.pumpUntilFound(find.byKey(InpatientKeys.admissions));
      await shootBoth(tester, harness, '08-admissions');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      await Get.toNamed<void>(Routes.INPATIENT_OVERVIEW);
      await tester.pumpUntilRouteSettled();
      await shootBoth(tester, harness, '09-ward-round');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();
    });

    testWidgets('admit and discharge forms', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester, fonts: true);

      await Get.toNamed<void>(Routes.INPATIENT_ADMIT);
      await tester.pumpUntilFound(find.byKey(AdmitPatientKeys.screen));
      await shootBoth(tester, harness, '10-admit');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      await Get.toNamed<void>(
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

      await Get.toNamed<void>(Routes.INPATIENT_ADD_WARD);
      await tester.pumpUntilFound(find.byKey(InpatientKeys.wardForm));
      await shootBoth(tester, harness, '12-add-ward');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      await Get.toNamed<void>(Routes.INPATIENT_ADD_BED);
      await tester.pumpUntilFound(find.byKey(InpatientKeys.bedForm));
      await shootBoth(tester, harness, '13-add-bed');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();
    });
  });

  group('pre-triage', () {
    testWidgets('board, detail and the two-step form', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester, fonts: true);

      await Get.toNamed<void>(Routes.PRE_TRIAGE);
      await tester.pumpUntilFound(find.byKey(PreTriageKeys.screen));
      await shootBoth(tester, harness, '14-pre-triage');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      // The screening with the alarming observations, so the out-of-range
      // treatment is in the contact sheet.
      await Get.toNamed<void>(
        Routes.PRE_TRIAGE_DETAILS,
        arguments: {'id': 's-1'},
      );
      await tester.pumpUntilFound(find.byKey(PreTriageKeys.detail));
      await shootBoth(tester, harness, '15-screening-detail');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      await Get.toNamed<void>(Routes.NEW_SCREENING_STEP1);
      await tester.pumpUntilFound(find.byKey(ScreeningKeys.step1));
      await shootBoth(tester, harness, '16-screening-step1');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      await Get.toNamed<void>(
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

      await Get.toNamed<void>(Routes.ADD_TO_QUEUE);
      await tester.pumpUntilFound(find.byKey(AddToQueueKeys.screen));
      await shootBoth(tester, harness, '18-add-to-queue');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      await Get.toNamed<void>(Routes.CONSULTATIONS);
      await tester.pumpUntilFound(find.byKey(ConsultationsKeys.screen));
      await shootBoth(tester, harness, '19-consultations');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      await Get.toNamed<void>(Routes.PHARMACY);
      await tester.pumpUntilFound(
        find.byKey(PlaceholderKeys.screen('pharmacy')),
      );
      await shootBoth(tester, harness, '20-placeholder');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();
    });
  });
}
