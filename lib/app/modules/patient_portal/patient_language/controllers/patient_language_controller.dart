import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/app_log.dart';
import '../../../../core/i18n/patient_text_translations.dart';
import '../../../../data/repositories/case_taking_repository.dart';
import '../../patient_entry.dart';
import '../../patient_portal_navigation.dart';
/// The first question of the interview, asked before the interview starts.
///
/// It is here rather than inside the conversation because the answer decides
/// what language the conversation is *in* — and a question about language
/// asked in a language the patient does not read is not a question.
class PatientLanguageController extends GetxController {
  PatientLanguageController({
    CaseTakingRepository repository = const CaseTakingRepository(),
  }) : _repository = repository;

  final CaseTakingRepository _repository;

  /// Whatever the dashboard passed. Empty on a deep link, which is why
  /// `PatientEntry.fromArguments` falls back rather than throwing.
  late final PatientEntry entry = PatientEntry.fromArguments(Get.arguments);

  late final Rx<PatientLanguage> selected = entry.language.obs;

  /// What the screen offers, starting from what the app shipped with.
  ///
  /// Seeded rather than empty, and that is the whole posture of this screen:
  /// the twelve rows are on the tablet and are on screen in the first frame.
  /// [_loadOfferedLanguages] can only narrow the list or correct what it says
  /// about the microphone.
  final RxList<PatientLanguageOffer> rxLanguages =
      PatientLanguageOffer.catalogue.obs;

  /// The row that is currently chosen, as the list holds it.
  ///
  /// By identity out of [rxLanguages] rather than by building a fresh offer, so
  /// the tile the patient tapped is the tile that draws as selected — and so
  /// that this follows the list when the server's answer replaces it.
  PatientLanguageOffer? get selectedOffer {
    for (final offer in rxLanguages) {
      if (offer.language == selected.value) return offer;
    }
    return null;
  }

  /// True where the chosen language can be read to the patient but not spoken
  /// back — which is what the notice under the list is for.
  bool get selectedCannotBeSpoken => selectedOffer?.canSpeak == false;

  @override
  void onReady() {
    super.onReady();
    // `onReady`, never `onInit`: the first widget to touch `controller`
    // constructs it, and a write to an observable during that build marks the
    // building `Obx` dirty.
    unawaited(_loadOfferedLanguages());
  }

  /// Tap a row and the screen changes language under your finger.
  ///
  /// The tile is the only sentence on this screen a patient who does not read
  /// English can act on — it carries the language's name in its own script, and
  /// that is deliberate. Everything around it stays English until they have
  /// chosen, because until they have chosen there is nothing to choose it in.
  ///
  /// So the heading, the detail line and the Continue button switch here, at
  /// the tap, rather than one screen later when the session is created. It is
  /// also the first proof the patient gets that the app really does speak their
  /// language, which is worth more on this screen than on any other.
  void choose(PatientLanguageOffer offer) {
    selected.value = offer.language;
    PatientTextTranslations.use(offer.language.code);
  }

  void continueToConsent() => PatientPortalNavigation.toConsent(
        entry.copyWith(language: selected.value),
      );

  /// Asks the hospital which languages its sidecar can actually work in.
  ///
  /// **Not `runGuarded`, and no `ErrorRetryBanner`** — which is the one place
  /// this controller departs from `.agents/RULES.md` §3.3, so it is worth
  /// saying why. That rule is for a screen with nothing to show until a request
  /// lands; this screen is fully drawn before the call is made. Putting a retry
  /// banner in front of a patient over a list the tablet already has would be
  /// asking them to fix the hospital's network before they are allowed to say
  /// they read Tamil.
  ///
  /// So a failure is logged and nothing else happens. The failure that *would*
  /// be visible — a microphone offered in a language the transcriber cannot
  /// hear — is caught in the interview instead, where `_withdrawVoice` takes
  /// the control away with a sentence the first time it proves unavailable.
  Future<void> _loadOfferedLanguages() async {
    try {
      final offered = PatientLanguageOffer.merge(await _repository.languages());

      // An empty answer is not an instruction to offer nothing. It is a route
      // that is not mounted yet, a list that has not been seeded, or a payload
      // shaped differently from the one this build parses — and a language
      // screen with no languages on it is a patient who cannot start.
      if (offered.isEmpty) return;

      rxLanguages.assignAll(offered);

      // The language in hand may not have survived the narrowing — a deep link
      // carrying `ta` into a hospital that has taken Tamil down, or simply the
      // default. Moving the selection is better than leaving it pointing at a
      // row that is no longer on screen, where "Continue" would start an
      // interview in a language nothing here offered.
      if (selectedOffer == null) selected.value = offered.first.language;
    } catch (error, stack) {
      AppLog.error(
        'PatientLanguageController',
        'the language list did not load; offering the built-in one',
        error,
        stack,
      );
    }
  }
}
