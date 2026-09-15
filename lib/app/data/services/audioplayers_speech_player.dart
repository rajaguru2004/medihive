import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'speech_player.dart';

/// [SpeechPlayer] over `audioplayers`.
///
/// The counterpart of `record_audio_source.dart`: the one file in the app that
/// knows an audio playback plugin exists. Everything above it holds a
/// [SpeechPlayer].
///
/// ## Why the whole class is wrapped in try/catch
///
/// Playback is an assist on a screen whose question is already rendered, so
/// there is no failure here worth surfacing to a patient mid-interview — and
/// several are reachable through no fault of the app: a device with the media
/// volume at zero, audio focus lost to a phone call, a manufacturer ROM that
/// refuses a codec, a headset unplugged between fetch and play. Each of those
/// throws from a different layer, and none of them is a reason to interrupt
/// somebody describing chest pain.
///
/// A failure sets [_failed], which turns [isAvailable] off for the rest of the
/// session. One dead player is a missing convenience; a control that throws
/// every time it is pressed is a broken app.
class AudioPlayersSpeechPlayer implements SpeechPlayer {
  AudioPlayersSpeechPlayer();

  AudioPlayer? _player;
  bool _failed = false;

  @override
  bool get isAvailable => !_failed;

  @override
  Future<void> play(Uint8List wav) async {
    if (_failed || wav.isEmpty) return;
    try {
      final player = _player ??= AudioPlayer();

      // Stop before playing rather than relying on the plugin to pre-empt.
      // `play` on a player that is already playing is defined differently
      // across platforms, and a question read over the top of the previous one
      // is the specific outcome this must never produce.
      await player.stop();

      // BytesSource keeps the audio in memory. Writing a temp file would be
      // the more ordinary implementation and is the wrong one here: a
      // patient's clinical question spoken aloud, left on the filesystem of a
      // shared ward device, survives a crash and the next person to pick it
      // up. `audio_source.dart` refuses to write a file for the same reason.
      await player.play(BytesSource(wav, mimeType: 'audio/wav'));
    } catch (_) {
      // Deliberately swallowed - see the class comment. The question is on
      // screen; the patient has lost nothing they can see.
      _failed = true;
      await _disposeQuietly();
    }
  }

  @override
  Future<void> stop() async {
    if (_player == null) return;
    try {
      await _player!.stop();
    } catch (_) {
      // Stopping is best-effort. A player that cannot be stopped is already
      // in a state this class has no way to recover, and throwing out of a
      // teardown path would take the screen's dispose with it.
      _failed = true;
      await _disposeQuietly();
    }
  }

  Future<void> _disposeQuietly() async {
    final player = _player;
    _player = null;
    if (player == null) return;
    try {
      await player.dispose();
    } catch (_) {
      // Nothing left to do: the handle is already unreachable from here.
    }
  }
}
