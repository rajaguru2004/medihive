import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/keys/appointment_form_keys.dart';
import 'package:medihive/app/modules/appointments/appointment_routes.dart';
import 'package:medihive/app/theme/theme.dart';

import '../support/pump.dart';
import 'robot.dart';

/// The booking form — new bookings and edits, which are one screen.
final class AppointmentFormRobot extends Robot {
  AppointmentFormRobot(super.harness);

  @override
  String? get route => AppointmentRoutes.form;

  @override
  Key get anchor => AppointmentFormKeys.screen;

  /// Opens the form.
  ///
  /// Fired and not awaited — `Get.toNamed` completes when the route is
  /// *popped*, so awaiting it hangs until the twelve-minute timeout.
  Future<void> open({String? appointmentId, String? patientId}) async {
    unawaited(
      Get.toNamed<void>(
            AppointmentRoutes.form,
            arguments: {'id': ?appointmentId, 'patientId': ?patientId},
          ) ??
          Future<void>.value(),
    );
    await tester.pumpUntilFound(find.byKey(AppointmentFormKeys.screen));
    await settle();
  }

  // ── Filling it in ─────────────────────────────────────────────────────────

  Future<void> choosePatient(String name) async {
    await tester.tapKeyWithoutKeyboard(AppointmentFormKeys.patient);
    await tester.pumpUntilRouteSettled();
    await tester.enterTextByKey(kPickerSearchKey, name);
    await pickFromSheet(name);
  }

  Future<void> chooseClinician(String name) async {
    await tester.tapKeyWithoutKeyboard(AppointmentFormKeys.doctor);
    await pickFromSheet(name);
  }

  Future<void> chooseToday() =>
      pickDate(AppointmentFormKeys.date, choice: 'Today');

  /// Opens the slot sheet and leaves it open, so a flow can read what this
  /// site's diary actually offers.
  Future<void> openSlots() async {
    await tester.tapKeyWithoutKeyboard(AppointmentFormKeys.time);
    await tester.pumpUntilRouteSettled();
  }

  Future<void> chooseSlot(String time) async {
    await openSlots();
    await tester.tapKey(AppointmentFormKeys.slot(time));
    await settle();
  }

  Future<void> chooseDuration(int minutes) =>
      tester.tapKeyWithoutKeyboard(AppointmentFormKeys.duration(minutes));

  Future<void> chooseType(String value) =>
      tester.tapKeyWithoutKeyboard(AppointmentFormKeys.type(value));

  Future<void> enterComplaint(String text) =>
      tester.enterTextByKey(AppointmentFormKeys.complaint, text);

  Future<void> save() async {
    await tester.tapKeyWithoutKeyboard(AppointmentFormKeys.save);
    await settle();
  }

  // ── Assertions ────────────────────────────────────────────────────────────

  /// The slots the open sheet is offering, in the order it offers them.
  ///
  /// Read off the keys rather than off the text, because the text is formatted
  /// in the site's clock and the key is the `"HH:mm"` the request carries — so
  /// this assertion and an assertion about the payload are about one value.
  List<String> get offeredSlots => find
      .byWidgetPredicate(
        (widget) =>
            widget is SheetRow &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>)
                .value
                .startsWith('appointment_form_slot_'),
        description: 'a slot row',
      )
      .evaluate()
      .map((element) => (element.widget.key! as ValueKey<String>)
          .value
          .replaceFirst('appointment_form_slot_', ''))
      .toList();

  void seeSaveBlocked() => expect(
        find.byKey(AppointmentFormKeys.save),
        findsOneWidget,
        reason: 'the form should still be on screen after a refused save',
      );

  void seeNoSaveBar() => expect(
        find.byKey(AppointmentFormKeys.save),
        findsNothing,
        reason: 'an account that cannot book must not be offered a save bar — '
            'controls are absent, not disabled',
      );

  void seeLocked() =>
      expect(find.byKey(AppointmentFormKeys.noAccess), findsWidgets);
}
