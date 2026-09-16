/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — a conversation, rather than a turn
///
/// The fourth way into the interview, and the only one that stays open.
/// `audio_source.dart` is push-to-talk: a recording is made, uploaded, turned
/// into text and handed back. This is a room — the microphone is published
/// into it and partial text comes back while the patient is still speaking, so
/// somebody describing chest pain watches their own words appear instead of
/// watching a button.
///
/// The same seam `audio_source.dart` established for the microphone,
/// `speech_player.dart` for the voice and `image_source.dart` for radiology,
/// spelled the same way on purpose. Two seams that differ only in their
/// vocabulary are two seams somebody has to read twice.
///
/// ## What this is not
///
/// **It is not how a question arrives.** `POST /turns` answers from a
/// deterministic selector in about fifteen milliseconds, and that is still the
/// only thing that decides what is asked next. What streams here is audio in
/// and interim text back. A room that never connects, drops halfway, or was
/// never configured costs the interview nothing: the tiles, the keyboard and
/// the record-then-upload microphone are all still there, and
/// `case_taking_controller.dart` falls back to them without a dialog.
///
/// That is why [isSupported] exists and why it is the first thing anything
/// asks. A control that is plainly absent beats one that takes a tap and fails,
/// which is `.agents/RULES.md` §0.1's rule pointed at a patient.
///
/// ## Why the app is handed a token rather than a key
///
/// [VoiceGrant] carries a short-lived room token and the URL to dial, both
/// minted by the server. It carries no API key and no secret, and there is no
/// field here that could hold one: a credential shipped inside an APK is a
/// credential belonging to anybody who has the APK, and a hospital cannot
/// rotate what is already on a thousand phones. So the app can join one room,
/// as one patient, until the token expires — and can mint nothing.
///
/// ## Why a refusal is still `MediaRefusal`
///
/// Joining publishes a microphone, so it asks for one, and it asks through
/// `media_access.dart` like everything else. There is exactly one
/// `permission_handler` call site in this app and this is not a second one —
/// the sentence a patient reads when they say no is written once, in
/// `patient_text.dart`, and arrives here already written.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import '../models/json.dart';

/// Where a live session has got to.
///
/// Four states rather than a bool, because "not live" covers three situations
/// that read differently to somebody holding the tablet: nothing has been
/// asked for yet, something is being opened, and something that was open has
/// gone. Only the last of those is worth a sentence.
enum VoiceSessionState {
  /// Nothing open, and nothing being opened. The resting state, and the one a
  /// session returns to after an ordinary [VoiceSession.leave].
  idle,

  /// Dialling. Said out loud on screen, because a tap that shows nothing for
  /// several seconds is a tap the patient makes again.
  connecting,

  /// Joined, publishing, and listening.
  live,

  /// It was live and it is not any more, through no decision of the patient's
  /// — the network went, the token expired, the room closed. This is the one
  /// that carries a sentence, and the one that puts the interview back on the
  /// record-then-upload microphone.
  dropped,
}

/// A short-lived pass into one room.
///
/// Minted by `POST /api/case-taking/voice/token` against the patient's bearer
/// token. It is deliberately the whole of what the app is trusted with: a
/// token, a URL and the room it names. There is no `apiKey` and no `apiSecret`
/// field, and adding one would be the defect rather than the feature — see the
/// library comment.
class VoiceGrant {
  const VoiceGrant({
    this.token = '',
    this.url = '',
    this.roomName = '',
    this.expiresAt,
  });

  /// The room token. Short-lived by design: minutes, not a session, so a token
  /// read off a device that was left on a ward trolley is a token that has
  /// already stopped working.
  final String token;

  /// Where to dial — the server's `LIVEKIT_URL`, sent back with the token
  /// rather than compiled in.
  ///
  /// Sent rather than built here on purpose. A hospital that moves its media
  /// server, or runs one per site, changes a server-side variable; an app that
  /// held the URL would need a release, and the release would have to reach
  /// every waiting-room tablet before the old address stopped answering.
  final String url;

  /// Which room the token is for. Carried so it can be logged and matched, and
  /// never rendered: a room name is server vocabulary.
  final String roomName;

  /// When the token stops working, when the server said.
  ///
  /// Null is "the server did not say", which is not the same as "it does not
  /// expire" — [isUsable] treats an absent expiry as fine to try, because the
  /// server is the thing that decides and refusing to dial on a missing
  /// optional field would take the feature away from a working deployment.
  final DateTime? expiresAt;

