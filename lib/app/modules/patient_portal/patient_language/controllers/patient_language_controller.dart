import 'package:get/get.dart';

import '../../patient_entry.dart';
import '../../patient_portal_navigation.dart';

/// The first question of the interview, asked before the interview starts.
///
/// It is here rather than inside the conversation because the answer decides
/// what language the conversation is *in* — and a question about language
/// asked in a language the patient does not read is not a question.
class PatientLanguageController extends GetxController {
  /// Whatever the dashboard passed. Empty on a deep link, which is why
  /// `PatientEntry.fromArguments` falls back rather than throwing.
  late final PatientEntry entry = PatientEntry.fromArguments(Get.arguments);

  late final Rx<PatientLanguage> selected = entry.language.obs;

  /// What the screen offers. One entry today; see [PatientLanguage].
  List<PatientLanguage> get languages => PatientLanguage.available;

  /// True while this build ships a single language, which is what the screen
  /// uses to decide whether to say so out loud.
  ///
  /// Derived rather than hardcoded: the line disappears on its own the moment
  /// the translation phase adds a second entry, rather than sitting there
  /// promising languages that have already arrived.
  bool get isSingleLanguage => languages.length == 1;

  void choose(PatientLanguage language) => selected.value = language;

  void continueToConsent() =>
      PatientPortalNavigation.toConsent(entry.copyWith(language: selected.value));
}
