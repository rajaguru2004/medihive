import 'package:get/get.dart';

import '../../patient_entry.dart';
import '../../patient_portal_navigation.dart';

/// Asking, once the patient has been told what they are agreeing to.
///
/// There is nothing to save here and that is not an omission. Consent is a
/// property of the case session, and the session is created by the interview —
/// so the answer travels forward in [PatientEntry] and the server stamps the
/// moment it was given. A timestamp read on the phone would be the device's
/// clock, which on a borrowed tablet is whatever it happens to be set to.
class PatientConsentController extends GetxController {
  late final PatientEntry entry = PatientEntry.fromArguments(Get.arguments);

  void agree() =>
      PatientPortalNavigation.toInterview(entry.copyWith(consentGiven: true));

  /// "Not now" is a real answer and it costs nothing.
  ///
  /// It goes all the way back to the dashboard rather than one screen back to
  /// the language question: somebody who has declined does not want to be
  /// handed the first half of the same sequence again.
  void decline() => PatientPortalNavigation.backToDashboard();
}