  /// Reads what `POST /api/case-taking/voice/token` answers with.
  ///
  /// Written against the route's **documented** shape rather than against a
  /// deployed one — the endpoint is being built alongside this — which is why
  /// each field is read under every name two people would plausibly pick.
  /// `case_session.dart` reads the language tags the same way and for the same
  /// reason: a client that accepts one spelling of `livekitUrl` is a client
  /// that breaks on a server written by somebody who spelled it `wsUrl`, and
  /// the failure is a feature that silently never appears.
  ///
  /// **There is no branch here that reads an API key or a secret**, under any
  /// name, even if a server were to send one. That is the point of the class,
  /// and a parser that helpfully picked one up would put it in memory on a
  /// waiting-room tablet.
  factory VoiceGrant.fromJson(Map<String, dynamic> json) {
    dynamic first(List<String> names) {
      for (final name in names) {
        final value = json[name];
        if (value != null) return value;
      }
      return null;
    }

    // Seconds-from-now is as common a way to say this as a timestamp, and a
    // client that understood only one of them would either dial with a dead
    // token or refuse a live one.
    final seconds = asInt(first(const ['expiresIn', 'expires_in', 'ttl']));
    final expiry = asDate(first(const ['expiresAt', 'expires_at', 'expiry'])) ??
        (seconds > 0 ? DateTime.now().add(Duration(seconds: seconds)) : null);

    return VoiceGrant(
      token: asString(
        first(const ['token', 'accessToken', 'access_token', 'roomToken']),
      ),
      url: asString(
        first(const ['url', 'livekitUrl', 'livekit_url', 'wsUrl', 'serverUrl']),
      ),
      roomName: asString(first(const ['roomName', 'room_name', 'room'])),
      expiresAt: expiry,
    );
  }

  /// Whether there is anything here worth dialling.
  ///
  /// Three things are checked, and the middle one is the one that is easy to
  /// leave out. A token and a URL must both be present; the URL must be a
  /// **websocket** URL, because a misconfigured server handing back its own
  /// `https://` origin produces a dial that hangs rather than one that fails,
  /// and a patient watching "Connecting" forever is worse than a patient told
  /// the live conversation is unavailable; and an expiry already in the past
  /// is a token that will be refused on arrival, which is a round trip and a
  /// timeout spent to learn what is already on the object.
  bool get isUsable {
    if (token.isEmpty || url.isEmpty) return false;
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    if (scheme != 'ws' && scheme != 'wss') return false;
    final expiry = expiresAt;
    return expiry == null || expiry.isAfter(DateTime.now());
  }

  /// Never the token. A grant reaches the log as the room it names and nothing
  /// else — `.agents/RULES.md` §3.2 forbids logging a token, and this is the
  /// object most likely to be printed while somebody is debugging a room that
  /// will not connect.
  @override
  String toString() => 'VoiceGrant(room: $roomName)';
}

/// Who a piece of live text came from.
enum VoiceSpeaker {
  /// The patient. Their own words, coming back as they say them.
  patient,

  /// The room's agent. Kept apart from the patient's because only one of the
  /// two may ever be filed as an answer, and a single stream with a flag on it
  /// is a flag somebody eventually forgets to read.
  agent,
}

/// One piece of text the room has heard.
///
/// Arrives repeatedly for the same utterance: several times with [isFinal]
/// false as the recogniser revises what it thinks it heard, then once with it
/// true. The interim ones are for the screen and are never filed; the final
/// one is what the patient is asked to confirm, on the same path a
/// record-then-upload transcript takes.
class VoiceTranscript {
  const VoiceTranscript({
    required this.text,
    required this.isFinal,
    this.speaker = VoiceSpeaker.patient,
    this.language,
  });

  final String text;

  /// False while the recogniser is still revising. **An interim transcript is
  /// never an answer.** It is shown so somebody can see they are being heard,
  /// and filing one would put a half-heard sentence on a chart.
  final bool isFinal;

  final VoiceSpeaker speaker;

  /// What the room says it heard this in. Carried rather than assumed: the
  /// session is told which language the patient speaks, and a segment that
  /// comes back tagged as something else is worth having on the object even
  /// though nothing branches on it today.
  final String? language;

  bool get isEmpty => text.trim().isEmpty;
}

/// A live voice conversation.
///
/// Every method is safe to call in any order and none of them throws for
/// ordinary failure. A [leave] with no [join] is a no-op; a [join] that cannot
/// connect reports [VoiceSessionState.dropped] and leaves the interview on the
/// paths it already had. The one exception is a refused microphone, which
/// throws `MediaRefusal` for the reason `media_access.dart` gives: a denial
/// cannot share the quiet return that means "nothing happened", or the patient
/// gets no sentence and a control that does nothing every time it is pressed.
abstract interface class VoiceSession {
  /// Whether this build can hold a live conversation at all.
  ///
  /// False on a platform with no WebRTC implementation, and false for the
  /// stub. Asked before anything else, because it is what decides whether the
  /// control is drawn — and drawing it is what causes a token to be minted, so
  /// a build that cannot use one never asks for one. A hospital that has not
  /// configured a media server is then never called either: the token route
  /// answers that it has nothing, and the session is simply not offered.
  bool get isSupported;

