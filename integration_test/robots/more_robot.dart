import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/core/keys/app_keys.dart';
import 'package:medihive/app/theme/theme.dart';

import '../support/pump.dart';
import 'robot.dart';
import 'shell_tab.dart';

/// The More hub: everything this account can reach that did not fit on the bar.
///
/// A shell tab rather than a pushed screen, so it is asserted the way the other
/// tabs are — by hit-testing the anchor, because an `IndexedStack` keeps every
/// tab it has built in the tree.
final class MoreRobot extends Robot with ShellTab {
  MoreRobot(super.harness);

  @override
  Key get anchor => MoreKeys.screen;

  @override
  String get shellTitle => 'More';

  /// This account can reach [label] from the hub.
  ///
  /// By the word on the row rather than by its route: the hub's rows are keyed
  /// by route because that is what a tap *does*, and a role flow's claim is
  /// "a pharmacist can reach Pharmacy", which is what the reader sees.
  ///
  /// Scoped to the hub twice over — to its anchor, because every other tab is
  /// still in the tree behind it, and to a [BentoRow], because a group heading
  /// reading "Diagnostics" must not answer for a destination of the same name.
  Future<void> seeItem(String label) async {
    // A row the hub has not scrolled to is still built — each group is one
    // `Column` inside one `SliverToBoxAdapter` — so this normally finds it
    // without moving anything. The reveal is the fallback for a hub long
    // enough to be lazily built, and it costs nothing when the row is there.
    await _reveal(label);
    expect(
      _item(label),
      findsOneWidget,
      reason: 'expected "$label" in the More hub',
    );
  }

  /// This account cannot reach [label] at all.
  ///
  /// The assertion that carries the weight. The bar hiding a destination means
  /// little on its own — everything the bar drops lands here — so "not on the
  /// bar **and** not in More" is what "this account does not have it" actually
  /// means.
  void seeNoItem(String label) => expect(
        _item(label),
        findsNothing,
        reason: 'the More hub offered "$label" to an account that cannot use '
            'it',
      );

  /// Opens the destination reading [label].
  ///
  /// Tapped through its key rather than through the finder that located it, so
  /// it goes out with the same discipline every other tap in this suite does:
  /// scrolled into view, and only once the tree has stopped moving.
  Future<void> openItem(String label) async {
    final row = await _reveal(label);
    final key = tester.widget<BentoRow>(row).key;
    if (key == null) {
      fail('the "$label" row in the More hub carries no key — rows are keyed '
          'by route through MoreKeys.item()');
    }
    await tester.tapKey(key);
    await settle();
  }

  /// The banner that says the navigation was built from the token rather than
  /// from the server, so the list may be short.
  void seeAccessDegraded() => expect(
        find.byKey(MoreKeys.accessNotice),
        findsOneWidget,
        reason: 'expected the hub to admit its list came from a stale source',
      );

  void seeNoAccessDegraded() =>
      expect(find.byKey(MoreKeys.accessNotice), findsNothing);

  Future<Finder> _reveal(String label) async {
    final row = _item(label);
    await tester.scrollToFinder(row);
    return row;
  }

  Finder _item(String label) => find.descendant(
        of: find.byKey(MoreKeys.screen),
        matching: find.ancestor(
          of: find.text(label),
          matching: find.byType(BentoRow),
        ),
      );
}
