import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/data/services/audio_source.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the spoken-answer seam
///
/// Two things are pinned here, and they are pinned for different reasons.
///
/// **`StubAudioSource` must hand back audio something can actually play.** It
/// is the implementation this build ships, so every screen downstream of the
/// microphone — the upload, the transcript the patient confirms, the answer
/// that lands on the case — runs against these bytes. A stub that produced a
/// plausible-looking buffer with a malformed header would leave all of that
/// looking finished and fail on the first device with a real recorder in it.
///
/// **`SpeechAudio` is the only place that decides how long a recording is.**
/// The duration is computed from the byte count rather than read out of a
/// container, which is exact — and exactness is only useful if the arithmetic
/// is right, so the boundaries are held here rather than discovered on a ward.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  String tagAt(Uint8List bytes, int offset) =>
      String.fromCharCodes(bytes.sublist(offset, offset + 4));

  ByteData viewOf(Uint8List bytes) => ByteData.sublistView(bytes);

  group('the stub ships a real WAV', () {
    final wav = StubAudioSource.spokenAnswerWav;

    test('it carries the RIFF/WAVE chunks a player looks for', () {
      expect(tagAt(wav, 0), 'RIFF');
      expect(tagAt(wav, 8), 'WAVE');
      expect(tagAt(wav, 12), 'fmt ');
      expect(tagAt(wav, 36), 'data');
    });

    test('the format chunk says uncompressed 16 kHz mono 16-bit', () {
      final header = viewOf(wav);
      expect(header.getUint32(16, Endian.little), 16, reason: 'fmt size');
      expect(header.getUint16(20, Endian.little), 1, reason: 'PCM');
      expect(header.getUint16(22, Endian.little), SpeechAudio.channels);
      expect(header.getUint32(24, Endian.little), SpeechAudio.sampleRate);
      expect(header.getUint16(34, Endian.little), SpeechAudio.bitsPerSample);

      // Byte rate and block align are derived, and a player that trusts them
      // over the other fields plays the tone at the wrong speed if they drift.
      expect(header.getUint32(28, Endian.little), 16000 * 2);
      expect(header.getUint16(32, Endian.little), 2);
    });

    test('both length fields agree with the bytes that follow them', () {
      final header = viewOf(wav);
      final dataBytes = wav.length - SpeechAudio.headerBytes;

      expect(header.getUint32(40, Endian.little), dataBytes);
      // The RIFF size counts everything after its own field: the remaining 36
      // header bytes plus the audio. A player reading this as the whole file
      // truncates the last eight bytes of every recording.
      expect(header.getUint32(4, Endian.little), 36 + dataBytes);
    });

    test('there is audio in it, not silence', () {
      final pcm = Uint8List.sublistView(wav, SpeechAudio.headerBytes);
      expect(pcm.length, greaterThan(0));
      expect(SpeechAudio.levelOfPcm16(pcm), greaterThan(0.5));
    });

    test('it is the same bytes on every run', () {
      // The sibling stubs spell their payload out as a constant so a test can
      // compare against it. This one is generated, which only buys the same
      // thing if generating it twice agrees.
      expect(StubAudioSource.spokenAnswerWav, same(wav));
      expect(SpeechAudio.wavFromPcm16(Uint8List(4)).length,
          SpeechAudio.headerBytes + 4);
    });
  });

  group('the stub answers like a recorder', () {
    test('a stop with no start is null, not an exception', () async {
      // A patient letting go of the button on the frame before the recorder
      // started is not an error worth a dialog.
      final source = StubAudioSource();
      addTearDown(source.dispose);

      expect(await source.stop(), isNull);
      expect(source.isRecording, isFalse);
    });

    test('start then stop hands back the recording', () async {
      final source = StubAudioSource();
      addTearDown(source.dispose);

      await source.start();
      expect(source.isRecording, isTrue);

      final recorded = await source.stop();
      expect(recorded, isNotNull);
      expect(recorded!.mimeType, 'audio/wav');
      expect(recorded.filename, endsWith('.wav'));
      expect(recorded.bytes, StubAudioSource.spokenAnswerWav);
      expect(source.isRecording, isFalse);
    });

    test('a cancelled recording hands back nothing at all', () async {
      // The patient's way out. "I did not mean to say that" has to leave
      // nothing behind on a device the next patient will hold.
      final source = StubAudioSource();
      addTearDown(source.dispose);

      await source.start();
      await source.cancel();

      expect(source.isRecording, isFalse);
      expect(await source.stop(), isNull);
    });

    test('the filename carries nothing about the patient', () async {
      final source = StubAudioSource();
      addTearDown(source.dispose);

      await source.start();
      final recorded = await source.stop();

      // A filename travels through logs, bucket listings and support tickets
      // that no retention policy covers.
      expect(recorded!.filename, 'spoken-answer.wav');
    });
  });

  group('how long a recording ran', () {
    test('the duration is the byte count, exactly', () {
      // 16 kHz, mono, two bytes a sample: one second is 32,000 bytes.
      expect(SpeechAudio.durationMsOfPcm16(32000), 1000);
      expect(SpeechAudio.durationMsOfPcm16(16000), 500);
      expect(SpeechAudio.durationMsOfPcm16(0), 0);
    });

    test("the stub's own duration matches its payload", () async {
      final source = StubAudioSource();
      addTearDown(source.dispose);

      await source.start();
      final recorded = await source.stop();

      expect(recorded!.durationMs, 750);
      expect(
        recorded.durationMs,
        SpeechAudio.durationMsOfPcm16(
          recorded.bytes.length - SpeechAudio.headerBytes,
        ),
      );
    });

    test('a brushed button is refused before it becomes an empty answer', () {
      // An empty transcript reads downstream as "the patient said nothing",
      // which is a clinical fact that is not true.
      final brushed = RecordedAudio(
        bytes: _empty,
        filename: 'spoken-answer.wav',
        mimeType: 'audio/wav',
        durationMs: RecordedAudio.minDurationMs - 1,
      );
      final answered = RecordedAudio(
        bytes: _empty,
        filename: 'spoken-answer.wav',
        mimeType: 'audio/wav',
        durationMs: RecordedAudio.minDurationMs,
      );

      expect(brushed.isTooShort, isTrue);
      expect(answered.isTooShort, isFalse, reason: 'the boundary is inclusive');
    });

    test('the label is minutes and padded seconds', () {
      RecordedAudio at(int ms) => RecordedAudio(
            bytes: _empty,
            filename: 'a.wav',
            mimeType: 'audio/wav',
            durationMs: ms,
          );

      expect(at(0).durationLabel, '0:00');
      expect(at(7400).durationLabel, '0:07');
      expect(at(65000).durationLabel, '1:05');
      expect(at(600000).durationLabel, '10:00');
    });
  });

  group('the level meter', () {
    /// [amplitude] as a fraction of full scale, as little-endian 16-bit PCM.
    Uint8List tone(double amplitude, {int samples = 400}) {
      final pcm = ByteData(samples * 2);
      for (var i = 0; i < samples; i++) {
        pcm.setInt16(i * 2, (amplitude * 32767).round(), Endian.little);
      }
      return pcm.buffer.asUint8List();
    }

    test('silence reads as nothing', () {
      expect(SpeechAudio.levelOfPcm16(tone(0)), 0);
      expect(SpeechAudio.levelOfPcm16(Uint8List(0)), 0);
    });

    test('full scale reads as everything', () {
      expect(SpeechAudio.levelOfPcm16(tone(1)), closeTo(1, 0.01));
    });

    test('a quiet voice still moves the meter well off the floor', () {
      // The reason the scale is logarithmic. A conversational voice is around
      // a tenth of full scale, and on a linear meter that is a bar which
      // barely leaves the floor — which reads to the person speaking as a
      // microphone that cannot hear them.
      final quiet = SpeechAudio.levelOfPcm16(tone(0.1));
      expect(quiet, greaterThan(0.5));
      expect(quiet, lessThan(1));
    });

    test('louder always reads higher', () {
      var previous = 0.0;
      for (final amplitude in [0.01, 0.05, 0.2, 0.6, 1.0]) {
        final level = SpeechAudio.levelOfPcm16(tone(amplitude));
        expect(level, greaterThan(previous), reason: '$amplitude');
        previous = level;
      }
    });

    test('a chunk with a trailing odd byte does not throw', () {
      // The platform hands over whatever it has. A half sample at the end of a
      // buffer is not a reason to take the screen down.
      final ragged = Uint8List.fromList([...tone(0.5, samples: 3), 0x11]);
      expect(SpeechAudio.levelOfPcm16(ragged), greaterThan(0));
      expect(SpeechAudio.levelOfPcm16(Uint8List.fromList([0x01])), 0);
    });
  });
}

/// A payload for the cases that are about the metadata rather than the audio.
final Uint8List _empty = Uint8List(0);
