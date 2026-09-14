import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/core/keys/app_keys.dart';
import 'package:medihive/app/modules/appointments/appointment_routes.dart';
import 'package:medihive/app/modules/billing/billing_routes.dart';
import 'package:medihive/app/modules/case_review/case_review_routes.dart';
import 'package:medihive/app/modules/consultations/consultation_routes.dart';
import 'package:medihive/app/modules/home/controllers/home_controller.dart';
import 'package:medihive/app/modules/laboratory/laboratory_routes.dart';
import 'package:medihive/app/modules/patient_documents/patient_documents_routes.dart';
import 'package:medihive/app/modules/patient_portal/patient_portal_routes.dart';
import 'package:medihive/app/modules/patients/patient_routes.dart';
import 'package:medihive/app/modules/pharmacy/pharmacy_routes.dart';
import 'package:medihive/app/modules/radiology/radiology_routes.dart';
import 'package:medihive/app/modules/users/user_routes.dart';
import 'package:medihive/app/routes/app_pages.dart';
import 'package:medihive/app/theme/theme.dart';

import '../fixtures/world_roles.dart';
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

      // The shift bands and the charts are below the figures, so the top of
      // the board is the only part a contact sheet ever sees. A screen that is
      // never captured is a screen nobody looks at — which is how the More hub
      // shipped with no top padding.
      await tester.scrollToKey(ShiftKeys.band('waiting'));
      await shootBoth(tester, harness, '02b-today-bands');
      await tester.scrollToKey(ShiftKeys.appointmentChart);
      await shootBoth(tester, harness, '02c-today-charts');

      await harness.showTab(Routes.QUEUE);
      await shootBoth(tester, harness, '03-queue');

      await harness.showTab(Routes.APPOINTMENTS);
      await shootBoth(tester, harness, '04-clinic');

      await harness.showTab(Routes.INPATIENT);
      await shootBoth(tester, harness, '05-inpatient');
    });
  });

  // The shell is the one screen that is a *different screen* per account: its
  // navigation is resolved from the server's access map, so a nurse and a
  // receptionist get different bars out of the same build. A contact sheet
  // that only ever shows the account which can see everything is a contact
  // sheet of the one case this product never ships to.
  //
  // One test per role rather than one test walking four. Each role needs its
  // own boot — the access map is read from storage before the first frame —
  // and the surface conversion above is per *test*, so four boots inside one
  // test would convert once and photograph four screens correctly while a
  // fifth silently reused a stale surface.
  group('the shell, by role', () {
    for (final role in const [
      WorldRole.superAdmin,
      WorldRole.nurse,
      WorldRole.receptionist,
      WorldRole.labTechnician,
    ]) {
      testWidgets('as ${role.roleName}', (tester) async {
        final harness = await AppHarness.bootSignedIn(
          tester,
          role: role,
          fonts: true,
        );

        // Today is the one destination every account has, so it is the frame
        // in which the bars are actually comparable.
        await tester.pumpUntilFound(find.byKey(HomeKeys.dashboard));
        await shootBoth(tester, harness, '22-shell-${_slug(role)}');

        // Whatever did not fit on the bar — which for a scoped account is most
        // of their navigation, and is the half a bar-only screenshot hides.
        // Skipped where everything fit: there is no More slot then, and no
        // screen behind it to photograph.
        if (HomeController.to.hasMore) {
          await harness.showTab(Routes.MORE);
          await tester.pumpUntilFound(find.byKey(MoreKeys.screen));
          await shootBoth(tester, harness, '23-more-${_slug(role)}');
        }
      });
    }
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

      open(Routes.PATIENTS);
      await tester.pumpUntilFound(find.byKey(PatientsKeys.screen));
      await shootBoth(tester, harness, '20-patients');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();
    });
  });


  // ── The modules this release added ──────────────────────────────────────
  //
  // One test per family rather than one per screen: each boots the app, and a
  // boot is four seconds. Within a family the screens are pushed and popped in
  // the order somebody actually walks them, so a contact sheet reads as a
  // journey rather than as an alphabetical list of surfaces.

  group('records', () {
    testWidgets('the register and one record', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester, fonts: true);

      open(PatientRoutes.hub, arguments: {'id': 'p-2'});
      await tester.pumpUntilFound(find.byKey(PatientHubKeys.screen));
      await shootBoth(tester, harness, '24-patient-hub');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(PatientRoutes.form);
      await tester.pumpUntilFound(find.byKey(PatientFormKeys.screen));
      await shootBoth(tester, harness, '25-patient-form');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();
    });
  });

  group('the clinic', () {
    testWidgets('booking and writing one up', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester, fonts: true);

      open(AppointmentRoutes.detailFor('a-1'));
      await tester.pumpUntilFound(find.byKey(AppointmentDetailKeys.screen));
      await shootBoth(tester, harness, '26-appointment');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(AppointmentRoutes.form);
      await tester.pumpUntilFound(find.byKey(AppointmentFormKeys.screen));
      await shootBoth(tester, harness, '27-booking');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(ConsultationRoutes.form);
      await tester.pumpUntilFound(find.byKey(ConsultationFormKeys.screen));
      await shootBoth(tester, harness, '28-consultation-form');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();
    });
  });

  group('diagnostics', () {
    testWidgets('the bench and the reading room', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester, fonts: true);

      open(LabRoutes.worklist);
      await tester.pumpUntilFound(find.byKey(LaboratoryKeys.screen));
      await shootBoth(tester, harness, '29-laboratory');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(LabRoutes.catalog);
      await tester.pumpUntilFound(find.byKey(LabCatalogKeys.screen));
      await shootBoth(tester, harness, '30-lab-catalogue');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(RadiologyRoutes.worklist);
      await tester.pumpUntilFound(find.byKey(RadiologyKeys.screen));
      await shootBoth(tester, harness, '31-radiology');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();
    });
  });

  group('operations', () {
    testWidgets('the counter and the ledger', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester, fonts: true);

      open(PharmacyRoutes.hub);
      await tester.pumpUntilFound(find.byKey(PharmacyKeys.screen));
      await shootBoth(tester, harness, '32-pharmacy');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(BillingRoutes.list);
      await tester.pumpUntilFound(find.byKey(BillingKeys.screen));
      await shootBoth(tester, harness, '33-billing');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(BillingRoutes.invoice('inv-4'));
      await tester.pumpUntilFound(find.byKey(InvoiceDetailKeys.screen));
      await shootBoth(tester, harness, '34-invoice');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(BillingRoutes.invoiceNew);
      await tester.pumpUntilFound(find.byKey(InvoiceFormKeys.screen));
      await shootBoth(tester, harness, '35-invoice-form');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();
    });
  });

  group('administration', () {
    testWidgets('staff, roles and the settings hub', (tester) async {
      final harness = await AppHarness.bootSignedIn(tester, fonts: true);

      open(StaffRoutes.list);
      await tester.pumpUntilFound(find.byKey(StaffKeys.screen));
      await shootBoth(tester, harness, '36-staff');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(StaffRoutes.form);
      await tester.pumpUntilFound(find.byKey(UserFormKeys.screen));
      await shootBoth(tester, harness, '37-user-form');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(Routes.SETTINGS);
      await tester.pumpUntilFound(find.byKey(SettingsKeys.screen));
      await shootBoth(tester, harness, '38-settings');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(Routes.SETTINGS_LOCALE);
      await tester.pumpUntilFound(find.byKey(SettingsLocaleKeys.screen));
      await shootBoth(tester, harness, '39-locale');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(Routes.SETTINGS_MODULES);
      await tester.pumpUntilFound(find.byKey(SettingsModulesKeys.screen));
      await shootBoth(tester, harness, '40-modules');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(Routes.INTEGRATIONS);
      await tester.pumpUntilFound(find.byKey(IntegrationsKeys.screen));
      await shootBoth(tester, harness, '41-integrations');
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

      // Opened fresh in each mode rather than toggled with the sheet up.
      // `Get.bottomSheet` snapshots the theme at push time, so toggling behind
      // an open sheet captures a state no user can reach — and it is not what
      // this shot is for. Closed explicitly between the two: a sheet owns
      // tickers that `flutter_test` checks for at the end of the test *body*,
      // earlier than `addTearDown`.
      for (final mode in ['light', 'dark']) {
        if (mode == 'dark') await harness.useDarkTheme();
        await tester.tapKey(QueueKeys.advance('q-1'));
        await tester.pumpUntilFound(find.byType(SheetShell));
        await shoot(tester, '21-sheet-$mode');
        Get.back<void>();
        await tester.pumpUntilRouteSettled();
      }
      await harness.useLightTheme();
    });
  });

  // The patient's side of the app.
  //
  // These screens are the only ones in MediHive not read by somebody who uses
  // the app forty times a shift. They are read once, by a person who is
  // unwell, possibly frightened, and has never seen this software before — so
  // the contact sheet matters more here than anywhere else in the build. A
  // ward board that is slightly too dense costs a nurse a second; a consent
  // screen that is slightly too dense costs a patient their consent.
  group('patient', () {
    testWidgets('the way in', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        fonts: true,
        role: WorldRole.patient,
      );

      await tester.pumpUntilFound(find.byKey(PatientPortalKeys.dashboard));
      await shootBoth(tester, harness, '30-patient-dashboard');

      open(PatientPortalRoutes.language);
      await tester.pumpUntilFound(find.byKey(PatientPortalKeys.language));
      await shootBoth(tester, harness, '31-patient-language');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(PatientPortalRoutes.consent);
      await tester.pumpUntilFound(find.byKey(PatientPortalKeys.consent));
      await shootBoth(tester, harness, '32-patient-consent');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();
    });

    testWidgets('claiming a record', (tester) async {
      final harness = await AppHarness.bootSignedOut(tester, fonts: true);

      open(PatientPortalRoutes.claim);
      await tester.pumpUntilFound(find.byKey(PatientPortalKeys.claim));
      await shootBoth(tester, harness, '33-patient-claim');
    });

    testWidgets('the interview', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        fonts: true,
        role: WorldRole.patient,
      );

      open(PatientPortalRoutes.caseTaking);
      await tester.pumpUntilFound(find.byKey(CaseTakingKeys.screen));
      await tester.pumpUntilFound(find.byKey(CaseTakingKeys.question));
      await shootBoth(tester, harness, '34-patient-interview');
    });

    testWidgets('documents and the case read back', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        fonts: true,
        role: WorldRole.patient,
      );

      open(PatientDocumentsRoutes.list);
      await tester.pumpUntilFound(find.byKey(PatientDocumentsKeys.screen));
      await shootBoth(tester, harness, '35-patient-documents');
      Get.back<void>();
      await tester.pumpUntilRouteSettled();

      open(CaseReviewRoutes.review);
      await tester.pumpUntilFound(find.byKey(CaseReviewKeys.screen));
      await shootBoth(tester, harness, '36-patient-case-review');
    });
  });
}

/// `LAB_TECHNICIAN` → `lab-technician`.
///
/// The server's own role name rather than the enum constant, so a reviewer
/// reading a filename is reading the thing an administrator would have picked
/// in the console.
String _slug(WorldRole role) =>
    role.roleName.toLowerCase().replaceAll('_', '-');
