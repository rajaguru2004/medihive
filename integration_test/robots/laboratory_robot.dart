import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/keys/laboratory_keys.dart';
import 'package:medihive/app/modules/laboratory/laboratory_routes.dart';
import 'package:medihive/app/theme/theme.dart';

import '../support/pump.dart';
import 'robot.dart';

/// The laboratory: the worklist, one order, a result and the catalogue.
///
/// One robot across the six screens rather than six, because every flow worth
/// writing here crosses them — an order is raised on one, collected on
/// another and resulted on a third, and a robot per screen would make the
/// chain read as four objects passing a string between them.
final class LaboratoryRobot extends Robot {
  LaboratoryRobot(super.harness);

  @override
  String? get route => LabRoutes.worklist;

  @override
  Key get anchor => LaboratoryKeys.screen;

  static const _rowPrefix = 'laboratory_row_';

  // ── Getting there ─────────────────────────────────────────────────────────

  /// Opens the worklist by route.
  ///
  /// Never awaited: `Get.toNamed` completes when the route is *popped*, so
  /// awaiting it here would wait for the end of the test.
  Future<void> open() async {
    unawaited(Get.toNamed<void>(LabRoutes.worklist));
    await tester.pumpUntilRouteSettled();
  }

  Future<void> assertOnWorklist() async {
    await assertVisible();
    seeNoErrorBanner();
  }

  /// The state a 403 on the list route leaves behind: no rows, no retry, and a
  /// sentence naming the only thing that can fix it.
  void seeLockedList() {
    expect(find.text('Not available to your role'), findsOneWidget);
    seeNoErrorBanner();
  }

  // ── The worklist ──────────────────────────────────────────────────────────

  /// The rows on the worklist, top to bottom.
  ///
  /// Read off the render tree rather than out of the controller: a sort that
  /// only happens in a list nobody paints is the same bug wearing a passing
  /// test.
  List<String> rowIdsInOrder() {
    final rows = <({double top, String id})>[
      for (final element in _rowElements)
        (
          top: (element.renderObject! as RenderBox)
              .localToGlobal(Offset.zero)
              .dy,
          id: _idOf(element.widget.key!),
        ),
    ]..sort((a, b) => a.top.compareTo(b.top));
    return [for (final row in rows) row.id];
  }

  void seeRow(String id) =>
      expect(find.byKey(LaboratoryKeys.row(id)), findsOneWidget);

  /// One figure from the stats header, by its label.
  ///
  /// The `Figure` itself rather than the pixels it produces: the colour on it
  /// is exactly what decides whether the cell is painted in the app's one
  /// alarm colour, and reading it here is what lets a flow assert that a zero
  /// is *not*.
  Figure figure(String label) => tester
      .widget<FigureGrid>(find.byKey(LaboratoryKeys.stats))
      .figures
      .firstWhere(
        (figure) => figure.label == label,
        orElse: () => throw StateError('no "$label" figure on the header'),
      );

  /// A word on one worklist row — a status pill, a priority, "Critical".
  void seeOnRow(String id, String text) => expect(
        find.descendant(
          of: find.byKey(LaboratoryKeys.row(id)),
          matching: find.text(text),
        ),
        findsOneWidget,
        reason: 'row $id should say "$text"',
      );

  Future<void> searchWorklist(String term) async {
    await tester.enterTextByKey(LaboratoryKeys.search, term);
    // Past `SearchField`'s own debounce, then the request it fires.
    await tester.pump(const Duration(milliseconds: 400));
    await settle();
  }

  Future<void> filterByStatus(String status) async {
    await tester.tapKey(LaboratoryKeys.filterOption('status', status));
    await settle();
  }

  Future<void> filterByPriority(String priority) async {
    await tester.tapKey(LaboratoryKeys.filterOption('priority', priority));
    await settle();
  }

  void seeNewOrderAction() =>
      expect(find.byKey(LaboratoryKeys.createOrder), findsOneWidget);

  void seeNoNewOrderAction() =>
      expect(find.byKey(LaboratoryKeys.createOrder), findsNothing);

  Future<void> openOrder(String id) async {
    await tester.tapKey(LaboratoryKeys.row(id));
    await tester.pumpUntilRouteSettled();
  }

  Future<void> startNewOrder() async {
    await tester.tapKey(LaboratoryKeys.createOrder);
    await tester.pumpUntilRouteSettled();
  }

