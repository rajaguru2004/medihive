import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/keys/pharmacy_keys.dart';
import 'package:medihive/app/modules/pharmacy/controllers/pharmacy_controller.dart';
import 'package:medihive/app/routes/app_pages.dart';
import 'package:medihive/app/theme/theme.dart';

import '../support/pump.dart';
import 'robot.dart';

/// The pharmacy: the counter hub, a prescription, and the dispense that empties
/// it.
///
/// One robot for the module's five screens because they are five views of two
/// things — a drug and a prescription — and a drug named on the inventory row
/// has to be the same drug on the dispense line.
final class PharmacyRobot extends Robot {
  PharmacyRobot(super.harness);

  @override
  String? get route => Routes.PHARMACY;

  @override
  Key get anchor => PharmacyKeys.screen;

  // ── Getting there ─────────────────────────────────────────────────────────

  /// Opens the counter and waits for it to paint.
  ///
  /// `Get.toNamed` is fired and **not awaited**: its future completes when the
  /// route is *popped*, so awaiting it here waits for something this flow has
  /// not done yet and never returns.
  Future<void> openCounter() async {
    await requestCounter();
    await tester.pumpUntilFound(find.byKey(PharmacyKeys.screen));
    await settle();
  }

  /// Asks for the counter without assuming it opens.
  ///
  /// For the account that may not have it: the route guard sends them to the
  /// refusal screen instead, and a helper that waited for the counter's anchor
  /// would fail with a timeout rather than with the assertion the flow means.
  Future<void> requestCounter() async {
    unawaited(Get.toNamed<void>(Routes.PHARMACY) ?? Future<void>.value());
    await tester.pumpUntilRouteSettled();
  }

  Future<void> assertOnCounter() async {
    await assertVisible();
    seeNoErrorBanner();
  }

  /// Switches the counter between its three views.
  Future<void> showSegment(PharmacyCounter counter) async {
    await tester.tapKey(PharmacyKeys.segment(counter.name));
    await settle();
  }

  // ── A prescription ────────────────────────────────────────────────────────

  Future<void> openPrescription(String id) async {
    await tester.tapKey(PharmacyKeys.prescription(id));
    await tester.pumpUntilFound(find.byKey(PharmacyKeys.prescriptionScreen));
    await settle();
  }

  Future<void> assertOnPrescription() async {
    await tester.pumpUntilFound(find.byKey(PharmacyKeys.prescriptionScreen));
    seeNoErrorBanner();
  }

  /// The counter is offered the two things it can do with a live prescription.
  void seeDispenseOffered() {
    expect(
      find.byKey(PharmacyKeys.dispenseAction),
      findsOneWidget,
      reason: 'an account that may dispense should be offered it',
    );
    expect(find.byKey(PharmacyKeys.cancelAction), findsOneWidget);
  }

  /// Controls are **absent**, not disabled, for an account that may not write.
  void seeNoDispenseOffered() {
    expect(find.byKey(PharmacyKeys.dispenseAction), findsNothing);
    expect(find.byKey(PharmacyKeys.cancelAction), findsNothing);
  }

  // ── Dispensing ────────────────────────────────────────────────────────────

  Future<void> startDispense() async {
    await tester.tapKey(PharmacyKeys.dispenseAction);
    await tester.pumpUntilFound(find.byKey(PharmacyKeys.dispenseScreen));
    await settle();
  }

  Future<void> assertOnDispense() async {
    await tester.pumpUntilFound(find.byKey(PharmacyKeys.dispenseScreen));
    seeNoErrorBanner();
  }

  /// What one line is currently handing over, as the field reads it.
  ///
  /// Read off the `TextField`'s own controller rather than off a `Text`: the
  /// screen clamps what was typed, and the clamp is what this exists to catch.
  String dispenseQuantity(String drugId) {
    final field = find.byKey(PharmacyKeys.dispenseQuantity(drugId));
    expect(
      field,
      findsOneWidget,
      reason: 'no dispense line for $drugId',
    );
    return tester.widget<TextField>(field).controller?.text ?? '';
  }

  Future<void> setDispenseQuantity(String drugId, String quantity) async {
    final key = PharmacyKeys.dispenseQuantity(drugId);
    await tester.enterTextByKey(key, quantity);
    await tester.pump();
  }

