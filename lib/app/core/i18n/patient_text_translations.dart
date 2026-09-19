/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the patient's own words, in the patient's own language
///
/// `patient_text.dart` says this phase would come last and would be cheap,
/// because every line already has a stable key, already flows through one
/// function, and already carries its placeholders as `{name}` rather than as
/// Dart interpolation. This is that phase, and it cost exactly what that file
/// predicted: a table per language and one call to [PatientText.useLookup].
/// **Not one call site changed.**
///
/// ── Why this had to happen now
///
/// Because the interview is conducted in the patient's language now. The server
/// sends Tamil questions, the Tamil voice reads them aloud, and until this file
/// existed they arrived inside English furniture — "Listening", "Check this",
/// "Send this to the hospital". A Tamil question under an English button is a
/// screen that tells a patient this was not really built for them.
///
/// ── What is deliberately NOT translated
///
/// Anything a clinician reads. `field.label` stays English in the rendered
/// case, exactly as `phrasebook.ts` says it must, and every staff screen in this
/// app is untouched. The line this file draws is the same one the server draws:
/// the patient reads their language, the chart reads English.
///
/// ── The review gate, and what it does and does not cover
///
/// The server refuses to *ask a clinical question* in an unreviewed
/// translation. These are not clinical questions — they are buttons, headings
/// and error messages — so they are not behind that gate, and a wrong word here
/// costs a confusing button rather than a wrong fact on a chart. The questions
/// themselves stay behind `MEDIHIVE_ALLOW_UNREVIEWED_PHRASEBOOKS` where they
/// belong.
///
/// A missing key falls back to the English the call site passed in, so a
/// half-finished table is a half-translated screen and never a blank one.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'patient_text.dart';

/// The patient-facing copy, by language and key.
abstract final class PatientTextTranslations {
  /// Languages this app has patient-facing copy for.
  ///
  /// Mirrors the server's `INTERVIEW_LANGUAGE_CODES`, and for the same reason
  /// that list exists: these are the languages the whole experience is in, not
  /// the ones the recogniser can hear.
  static const Set<String> languages = {'en', 'ta', 'hi'};

  /// Install the table for a language tag, or restore English.
  ///
  /// Takes the tag the session actually carries — `ta`, `ta-IN`, `TA` — and
  /// reduces it the way the server's `normaliseLanguage` does, because the two
  /// are reading the same value out of the same session row.
  ///
  /// Anything unknown installs nothing, which leaves every line on the English
  /// it was written in. That is the same answer a missing key gives, and it is
  /// the right one: a patient reading English is inconvenienced, a patient
  /// reading a key like `draft.accept` is being shown a bug.
  static void use(String? languageTag) {
    final code = _primary(languageTag);
    final table = _tables[code];
    PatientText.useLookup(
      table == null ? null : (key, english) => table[key] ?? english,
    );
  }

  /// Whether this build can put the patient-facing surface in a language.
  ///
  /// True for English with no table, and that is not a special case being
  /// smuggled in: English is the source these lines were written in, not a
  /// translation of something else — the same relationship `phrasebook.ts`
  /// describes between `field.prompt` and the books beside it. A table for it
  /// would be a second copy of every string, free to drift from the call sites.
  static bool has(String? languageTag) =>
      languages.contains(_primary(languageTag));

  static String _primary(String? tag) {
    final trimmed = (tag ?? '').trim().toLowerCase().replaceAll('_', '-');
    return trimmed.split('-').first;
  }

  static const Map<String, Map<String, String>> _tables = {
    'ta': _tamil,
    'hi': _hindi,
  };

