import 'dart:typed_data';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — where a spoken question comes out
///
/// The other half of `audio_source.dart`. That seam is how a patient's voice
/// gets in; this is how the question gets back out, for a patient who cannot
/// read the screen — long sight, low literacy, a language they speak but do not
/// read, or simply a phone held at arm's length in a corridor.
///
/// The surface is deliberately two verbs and a flag. The server hands back a
/// finished WAV from `POST /case-taking/tts`; there is nothing to stream,
/// nothing to seek, and no playlist. Anything richer would be surface nobody
/// calls, and a seam exists to be stubbed in a widget test — an audio plugin
/// answers over a method channel, and a method channel in a widget test is a
/// stub either way.
///
/// The same seam `audio_source.dart` established for the microphone and
/// `image_source.dart` for radiology, spelled the same way on purpose.
///
/// ## Why it takes bytes and not a URL
///
/// The obvious signature is `play(Uri)`, letting the player fetch the audio
/// itself. It would not work here. The audio lives behind
/// `POST /case-taking/tts`, which needs the bearer token, a JSON body, and the
/// `ngrok-skip-browser-warning` header that `DioClient` attaches — none of
/// which a bare audio player sends. Fetching stays with `DioClient`, where the
/// interceptors are, and the player is handed the bytes it already has.
///
/// It also means the recording of a patient's question never lands on disk,
/// which is the same reason `audio_source.dart` refuses to write a file.
///
/// ## Why nothing here throws
///
/// Speech is an assist, never the channel. Every question is on screen before
/// a single byte of audio is requested, so a player that cannot play has cost
/// the patient nothing — and an exception on that path would abort an
/// interview over a convenience. Implementations swallow their own failures
/// and report them through [isAvailable]; callers are not expected to guard.
abstract class SpeechPlayer {
  /// Play [wav] from the start, replacing anything already playing.
  ///
  /// Replacing rather than queueing is the whole behaviour: the only thing
  /// that triggers this is a new question arriving, and a patient who has
  /// moved on should not have to sit through the previous one.
  ///
  /// Completes when playback has been *started*, not when it has finished.
  /// Awaiting the end would hold the caller across several seconds of audio
  /// for no reason — the interview has already moved on.
  Future<void> play(Uint8List wav);

  /// Stop immediately and discard whatever is playing.
  ///
  /// Called when the patient answers, leaves the screen, or the session is
  /// torn down. On a shared ward device a question still being read aloud
  /// after the next patient picks it up is a disclosure, so this is not
  /// merely tidiness.
  Future<void> stop();

  /// Whether this device can play at all.
  ///
  /// False on a platform with no audio implementation, or after a failure
  /// this player has decided not to retry. Callers use it to decide whether to
  /// offer the control, not whether it is safe to call [play] — calling
  /// [play] on an unavailable player is a no-op, not an error.
  bool get isAvailable;
}

/// A player that does nothing, successfully.
///
/// The default in tests and on any platform without audio. It reports
/// [isAvailable] as false so a caller that offers a "read aloud" control hides
/// it, rather than showing a button that silently does nothing — which reads
/// as a broken app rather than an absent capability.
class StubSpeechPlayer implements SpeechPlayer {
  const StubSpeechPlayer();

  @override
  bool get isAvailable => false;

  @override
  Future<void> play(Uint8List wav) async {}

  @override
  Future<void> stop() async {}
}
