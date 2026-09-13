import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/keys/app_keys.dart';
import 'package:medihive/app/routes/app_pages.dart';

import '../support/pump.dart';
import 'robot.dart';

/// Pre-triage: the screening board, the two-step form it opens, and one
/// screening's detail.
///
/// Three screens, one robot, for the reason `ScreeningKeys` is one file for
/// three: they are one task. Step two validates against what step one
/// collected and the detail is what the pair produced, so a flow that walks
/// them should not have to hold three objects to do it.
final class PreTriageRobot extends Robot {
  PreTriageRobot(super.harness);

  @override
  String? get route => Routes.PRE_TRIAGE;

  @override
  Key get anchor => PreTriageKeys.screen;

  // ── The board ─────────────────────────────────────────────────────────────

  /// Pushes the screening board.
  ///
  /// Fired and not awaited — `Get.toNamed` completes when the route is
  /// *popped*, so awaiting it hangs until the twelve-minute timeout.
  Future<void> openBoard() async {
    unawaited(Get.toNamed<void>(Routes.PRE_TRIAGE) ?? Future<void>.value());
    await tester.pumpUntilFound(find.byKey(PreTriageKeys.screen));
    await settle();
  }

  Future<void> assertOnBoard() async {
    await assertVisible();
    seeNoErrorBanner();
  }

  // ── Step one: who ─────────────────────────────────────────────────────────

  /// Starts a screening from the board's own button, rather than by pushing the
  /// route — the button being wired to nothing is a regression worth catching.
  Future<void> startNewScreening() async {
    await tester.tapKey(PreTriageKeys.newScreening);
    await tester.pumpUntilFound(find.byKey(ScreeningKeys.step1));
    await settle();
  }

  Future<void> assertOnStep1() async {
    await tester.pumpUntilFound(find.byKey(ScreeningKeys.step1));
    expect(Get.currentRoute, Routes.NEW_SCREENING_STEP1);
  }

  Future<void> enterWho({
    required String firstName,
    String? lastName,
    String? age,
    String? sex,
  }) async {
    await tester.enterTextByKey(ScreeningKeys.nameField, firstName);
    if (lastName != null) {
      await tester.enterTextByKey(ScreeningKeys.lastNameField, lastName);
    }
    if (age != null) await tester.enterTextByKey(ScreeningKeys.ageField, age);
    if (sex != null) {
      await tester.tapKeyWithoutKeyboard(ScreeningKeys.sexOption(sex));
    }
  }

  Future<void> goToObservations() async {
    await tester.tapKeyWithoutKeyboard(ScreeningKeys.step1Next);
    await tester.pumpUntilFound(find.byKey(ScreeningKeys.step2));
    await settle();
  }

  // ── Step two: what ────────────────────────────────────────────────────────

  Future<void> assertOnStep2() async {
    await tester.pumpUntilFound(find.byKey(ScreeningKeys.step2));
    expect(Get.currentRoute, Routes.NEW_SCREENING_STEP2);
  }

  /// Step two's header carries the name step one collected. It is the only
  /// thing on this screen that proves the hand-off happened before the save
  /// does.
  void seeCarriedIdentity(String fullName) => seeText(fullName);

  Future<void> enterObservations({
    required String complaint,
    String? temperature,
    String? pulse,
    String? systolic,
    String? diastolic,
  }) async {
    await tester.enterTextByKey(ScreeningKeys.complaintField, complaint);
    if (temperature != null) {
      await tester.enterTextByKey(ScreeningKeys.temperatureField, temperature);
    }
    if (pulse != null) {
      await tester.enterTextByKey(ScreeningKeys.pulseField, pulse);
    }
    if (systolic != null) {
      await tester.enterTextByKey(ScreeningKeys.bpSystolicField, systolic);
    }
    if (diastolic != null) {
      await tester.enterTextByKey(ScreeningKeys.bpDiastolicField, diastolic);
    }
  }

  /// Chooses where this patient goes next, through the picker sheet.
  Future<void> routeTo(String department) async {
    await tester.tapKeyWithoutKeyboard(ScreeningKeys.acuityPicker);
    await pickFromSheet(department);
  }

  /// The live flag over the observations — the form telling a nurse before the
  /// save rather than after it.
  void seeObservationWarning() => expect(
        find.textContaining('outside the normal adult range'),
        findsOneWidget,
        reason: 'an out-of-range reading should be flagged as it is typed',
      );

  Future<void> saveScreening() async {
    await tester.tapKeyWithoutKeyboard(ScreeningKeys.submit);
    await settle();
  }

  // ── The detail ────────────────────────────────────────────────────────────

  /// Opens one screening by id, the way a deep link does.
  Future<void> openScreening(String id) async {
    unawaited(
      Get.toNamed<void>(
            Routes.PRE_TRIAGE_DETAILS,
            arguments: {'id': id},
          ) ??
          Future<void>.value(),
    );
    await tester.pumpUntilFound(find.byKey(PreTriageKeys.detail));
    await settle();
  }

  Future<void> assertOnDetail() async {
    await tester.pumpUntilFound(find.byKey(PreTriageKeys.detailVitals));
    expect(Get.currentRoute, Routes.PRE_TRIAGE_DETAILS);
  }

  /// The banner that says in words what the vital tiles only colour.
  Future<void> seeObservationFlag({String? containing}) async {
    await tester.pumpUntilFound(find.byKey(PreTriageKeys.detailFlag));
    if (containing != null) {
      expect(
        find.descendant(
          of: find.byKey(PreTriageKeys.detailFlag),
          matching: find.textContaining(containing),
        ),
        findsOneWidget,
        reason: 'expected the flag to say "$containing"',
      );
    }
  }

  void seeNoObservationFlag() => expect(
        find.byKey(PreTriageKeys.detailFlag),
        findsNothing,
        reason: 'readings inside their ranges must not raise a flag — a '
            'warning that is always up is a warning nobody reads',
      );
}
