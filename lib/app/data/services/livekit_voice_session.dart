/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the room, behind `VoiceSession`
///
/// The one file in the app that knows `livekit_client` exists. Everything above
/// it holds a [VoiceSession], which is what lets the interview be tested
/// without a method channel and what makes [StubVoiceSession] a straight swap
/// on a build that has no media server to dial.
///
/// The counterpart of `record_audio_source.dart` for the microphone and
/// `audioplayers_speech_player.dart` for the voice, and it is written in the
/// same posture as the second of those: **nothing here throws for an ordinary
/// failure.** A live conversation is an enhancement on top of an interview that
/// already works by tap, by keyboard and by record-then-upload, so an
/// unreachable server, a rejected token or a room that closes halfway is a
/// state to report and not an exception to raise. The single exception is a
/// refused microphone, which `media_access.dart` requires to travel on the
/// error channel because a denial cannot share the quiet return that means
/// "nothing happened".
///
/// ## What it does with the grant
///
/// Dials the URL the server sent with the token the server minted. It holds no
/// API key and no secret and has no way to mint anything — see
/// `voice_session.dart` for why that is the design rather than an omission.
///
/// ## Why the failure flag is sticky
///
/// [isSupported] goes false for the rest of the session once a room has failed
/// in a way this class will not retry. One dead room is a missing convenience;
/// a microphone that drops the patient into a reconnect on every question is an
/// interview nobody finishes. `audioplayers_speech_player.dart` holds the same
/// flag for the same reason.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import '../../core/app_log.dart';
import 'media_access.dart';
import 'voice_session.dart';

/// [VoiceSession] over `livekit_client`.
class LiveKitVoiceSession implements VoiceSession {
  LiveKitVoiceSession();

  /// How long a dial may take before the patient is put back on the
  /// record-then-upload microphone.
  ///
  /// Deliberately shorter than anything else in this app's network budget.
  /// `DioClient` waits thirty seconds for a turn because a turn *is* the
  /// interview; this is an enhancement, and a patient who has just tapped a
  /// microphone and is watching "Connecting" has lost more than the feature was
  /// worth well before then. Eight seconds is paid at most once per interview —
  /// the controller tries a room once and stays on the recorder afterwards.
  static const Duration _dialBudget = Duration(seconds: 8);

  /// The three processors are on for the same reason `record_audio_source.dart`
  /// turns them on: the room this runs in is a waiting room, with a television,
  /// a queue, and somebody being called to desk four while the patient is
  /// mid-sentence.
  static const RoomOptions _roomOptions = RoomOptions(
    defaultAudioCaptureOptions: AudioCaptureOptions(
      noiseSuppression: true,
      echoCancellation: true,
      autoGainControl: true,
    ),
    // Both are video features, and this room carries no video. Left explicitly
    // off rather than defaulted so a later reader does not have to check which
    // way the library's defaults fell.
    adaptiveStream: false,
    dynacast: false,
  );

  /// Broadcast, and **not closed by [leave]**.
  ///
  /// A patient who stops talking and starts again is the ordinary case, not the
  /// exception, and a stream closed on the first leave hands the second session
  /// a dead channel with nothing on screen to say why. They live as long as
  /// this object, which the binding keeps for the length of the interview.
  final StreamController<VoiceTranscript> _transcripts =
      StreamController<VoiceTranscript>.broadcast();

  final StreamController<VoiceSessionState> _state =
      StreamController<VoiceSessionState>.broadcast();

  Room? _room;
  EventsListener<RoomEvent>? _events;

  bool _live = false;
  bool _carriesTheVoice = false;

  /// Set by a failure this class has decided not to retry. See the class
  /// comment.
  bool _failed = false;

  @override
  bool get isSupported => !_failed;

  @override
  bool get isLive => _live;

  @override
  bool get carriesTheVoice => _carriesTheVoice;

  @override
  Stream<VoiceTranscript> get transcripts => _transcripts.stream;

  @override
  Stream<VoiceSessionState> get state => _state.stream;

