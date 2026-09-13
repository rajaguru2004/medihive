import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/core/keys/app_keys.dart';
import 'package:medihive/app/theme/theme.dart';

import '../support/pump.dart';
import 'robot.dart';
import 'shell_tab.dart';

/// The queue board.
///
/// The one screen in this app where ordering is the product, so this robot's
/// job is mostly to report the order it can see — by key, in painted order —
/// and let the flow say what that order should be.
final class QueueRobot extends Robot with ShellTab {
  QueueRobot(super.harness);

  @override
  Key get anchor => QueueKeys.screen;

  @override
  String get shellTitle => 'Queue';

  /// The label on the chip that turns the acuity filter off. `QueueController`
  /// keeps it private, and it is a word on screen, so it lives here.
  static const allAcuities = 'All acuities';

  static const _rowPrefix = 'queue_row_';

  Future<void> assertOnBoard() async {
    await assertVisible();
    seeNoErrorBanner();
  }

  /// The rows on the board, top to bottom.
  ///
  /// Read off the render tree rather than out of the controller: the sort this
  /// asserts is only worth anything if it is the sort a clinician is looking
  /// at, and a list that sorts correctly into a widget nobody paints is the
  /// same bug wearing a passing test.
  ///
  /// Every row is built whether or not it is above the fold — the board is one
  /// `Column` in one sliver — so this is the whole board, not the visible slice.
  List<String> rowIdsInOrder() {
    final rows = <({double top, String id})>[
      for (final element in _rowElements)
        (
          top: (element.renderObject! as RenderBox).localToGlobal(Offset.zero).dy,
          id: _idOf(element.widget.key!),
        ),
    ]..sort((a, b) => a.top.compareTo(b.top));
    return [for (final row in rows) row.id];
  }

  void seeRowOrder(List<String> ids) => expect(
        rowIdsInOrder(),
        ids,
        reason: 'the board is not in acuity-then-arrival order',
      );

  /// The triage code on one row's pill — the rank the sort claims to be using.
  String acuityOf(String id) => tester
      .widget<AcuityPill>(
        find
            .descendant(
              of: find.byKey(QueueKeys.row(id)),
              matching: find.byType(AcuityPill),
            )
            .first,
      )
      .code;

  /// Calls whoever the board put first.
  Future<void> callNext() async {
    await tester.tapKey(QueueKeys.callNext);
    await settle();
  }

  /// Narrows the board to one triage level. [code] is the stored code — `P1` —
  /// or [allAcuities] to take the filter off again.
  Future<void> filterBy(String code) async {
    await tester.tapKey(QueueKeys.filter(code));
    await settle();
  }

  Future<void> clearFilter() => filterBy(allAcuities);

  /// Opens the actions sheet for one person in the queue.
  ///
  /// Whatever it opens has to be closed before the test body ends — the sheet
  /// owns a ticker on the overlay. [closeSheet] is the other half.
  Future<void> openActionsFor(String id) async {
    await tester.tapKey(QueueKeys.advance(id));
    await tester.pumpUntilRouteSettled();
  }

  /// A row in the open actions sheet, by the words on it.
  void seeSheetAction(String label) => expect(
        find.ancestor(of: find.text(label), matching: find.byType(SheetRow)),
        findsOneWidget,
        reason: 'the actions sheet should offer "$label"',
      );

  Iterable<Element> get _rowElements => find
      .byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(_rowPrefix),
        description: 'a keyed queue row',
      )
      .evaluate();

  String _idOf(Key key) =>
      (key as ValueKey<String>).value.substring(_rowPrefix.length);
}
