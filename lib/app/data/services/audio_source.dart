/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — where a spoken answer comes from
///
/// Case-taking asks a patient about their own body, and a patient who is
/// frightened, in pain, or holding a phone in one hand types badly and speaks
/// fine. The case-taking screens need one thing from a microphone: bytes, a
/// filename, a media type and how long it ran. That is a small enough surface
/// to state here and inject, which is what keeps the controller testable
/// without a platform channel — a recorder plugin answers over the method
/// channel, and a method channel in a widget test is a stub either way.
///
/// The same seam `image_source.dart` established for radiology and
/// `file_source.dart` for the analyser imports, deliberately spelled the same
/// way. Two seams that differ only in their vocabulary are two seams somebody
/// has to read twice.
///
/// ## Why this one has four methods where the other two have one
///
/// Picking is a question with an answer. Recording is a thing that runs: it
/// starts when a thumb goes down, it has a level while it runs, and it either
/// finishes or is thrown away. A single `Future<RecordedAudio?> record()`
/// would have nowhere to put the stop, so [AudioSource] states the whole
/// lifecycle and nothing more. [level] is here rather than in the widget
/// because the only honest source of a level meter is the audio itself.
///
/// ## Why it never touches the filesystem
///
/// `record` will write a file and hand back a path, and the obvious
/// implementation reads that file and deletes it. This one streams raw PCM
/// into memory instead and wraps it in a WAV header at the end
/// ([SpeechAudio.wavFromPcm16]). Two reasons, and the second is the one that
/// decided it:
///
///  * A patient's recorded voice on a **shared ward tablet** is the single
///    most identifying thing this app has ever held. A file is something that
///    survives a crash, a backup and the next person to pick the device up; a
///    buffer that is cleared on cancel is not.
///  * The duration comes out exact. A compressed container has to be decoded
///    before anything can say how long it is, and a recording whose length is
///    unknown is one nothing downstream can sanity-check.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

/// The one audio format this app records, ships and stubs.
///
/// 16 kHz mono 16-bit PCM: the format every speech transcriber asks for, and
/// small enough that half a minute of talking is under a megabyte over ward
/// wifi. Stated once so the recorder, the stub and the tests cannot drift.
abstract final class SpeechAudio {
  static const int sampleRate = 16000;
  static const int channels = 1;
  static const int bitsPerSample = 16;

  /// Sent explicitly rather than guessed from the extension: Dio types a part
  /// it was given no type for as `application/octet-stream`, and an upload
  /// route judging on the filename alone is a route that accepts anything.
  static const String mimeType = 'audio/wav';

  /// The 44-byte RIFF/WAVE preamble.
  static const int headerBytes = 44;

  static int get _bytesPerSample => bitsPerSample ~/ 8;

  /// How long [byteCount] bytes of PCM runs for, in milliseconds.
  ///
  /// Exact, because PCM is a fixed number of bytes per second. This is the
  /// whole reason the recorder streams rather than writing a compressed file.
  static int durationMsOfPcm16(int byteCount) =>
      (byteCount * 1000) ~/ (sampleRate * channels * _bytesPerSample);

  /// Wraps raw little-endian 16-bit PCM in a WAV header.
  ///
  /// Nothing clever: the canonical 44-byte header, which is what makes the
  /// result a file a browser, a clinician's phone and an ffmpeg pipeline all
  /// open without being told what it is.
  static Uint8List wavFromPcm16(Uint8List pcm) {
    final header = ByteData(headerBytes);
    final byteRate = sampleRate * channels * _bytesPerSample;

    _tag(header, 0, 'RIFF');
    // Everything after this field: the 36 remaining header bytes plus the audio.
    header.setUint32(4, 36 + pcm.lengthInBytes, Endian.little);
    _tag(header, 8, 'WAVE');

    _tag(header, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // PCM fmt chunks are 16 bytes.
    header.setUint16(20, 1, Endian.little); // 1 = uncompressed PCM.
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, channels * _bytesPerSample, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    _tag(header, 36, 'data');
    header.setUint32(40, pcm.lengthInBytes, Endian.little);

    return (BytesBuilder(copy: false)
          ..add(header.buffer.asUint8List())
          ..add(pcm))
        .takeBytes();
  }

  /// A 0…1 level for one chunk of PCM, for the listening indicator.
  ///
  /// Logarithmic, spanning the bottom 50 dB. A meter that is linear in
  /// amplitude sits almost on the floor for ordinary speech — a conversational
  /// voice is around a tenth of full scale — so a linear bar barely moves
  /// while somebody is talking and reads as "this is not picking me up".
  ///
  /// The samples are read a byte at a time rather than through
  /// [ByteBuffer.asInt16List], which requires a two-byte-aligned offset and
  /// throws on a chunk the platform happened to hand over as a view into a
  /// larger buffer.
  static double levelOfPcm16(Uint8List pcm) {
    if (pcm.length < 2) return 0;

    var sumOfSquares = 0.0;
    var count = 0;
    for (var i = 0; i + 1 < pcm.length; i += 2) {
      final raw = pcm[i] | (pcm[i + 1] << 8);
      final sample = raw >= 0x8000 ? raw - 0x10000 : raw;
      sumOfSquares += sample * sample;
      count++;
    }
    if (count == 0) return 0;

    final rms = math.sqrt(sumOfSquares / count) / 32768;
    if (rms <= 0) return 0;

    const floorDb = -50.0;
    final db = 20 * math.log(rms) / math.ln10;
    return ((db - floorDb) / -floorDb).clamp(0.0, 1.0);
  }

  static void _tag(ByteData out, int offset, String tag) {
    for (var i = 0; i < tag.length; i++) {
      out.setUint8(offset + i, tag.codeUnitAt(i));
    }
  }
}

/// One spoken answer, ready to be posted as a multipart part.
class RecordedAudio {
  const RecordedAudio({
    required this.bytes,
    required this.filename,
    required this.mimeType,
    required this.durationMs,
  });

