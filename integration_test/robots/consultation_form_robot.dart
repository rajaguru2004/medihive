import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/keys/consultation_form_keys.dart';
import 'package:medihive/app/modules/consultations/consultation_routes.dart';
import 'package:medihive/app/theme/theme.dart';

import '../support/pump.dart';
import 'robot.dart';

/// Writing up a consultation.
///
/// Every field lives in one `Form` across four tabs, and the tabs are hidden
/// rather than unbuilt — so a finder reaches a field on any tab, and a *tap*
/// reaches it only on the tab that is showing. Every method here that touches a
/// field opens its tab first, which is also what a person would have to do.
final class ConsultationFormRobot extends Robot {
  ConsultationFormRobot(super.harness);

  @override
  String? get route => ConsultationRoutes.form;

  @override
  Key get anchor => ConsultationFormKeys.screen;

  Future<void> open({
    String? consultationId,
    String? patientId,
    String? appointmentId,
  }) async {
    unawaited(
      Get.toNamed<void>(
            ConsultationRoutes.form,
            arguments: {
              'id': ?consultationId,
              'patientId': ?patientId,
              'appointmentId': ?appointmentId,
            },
          ) ??
          Future<void>.value(),
    );
    await tester.pumpUntilFound(find.byKey(ConsultationFormKeys.screen));
    await settle();
  }

  Future<void> openTab(String name) async {
    await tester.tapKeyWithoutKeyboard(ConsultationFormKeys.tab(name));
    await tester.pumpUntilViewportStable();
  }

  // ── Visit ─────────────────────────────────────────────────────────────────

  Future<void> choosePatient(String name) async {
    await openTab('visit');
    await tester.tapKeyWithoutKeyboard(ConsultationFormKeys.patient);
    await tester.pumpUntilRouteSettled();
    await tester.enterTextByKey(kPickerSearchKey, name);
    await pickFromSheet(name);
  }

  Future<void> chooseClinician(String name) async {
    await openTab('visit');
    await tester.tapKeyWithoutKeyboard(ConsultationFormKeys.doctor);
    await pickFromSheet(name);
  }

  // ── Vitals ────────────────────────────────────────────────────────────────

  /// Enters observations. Anything left out is left blank, which is how an
  /// unobserved vital is actually recorded — and the case a screen must not
  /// paint as a reading of zero.
  Future<void> enterVitals({
    String? temperature,
    String? systolic,
    String? diastolic,
    String? pulse,
    String? respiratoryRate,
    String? oxygenSaturation,
  }) async {
    await openTab('vitals');
    if (temperature != null) {
      await tester.enterTextByKey(
        ConsultationFormKeys.temperature,
        temperature,
      );
    }
    if (systolic != null) {
      await tester.enterTextByKey(ConsultationFormKeys.systolic, systolic);
    }
    if (diastolic != null) {
      await tester.enterTextByKey(ConsultationFormKeys.diastolic, diastolic);
    }
    if (pulse != null) {
      await tester.enterTextByKey(ConsultationFormKeys.pulse, pulse);
    }
    if (respiratoryRate != null) {
      await tester.enterTextByKey(
        ConsultationFormKeys.respiratoryRate,
        respiratoryRate,
      );
    }
    if (oxygenSaturation != null) {
      await tester.enterTextByKey(
        ConsultationFormKeys.oxygenSaturation,
        oxygenSaturation,
      );
    }
    await tester.pump();
  }

  /// The warning over the observations — the form telling a clinician before
  /// the record is saved rather than after somebody opens it again.
  void seeVitalsWarning({String? containing}) {
    expect(
      find.byKey(ConsultationFormKeys.vitalsFlag),
      findsOneWidget,
      reason: 'an out-of-range reading must be flagged in words, not only in '
          'the colour of a unit',
    );
    if (containing != null) {
      expect(
        find.descendant(
          of: find.byKey(ConsultationFormKeys.vitalsFlag),
          matching: find.textContaining(containing),
        ),
        findsOneWidget,
        reason: 'expected the warning to say "$containing"',
      );
    }
  }

