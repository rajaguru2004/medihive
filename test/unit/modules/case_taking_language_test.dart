import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/data/models/case_session.dart';
import 'package:medihive/app/data/repositories/case_taking_repository.dart';
import 'package:medihive/app/data/services/audio_source.dart';
import 'package:medihive/app/data/services/speech_player.dart';
import 'package:medihive/app/modules/case_taking/controllers/case_taking_controller.dart';
import 'package:medihive/app/modules/patient_portal/patient_entry.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the two languages of one interview
///
/// The patient picks the language they will **speak**. Everything they read and
/// everything they hear is **English**. So the session carries two tags and not
/// one, and the whole of this file is about them not being swapped.
///
/// A swap fails silently and fails badly in both directions:
///
///   * **Input on `/tts`** reads an English question aloud with a Tamil voice —
///     audible nonsense to the one patient the audio exists for, somebody who
///     cannot comfortably read the screen.
///
///   * **Output on `/stt`** hands `faster-whisper` an English hint for a Tamil
///     answer, and what comes back is not a refusal. It is a plausible English
///     sentence the patient never said, filed against their chart.
///
/// The third property is tolerance. The split is being built on the server
/// while this runs against deployments that have not shipped it, and a session
/// arriving with the single old `language` tag must behave exactly as it did
/// before the split existed — not fall back to a constant, which would read a
/// Tamil interview aloud in English.
/// ─────────────────────────────────────────────────────────────────────────────

/// Answers both voice routes without a socket, and keeps the tag it was given.
class _LanguageSpyRepository extends CaseTakingRepository {
  final List<String?> transcribed = [];
  final List<String?> spoken = [];

  @override
  Future<CaseTranscript> transcribe(
    RecordedAudio audio, {
    String? language,
  }) async {
    transcribed.add(language);
    // Non-empty on purpose: an empty transcript takes the toast path, which
    // wants a widget tree this tier does not have.
    return const CaseTranscript(text: 'it started on Tuesday', confidence: 0.9);
  }

  @override
  Future<Uint8List> speak(String text, {String? language}) async {
    spoken.add(language);
    return Uint8List(0);
  }
}

/// A player that is available, which `StubSpeechPlayer` deliberately is not —
/// and read-aloud is hidden entirely on a player that is not.
class _AvailableSpeechPlayer implements SpeechPlayer {
  @override
  bool get isAvailable => true;

  @override
  Future<void> play(Uint8List wav) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _LanguageSpyRepository repository;
  late CaseTakingController controller;

  CaseSession sessionWith(Map<String, dynamic> language) =>
      CaseSession.fromJson({
        'id': 'session-1',
        'status': 'in_progress',
        ...language,
      });

  const question = CaseQuestion(
    fieldPath: 'hpi.onset',
    section: 'hpi',
    label: 'Onset',
    kind: CaseQuestionKind.text,
    prompt: 'When did it start?',
  );

  /// Two taps: one to open the microphone, one to close it and send.
  Future<void> answerOutLoud() async {
    await controller.toggleMicrophone();
    await controller.toggleMicrophone();
  }

  /// Off and on again, which is the one public path that reads the question on
  /// the table rather than waiting for the next one.
  Future<void> readTheQuestionAloud() async {
    controller.rxQuestion.value = question;
    controller.toggleReadAloud();
    controller.toggleReadAloud();
    await pumpEventQueue();
  }

  setUp(() {
    repository = _LanguageSpyRepository();
    Get.put<AudioSource>(StubAudioSource());
    Get.put<SpeechPlayer>(_AvailableSpeechPlayer());
    controller = CaseTakingController(repository: repository);
  });

  tearDown(() {
    controller.onClose();
    Get.reset();
  });

