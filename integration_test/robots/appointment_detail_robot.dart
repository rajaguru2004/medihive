import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/keys/appointment_detail_keys.dart';
import 'package:medihive/app/modules/appointments/appointment_routes.dart';

import '../support/pump.dart';
import 'robot.dart';

/// One booking, and the ladder a clinic desk walks it along.
final class AppointmentDetailRobot extends Robot {
  AppointmentDetailRobot(super.harness);

  /// Null, deliberately. This screen is registered as `/appointments/:id` and
  /// opened at `/appointments/ap-scheduled`, so the pattern and the current
  /// route are never the same string — [seeOpenOn] checks the id instead.
  @override
  String? get route => null;

  @override
  Key get anchor => AppointmentDetailKeys.screen;

  /// Opens one booking by id, the way a deep link does.
  Future<void> open(String id) async {
    unawaited(
      Get.toNamed<void>(
            AppointmentRoutes.detailFor(id),
            arguments: {'id': id},
          ) ??
          Future<void>.value(),
    );
    await tester.pumpUntilFound(find.byKey(AppointmentDetailKeys.screen));
    await settle();
  }

  void seeOpenOn(String id) => expect(
        Get.currentRoute,
        AppointmentRoutes.detailFor(id),
        reason: 'expected the detail for $id',
      );

  // ── The ladder ────────────────────────────────────────────────────────────

  Future<void> moveTo(String status) async {
    await tester.tapKeyWithoutKeyboard(AppointmentDetailKeys.action(status));
    await settle();
  }

  void seeStep(String status) => expect(
        find.byKey(AppointmentDetailKeys.action(status)),
        findsOneWidget,
        reason: 'expected "$status" to be on offer',
      );

  void seeNoStep(String status) => expect(
        find.byKey(AppointmentDetailKeys.action(status)),
        findsNothing,
        reason: '"$status" is not a step this booking can take from here',
      );

  void seeTimeline() =>
      expect(find.byKey(AppointmentDetailKeys.timeline), findsOneWidget);

  void seeClosedNotice() => expect(
        find.byKey(AppointmentDetailKeys.closedNotice),
        findsOneWidget,
        reason: 'a booking that is finished with says so rather than offering '
            'buttons that would be refused',
      );

  // ── Reschedule ────────────────────────────────────────────────────────────

  /// Opens the reschedule sheet, chooses a day and a slot, and sends it.
  Future<void> reschedule({required String slot}) async {
    await tester.tapKeyWithoutKeyboard(AppointmentDetailKeys.reschedule);
    await tester.pumpUntilRouteSettled();

    await pickDate(AppointmentDetailKeys.rescheduleDate, choice: 'In a week');

    await tester.tapKeyWithoutKeyboard(AppointmentDetailKeys.rescheduleTime);
    await tester.pumpUntilRouteSettled();
    await tester.tapKey(AppointmentDetailKeys.rescheduleSlot(slot));
    await tester.pumpUntilRouteSettled();

    await tester.tapKeyWithoutKeyboard(AppointmentDetailKeys.rescheduleSave);
    await settle();
  }

  void seeNoReschedule() =>
      expect(find.byKey(AppointmentDetailKeys.reschedule), findsNothing);

  // ── Cancel ────────────────────────────────────────────────────────────────

  Future<void> openCancel() async {
    await tester.tapKeyWithoutKeyboard(AppointmentDetailKeys.cancel);
    await tester.pumpUntilRouteSettled();
  }

  /// Tries to continue past the cancel sheet without giving a reason.
  Future<void> continueWithoutReason() async {
    await tester.tapKeyWithoutKeyboard(AppointmentDetailKeys.cancelSave);
    await tester.pump();
  }

  /// True while the cancel sheet is still up — which it is when the reason was
  /// refused.
  bool get cancelSheetIsOpen =>
      find.byKey(AppointmentDetailKeys.cancelReason).evaluate().isNotEmpty;

  /// Gives the reason and closes the sheet, leaving the confirm on screen.
  ///
  /// Two steps rather than one so a flow can read what the confirm says before
  /// agreeing to it — which is the half of this interaction that matters.
  Future<void> submitCancelReason(String reason) async {
    await tester.enterTextByKey(AppointmentDetailKeys.cancelReason, reason);
    await tester.tapKeyWithoutKeyboard(AppointmentDetailKeys.cancelSave);
    await tester.pumpUntilRouteSettled();
    await tester.pumpUntilFound(find.byKey(AppointmentDetailKeys.cancelConfirm));
  }

  Future<void> confirmCancel() async {
    await tester.tap(find.byKey(AppointmentDetailKeys.cancelConfirm));
    await settle();
  }

  /// The confirm dialog has to name the patient. "Cancel this appointment?"
  /// over a ward tablet somebody else left open is how the wrong slot goes.
  void seeConfirmNames(String name) => expect(
        find.textContaining(name),
        findsWidgets,
        reason: 'the confirm should name the patient',
      );

  void seeNoCancel() =>
      expect(find.byKey(AppointmentDetailKeys.cancel), findsNothing);

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteBooking() async {
    await tester.tapKeyWithoutKeyboard(AppointmentDetailKeys.delete);
    await tester.pumpUntilFound(find.byKey(AppointmentDetailKeys.deleteConfirm));
    await tester.tap(find.byKey(AppointmentDetailKeys.deleteConfirm));
    await settle();
  }

  void seeNoDelete() =>
      expect(find.byKey(AppointmentDetailKeys.delete), findsNothing);

  void seeNoEdit() =>
      expect(find.byKey(AppointmentDetailKeys.edit), findsNothing);

  void seeLocked() =>
      expect(find.byKey(AppointmentDetailKeys.noAccess), findsOneWidget);
}