  Future<void> confirmDispense() async {
    await tester.tapKeyWithoutKeyboard(PharmacyKeys.dispenseConfirm);
    await settle();
  }

  /// The counter was refused for stock, and the refusal says which drug.
  ///
  /// Inline rather than as a toast, and that is the assertion as much as the
  /// words are: the screen has just lowered the quantity it was refused over,
  /// and a message that vanishes in three seconds takes the explanation for
  /// that with it.
  void seeStockRefusal({required String naming}) {
    final banner = find.byKey(PharmacyKeys.dispenseError);
    expect(
      banner,
      findsOneWidget,
      reason: 'a refused dispense should say so on the screen',
    );
    expect(
      find.descendant(of: banner, matching: find.textContaining(naming)),
      findsOneWidget,
      reason: 'the refusal must name "$naming" — "that request was rejected" '
          'over a counter queue tells a pharmacist nothing they can act on',
    );
  }

  // ── The shelf ─────────────────────────────────────────────────────────────

  Future<void> searchShelf(String term) async {
    await tester.enterTextByKey(PharmacyKeys.inventorySearch, term);
    // The search field debounces, so the request is a few frames out.
    await tester.pumpUntil(
      () => PharmacyController.to.search.value.trim() == term.trim(),
      reason: 'the shelf never searched for "$term"',
    );
    await settle();
  }

  Future<void> filterShelfBy(String category) async {
    await tester.tapKey(PharmacyKeys.category(category));
    await settle();
  }

  /// The drugs on the shelf right now, in the order it lists them.
  ///
  /// The stock block inside each row carries a key with the same prefix, so it
  /// is excluded by name rather than by hoping the row is found first.
  List<String> drugIdsInOrder() => [
        for (final element in find
            .byWidgetPredicate(
              (widget) => _isDrugRowKey(widget.key),
              description: 'a keyed inventory row',
            )
            .evaluate())
          (element.widget.key! as ValueKey<String>)
              .value
              .substring(_drugKeyPrefix.length),
      ];

  static bool _isDrugRowKey(Key? key) {
    if (key is! ValueKey<String>) return false;
    return key.value.startsWith(_drugKeyPrefix) &&
        !key.value.startsWith(_drugStockKeyPrefix);
  }

  /// A shelf that needs attention is **amber, and never red**.
  ///
  /// Both halves matter and only the second is about safety. Red in this app
  /// means a patient is deteriorating; a box nobody reordered is somebody's
  /// afternoon, and a screen that paints it red costs every real red its
  /// meaning. Asserted on the resolved ink rather than on the token, because
  /// the token is walked toward the ground before it is drawn and it is the
  /// drawn colour a reader sees.
  Future<void> seeAmberStock(String drugId) async {
    final block = PharmacyKeys.drugStock(drugId);
    await tester.scrollToKey(block);

    final finder = find.byKey(block);
    expect(finder, findsOneWidget, reason: 'no inventory row for $drugId');

    final context = tester.element(finder);
    final amber = semanticInk(context, AppColors.warning);
    // `error` and `acuityCritical` are the same value by design — there is
    // one red in this app — so naming one of them covers both.
    final forbidden = <Color>{
      AppColors.error,
      semanticInk(context, AppColors.error),
    };

    final inks = tester
        .widgetList<Text>(
          find.descendant(of: finder, matching: find.byType(Text)),
        )
        .map((text) => text.style?.color)
        .toList();

    expect(
      inks,
      contains(amber),
      reason: '$drugId is low or empty, so something on its row should be '
          'amber',
    );
    for (final ink in inks) {
      expect(
        forbidden.contains(ink),
        isFalse,
        reason: '$drugId is a stock problem, not a deteriorating patient — '
            'red is reserved',
      );
    }

    // The bar is a fill, not a word, so it keeps the raw token.
    final bars = tester.widgetList<UsedBar>(
      find.descendant(of: finder, matching: find.byType(UsedBar)),
    );
    for (final bar in bars) {
      expect(bar.color, AppColors.warning);
    }
  }

  /// Today's receipts are on screen.
  void seeReceipts() => expect(find.byKey(PharmacyKeys.salesList), findsWidgets);

  static const String _drugKeyPrefix = 'pharmacy_drug_';
  static const String _drugStockKeyPrefix = 'pharmacy_drug_stock_';
}
