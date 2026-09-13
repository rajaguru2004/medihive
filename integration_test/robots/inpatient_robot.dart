import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/keys/app_keys.dart';
import 'package:medihive/app/routes/app_pages.dart';
import 'package:medihive/app/theme/theme.dart';

import '../support/pump.dart';
import 'robot.dart';
import 'shell_tab.dart';

/// The inpatient estate: the shell's Wards tab, and the bed map it opens.
///
/// One robot for two screens because `InpatientKeys` is one file for four, and
/// for the same reason — they are views of one thing, a ward's beds, and a bed
/// named on one of them must be the same bed on the others.
final class InpatientRobot extends Robot with ShellTab {
  InpatientRobot(super.harness);

  @override
  Key get anchor => InpatientKeys.overview;

  @override
  String get shellTitle => 'Inpatient';

  static const _bedPrefix = 'inpatient_bed_';

  // ── The tab ───────────────────────────────────────────────────────────────

  Future<void> assertOnBoard() async {
    await assertVisible();
    seeNoErrorBanner();
  }

  // ── The bed map ───────────────────────────────────────────────────────────

  /// Pushes the bed map.
  ///
  /// `Get.toNamed` is fired and **not awaited**: its future completes when the
  /// route is *popped*, so awaiting it here would wait for something this flow
  /// has not done yet and never returns. The same trap is commented in
  /// `SessionManager.endSession`.
  Future<void> openBedMap() async {
    unawaited(
      Get.toNamed<void>(Routes.INPATIENT_BEDS_GRID) ?? Future<void>.value(),
    );
    await tester.pumpUntilFound(find.byKey(InpatientKeys.beds));
    await settle();
  }

  Future<void> assertOnBedMap() async {
    await tester.pumpUntilFound(find.byKey(InpatientKeys.bedGrid));
    expect(
      Get.currentRoute,
      Routes.INPATIENT_BEDS_GRID,
      reason: 'the bed grid rendered but the route is ${Get.currentRoute}',
    );
    // The key is the second half of the clinical rule: the map carries four
    // states as four fills, and a fill with no key beside it is a colour.
    expect(find.byKey(InpatientKeys.bedLegend), findsOneWidget);
  }

  /// The beds on the map, in the order the grid lays them out.
  List<String> bedIdsInOrder() {
    final beds = <({double top, double left, String id})>[
      for (final element in _bedElements)
        (
          top: (element.renderObject! as RenderBox).localToGlobal(Offset.zero).dy,
          left:
              (element.renderObject! as RenderBox).localToGlobal(Offset.zero).dx,
          id: _idOf(element.widget.key!),
        ),
    ]..sort((a, b) {
        final byRow = a.top.compareTo(b.top);
        return byRow != 0 ? byRow : a.left.compareTo(b.left);
      });
    return [for (final bed in beds) bed.id];
  }

  int get bedCount => _bedElements.length;

  /// Narrows the map to one bed state. Tapping the same chip again clears it,
  /// which is the control's own behaviour rather than this robot's.
  Future<void> filterBedsBy(BedState state) async {
    await tester.tapKey(InpatientKeys.bedStateFilter(state.name));
    await settle();
  }

  /// Opens one bed's sheet. Close it with [closeSheet] before the test ends.
  Future<void> openBed(String id) async {
    await tester.tapKey(InpatientKeys.bed(id));
    await tester.pumpUntilRouteSettled();
  }

  /// A row in the open bed sheet, by the words on it.
  void seeBedAction(String label) => expect(
        find.ancestor(of: find.text(label), matching: find.byType(SheetRow)),
        findsOneWidget,
        reason: 'the bed sheet should offer "$label"',
      );

  void seeNoBedAction(String label) => expect(
        find.ancestor(of: find.text(label), matching: find.byType(SheetRow)),
        findsNothing,
        reason: 'the bed sheet should not offer "$label"',
      );

  Iterable<Element> get _bedElements => find
      .byWidgetPredicate(
        (widget) =>
            widget is BedTile &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(_bedPrefix),
        description: 'a keyed bed tile',
      )
      .evaluate();

  String _idOf(Key key) =>
      (key as ValueKey<String>).value.substring(_bedPrefix.length);
}