  Future<void> openCatalogue() async {
    await tester.tapKey(LaboratoryKeys.openCatalog);
    await tester.pumpUntilRouteSettled();
  }

  // ── Raising an order ──────────────────────────────────────────────────────

  Future<void> assertOnOrderForm() async {
    await tester.pumpUntilFound(find.byKey(LaboratoryKeys.orderFormScreen));
  }

  /// Picks a patient through the searching picker.
  Future<void> choosePatient(String name) async {
    await tester.tapKeyWithoutKeyboard(LaboratoryKeys.orderPatient);
    await tester.pumpUntilRouteSettled();
    await pickFromSheet(name);
  }

  /// Ticks [testIds] in the catalogue sheet and closes it.
  Future<void> addTests(List<String> testIds) async {
    await tester.tapKeyWithoutKeyboard(LaboratoryKeys.orderAddTests);
    await tester.pumpUntilRouteSettled();
    for (final id in testIds) {
      await tester.tapKey(LaboratoryKeys.catalogPick(id));
    }
    await tester.tapKey(LaboratoryKeys.catalogPickDone);
    await tester.pumpUntilRouteSettled();
  }

  Future<void> setOrderPriority(String priority) async {
    await tester.tapKeyWithoutKeyboard(LaboratoryKeys.orderPriority(priority));
    await tester.pump();
  }

  Future<void> setTestUrgency(String testId, String urgency) async {
    await tester
        .tapKeyWithoutKeyboard(LaboratoryKeys.orderTestUrgency(testId, urgency));
    await tester.pump();
  }

  Future<void> typeIndication(String text) =>
      tester.enterTextByKey(LaboratoryKeys.orderIndication, text);

  Future<void> submitOrder() async {
    await tester.tapKeyWithoutKeyboard(LaboratoryKeys.orderSubmit);
    await tester.pumpUntilRouteSettled();
  }

  // ── One order ─────────────────────────────────────────────────────────────