  /// Joins the room [grant] names and publishes the microphone.
  ///
  /// [inputLanguage] is what the patient speaks and [outputLanguage] is what
  /// the interview answers in — English, under the current rule. Both are
  /// passed to the room as participant attributes as well as to the token
  /// route, so an agent that reads attributes needs no second round trip.
  ///
  /// Throws `MediaRefusal` when the microphone is refused. Everything else —
  /// an unreachable server, a rejected token, a timeout — is reported as
  /// [VoiceSessionState.dropped] on [state] rather than thrown: a live
  /// conversation is an enhancement, and an exception on this path would abort
  /// an interview over a convenience.
  Future<void> join(
    VoiceGrant grant, {
    required String inputLanguage,
    required String outputLanguage,
  });

  /// Leaves the room and releases the microphone. Idempotent.
  ///
  /// Called when the patient stops talking, leaves the screen, or the session
  /// is torn down. On a shared ward device a room still carrying a live
  /// microphone after the next patient picks the tablet up is a disclosure,
  /// so this is not merely tidiness.
  Future<void> leave();

  /// Stops or resumes publishing, without leaving the room.
  ///
  /// The room stays up across a question boundary — that is the point of it —
  /// but the audio must not. An answer given by tapping a tile means whatever
  /// the microphone was hearing belonged to a question that has just left the
  /// screen, and a recording spanning two questions is the defect
  /// `case_taking_drafts.dart` calls worse than a missing answer.
  Future<void> setMicrophoneEnabled(bool enabled);

  /// Whether a room is joined right now.
  bool get isLive;

  /// Whether the room has taken over reading the questions out loud.
  ///
  /// True once an agent in the room publishes audio. It exists to stop two
  /// voices reading one clinical question over each other: read-aloud goes
  /// through `POST /case-taking/tts` and `audioplayers`, and if the room is
  /// also speaking, both are audible at once in a waiting room.
  ///
  /// Deliberately not "a room is live". A room whose agent never speaks must
  /// leave the HTTP voice alone, because the patient it was built for —
  /// somebody who cannot comfortably read the screen — would otherwise lose
  /// the questions entirely by opting into a conversation.
  bool get carriesTheVoice;

  /// What the room is hearing, interim and final.
  ///
  /// Broadcast, and it outlives a [leave]: a patient who stops talking and
  /// starts again is the ordinary case, not the exception, and a stream closed
  /// on the first leave hands the second room a dead channel with nothing on
  /// screen to say why. [dispose] is what ends it.
  Stream<VoiceTranscript> get transcripts;

  /// Where the session has got to. Broadcast on the same terms as
  /// [transcripts], and the caller's cue to put the interview back on the
  /// record-then-upload microphone.
  Stream<VoiceSessionState> get state;

  /// Releases everything this object holds. Idempotent, and terminal.
  ///
  /// The distinction from [leave] is the one `audio_source.dart` draws between
  /// `cancel` and `dispose`: leaving ends a conversation and the next one can
  /// start, while this ends the object. The interview calls it from `onClose`,
  /// where the screen is going away and there will be no next one.
  Future<void> dispose();
}

/// A session that is never offered.
///
/// The default in tests and on any platform without WebRTC. It reports
/// [isSupported] as false, which is what keeps a widget test away from a
/// method channel — and, more usefully, keeps every existing interview flow on
/// the record-then-upload path with no fixture for a room token, because a
/// control that is never drawn never mints one.
///
/// Unlike `StubAudioSource`, which ships real playable audio so the whole
/// spoken path is exercised on a build with no recorder, this one does
/// nothing. The difference is what each stub stands in for: a recording can be
/// faked honestly, and a conversation with a server cannot. A stub that
/// pretended to connect would make the one property this seam exists to
/// guarantee — that the interview finishes without it — the only property
/// never tested.
class StubVoiceSession implements VoiceSession {
  const StubVoiceSession();

  @override
  bool get isSupported => false;

  @override
  bool get isLive => false;

  @override
  bool get carriesTheVoice => false;

  @override
  Stream<VoiceTranscript> get transcripts =>
      const Stream<VoiceTranscript>.empty();

  @override
  Stream<VoiceSessionState> get state =>
      const Stream<VoiceSessionState>.empty();

  @override
  Future<void> join(
    VoiceGrant grant, {
    required String inputLanguage,
    required String outputLanguage,
  }) async {}

  @override
  Future<void> leave() async {}

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {}

  @override
  Future<void> dispose() async {}
}
