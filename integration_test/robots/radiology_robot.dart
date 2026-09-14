import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/keys/no_access_keys.dart';
import 'package:medihive/app/core/keys/radiology_keys.dart';
import 'package:medihive/app/modules/radiology/radiology_routes.dart';
import 'package:medihive/app/modules/radiology/views/radiology_shared.dart';
import 'package:medihive/app/routes/app_pages.dart';
import 'package:medihive/app/theme/theme.dart';

import '../support/pump.dart';
import 'robot.dart';

/// Imaging: the worklist, one order, the read, and the catalogue.
///
/// One robot for six screens because `RadiologyKeys` is one file for six, and
/// for the same reason — they are views of one study, and an order named on
/// the worklist has to be the same order on the detail and the same order on
/// the report.
final class RadiologyRobot extends Robot {
  RadiologyRobot(super.harness);

  /// Spans screens, so no single route identifies it. [assertOnWorklist] and
  /// the other `assertOn…` methods check the one they are about.
  @override
  String? get route => null;

  @override
  Key get anchor => RadiologyKeys.screen;

  // ── Getting there ─────────────────────────────────────────────────────────

  /// Opens the worklist as its own route.
  ///
  /// `Get.toNamed` is fired and **not awaited**: its future completes when the
  /// route is *popped*, so awaiting it here waits for something this flow has
  /// not done yet and never returns.
  Future<void> openWorklist() async {
    unawaited(
      Get.toNamed<void>(RadiologyRoutes.worklist) ?? Future<void>.value(),
    );
    await tester.pumpUntilRouteSettled();
  }

  Future<void> assertOnWorklist() async {
    await tester.pumpUntilFound(find.byKey(RadiologyKeys.screen));
    seeNoErrorBanner();
  }

  /// Opens the report form directly, for a report that already exists.
  ///
  /// A deep link rather than a walk through the detail screen: this is how the
  /// amendment rule is reached without first asserting six other things.
  Future<void> openReportForEditing(String reportId, {String? orderId}) async {
    unawaited(
      Get.toNamed<void>(
            RadiologyRoutes.reportEdit,
            arguments: {'reportId': reportId, 'orderId': ?orderId},
          ) ??
          Future<void>.value(),
    );
    await tester.pumpUntilFound(find.byKey(RadiologyKeys.reportForm));
    await settle();
  }

  // ── The worklist ──────────────────────────────────────────────────────────

  /// The red banner over the worklist. Present only when a read has found
  /// something, which is the whole assertion — an empty one would be a red
  /// that has been taught to mean nothing.
  void seeCriticalBanner({String? containing}) {
    expect(
      find.byKey(RadiologyKeys.critical),
      findsOneWidget,
      reason: 'expected the critical-findings banner',
    );
    if (containing != null) {
      expect(
        find.descendant(
          of: find.byKey(RadiologyKeys.critical),
          matching: find.textContaining(containing),
        ),
        findsOneWidget,
        reason: 'the critical banner should mention "$containing"',
      );
    }
  }

  void seeNoCriticalBanner() => expect(
        find.byKey(RadiologyKeys.critical),
        findsNothing,
        reason: 'nothing is critical, so there should be no banner at all',
      );

  void seeFigures() =>
      expect(find.byKey(RadiologyKeys.stats), findsOneWidget);

  void seeOrder(String id) => expect(
        find.byKey(RadiologyKeys.order(id)),
        findsOneWidget,
        reason: 'expected order $id on the worklist',
      );

  void seeNoOrder(String id) =>
      expect(find.byKey(RadiologyKeys.order(id)), findsNothing);

  /// How many orders the worklist is showing.
  ///
  /// By widget type, not by key prefix: `radiology_order_` also opens every
  /// key on the order form and the detail — `radiology_order_patient`,
  /// `radiology_order_timeline` — so a prefix count would report rows on a
  /// screen that has none.
  int get orderCount =>
      find.byType(RadiologyOrderRow).evaluate().length;

  Future<void> filterByStatus(String status) async {
    await tester.tapKey(RadiologyKeys.statusFilter(status));
    await settle();
  }

  Future<void> filterByUrgency(String urgency) async {
    await tester.tapKey(RadiologyKeys.urgencyFilter(urgency));
    await settle();
  }

  /// "This account is offered the one write this screen has."
  void seeNewOrderAction() => expect(
        find.byKey(RadiologyKeys.newOrder),
        findsWidgets,
        reason: 'this role should be able to raise an imaging request',
      );

  void seeNoNewOrderAction() => expect(
        find.byKey(RadiologyKeys.newOrder),
        findsNothing,
        reason: 'a control this account cannot use must be absent, not '
            'disabled',
      );

