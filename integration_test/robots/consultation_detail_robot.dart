import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/keys/consultation_detail_keys.dart';
import 'package:medihive/app/modules/consultations/consultation_routes.dart';

import '../support/pump.dart';
import 'robot.dart';

/// One consultation, as the record somebody opens afterwards.
final class ConsultationDetailRobot extends Robot {
  ConsultationDetailRobot(super.harness);

  /// Null, deliberately: the page is registered as `/consultations/:id` and
  /// opened at `/consultations/c-flagged`, so the pattern and the current route
  /// are never the same string. [seeOpenOn] checks the id instead.
  @override
  String? get route => null;

  @override
  Key get anchor => ConsultationDetailKeys.screen;

  Future<void> open(String id) async {
    unawaited(
      Get.toNamed<void>(
            ConsultationRoutes.detailFor(id),
            arguments: {'id': id},
          ) ??
          Future<void>.value(),
    );
    await tester.pumpUntilFound(find.byKey(ConsultationDetailKeys.screen));
    await settle();
  }

  void seeOpenOn(String id) => expect(
        Get.currentRoute,
        ConsultationRoutes.detailFor(id),
        reason: 'expected the record for $id',
      );

  // ── Observations ──────────────────────────────────────────────────────────

  void seeVitals() =>
      expect(find.byKey(ConsultationDetailKeys.vitals), findsOneWidget);

  /// The warning the form raised while the readings were typed, on the record
  /// that opens afterwards. The app shipped a bug once where only one of the
  /// two said anything.
  void seeVitalsWarning({String? containing}) {
    expect(
      find.byKey(ConsultationDetailKeys.vitalsFlag),
      findsOneWidget,
      reason: 'the record must carry the same worded warning the form raised',
    );
    if (containing != null) {
      expect(
        find.descendant(
          of: find.byKey(ConsultationDetailKeys.vitalsFlag),
          matching: find.textContaining(containing),
        ),
        findsOneWidget,
        reason: 'expected the warning to say "$containing"',
      );
    }
  }

  void seeNoVitalsWarning() => expect(
        find.byKey(ConsultationDetailKeys.vitalsFlag),
        findsNothing,
        reason: 'nothing here is outside its range, so nothing may be flagged',
      );

  // ── What the encounter produced ───────────────────────────────────────────

  // Each of these scrolls first. A record with vitals, notes, a diagnosis and
  // a plan on it is longer than a phone, and a sliver below the fold is **not
  // built** — so an assertion that only looks reports a script the screen is
  // carrying as missing.
  Future<void> seePrescription() async {
    await tester.scrollToKey(ConsultationDetailKeys.prescription);
    expect(find.byKey(ConsultationDetailKeys.prescription), findsOneWidget);
  }

  Future<void> seeLabOrders() async {
    await tester.scrollToKey(ConsultationDetailKeys.labOrders);
    expect(find.byKey(ConsultationDetailKeys.labOrders), findsOneWidget);
  }

  Future<void> seeImagingOrders() async {
    await tester.scrollToKey(ConsultationDetailKeys.radiologyOrders);
    expect(
      find.byKey(ConsultationDetailKeys.radiologyOrders),
      findsOneWidget,
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void seeAction(Key key) => expect(find.byKey(key), findsOneWidget);
  void seeNoAction(Key key) => expect(find.byKey(key), findsNothing);

  /// Every gated control at once, for a role that may only read.
  Future<void> seeNoActionsAtAll() async {
    for (final key in const [
      ConsultationDetailKeys.edit,
      ConsultationDetailKeys.delete,
      ConsultationDetailKeys.orderLab,
      ConsultationDetailKeys.orderImaging,
      ConsultationDetailKeys.newInvoice,
    ]) {
      expect(
        find.byKey(key),
        findsNothing,
        reason: '$key must be absent, not disabled, for a read-only account',
      );
    }
    await tester.scrollToKey(ConsultationDetailKeys.noActions);
    expect(find.byKey(ConsultationDetailKeys.noActions), findsOneWidget);
  }

  Future<void> deleteRecord() async {
    await tester.tapKeyWithoutKeyboard(ConsultationDetailKeys.delete);
    await tester.pumpUntilFound(
      find.byKey(ConsultationDetailKeys.deleteConfirm),
    );
    await tester.tap(find.byKey(ConsultationDetailKeys.deleteConfirm));
    await settle();
  }
}