  Future<void> assertOnOrder() async {
    await tester.pumpUntilFound(find.byKey(LaboratoryKeys.orderDetailScreen));
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'the order is still loading',
    );
  }

  /// The status pill on the record header.
  void seeOrderStatus(String label) => expect(
        find.descendant(
          of: find.byType(RecordHeader),
          matching: find.text(label),
        ),
        findsOneWidget,
        reason: 'the order header should read "$label"',
      );

  void seeCollectAction() =>
      expect(find.byKey(LaboratoryKeys.collectSample), findsOneWidget);

  void seeNoCollectAction() =>
      expect(find.byKey(LaboratoryKeys.collectSample), findsNothing);

  void seeNoVerifyAction(String resultId) => expect(
        find.byKey(LaboratoryKeys.verifyResult(resultId)),
        findsNothing,
      );

  /// The banner a critical result raises, and the words on it.
  void seeCriticalBanner() {
    expect(
      find.byKey(LaboratoryKeys.criticalBanner),
      findsOneWidget,
      reason: 'a critical result must raise a banner, not only tint a figure',
    );
    expect(
      find.descendant(
        of: find.byKey(LaboratoryKeys.criticalBanner),
        matching: find.textContaining('Critical'),
      ),
      findsOneWidget,
      reason: 'the banner has to carry the word, not only the colour',
    );
  }

  void seeNoCriticalBanner() =>
      expect(find.byKey(LaboratoryKeys.criticalBanner), findsNothing);

  /// The word "Critical" on the result itself — the half a colour-blind
  /// reader, a greyscale printout and anyone across a corridor depends on.
  void seeCriticalWordOnResult(String resultId) => expect(
        find.descendant(
          of: find.byKey(LaboratoryKeys.resultRow(resultId)),
          matching: find.text('Critical'),
        ),
        findsOneWidget,
        reason: 'a critical result must carry the word beside its colour',
      );

  void seeResult(String resultId, String value) => expect(
        find.descendant(
          of: find.byKey(LaboratoryKeys.resultRow(resultId)),
          matching: find.text(value),
        ),
        findsOneWidget,
      );

  /// Any result row, for a result whose id the fixtures did not choose.
  void seeAnyResult() => expect(
        find.byType(VitalFigure),
        findsWidgets,
        reason: 'the order should be showing a reading by now',
      );

  /// Logs the sample through the accession sheet.
  Future<void> collectSample({String accession = ''}) async {
    await tester.tapKey(LaboratoryKeys.collectSample);
    await tester.pumpUntilRouteSettled();
    if (accession.isNotEmpty) {
      await tester.enterTextByKey(LaboratoryKeys.accessionField, accession);
    }
    await tester.tapKeyWithoutKeyboard(LaboratoryKeys.accessionConfirm);
    await tester.pumpUntilRouteSettled();
    await settle();
  }

  Future<void> rejectSample(String reason) async {
    await tester.tapKey(LaboratoryKeys.rejectSample);
    await tester.pumpUntilRouteSettled();
    await tester.enterTextByKey(LaboratoryKeys.rejectReasonField, reason);
    await tester.tapKeyWithoutKeyboard(LaboratoryKeys.rejectConfirm);
    await tester.pumpUntilRouteSettled();
    await settle();
  }

  Future<void> enterResultFor(String testId) async {
    await tester.tapKey(LaboratoryKeys.enterResult(testId));
    await tester.pumpUntilRouteSettled();
  }

  Future<void> verifyResult(String resultId) async {
    await tester.tapKey(LaboratoryKeys.verifyResult(resultId));
    await settle();
  }

  // ── A result ──────────────────────────────────────────────────────────────

  Future<void> assertOnResultForm() async {
    await tester.pumpUntilFound(find.byKey(LaboratoryKeys.resultFormScreen));
  }

  /// The reference range the form shows beside the value field.
  void seeReferenceRange(String text) => expect(
        find.descendant(
          of: find.byKey(LaboratoryKeys.resultReference),
          matching: find.textContaining(text),
        ),
        // `findsWidgets`, not one: a test keyed by sex carries a male range
        // and a female one, and both are shown.
        findsWidgets,
        reason: 'the person typing the value has to see what it is measured '
            'against',
      );

  /// The flag control offers words, never the stored letters.
  void seeFlagWords() {
    for (final word in const ['Normal', 'High', 'Low', 'Abnormal']) {
      expect(
        find.text(word),
        findsWidgets,
        reason: 'the flag control should read "$word", not a bare letter',
      );
    }
  }

  Future<void> typeResultValue(String value) =>
      tester.enterTextByKey(LaboratoryKeys.resultValue, value);

  Future<void> flagAs(String flag) async {
    await tester.tapKeyWithoutKeyboard(LaboratoryKeys.resultFlag(flag));
    await tester.pump();
  }

  Future<void> toggleCritical() async {
    await tester.tapKeyWithoutKeyboard(LaboratoryKeys.resultCritical);
    await tester.pump();
  }

  Future<void> toggleAbnormal() async {
    await tester.tapKeyWithoutKeyboard(LaboratoryKeys.resultAbnormal);
    await tester.pump();
  }

  bool get abnormalIsOn =>
      tester.widget<Switch>(find.byKey(LaboratoryKeys.resultAbnormal)).value;

  bool get criticalIsOn =>
      tester.widget<Switch>(find.byKey(LaboratoryKeys.resultCritical)).value;

  Future<void> saveResult() async {
    await tester.tapKeyWithoutKeyboard(LaboratoryKeys.resultSubmit);
    await tester.pumpUntilRouteSettled();
    await settle();
  }

  // ── The catalogue ─────────────────────────────────────────────────────────

  Future<void> assertOnCatalogue() async {
    await tester.pumpUntilFound(find.byKey(LaboratoryKeys.catalogScreen));
  }

  int get catalogueRowCount => find
      .byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('lab_catalog_row_'),
        description: 'a keyed catalogue row',
      )
      .evaluate()
      .length;

  void seeCatalogueRow(String id) =>
      expect(find.byKey(LaboratoryKeys.catalogRow(id)), findsOneWidget);

  /// The price on a catalogue row, formatted in the site's own convention.
  void seePriceOn(String id, String formatted) => expect(
        find.descendant(
          of: find.byKey(LaboratoryKeys.catalogRow(id)),
          matching: find.text(formatted),
        ),
        findsOneWidget,
        reason: 'a price list with a bare number on it is how one ships to the '
            'wrong country',
      );

  Future<void> searchCatalogue(String term) async {
    await tester.enterTextByKey(LaboratoryKeys.catalogSearch, term);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  Iterable<Element> get _rowElements => find
      .byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(_rowPrefix),
        description: 'a keyed worklist row',
      )
      .evaluate();

  String _idOf(Key key) =>
      (key as ValueKey<String>).value.substring(_rowPrefix.length);
}