  Future<void> tapNewOrder() async {
    await tester.tapKey(RadiologyKeys.newOrder);
    await tester.pumpUntilFound(find.byKey(RadiologyKeys.orderForm));
    await settle();
  }

  Future<void> openOrder(String id) async {
    await tester.tapKey(RadiologyKeys.order(id));
    await tester.pumpUntilFound(find.byKey(RadiologyKeys.orderDetail));
    await settle();
  }

  // ── The order form ────────────────────────────────────────────────────────

  Future<void> assertOnOrderForm() async {
    await tester.pumpUntilFound(find.byKey(RadiologyKeys.orderForm));
    expect(Get.currentRoute, RadiologyRoutes.orderNew);
  }

  /// Chooses a patient through the picker's own sheet.
  Future<void> choosePatient(String name) async {
    await tester.tapKeyWithoutKeyboard(RadiologyKeys.orderPatient);
    await settle();
    await pickFromSheet(name);
  }

  /// Chooses an exam from the grouped catalogue sheet. [name] is the row's
  /// own label, which is the exam's display name.
  Future<void> chooseExam(String name) async {
    await tester.tapKeyWithoutKeyboard(RadiologyKeys.orderExam);
    await settle();
    await pickFromSheet(name);
  }

  Future<void> chooseUrgency(String urgency) async {
    await tester.tapKey(RadiologyKeys.orderUrgencyOption(urgency));
    await tester.pump();
  }

  Future<void> enterIndication(String text) =>
      tester.enterTextByKey(RadiologyKeys.orderIndication, text);

  /// The banner a contrast study raises. It changes how the patient is
  /// prepared, so its presence is the assertion.
  void seeContrastNotice() => expect(
        find.byKey(RadiologyKeys.orderContrast),
        findsOneWidget,
        reason: 'a contrast study must say so on the request form',
      );

  void seeNoContrastNotice() =>
      expect(find.byKey(RadiologyKeys.orderContrast), findsNothing);

  Future<void> submitOrder() async {
    await tester.tapKeyWithoutKeyboard(RadiologyKeys.orderSubmit);
    await settle();
  }

  // ── One order ─────────────────────────────────────────────────────────────

  Future<void> assertOnOrderDetail() async {
    await tester.pumpUntilFound(find.byKey(RadiologyKeys.orderDetail));
    expect(
      Get.currentRoute.startsWith('/radiology/orders/'),
      isTrue,
      reason: 'the order detail rendered but the route is ${Get.currentRoute}',
    );
  }

  void seeAction(Key key) => expect(
        find.byKey(key),
        findsOneWidget,
        reason: 'expected the action keyed $key on this order',
      );

  void seeNoAction(Key key) => expect(
        find.byKey(key),
        findsNothing,
        reason: 'the action keyed $key should be absent on this order',
      );

  void seeTimeline() =>
      expect(find.byKey(RadiologyKeys.orderTimeline), findsOneWidget);

  /// Schedules the study for today through the date sheet.
  Future<void> scheduleForToday() async {
    await tester.tapKey(RadiologyKeys.actionSchedule);
    await tester.pumpUntilFound(find.byKey(RadiologyKeys.scheduleDate));
    await pickDate(RadiologyKeys.scheduleDate);
    await tester.tapKeyWithoutKeyboard(RadiologyKeys.scheduleConfirm);
    await tester.pumpUntilGone(find.byKey(RadiologyKeys.scheduleConfirm));
    await settle();
  }

  Future<void> startStudy() async {
    await tester.tapKey(RadiologyKeys.actionStart);
    await settle();
  }

  Future<void> markPerformed() async {
    await tester.tapKey(RadiologyKeys.actionPerformed);
    await settle();
  }

  /// Cancels the order with a reason, which this screen requires even though
  /// the server does not.
  Future<void> cancelBecause(String reason) async {
    await tester.tapKey(RadiologyKeys.actionCancel);
    await tester.pumpUntilFound(find.byKey(RadiologyKeys.cancelReason));
    await tester.enterTextByKey(RadiologyKeys.cancelReason, reason);
    await tester.tapKeyWithoutKeyboard(RadiologyKeys.cancelConfirm);
    await tester.pumpUntilGone(find.byKey(RadiologyKeys.cancelConfirm));
    await settle();
  }

  Future<void> openReportForm() async {
    await tester.tapKey(RadiologyKeys.actionReport);
    await tester.pumpUntilFound(find.byKey(RadiologyKeys.reportForm));
    await settle();
  }

  Future<void> uploadImage() async {
    await tester.tapKey(RadiologyKeys.actionUpload);
    await settle();
  }

  void seeImages() => expect(
        find.byKey(RadiologyKeys.images),
        findsOneWidget,
        reason: 'the study should show the images attached to its report',
      );