  static const Map<String, String> _tamil = {
      'answer.yes': 'ஆம்',
      'answer.no': 'இல்லை',
      'answer.unknown': 'தெரியவில்லை',
      'answer.skip': 'தவிர்',
      'answer.unknown.past': 'தெரியவில்லை',
      'answer.skip.past': 'தவிர்க்கப்பட்டது',
      'answer.change': 'மாற்று',
      'entry.title': 'தொடங்கும் முன்',
      'language.heading': 'உங்கள் மொழியைத் தேர்ந்தெடுங்கள்',
      'language.detail': 'நீங்கள் பேசும் மொழியைத் தேர்ந்தெடுங்கள். கேள்விகளும் அதே மொழியில் திரையில் தெரியும், படித்தும் காட்டப்படும்.',
      'language.continue': 'தொடரவும்',
      'language.voice.unsupported': '{language} மொழியில் வாய்மொழியாக பதிலளிப்பது இன்னும் இயங்கவில்லை. நீங்கள் தட்டச்சு செய்யலாம், அல்லது ஒரு விருப்பத்தைத் தேர்ந்தெடுக்கலாம்.',
      'speak.on': 'கேள்விகளைப் படித்துக் காட்டு',
      'speak.off': 'படிப்பதை நிறுத்து',
      'mic.idle': 'வாய்மொழியாகப் பதிலளியுங்கள்',
      'mic.listening': 'கேட்கிறேன்',
      'mic.stop': 'முடித்ததும் தட்டுங்கள்',
      'mic.working': 'எழுதிக் கொண்டிருக்கிறேன்',
      'live.connecting': 'இணைக்கிறேன்…',
      'live.interim': 'நாங்கள் கேட்பது',
      'live.error.open': 'இப்போது நீங்கள் பேசும்போது கேட்க முடியவில்லை. ஒவ்வொரு கேள்விக்கும் தனியாக வாய்மொழியாகப் பதிலளிக்கலாம், அல்லது தட்டச்சு செய்யலாம்.',
      'live.error.dropped': 'நீங்கள் பேசும்போது கேட்பதை நிறுத்திவிட்டோம். ஒவ்வொரு கேள்விக்கும் தனியாக வாய்மொழியாகப் பதிலளிக்கலாம், அல்லது தட்டச்சு செய்யலாம்.',
      'draft.heading': 'நீங்கள் சொன்னது',
      'draft.accept': 'அது சரி',
      'draft.retry': 'மீண்டும் சொல்லுங்கள்',
      'draft.type': 'தட்டச்சு செய்கிறேன்',
      'confidence.clear': 'தெளிவு',
      'confidence.unsure': 'சரிபாருங்கள்',
      'confidence.unheard': 'கேட்க சிரமம்',
      'source.spoken': 'பேசியது',
      'source.typed': 'தட்டச்சு',
      'source.chosen': 'தேர்வு',
      'source.record': 'உங்கள் பதிவிலிருந்து',
      'progress.step': 'கேள்வி {step} / {total}',
      'redflag.heading': 'இப்போதே ஒரு செவிலியரிடம் சொல்லுங்கள்',
      'redflag.body': 'இந்தக் கேள்விகள் முடியும் வரை காத்திருக்க வேண்டாம். இந்தத் திரையை மேசையில் உள்ளவரிடம் காட்டுங்கள்.',
      'redflag.action': 'செவிலியரிடம் சொல்',
      'permission.microphone.denied': 'மைக்ரோஃபோன் இல்லாமல் வாய்மொழியாகப் பதிலளிக்க முடியாது. நீங்கள் தட்டச்சு செய்யலாம்.',
      'permission.microphone.blocked': 'MediHive-க்கு மைக்ரோஃபோன் அணைக்கப்பட்டுள்ளது. அமைப்புகளில் அதை இயக்குங்கள், அல்லது தட்டச்சு செய்யுங்கள்.',
      'permission.camera.denied': 'கேமரா இல்லாமல் இங்கே புகைப்படம் எடுக்க முடியாது. நீங்கள் விவரித்துச் சொல்லலாம்.',
      'permission.camera.blocked': 'MediHive-க்கு கேமரா அணைக்கப்பட்டுள்ளது. அமைப்புகளில் இயக்குங்கள், அல்லது விவரித்துச் சொல்லுங்கள்.',
      'permission.photos.denied': 'உங்கள் புகைப்படங்களுக்கு அனுமதி இல்லாமல் ஒன்றை இணைக்க முடியாது. புதிதாக ஒரு படம் எடுக்கலாம்.',
      'permission.photos.blocked': 'MediHive-க்கு உங்கள் புகைப்படங்கள் அணைக்கப்பட்டுள்ளன. அமைப்புகளில் இயக்குங்கள், அல்லது புதிதாக ஒரு படம் எடுங்கள்.',
      'permission.settings': 'அமைப்புகளைத் திற',
      'interview.title': 'உங்கள் பதில்கள்',
      'interview.how': 'ஒரு பதிலைத் தட்டுங்கள், தட்டச்சு செய்யுங்கள், அல்லது வாய்மொழியாகச் சொல்லுங்கள்.',
      'interview.type.label': 'உங்கள் பதிலைத் தட்டச்சு செய்யுங்கள்',
      'interview.type.hint': 'இங்கே தட்டச்சு செய்யுங்கள்',
      'interview.type.send': 'அனுப்பு',
      'interview.sending': 'அனுப்புகிறேன்',
      'interview.sending.long': 'உங்கள் பதிலை மருத்துவமனைக்கு அனுப்புகிறேன்…',
      'interview.extracting': 'இன்னும் படித்துக் கொண்டிருக்கிறேன்',
      'interview.voice.unavailable': 'வாய்மொழியாகப் பதிலளிப்பது இப்போது இயங்கவில்லை. நீங்கள் தட்டச்சு செய்யலாம், அல்லது கீழே ஒன்றைத் தட்டலாம்.',
      'interview.voice.empty': 'எதுவும் கேட்கவில்லை. மீண்டும் முயலுங்கள், அல்லது தட்டச்சு செய்யுங்கள்.',
      'interview.voice.short': 'அது கேட்க மிகவும் சுருக்கமாக இருந்தது. இன்னும் கொஞ்சம் நேரம் பேசுங்கள், அல்லது தட்டச்சு செய்யுங்கள்.',
      'interview.live.hint': 'சும்மா பேசுங்கள். நீங்கள் நிறுத்தியதும் அடுத்த கேள்வியைக் கேட்போம்.',
      'interview.live.listening': 'கேட்கிறேன்',
      'interview.live.speaking': 'பேசுகிறேன்',
      'interview.live.exit': 'தட்டவோ தட்டச்சு செய்யவோ செய்கிறேன்',
      'interview.live.exited': 'மீண்டும் தட்டியோ தட்டச்சு செய்தோ பதிலளிக்கலாம்.',
      'interview.done.heading': 'நாங்கள் கேட்க வேண்டியது இத்துடன் முடிந்தது',
      'interview.done.body': 'உங்களைப் பார்ப்பதற்கு முன் மருத்துவர் உங்கள் பதில்களைப் படிப்பார். தேவைப்பட்டால் திரும்பிச் சென்று எதையும் மாற்றலாம்.',
      'interview.done.action': 'இப்போதைக்கு முடிந்தது',
      'interview.done.restart': 'அனுப்பிவிட்டு புதிதாகத் தொடங்கு',
      'interview.done.restart.title': 'இதை மருத்துவமனைக்கு அனுப்பவா?',
      'interview.done.restart.body': 'உங்கள் பதில்கள் இருக்கும் நிலையிலேயே மருத்துவமனைக்கு அனுப்பப்படும், பிறகு மாற்ற முடியாது. அதன் பிறகு புதிய கேள்விகள் தொடங்கும்.',
      'interview.done.restart.confirm': 'அனுப்பிவிட்டு தொடங்கு',
      'interview.done.restart.sent': 'அனுப்பப்பட்டது. புதிய கேள்விகளுக்குப் பதிலளிக்கத் தொடங்கலாம்.',
      'interview.done.restart.halfway': 'உங்கள் பதில்கள் அனுப்பப்பட்டன. புதிய கேள்விகளை இப்போது திறக்க முடியவில்லை — சிறிது நேரத்தில் மீண்டும் முயலுங்கள்.',
      'interview.settling': 'உங்கள் கடைசிப் பதிலை எழுதி முடிக்கிறோம்.',
      'interview.settling.stalled': 'உங்கள் கடைசிப் பதிலைச் சேமிக்க வழக்கத்தை விட நேரம் ஆகிறது. இதுவரையான உங்கள் பதில்கள் பாதுகாப்பாக உள்ளன. மீண்டும் பார்க்கலாம், அல்லது பிறகு வரலாம்.',
      'interview.settling.retry': 'மீண்டும் பார்',
      'interview.error.start': 'உங்கள் கேள்விகளைத் திறக்க முடியவில்லை. இணைப்பைச் சரிபார்த்து மீண்டும் முயலுங்கள்.',
      'interview.error.turn': 'அந்தப் பதில் எங்களை வந்து சேரவில்லை. மீண்டும் முயலுங்கள்.',
      'interview.error.retry': 'மீண்டும் முயல்',
      'interview.offline': 'நீங்கள் நிறுத்திய இடம் இது. இப்போது மருத்துவமனையை அடைய முடியவில்லை, எனவே நீங்கள் மீண்டும் முயலும் வரை புதிதாக எதுவும் சேமிக்க முடியாது.',
      'documents.title': 'உங்கள் ஆவணங்கள்',
      'documents.add': 'ஒரு ஆவணத்தைச் சேர்',
      'documents.camera': 'புகைப்படம் எடு',
      'documents.gallery': 'ஏற்கனவே உள்ள படத்தைத் தேர்ந்தெடு',
      'documents.pdf': 'ஒரு PDF தேர்ந்தெடு',
      'documents.empty.title': 'இன்னும் எதுவும் சேர்க்கப்படவில்லை',
      'documents.empty.body': 'மருந்துச் சீட்டு, அறிக்கை அல்லது வெளியேற்றக் கடிதத்தைப் புகைப்படம் எடுங்கள் — நாங்கள் உங்களுடன் சேர்ந்து படிப்போம்.',
      'documents.sending': 'அனுப்புகிறேன் — {percent}%',
      'documents.too.large': 'அந்தக் கோப்பு {size}, இது எங்களால் ஏற்க முடிந்ததை விட அதிகம். ஒரு பக்கமாகப் புகைப்படம் எடுங்கள், அல்லது சிறிய கோப்பை அனுப்புங்கள்.',
      'documents.error.send': 'அந்த ஆவணம் எங்களை வந்து சேரவில்லை. மீண்டும் முயலுங்கள்.',
      'documents.duplicate.open': 'முதல் நகலைத் திற',
      'documents.error.type': 'அந்த வகைக் கோப்பைப் படிக்க முடியாது. ஆவணத்தின் புகைப்படம் அல்லது PDF தேர்ந்தெடுங்கள்.',
      'documents.review.title': 'நாங்கள் கண்டதைச் சரிபாருங்கள்',
      'documents.original': 'மூலப் படத்தைப் பார்',
      'documents.confidence.title': 'இது எப்படிப் படிக்கப்பட்டது',
      'documents.confidence.ocr': 'பக்கத்தில் இருந்து படித்த எழுத்து',
      'documents.confidence.extraction': 'அந்த எழுத்தில் கண்ட தகவல்',
      'documents.confidence.none': 'அளவிடப்படவில்லை',
      'documents.section.medications': 'மருந்துகள்',
      'documents.section.investigations': 'பரிசோதனை முடிவுகள்',
      'documents.section.diagnoses': 'இந்த ஆவணத்தில் எழுதப்பட்ட நோய் விவரம்',
      'documents.section.procedures': 'சிகிச்சை முறைகள்',
      'documents.section.followup': 'அடுத்து என்ன செய்ய வேண்டும்',
      'documents.section.allergies': 'ஒவ்வாமைகள்',
      'documents.value.corrected': 'இதை நீங்கள் திருத்தினீர்கள்',
      'documents.value.confirmed': 'இதை நீங்கள் உறுதிப்படுத்தினீர்கள்',
      'documents.value.unsure': 'இதைப் பற்றி உங்களுக்கு உறுதியில்லை',
      'documents.value.unchecked': 'இன்னும் சரிபார்க்கப்படவில்லை',
      'documents.correct.hint': 'இது என்ன சொல்ல வேண்டும்?',
      'documents.correct.save': 'சேமி',
      'documents.verify': 'இந்த ஆவணத்தை உறுதிப்படுத்து',
      'documents.verify.done': 'நன்றி. அது உறுதிப்படுத்தப்பட்டது.',
      'documents.verify.blocked': 'இங்கே ஏதோ தவறாகவோ உறுதியில்லாமலோ இருப்பதால், இந்த ஆவணத்தைச் சரி என்று குறிக்க மாட்டோம். ஒரு மருத்துவர் உங்களுடன் சேர்ந்து இதைப் பார்ப்பார்.',
      'review.title': 'நாங்கள் புரிந்து கொண்டது',
      'review.intro': 'உங்களைப் பற்றி நாங்கள் புரிந்து கொண்டது இதுதான். இதைப் படித்து, சரியில்லாத எதையும் அனுப்பும் முன் மாற்றுங்கள்.',
      'review.disclaimer': 'நீங்கள் சொன்னதை எழுதி வைத்திருக்கிறோம். இது நோய் கண்டறிதல் அல்ல, உங்களைப் பற்றி இங்கே எதுவும் முடிவு செய்யப்படவில்லை.',
      'review.missing.title': 'இன்னும் கேட்க வேண்டியவை',
      'review.missing.body': 'இவற்றைப் பற்றி இன்னும் யாரும் உங்களிடம் கேட்கவில்லை. மௌனம் ஒரு பதிலாகப் படிக்கப்படக் கூடாது என்பதற்காக இவை பட்டியலிடப்பட்டுள்ளன.',
      'review.contradiction.title': 'இவற்றைச் சரிபாருங்கள்',
      'review.contradiction.body': 'மருத்துவமனையில் ஏற்கனவே உள்ளதிலிருந்து இவை மாறுபடுகின்றன. நாங்கள் எதையும் மாற்றவில்லை — எது சரி என்று மேசையில் சொல்லுங்கள்.',
      'review.contradiction.document': 'நீங்கள் அனுப்பிய ஆவணத்தில்',
      'review.contradiction.record': 'உங்கள் பதிவில் ஏற்கனவே',
      'review.contradiction.new': 'உங்கள் பதிவில் இது இன்னும் இல்லை',
      'review.submit': 'இதை மருத்துவமனைக்கு அனுப்பு',
      'review.submitted.title': 'உங்கள் பதில்கள் அனுப்பப்பட்டன',
      'review.submitted.body': 'உங்களைப் பார்ப்பதற்கு முன் மருத்துவர் அவற்றைப் படிப்பார்.',
      'review.submitted.locked': 'இது ஏற்கனவே மருத்துவமனைக்கு அனுப்பப்பட்டுவிட்டது, எனவே இங்கே மாற்ற முடியாது. ஏதேனும் தவறு இருந்தால் மேசையில் சொல்லுங்கள்.',
      'review.error.submit': 'அது மருத்துவமனையை வந்து சேரவில்லை. மீண்டும் முயலுங்கள்.',
      'review.error.correct': 'அந்த மாற்றம் எங்களை வந்து சேரவில்லை. மீண்டும் முயலுங்கள்.',
      'review.progress': '{expected}-ல் {addressed} பதிலளிக்கப்பட்டது',
  };