  final Uint8List bytes;

  /// What the server files it under. Carries its extension, because the bucket
  /// key is built from it.
  ///
  /// Deliberately carries nothing about the patient and nothing from the
  /// clock. A filename travels through logs, bucket listings and support
  /// tickets that no retention policy covers, and the route already knows
  /// which question and which case this belongs to without being told twice.
  final String filename;

  final String mimeType;

  /// How long the recording runs. Exact — see [SpeechAudio.durationMsOfPcm16].
  final int durationMs;

  int get sizeInBytes => bytes.length;

  /// What an upload route will allow. Stated here so a screen can refuse an
  /// over-long recording with a sentence instead of sending four minutes of
  /// audio over ward wifi to be told no. At 16 kHz mono this is about five
  /// minutes, which is far longer than any single answer.
  static const int maxBytes = 10 * 1024 * 1024;

  bool get isTooLarge => sizeInBytes > maxBytes;

  /// Below this, a recording is a thumb brushing the button rather than an
  /// answer. Sending it produces an empty transcript, which reads downstream
  /// as "the patient said nothing" — a clinical fact that is not true.
  static const int minDurationMs = 300;

  bool get isTooShort => durationMs < minDurationMs;

  /// `0:07`. Beside the play control, because a waveform alone does not tell
  /// somebody whether they caught the whole sentence.
  String get durationLabel {
    final totalSeconds = durationMs ~/ 1000;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '${totalSeconds ~/ 60}:$seconds';
  }
}

/// A source of spoken answers.
///
/// Every method is safe to call in any order. A [stop] with no [start] before
/// it answers null rather than throwing: the screen that ends up doing that is
/// one where a patient let go of the button on a frame the recorder had not
/// started on yet, and that is not an error worth a dialog.
abstract interface class AudioSource {
  /// Begins recording.
  ///
  /// Throws a `MediaRefusal` when the microphone is refused — **never** a
  /// silent return. See `media_access.dart` for why a denial cannot share the
  /// null that means "changed their mind".
  Future<void> start();

  /// Ends the recording and hands back what was captured.
  ///
  /// Null when nothing was captured — not started, or stopped on the same
  /// frame it began.
  Future<RecordedAudio?> stop();

  /// Ends the recording and throws away what was captured.
  ///
  /// The patient's way out. After this the bytes are gone from memory, which
  /// is the point: on a shared tablet "I did not mean to say that" has to
  /// actually mean it.
  Future<void> cancel();

  /// Whether a recording is running right now.
  bool get isRecording;

  /// A 0…1 loudness, often enough to animate.
  ///
  /// It is what tells a patient the device can hear them. Without it, somebody
  /// who is speaking quietly has no way to tell a working microphone from a
  /// dead one, and the usual response is to give up and type.
  Stream<double> get level;

  /// Releases the microphone. Idempotent.
  Future<void> dispose();
}

/// The implementation this build ships with.
///
/// It answers with a **real, playable WAV** rather than with null, so every
/// step downstream of the microphone — the multipart post, the transcript
/// draft the patient confirms, the answer that lands on the case — is
/// exercised end to end on a build that has no recorder plugin in it. A stub
/// that returned null would leave the whole spoken path untested and looking
/// finished.
///
/// Unlike its siblings in `image_source.dart` and `file_source.dart`, the
/// bytes are **generated rather than spelled out**. Three quarters of a second
/// of 16 kHz audio is twenty-four thousand bytes, which is not a literal
/// anybody can read or review — and generating it through
/// [SpeechAudio.wavFromPcm16] means the stub exercises the same header writer
/// the real recorder depends on. It is still a constant: the same tone, the
/// same length, the same bytes on every run, so a test can hold it still.
class StubAudioSource implements AudioSource {
  StubAudioSource();

  /// Three quarters of a second of a 440 Hz tone at a third of full scale.
  ///
  /// A tone rather than recorded speech, and deliberately so: a sample of an
  /// actual voice shipped inside the application binary is a voice somebody
  /// owns, and the one thing this seam exists to be careful with is a
  /// patient's recorded voice.
  static final Uint8List spokenAnswerWav = SpeechAudio.wavFromPcm16(_tone());

  static Uint8List _tone() {
    const durationMs = 750;
    const frequency = 440.0;
    const amplitude = 0.33 * 32767;

    const samples = SpeechAudio.sampleRate * durationMs ~/ 1000;
    final pcm = ByteData(samples * 2);
    for (var i = 0; i < samples; i++) {
      final value = amplitude *
          math.sin(2 * math.pi * frequency * i / SpeechAudio.sampleRate);
      pcm.setInt16(i * 2, value.round(), Endian.little);
    }
    return pcm.buffer.asUint8List();
  }

  bool _running = false;

  final StreamController<double> _level = StreamController<double>.broadcast();

  @override
  bool get isRecording => _running;

  @override
  Stream<double> get level => _level.stream;

  @override
  Future<void> start() async => _running = true;

  @override
  Future<RecordedAudio?> stop() async {
    if (!_running) return null;
    _running = false;
    return RecordedAudio(
      bytes: spokenAnswerWav,
      filename: 'spoken-answer.wav',
      mimeType: SpeechAudio.mimeType,
      durationMs: SpeechAudio.durationMsOfPcm16(
        spokenAnswerWav.length - SpeechAudio.headerBytes,
      ),
    );
  }

  @override
  Future<void> cancel() async => _running = false;

  @override
  Future<void> dispose() async {
    _running = false;
    if (!_level.isClosed) await _level.close();
  }
}