  void seeImage(String url) =>
      expect(find.byKey(RadiologyKeys.image(url)), findsOneWidget);

  // ── The read ──────────────────────────────────────────────────────────────

  Future<void> assertOnReportForm() async {
    await tester.pumpUntilFound(find.byKey(RadiologyKeys.reportForm));
  }

  /// The three fields every read needs.
  Future<void> writeRead({
    required String technique,
    required String findings,
    required String impression,
  }) async {
    await tester.enterTextByKey(RadiologyKeys.reportTechnique, technique);
    await tester.enterTextByKey(RadiologyKeys.reportFindings, findings);
    await tester.enterTextByKey(RadiologyKeys.reportImpression, impression);
  }

  Future<void> turnOnCriticalFindings() async {
    await tester.tapKeyWithoutKeyboard(RadiologyKeys.reportCritical);
    await tester.pumpUntilFound(find.byKey(RadiologyKeys.reportCriticalText));
  }

  Future<void> enterCriticalFinding(String text) =>
      tester.enterTextByKey(RadiologyKeys.reportCriticalText, text);

  Future<void> enterNotifiedTo(String name) =>
      tester.enterTextByKey(RadiologyKeys.reportNotifiedTo, name);

  Future<void> enterAmendmentReason(String reason) =>
      tester.enterTextByKey(RadiologyKeys.reportAmendment, reason);

  Future<void> chooseReportStatus(String status) async {
    await tester.tapKeyWithoutKeyboard(
      RadiologyKeys.reportStatusOption(status),
    );
    await tester.pump();
  }

  /// The amendment field is on screen only for a report that has been signed.
  void seeAmendmentField() => expect(
        find.byKey(RadiologyKeys.reportAmendment),
        findsOneWidget,
        reason: 'a signed report must ask why it is being changed',
      );

  void seeNoAmendmentField() =>
      expect(find.byKey(RadiologyKeys.reportAmendment), findsNothing);

  Future<void> saveReport() async {
    await tester.tapKeyWithoutKeyboard(RadiologyKeys.reportSave);
    await settle();
  }

  /// "The form refused, and said how many fields it refused over."
  ///
  /// The count rather than the field, because the field being complained about
  /// is usually several screens up — which is the whole reason the summary sits
  /// above the save bar.
  void seeFieldErrorSummary() => expect(
        find.byType(FieldErrorSummary),
        findsOneWidget,
        reason: 'a refused save must say so above the button that refused',
      );

  void seeNoFieldErrorSummary() =>
      expect(find.byType(FieldErrorSummary), findsNothing);

  // ── The catalogue ─────────────────────────────────────────────────────────

  Future<void> openCatalog() async {
    unawaited(
      Get.toNamed<void>(RadiologyRoutes.catalog) ?? Future<void>.value(),
    );
    await tester.pumpUntilFound(find.byKey(RadiologyKeys.catalog));
    await settle();
  }

  void seeExam(String id) =>
      expect(find.byKey(RadiologyKeys.exam(id)), findsOneWidget);

  Future<void> openExam(String id) async {
    await tester.tapKey(RadiologyKeys.exam(id));
    await tester.pumpUntilFound(find.byKey(RadiologyKeys.examForm));
    await settle();
  }

  Future<void> tapAddExam() async {
    await tester.tapKey(RadiologyKeys.catalogAdd);
    await tester.pumpUntilFound(find.byKey(RadiologyKeys.examForm));
    await settle();
  }

  Future<void> saveExam() async {
    await tester.tapKeyWithoutKeyboard(RadiologyKeys.examSave);
    await settle();
  }

  // ── Refusal ───────────────────────────────────────────────────────────────

  /// "This account got a locked state rather than a worklist."
  ///
  /// Either of the app's two locked states counts, and the flow should not
  /// have to know which: the route guard turns an ungranted module into the
  /// shared no-access screen, and a grant withdrawn mid-session lands on the
  /// worklist's own panel instead. What must be true in both is that no
  /// imaging order is on screen.
  Future<void> assertNoAccess() async {
    await tester.pumpUntil(
      () =>
          find.byKey(NoAccessKeys.screen).evaluate().isNotEmpty ||
          find.byKey(RadiologyKeys.locked).evaluate().isNotEmpty,
      reason: 'expected a locked state; the route is ${Get.currentRoute}',
    );
    expect(
      orderCount,
      0,
      reason: 'a refused account must not be shown a single imaging order',
    );
    seeNoErrorBanner();
  }

  /// The guard sent them to the shared refusal rather than to the worklist.
  void seeGuardRefusal() {
    expect(find.byKey(NoAccessKeys.screen), findsOneWidget);
    expect(Get.currentRoute, Routes.NO_ACCESS);
  }
}
