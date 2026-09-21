import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../data/models/case_intake.dart';
import '../../../data/repositories/case_intake_repository.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/theme.dart';
import '../case_intake_routes.dart';

/// One patient's intake, read by somebody who is not that patient.
///
/// The thinnest controller in the app that matters, and deliberately: there
/// is one read and there are no writes. A doctor holds `case-taking: read`
/// and nothing else — an intake a clinician can rewrite stops being evidence
/// of what the patient said — so there is no draft here, no correction path,
/// and no method that could grow into one.
class CaseIntakeController extends GetxController with LoadStateMixin {
  static CaseIntakeController get to => Get.find<CaseIntakeController>();

  final CaseIntakeRepository _repository = caseIntakeRepository;

  final Rx<CaseIntake> intake = CaseIntake.empty.obs;

  /// Read live off the route rather than captured in `onInit`, so a screen
  /// reopened at another id by a deep link is looking at the id it was opened
  /// for.
  String get submissionId =>
      Get.parameters[CaseIntakeRoutes.submissionIdParam] ?? '';

  @override
  void onReady() {
    super.onReady();
    unawaited(reload());
  }

  /// **Not `refresh()`** — `GetxController` owns that name and returns void,
  /// so an `onRefresh:` wired to it never awaits and the spinner snaps back
  /// before the request has left.
  Future<void> reload() => runGuarded(
        () async {
          final id = submissionId;
          if (id.isEmpty) {
            intake.value = CaseIntake.empty;
            return;
          }
          intake.value = await _repository.read(id);
        },
        fallback: "Couldn't open that intake.",
      );

  /// Puts the whole case on the clipboard.
  ///
  /// The plain-text rendering the server stored, not a re-assembly of the
  /// sections on screen: what gets pasted into a note must be what the patient
  /// sent, and a client that rebuilt it would be a second renderer quietly
  /// disagreeing with the first.
  Future<void> copyTranscript() async {
    final text = intake.value.text.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    showBentoToast('Intake copied.');
  }
}