  void seeNoVitalsWarning() => expect(
        find.byKey(ConsultationFormKeys.vitalsFlag),
        findsNothing,
        reason: 'readings inside their ranges must not raise a warning — one '
            'that is always up is one nobody reads',
      );

  // ── Notes ─────────────────────────────────────────────────────────────────

  Future<void> enterComplaint(String text) async {
    await openTab('notes');
    await tester.enterTextByKey(ConsultationFormKeys.complaint, text);
  }

  Future<void> enterDiagnosis(String text) async {
    await openTab('notes');
    await tester.enterTextByKey(ConsultationFormKeys.diagnosis, text);
  }

  Future<void> addIcdCode(String code) async {
    await openTab('notes');
    await tester.enterTextByKey(ConsultationFormKeys.icdInput, code);
    await tester.tapKeyWithoutKeyboard(ConsultationFormKeys.icdAdd);
    await tester.pump();
  }

  void seeIcdCode(String code) =>
      expect(find.byKey(ConsultationFormKeys.icdChip(code)), findsOneWidget);

  // ── Prescription ──────────────────────────────────────────────────────────

  /// Writes one line of the script.
  Future<void> prescribe({
    int index = 0,
    required String drug,
    required String dosage,
    required String frequency,
    required String duration,
    String? quantity,
  }) async {
    await openTab('plan');

    await tester.tapKeyWithoutKeyboard(
      ConsultationFormKeys.prescriptionDrug(index),
    );
    await tester.pumpUntilRouteSettled();
    await tester.enterTextByKey(kPickerSearchKey, drug);
    await pickFromSheet(drug);

    await tester.enterTextByKey(
      ConsultationFormKeys.prescriptionDosage(index),
      dosage,
    );
    await tester.enterTextByKey(
      ConsultationFormKeys.prescriptionFrequency(index),
      frequency,
    );
    await tester.enterTextByKey(
      ConsultationFormKeys.prescriptionDuration(index),
      duration,
    );
    if (quantity != null) {
      await tester.enterTextByKey(
        ConsultationFormKeys.prescriptionQuantity(index),
        quantity,
      );
    }
    await tester.pump();
  }

  Future<void> addPrescriptionLine() async {
    await openTab('plan');
    await tester.tapKeyWithoutKeyboard(ConsultationFormKeys.prescriptionAdd);
    await tester.pump();
  }

  // ── Orders ────────────────────────────────────────────────────────────────

  void seeOrdersCard() => expect(
        find.byKey(ConsultationFormKeys.orders),
        findsOneWidget,
        reason: 'an account that can raise a request should be offered one',
      );

  void seeNoOrdersCard() => expect(
        find.byKey(ConsultationFormKeys.orders),
        findsNothing,
        reason: 'an account that can order neither tests nor imaging must not '
            'see the card — controls are absent, not disabled',
      );

  void seeOrderFailure({String? containing}) {
    expect(find.byKey(ConsultationFormKeys.ordersFailed), findsOneWidget);
    if (containing != null) {
      expect(
        find.descendant(
          of: find.byKey(ConsultationFormKeys.ordersFailed),
          matching: find.textContaining(containing),
        ),
        findsOneWidget,
      );
    }
  }

  // ── Saving ────────────────────────────────────────────────────────────────

  Future<void> save() async {
    await tester.tapKeyWithoutKeyboard(ConsultationFormKeys.save);
    await settle();
  }

  void seeNoSaveBar() => expect(
        find.byKey(ConsultationFormKeys.save),
        findsNothing,
        reason: 'an account that cannot write a consultation must not be '
            'offered a save bar',
      );

  void seeStillOnForm() =>
      expect(find.byKey(ConsultationFormKeys.screen), findsOneWidget);

  /// Which tab is showing, by its label on the segmented control.
  ///
  /// A save refused by a field three tabs away has to *take* the reader there;
  /// marking a field nobody can see is a form that appears to do nothing.
  bool isOnTab(String label) {
    final segmented = tester.widgetList<BentoSegmented<Object?>>(
      find.byWidgetPredicate(
        (widget) => widget is BentoSegmented<Object?>,
        description: 'a segmented control',
      ),
    );
    return segmented.any((control) => control.labelOf(control.selected) == label);
  }
}
