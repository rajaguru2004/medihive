/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the microphone, behind `AudioSource`
///
/// The one file in the app that knows the `record` package exists. Everything
/// above it sees the four methods `audio_source.dart` declares, which is what
/// lets a controller be tested without a method channel and what makes
/// [StubAudioSource] a straight swap on a build with no plugin.
///
/// It streams rather than recording to a file. `audio_source.dart` has the
/// reasoning; the short version is that a patient's recorded voice should not
/// outlive the screen it was captured on, and a file on a shared ward tablet
/// does.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../../core/app_log.dart';
import 'audio_source.dart';
import 'media_access.dart';

/// [AudioSource] over `record`.
class RecordAudioSource implements AudioSource {
  /// [recorder] is injectable only so a test can hand in a fake. Production
  /// builds one and keeps it: an `AudioRecorder` per recording leaks a
  /// platform-side session on every question.
  RecordAudioSource({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  /// `pcm16bits` is not a preference — it is the only encoder `startStream`
  /// offers. The three processors below are on because the room this runs in
  /// is a waiting room: a television, a queue, and somebody being called to
  /// desk four while the patient is mid-sentence.
  static const RecordConfig _config = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: SpeechAudio.sampleRate,
    numChannels: SpeechAudio.channels,
    autoGain: true,
    echoCancel: true,
    noiseSuppress: true,
  );

  final AudioRecorder _recorder;

  /// `copy: true` is the default and is load-bearing here: the platform is
  /// entitled to hand the same buffer back on the next chunk, and a builder
  /// holding views rather than copies would end a minute's recording as sixty
  /// copies of its last frame.
  final BytesBuilder _pcm = BytesBuilder();

  final StreamController<double> _level = StreamController<double>.broadcast();

  StreamSubscription<Uint8List>? _chunks;

  /// Completes when the platform has closed the audio stream, which is the
  /// only signal that the tail of the recording has arrived.
  Completer<void>? _drained;

  bool _running = false;

  @override
  bool get isRecording => _running;

  @override
  Stream<double> get level => _level.stream;

  @override
  Future<void> start() async {
    if (_running) return;

    // Before the recorder, not inside it. `record` would ask for the
    // microphone itself and answer with a bool, and a bool cannot tell a
    // patient who declined from a device where the switch is off — which are
    // two different sentences. See `media_access.dart`.
    await MediaAccess.require(MediaPermission.microphone);

    _pcm.clear();
    final drained = Completer<void>();
    _drained = drained;

    final stream = await _recorder.startStream(_config);
    _running = true;

    _chunks = stream.listen(
      _onChunk,
      onDone: () {
        if (!drained.isCompleted) drained.complete();
      },
      onError: (Object error, StackTrace stack) {
        AppLog.error('RecordAudioSource', 'audio stream failed', error, stack);
        if (!drained.isCompleted) drained.complete();
      },
      cancelOnError: true,
    );
  }

  @override
  Future<RecordedAudio?> stop() async {
    if (!_running) return null;
    _running = false;

    await _recorder.stop();

    // Waited on rather than assumed. `stop()` returning is the platform
    // agreeing to stop; the last buffers arrive on the stream afterwards, and
    // cancelling the subscription here would clip the end off every answer —
    // which on a question like "how long has this been going on" is the half
    // of the sentence that carries the fact.
    //
    // Bounded, because a platform that never closes the stream would otherwise
    // leave a patient looking at a spinner with no way back.
    await _drained?.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => AppLog.warn(
        'RecordAudioSource',
        'audio stream did not close; using what arrived',
      ),
    );

    await _chunks?.cancel();
    _chunks = null;
    _drained = null;

    final pcm = _pcm.takeBytes();
    if (pcm.isEmpty) return null;

    return RecordedAudio(
      bytes: SpeechAudio.wavFromPcm16(pcm),
      filename: 'spoken-answer.wav',
      mimeType: SpeechAudio.mimeType,
      durationMs: SpeechAudio.durationMsOfPcm16(pcm.length),
    );
  }

  @override
  Future<void> cancel() async {
    _running = false;
    await _recorder.cancel();
    await _chunks?.cancel();
    _chunks = null;
    _drained = null;

    // The whole point of the control. "I did not mean to say that" has to
    // actually leave nothing behind on a device the next patient will hold.
    _pcm.clear();
  }

  @override
  Future<void> dispose() async {
    _running = false;
    await _chunks?.cancel();
    _chunks = null;
    _drained = null;
    _pcm.clear();
    if (!_level.isClosed) await _level.close();
    await _recorder.dispose();
  }

  void _onChunk(Uint8List chunk) {
    if (chunk.isEmpty) return;

    // A device left face-down on a chair with the button still down records
    // until it runs out of memory. Past the cap the audio is dropped and the
    // meter keeps moving, so the screen still reads as alive while the
    // recording stops growing.
    if (_pcm.length + chunk.lengthInBytes <= RecordedAudio.maxBytes) {
      _pcm.add(chunk);
    }

    if (!_level.isClosed) _level.add(SpeechAudio.levelOfPcm16(chunk));
  }
}