  group('the session as the phone reads it', () {
    test('it keeps both tags when the server sends both', () {
      final session = sessionWith(const {
        'language': 'ta',
        'inputLanguage': 'ta',
        'outputLanguage': 'en',
      });

      expect(session.inputLanguage, 'ta');
      expect(session.outputLanguage, 'en');
    });

    test('either spelling of the key is read', () {
      // The split is being written on the server while this is being written
      // here, and `inputLanguage` / `input_language` / `sttLanguage` are three
      // names two people would each pick one of.
      expect(
        sessionWith(const {'input_language': 'ta'}).inputLanguage,
        'ta',
      );
      expect(
        sessionWith(const {'ttsLanguage': 'en'}).outputLanguage,
        'en',
      );
    });

    test('a session with no split carries no split', () {
      // Null, never `language` and never `en`. Absence means "this server has
      // not split the session", and only the caller knows what to do about it.
      final session = sessionWith(const {'language': 'ta'});

      expect(session.language, 'ta');
      expect(session.inputLanguage, isNull);
      expect(session.outputLanguage, isNull);
    });
  });

  group('what `/stt` is told', () {
    test('it is the language the patient speaks', () async {
      controller.rxSession.value = sessionWith(const {
        'language': 'ta',
        'inputLanguage': 'ta',
        'outputLanguage': 'en',
      });

      await answerOutLoud();

      expect(repository.transcribed, ['ta']);
    });

    test('a tag this build cannot name still reaches the sidecar', () async {
      // The hospital's transcriber may well have a model this app has no row
      // for. Narrowing the tag to a known language here would quietly
      // transcribe somebody's Urdu as English — and an English sentence the
      // patient never said is worse than no transcript at all.
      controller.rxSession.value = sessionWith(const {'inputLanguage': 'ur'});

      await answerOutLoud();

      expect(repository.transcribed, ['ur']);
    });

    test('with no session yet, it is what the patient picked', () async {
      // The entry screen's answer is the floor for the moment before the
      // session lands, and for the case where it never does.
      expect(controller.entry.language, PatientLanguage.english);

      await answerOutLoud();

      expect(repository.transcribed, ['en']);
    });
  });

  group('what `/tts` is told', () {
    test('it is the language the question is written in', () async {
      controller.rxSession.value = sessionWith(const {
        'language': 'ta',
        'inputLanguage': 'ta',
        'outputLanguage': 'en',
      });

      await readTheQuestionAloud();

      // English, though the patient picked Tamil. The voice reads the prompt
      // the server sent, so the only correct voice is the one that matches
      // that text.
      expect(repository.spoken, ['en']);
    });
  });

  group('a server that has not split its sessions yet', () {
    test('both routes fall back to the one tag it does send', () async {
      controller.rxSession.value = sessionWith(const {'language': 'ta'});

      await answerOutLoud();
      await readTheQuestionAloud();

      // Exactly the behaviour before the split existed. A fallback of `en` on
      // the output side would read a Tamil question aloud in an English voice.
      expect(repository.transcribed, ['ta']);
      expect(repository.spoken, ['ta']);
    });
  });

  group('the two capability gates', () {
    test('the microphone follows what the patient speaks', () {
      controller.rxSession.value = sessionWith(const {
        'inputLanguage': 'or',
        'outputLanguage': 'en',
      });

      expect(controller.spokenLanguage, PatientLanguage.odia);
      expect(controller.spokenLanguage.canSpeak, isFalse);
    });

    test('read-aloud follows the language of the questions', () async {
      // The change this file exists for. Odia has no transcriber and never
      // had a missing voice, and the questions are English now — so an Odia
      // patient keeps the audio they were previously judged against their own
      // language for.
      controller.rxSession.value = sessionWith(const {
        'inputLanguage': 'or',
        'outputLanguage': 'en',
      });

      expect(controller.readAloudLanguage, PatientLanguage.english);
      expect(controller.canReadAloud, isTrue);

      await readTheQuestionAloud();
      expect(repository.spoken, ['en']);
    });
  });
}
