import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/app_log.dart';
import '../../../../data/models/drafts/patient_portal_drafts.dart';
import '../../../../data/repositories/patient_portal_repository.dart';
import '../../patient_portal_messages.dart';
import '../../patient_portal_navigation.dart';

/// Claiming a record with the two things printed on a hospital card.
///
/// Both are required, and that is the server's rule rather than this form's: a
/// record number on its own is a sequential figure on a piece of paper anybody
/// could be holding, and the date of birth is what makes the pair evidence
/// that the card is yours.
///
/// This controller knows one thing the screen must never forget — **the answer
/// does not tell it whether the record exists.** A claim against an MRN that
/// matched nothing succeeds here and is refused at activation, so there is no
/// branch in [submit] that could show a "not found", and the copy for the
/// refusal that does eventually arrive lives in `patient_portal_messages.dart`
/// with the reasoning beside it.
class PatientClaimController extends GetxController {
  final PatientPortalRepository _repository = const PatientPortalRepository();

  final TextEditingController mrnController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final Rxn<DateTime> dateOfBirth = Rxn<DateTime>();
  final RxnString dateOfBirthError = RxnString();

  final RxBool isSubmitting = false.obs;
  final RxnString errorMessage = RxnString();

  /// The number on the card. 3 to 64 characters, which is the DTO's range —
  /// stated here so a card that is too short is refused before the request
  /// leaves rather than coming back as a 400 the patient cannot read.
  String? validateMrn(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter the number on your hospital card';
    if (text.length < 3) return 'That looks too short to be a hospital number';
    if (text.length > 64) return 'That looks too long to be a hospital number';
    return null;
  }

  Future<void> submit() async {
    if (isSubmitting.value) return;

    // Both halves, and both before the request. The date lives outside the
    // `Form` — it is a picker, not a field — so `validate()` cannot see it and
    // a form that only asked the fields would post half a claim.
    final formOk = formKey.currentState?.validate() ?? false;
    dateOfBirthError.value = dateOfBirth.value == null
        ? 'Choose the date of birth on your card'
        : null;
    if (!formOk || dateOfBirthError.value != null) return;

    // The keyboard comes down before the request: on a phone the error lands
    // below the fold and behind the keyboard otherwise, so a refused claim
    // looks like nothing happened at all.
    FocusManager.instance.primaryFocus?.unfocus();

    isSubmitting.value = true;
    errorMessage.value = null;

    try {
      final claim = await _repository.claim(
        PatientClaimDraft(
          mrn: mrnController.text,
          dateOfBirth: dateOfBirth.value!,
        ),
      );
      if (claim.isEmpty) {
        // A 200 with no token is a backend contract break, not a wrong card.
        errorMessage.value = kPatientClaimRefused;
        return;
      }
      PatientPortalNavigation.toActivate(claim.claimToken);
    } catch (e, stack) {
      errorMessage.value = patientPortalMessage(e);
      // Nothing identifying in the log line. The interceptor redacts tokens
      // and passwords; it does not know what an MRN is, and this one is on us.
      AppLog.error('PatientClaimController', 'claim refused', e, stack);
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    mrnController.dispose();
    super.onClose();
  }
}