  static const Map<String, String> _hindi = {
      'answer.yes': 'हाँ',
      'answer.no': 'नहीं',
      'answer.unknown': 'पता नहीं',
      'answer.skip': 'छोड़ें',
      'answer.unknown.past': 'पक्का नहीं',
      'answer.skip.past': 'छोड़ा गया',
      'answer.change': 'बदलें',
      'entry.title': 'शुरू करने से पहले',
      'language.heading': 'अपनी भाषा चुनिए',
      'language.detail': 'वह भाषा चुनिए जिसमें आप बोलेंगे। सवाल भी उसी भाषा में स्क्रीन पर दिखेंगे और पढ़कर सुनाए जाएँगे।',
      'language.continue': 'आगे बढ़ें',
      'language.voice.unsupported': '{language} में बोलकर जवाब देना अभी काम नहीं करता। आप टाइप कर सकते हैं, या नीचे से कोई विकल्प चुन सकते हैं।',
      'speak.on': 'सवाल पढ़कर सुनाइए',
      'speak.off': 'पढ़ना बंद कीजिए',
      'mic.idle': 'बोलकर जवाब दीजिए',
      'mic.listening': 'सुन रहा हूँ',
      'mic.stop': 'बोलना पूरा होने पर दबाइए',
      'mic.working': 'लिख रहा हूँ',
      'live.connecting': 'जोड़ रहा हूँ…',
      'live.interim': 'हम सुन रहे हैं',
      'live.error.open': 'अभी आपके बोलते समय सुन नहीं पा रहे। आप एक-एक सवाल का जवाब बोलकर दे सकते हैं, या टाइप कर सकते हैं।',
      'live.error.dropped': 'आपके बोलते समय सुनना बंद हो गया है। आप एक-एक सवाल का जवाब बोलकर दे सकते हैं, या टाइप कर सकते हैं।',
      'draft.heading': 'आपने कहा',
      'draft.accept': 'यह सही है',
      'draft.retry': 'फिर से बोलिए',
      'draft.type': 'टाइप करता हूँ',
      'confidence.clear': 'साफ़',
      'confidence.unsure': 'जाँच लीजिए',
      'confidence.unheard': 'सुनने में मुश्किल',
      'source.spoken': 'बोला गया',
      'source.typed': 'टाइप किया',
      'source.chosen': 'चुना गया',
      'source.record': 'आपके रिकॉर्ड से',
      'progress.step': 'सवाल {step} / {total}',
      'redflag.heading': 'अभी नर्स को बताइए',
      'redflag.body': 'इन सवालों के ख़त्म होने का इंतज़ार मत कीजिए। यह स्क्रीन डेस्क पर किसी को दिखाइए।',
      'redflag.action': 'नर्स को बताएँ',
      'permission.microphone.denied': 'माइक्रोफ़ोन के बिना आप बोलकर जवाब नहीं दे सकते। आप टाइप कर सकते हैं।',
      'permission.microphone.blocked': 'MediHive के लिए माइक्रोफ़ोन बंद है। सेटिंग्स में चालू कीजिए, या टाइप कीजिए।',
      'permission.camera.denied': 'कैमरे के बिना आप यहाँ फ़ोटो नहीं ले सकते। आप बताकर समझा सकते हैं।',
      'permission.camera.blocked': 'MediHive के लिए कैमरा बंद है। सेटिंग्स में चालू कीजिए, या बताकर समझाइए।',
      'permission.photos.denied': 'आपकी फ़ोटो तक पहुँच के बिना आप कोई फ़ोटो नहीं जोड़ सकते। नई फ़ोटो ले सकते हैं।',
      'permission.photos.blocked': 'MediHive के लिए आपकी फ़ोटो बंद हैं। सेटिंग्स में चालू कीजिए, या नई फ़ोटो लीजिए।',
      'permission.settings': 'सेटिंग्स खोलें',
      'interview.title': 'आपके जवाब',
      'interview.how': 'कोई जवाब दबाइए, टाइप कीजिए, या बोलकर बताइए।',
      'interview.type.label': 'अपना जवाब टाइप कीजिए',
      'interview.type.hint': 'यहाँ टाइप कीजिए',
      'interview.type.send': 'भेजें',
      'interview.sending': 'भेज रहा हूँ',
      'interview.sending.long': 'आपका जवाब अस्पताल भेज रहा हूँ…',
      'interview.extracting': 'अभी पढ़ रहा हूँ',
      'interview.voice.unavailable': 'बोलकर जवाब देना अभी काम नहीं कर रहा। आप टाइप कर सकते हैं, या नीचे से कोई चुन सकते हैं।',
      'interview.voice.empty': 'हमें कुछ सुनाई नहीं दिया। फिर कोशिश कीजिए, या टाइप कीजिए।',
      'interview.voice.short': 'वह सुनने के लिए बहुत छोटा था। थोड़ी देर और बोलिए, या टाइप कीजिए।',
      'interview.live.hint': 'बस बोलते रहिए। जब आप रुकेंगे, हम अगला सवाल पूछेंगे।',
      'interview.live.listening': 'सुन रहा हूँ',
      'interview.live.speaking': 'बोल रहा हूँ',
      'interview.live.exit': 'दबाकर या टाइप करके जवाब दूँगा',
      'interview.live.exited': 'आप फिर से दबाकर या टाइप करके जवाब दे सकते हैं।',
      'interview.done.heading': 'हमें जो पूछना था, वह पूरा हो गया',
      'interview.done.body': 'डॉक्टर आपको देखने से पहले आपके जवाब पढ़ेंगे। ज़रूरत हो तो आप वापस जाकर कुछ भी बदल सकते हैं।',
      'interview.done.action': 'अभी के लिए हो गया',
      'interview.done.restart': 'भेजकर नया शुरू करें',
      'interview.done.restart.title': 'इसे अस्पताल भेजें?',
      'interview.done.restart.body': 'आपके जवाब जैसे हैं वैसे ही अस्पताल भेज दिए जाएँगे, और उसके बाद बदले नहीं जा सकेंगे। फिर नए सवाल शुरू होंगे।',
      'interview.done.restart.confirm': 'भेजें और शुरू करें',
      'interview.done.restart.sent': 'भेज दिया गया। आप नए सवालों के जवाब देना शुरू कर सकते हैं।',
      'interview.done.restart.halfway': 'आपके जवाब भेज दिए गए। नए सवाल अभी नहीं खुल पाए — थोड़ी देर में फिर कोशिश कीजिए।',
      'interview.settling': 'हम आपका आख़िरी जवाब लिख रहे हैं।',
      'interview.settling.stalled': 'आपका आख़िरी जवाब सहेजने में सामान्य से ज़्यादा समय लग रहा है। अब तक के आपके जवाब सुरक्षित हैं। आप फिर देख सकते हैं, या बाद में आ सकते हैं।',
      'interview.settling.retry': 'फिर देखें',
      'interview.error.start': 'हम आपके सवाल नहीं खोल पाए। अपना कनेक्शन देखकर फिर कोशिश कीजिए।',
      'interview.error.turn': 'वह जवाब हम तक नहीं पहुँचा। फिर कोशिश कीजिए।',
      'interview.error.retry': 'फिर कोशिश करें',
      'interview.offline': 'आप यहीं तक पहुँचे थे। अभी हम अस्पताल तक नहीं पहुँच पाए, इसलिए आपके दोबारा कोशिश करने तक कुछ नया सहेजा नहीं जा सकेगा।',
      'documents.title': 'आपके दस्तावेज़',
      'documents.add': 'दस्तावेज़ जोड़ें',
      'documents.camera': 'फ़ोटो लें',
      'documents.gallery': 'पहले से मौजूद फ़ोटो चुनें',
      'documents.pdf': 'PDF चुनें',
      'documents.empty.title': 'अभी कुछ नहीं जोड़ा गया',
      'documents.empty.body': 'पर्ची, रिपोर्ट या डिस्चार्ज लेटर की फ़ोटो लीजिए — हम उसे आपके साथ पढ़ेंगे।',
      'documents.sending': 'भेज रहा हूँ — {percent}%',
      'documents.too.large': 'वह फ़ाइल {size} की है, जो हमारी सीमा से ज़्यादा है। एक-एक पन्ने की फ़ोटो लीजिए, या छोटी फ़ाइल भेजिए।',
      'documents.error.send': 'वह दस्तावेज़ हम तक नहीं पहुँचा। फिर कोशिश कीजिए।',
      'documents.duplicate.open': 'पहली कॉपी खोलें',
      'documents.error.type': 'उस तरह की फ़ाइल पढ़ी नहीं जा सकती। दस्तावेज़ की फ़ोटो चुनिए, या PDF।',
      'documents.review.title': 'हमें जो मिला, उसे जाँच लीजिए',
      'documents.original': 'मूल देखें',
      'documents.confidence.title': 'यह कैसे पढ़ा गया',
      'documents.confidence.ocr': 'पन्ने से पढ़ा गया लेख',
      'documents.confidence.extraction': 'उस लेख में मिली जानकारी',
      'documents.confidence.none': 'मापा नहीं गया',
      'documents.section.medications': 'दवाइयाँ',
      'documents.section.investigations': 'जाँच के नतीजे',
      'documents.section.diagnoses': 'इस दस्तावेज़ में लिखी बीमारियाँ',
      'documents.section.procedures': 'प्रक्रियाएँ',
      'documents.section.followup': 'आगे क्या करना है',
      'documents.section.allergies': 'एलर्जी',
      'documents.value.corrected': 'आपने इसे ठीक किया',
      'documents.value.confirmed': 'आपने इसकी पुष्टि की',
      'documents.value.unsure': 'आपको इस पर पक्का नहीं',
      'documents.value.unchecked': 'अभी जाँचा नहीं गया',
      'documents.correct.hint': 'इसमें क्या लिखा होना चाहिए?',
      'documents.correct.save': 'सहेजें',
      'documents.verify': 'इस दस्तावेज़ की पुष्टि करें',
      'documents.verify.done': 'धन्यवाद। इसकी पुष्टि हो गई।',
      'documents.verify.blocked': 'यहाँ कुछ ग़लत या अनिश्चित होने के कारण हम इस दस्तावेज़ को सही नहीं मानेंगे। एक चिकित्सक इसे आपके साथ देखेंगे।',
      'review.title': 'हमने जो समझा',
      'review.intro': 'आपके बारे में हमने यह समझा है। इसे पढ़िए और भेजने से पहले जो सही न हो उसे बदल दीजिए।',
      'review.disclaimer': 'यह वही है जो आपने हमें बताया, लिखा हुआ। यह कोई निदान नहीं है, और यहाँ आपके बारे में कुछ तय नहीं किया गया है।',
      'review.missing.title': 'अभी पूछना बाक़ी है',
      'review.missing.body': 'इनके बारे में अभी किसी ने आपसे नहीं पूछा। ये इसलिए दिखाए गए हैं ताकि चुप्पी को जवाब न समझ लिया जाए।',
      'review.contradiction.title': 'इन्हें जाँच लीजिए',
      'review.contradiction.body': 'ये उससे अलग हैं जो अस्पताल के पास पहले से है। हमने कुछ भी नहीं बदला — कृपया डेस्क पर बताइए कि कौन-सा सही है।',
      'review.contradiction.document': 'आपके भेजे दस्तावेज़ में',
      'review.contradiction.record': 'आपके रिकॉर्ड में पहले से',
      'review.contradiction.new': 'आपके रिकॉर्ड में इसका ज़िक्र अभी नहीं है',
      'review.submit': 'इसे अस्पताल भेजें',
      'review.submitted.title': 'आपके जवाब भेज दिए गए हैं',
      'review.submitted.body': 'डॉक्टर आपको देखने से पहले इन्हें पढ़ेंगे।',
      'review.submitted.locked': 'यह अस्पताल भेजा जा चुका है, इसलिए यहाँ बदला नहीं जा सकता। कुछ ग़लत हो तो डेस्क पर बताइए।',
      'review.error.submit': 'वह अस्पताल तक नहीं पहुँचा। फिर कोशिश कीजिए।',
      'review.error.correct': 'वह बदलाव हम तक नहीं पहुँचा। फिर कोशिश कीजिए।',
      'review.progress': '{expected} में से {addressed} के जवाब मिले',
  };
}
