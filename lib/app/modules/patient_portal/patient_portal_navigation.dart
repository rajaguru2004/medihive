import 'dart:async';

import 'package:get/get.dart';

import 'patient_entry.dart';
import 'patient_portal_routes.dart';

/// Moving through the entry sequence, in one place.
///
/// Every one of these is `unawaited`, and that is the point of the file rather
/// than an aside. **`await Get.toNamed(...)` does not complete when the screen
/// opens — it completes when the route is *popped*.** A controller that awaits
/// it is a controller that sits in an unfinished async call for as long as the
/// patient is on the next screen, and any `finally` it was relying on to clear
/// a submitting flag never runs until they come back. It has cost this
/// codebase a debugging session already; collecting the four navigations here
/// means it can only be got wrong once.
///
/// The sequence is dashboard → language → consent → interview, and the two
/// answers collected on the way travel in the arguments as [PatientEntry].
abstract final class PatientPortalNavigation {
  /// From the dashboard's primary action into the first question.
  static void beginEntry() {
    unawaited(
      Get.toNamed<void>(
            PatientPortalRoutes.language,
            arguments: const PatientEntry().toArguments(),
          ) ??
          Future<void>.value(),
    );
  }

  /// Language chosen; on to what they are agreeing to.
  static void toConsent(PatientEntry entry) {
    unawaited(
      Get.toNamed<void>(
            PatientPortalRoutes.consent,
            arguments: entry.toArguments(),
          ) ??
          Future<void>.value(),
    );
  }

  /// Consent given; on to the questions.
  ///
  /// `offNamed` rather than `toNamed`: back from the interview should return
  /// the patient to their dashboard, not to the consent screen they have
  /// already answered. Being asked to agree a second time reads as the first
  /// answer not having been recorded.
  static void toInterview(PatientEntry entry) {
    unawaited(
      Get.offNamed<void>(
            PatientPortalRoutes.caseTaking,
            arguments: entry.toArguments(),
          ) ??
          Future<void>.value(),
    );
  }

  /// Into a booking, from the dashboard or from the end of an interview.
  ///
  /// No patient id travels with it: the booking screen reads that from the
  /// record, and a screen that took one in its arguments would be a screen
  /// somebody could deep-link with somebody else's.
  ///
  /// [reason] is the complaint the interview recorded, carried across so the
  /// patient does not type out what they have just finished saying. It is
  /// text in a field they can still edit, not a decision — see
  /// `CaseReview.complaintSummary` for what is and is not allowed into it.
  static void toBooking({String? reason}) {
    final text = (reason ?? '').trim();
    unawaited(
      Get.toNamed<void>(
            PatientPortalRoutes.book,
            arguments: text.isEmpty ? null : {'reason': text},
          ) ??
          Future<void>.value(),
    );
  }

  /// All the way back to the patient's own screen, clearing whatever is on the
  /// stack behind it.
  static void backToDashboard() {
    unawaited(
      Get.offAllNamed<void>(PatientPortalRoutes.dashboard) ??
          Future<void>.value(),
    );
  }

  /// Claim, from the sign-in screen: somebody with a hospital card and no
  /// account.
  static void toClaim() {
    unawaited(
      Get.toNamed<void>(PatientPortalRoutes.claim) ?? Future<void>.value(),
    );
  }

  /// Claim answered; on to setting a password. `offNamed`, because going back
  /// to the claim form with a token already issued would spend a second one
  /// against the same record for no reason.
  static void toActivate(String claimToken) {
    unawaited(
      Get.offNamed<void>(
            PatientPortalRoutes.activate,
            arguments: {'claimToken': claimToken},
          ) ??
          Future<void>.value(),
    );
  }
}