  @override
  Future<void> join(
    VoiceGrant grant, {
    required String inputLanguage,
    required String outputLanguage,
  }) async {
    if (_live || _failed) return;

    if (!grant.isUsable) {
      // A grant with no token, a non-websocket URL or an expiry already past.
      // Reported rather than dialled: `voice_session.dart` explains why an
      // `https://` origin handed back by a misconfigured server is worse than
      // an outright refusal — it hangs instead of failing.
      AppLog.warn('LiveKitVoiceSession', 'the room grant was not usable');
      _announce(VoiceSessionState.dropped);
      return;
    }

    // Before the room, not inside it. `livekit_client` would ask for the
    // microphone itself on first publish, and what it answers with cannot tell
    // a patient who declined from a device where the switch is off — which are
    // two different sentences. `media_access.dart` is the only place in this
    // app that asks, and this is not a second one.
    //
    // Deliberately outside the try below: a `MediaRefusal` is the one thing
    // here that must reach the caller, because the exception *is* the sentence.
    await MediaAccess.require(MediaPermission.microphone);

    _announce(VoiceSessionState.connecting);

    final room = Room(roomOptions: _roomOptions);
    _room = room;
    _listen(room);

    try {
      await room
          .connect(
            grant.url,
            grant.token,
            // The agent's audio, subscribed on arrival rather than on request.
            // There is one other participant in this room and the patient is
            // meant to hear it.
            connectOptions: const ConnectOptions(autoSubscribe: true),
          )
          .timeout(_dialBudget);

      final me = room.localParticipant;

      // Sent here as well as on the token request so an agent that reads
      // participant attributes needs no second round trip to learn which
      // language it is listening for. `outputLanguage` is English under the
      // current rule and is sent anyway — the room should not have to assume
      // what the interview is written in.
      //
      // ── Its own try, and that is the whole of the fix
      //
      // "Best-effort: an agent that ignores attributes loses nothing, and a
      // server that refuses them is not a reason to drop a working room" is
      // what this comment said while the call sat inside the connect's `try`,
      // awaited. So a refusal *was* a reason to drop a working room, and it
      // dropped one: a token minted without `canUpdateOwnMetadata` answers
      //
      //     NOT_ALLOWED - does not have permission to update own metadata
      //
      // and that threw, landed in the catch below, set `_failed` — which
      // retires live voice for the rest of the session — and tore down a room
      // whose DTLS handshake had already completed and whose SRTP was already
      // active. On the handset it read as "We could not listen as you speak
      // just now", with the media path in perfect working order underneath.
      //
      // The grant is fixed too, server-side, so the attributes now land. This
      // stays because the two are independent: the next best-effort signal call
      // somebody adds must not be able to do this again.
      try {
        await me?.setAttributes({
          'inputLanguage': inputLanguage,
          'outputLanguage': outputLanguage,
        });
      } catch (error) {
        AppLog.warn(
          'LiveKitVoiceSession',
          'the room would not take the language attributes, carrying on: $error',
        );
      }

      // Not best-effort, and deliberately inside the outer try: a room the
      // patient cannot speak into is not a conversation, and failing here is
      // exactly the case the record-then-upload fallback exists for.
      await me?.setMicrophoneEnabled(true);

      _live = true;
      _announce(VoiceSessionState.live);
    } catch (error, stack) {
      // Every ordinary failure lands here: an unreachable server, a token the
      // room refused, a dial that ran past the budget, a publish the platform
      // would not accept. None of them is worth an exception — the interview
      // has three other ways to answer a question and the caller's job is to
      // put it back on one of them.
      AppLog.error('LiveKitVoiceSession', 'the room would not open', error, stack);
      _failed = true;
      await _teardown();
      _announce(VoiceSessionState.dropped);
    }
  }

  @override
  Future<void> leave() async {
    if (_room == null) return;
    await _teardown();
    _announce(VoiceSessionState.idle);
  }

  @override
  Future<void> dispose() async {
    await _teardown();
    if (!_transcripts.isClosed) await _transcripts.close();
    if (!_state.isClosed) await _state.close();
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (!_live) return;
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(enabled);
    } catch (error, stack) {
      // Muting is best-effort and its failure is not the patient's problem.
      // Not made sticky: a publish that would not toggle is not the same as a
      // room that will not open, and taking the whole feature away for it
      // would cost more than it saves.
      AppLog.error(
          'LiveKitVoiceSession', 'the microphone would not toggle', error, stack);
    }
  }

  void _listen(Room room) {
    final events = room.createListener();
    _events = events;

    events
      ..on<TranscriptionEvent>(_onTranscription)
      ..on<TrackSubscribedEvent>(_onTrackSubscribed)
      ..on<RoomDisconnectedEvent>((event) async {
        // The room went while the patient was using it. Not `_failed`: a
        // dropped connection is worth another try later, unlike a room that
        // refused to open in the first place.
        AppLog.warn('LiveKitVoiceSession', 'the room closed: ${event.reason}');
        await _teardown();
        _announce(VoiceSessionState.dropped);
      });
  }

  void _onTranscription(TranscriptionEvent event) {
    // `LocalParticipant` is the patient; anything else in this room is the
    // agent. Decided on the participant rather than on a flag in the payload,
    // because only one of the two may ever be filed as an answer and the
    // distinction has to be structural.
    final speaker = event.participant is LocalParticipant
        ? VoiceSpeaker.patient
        : VoiceSpeaker.agent;

    for (final segment in event.segments) {
      if (segment.text.trim().isEmpty) continue;
      if (_transcripts.isClosed) return;
      _transcripts.add(
        VoiceTranscript(
          text: segment.text,
          isFinal: segment.isFinal,
          speaker: speaker,
          language: segment.language.isEmpty ? null : segment.language,
        ),
      );
    }
  }

  void _onTrackSubscribed(TrackSubscribedEvent event) {
    if (event.track is! AudioTrack) return;
    // The room has a voice of its own from here on, so the HTTP read-aloud
    // must stand down. Two voices reading one clinical question over each
    // other in a waiting room is the outcome `voice_session.dart` names, and
    // this is the only moment the app can know it is about to happen.
    _carriesTheVoice = true;
  }

  /// Closes the room and forgets it. Safe to call twice, and safe to call on a
  /// room that never connected.
  Future<void> _teardown() async {
    _live = false;
    _carriesTheVoice = false;

    final events = _events;
    final room = _room;
    _events = null;
    _room = null;

    try {
      await events?.dispose();
      await room?.disconnect();
      await room?.dispose();
    } catch (error, stack) {
      // Nothing left to do about it. Throwing out of a teardown would take the
      // screen's `onClose` with it, and the handles are already unreachable
      // from here.
      AppLog.error('LiveKitVoiceSession', 'the room would not close', error, stack);
    }
  }

  void _announce(VoiceSessionState next) {
    if (_state.isClosed) return;
    _state.add(next);
  }
}
