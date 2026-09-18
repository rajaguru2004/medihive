import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/data/services/voice_session.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the live-conversation seam
///
/// Three things are pinned here, and they are pinned for different reasons.
///
/// **The app is handed a pass, never a key.** A credential shipped inside an
/// APK belongs to everybody who has the APK, and a hospital cannot rotate what
/// is already on a thousand waiting-room tablets. [VoiceGrant] has no field
/// that could hold one and its parser reads no key that could carry one — so
/// this asserts on an *absence*, which is exactly the kind of requirement that
/// quietly stops being true.
///
/// **A grant that cannot work is refused before it is dialled.** The one that
/// decided this test is the `https://` origin: a misconfigured server handing
/// back its own base URL instead of its `LIVEKIT_URL` produces a dial that
/// **hangs** rather than one that fails, and a patient watching "Connecting"
/// forever is worse than a patient never offered the feature. The arithmetic
/// of "has it expired" is held here for the same reason it is in
/// `audio_source.dart` — it is only useful if it is right.
///
/// **`StubVoiceSession` is never offered.** It is what every widget test gets,
/// and the property worth holding still is not that it works: it is that it
/// reports itself unsupported, so no test dials a room, no test answers a
/// method channel, and what the interview flows prove is the path a site with
/// no media server actually takes.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  group('a grant carries a pass and nothing else', () {
    test('it reads the token, the URL and the room', () {
      final grant = VoiceGrant.fromJson(const {
        'token': 'eyJhbGciOi.short.lived',
        'url': 'wss://livekit.hospital.example',
        'roomName': 'case_sess_1',
      });

      expect(grant.token, 'eyJhbGciOi.short.lived');
      expect(grant.url, 'wss://livekit.hospital.example');
      expect(grant.roomName, 'case_sess_1');
      expect(grant.isUsable, isTrue);
    });

    test('a secret on the payload is not picked up', () {
      // A server should never send these. If one ever does, the phone is not
      // the thing that keeps them.
      final grant = VoiceGrant.fromJson(const {
        'token': 'eyJhbGciOi.short.lived',
        'url': 'wss://livekit.hospital.example',
        'apiKey': 'APIabc123',
        'apiSecret': 'sh0uldNeverLeaveTheServer',
      });

      expect(grant.isUsable, isTrue);
      expect(grant.toString(), isNot(contains('APIabc123')));
      expect(grant.toString(), isNot(contains('sh0uldNeverLeaveTheServer')));
    });

    test('the token never reaches a log line', () {
      // `.agents/RULES.md` §3.2 forbids logging a token, and this is the
      // object most likely to be printed while somebody is debugging a room
      // that will not connect.
      const grant = VoiceGrant(
        token: 'eyJhbGciOi.short.lived',
        url: 'wss://livekit.hospital.example',
        roomName: 'case_sess_1',
      );

      expect(grant.toString(), contains('case_sess_1'));
      expect(grant.toString(), isNot(contains('eyJhbGciOi')));
    });
  });

  group('the names two people would each pick', () {
    // The route is being written alongside this, so every field is read under
    // its plausible spellings — the same posture `case_session.dart` takes for
    // the language tags, and for the same reason: a client that accepts one
    // spelling of `livekitUrl` is a feature that silently never appears.

    test('an access token under another name is still a token', () {
      final grant = VoiceGrant.fromJson(const {
        'accessToken': 'abc.def.ghi',
        'livekitUrl': 'wss://media.example',
      });
      expect(grant.token, 'abc.def.ghi');
      expect(grant.url, 'wss://media.example');
    });

    test('a websocket URL under any of its names', () {
      for (final name in const ['url', 'livekitUrl', 'wsUrl', 'serverUrl']) {
        final grant = VoiceGrant.fromJson({
          'token': 'abc',
          name: 'wss://media.example',
        });
        expect(grant.url, 'wss://media.example', reason: name);
      }
    });

    test('seconds-from-now is as good as a timestamp', () {
      // A client that understood only one of the two would either dial with a
      // dead token or refuse a live one.
      final grant = VoiceGrant.fromJson(const {
        'token': 'abc',
        'url': 'wss://media.example',
        'expiresIn': 300,
      });

      expect(grant.expiresAt, isNotNull);
      expect(grant.isUsable, isTrue);
      expect(
        grant.expiresAt!.difference(DateTime.now()).inSeconds,
        closeTo(300, 5),
      );
    });

    test('a payload that says nothing is not usable', () {
      // A 404 from a site with no media server parses to this rather than
      // throwing, and it has to read as "there is no room", not as an error.
      final grant = VoiceGrant.fromJson(const <String, dynamic>{});
      expect(grant.isUsable, isFalse);
    });
  });

  group('what is refused before it is dialled', () {
    VoiceGrant grantWith(String url) =>
        VoiceGrant(token: 'abc', url: url, roomName: 'r');

    test('an https origin is refused rather than dialled', () {
      // The one that decided this test. A dial to an `https://` origin hangs
      // instead of failing, and a patient watching "Connecting" forever is
      // worse than a patient never offered the feature.
      expect(grantWith('https://api.hospital.example').isUsable, isFalse);
      expect(grantWith('http://api.hospital.example').isUsable, isFalse);
    });

    test('both websocket schemes are accepted', () {
      // `ws://` is what a site running its media server inside the hospital
      // network behind its own TLS terminator answers with.
      expect(grantWith('wss://media.example').isUsable, isTrue);
      expect(grantWith('ws://10.0.4.12:7880').isUsable, isTrue);
    });

    test('nonsense in the URL field is refused, not parsed into a dial', () {
      expect(grantWith('not a url at all').isUsable, isFalse);
      expect(grantWith('').isUsable, isFalse);
    });

    test('a token with no URL, and a URL with no token, are both refused', () {
      expect(const VoiceGrant(token: 'abc').isUsable, isFalse);
      expect(const VoiceGrant(url: 'wss://media.example').isUsable, isFalse);
    });

    test('an expiry already past is refused before the round trip', () {
      final stale = VoiceGrant(
        token: 'abc',
        url: 'wss://media.example',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(stale.isUsable, isFalse);
    });

    test('an expiry still ahead is fine', () {
      final fresh = VoiceGrant(
        token: 'abc',
        url: 'wss://media.example',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      expect(fresh.isUsable, isTrue);
    });

    test('no expiry at all is the server not saying, not a refusal', () {
      // Refusing to dial on a missing optional field would take the feature
      // away from a deployment that works.
      const quiet = VoiceGrant(token: 'abc', url: 'wss://media.example');
      expect(quiet.expiresAt, isNull);
      expect(quiet.isUsable, isTrue);
    });
  });

  group('an interim transcript is not an answer', () {
    test('a revision says so, and a final one says so', () {
      const revising = VoiceTranscript(text: 'about thr', isFinal: false);
      const settled = VoiceTranscript(text: 'about three days', isFinal: true);

      expect(revising.isFinal, isFalse);
      expect(settled.isFinal, isTrue);
    });

    test('the patient and the agent are told apart on the object', () {
      // Structural, not a flag somebody has to remember to read: only one of
      // these two may ever be filed as an answer.
      const patient = VoiceTranscript(text: 'three days', isFinal: true);
      const agent = VoiceTranscript(
        text: 'How long has this been going on?',
        isFinal: true,
        speaker: VoiceSpeaker.agent,
      );

      expect(patient.speaker, VoiceSpeaker.patient);
      expect(agent.speaker, VoiceSpeaker.agent);
    });

    test('whitespace is nothing heard', () {
      // A segment of spaces reaching the screen would read as the app hearing
      // something when it heard nothing.
      const blank = VoiceTranscript(text: '   ', isFinal: false);
      expect(blank.isEmpty, isTrue);
      expect(const VoiceTranscript(text: 'y', isFinal: false).isEmpty, isFalse);
    });
  });

  group('the stub is never offered', () {
    test('it reports itself unsupported', () {
      // The property the whole feature rests on. A widget test gets this, so
      // no test dials a room and no test answers a method channel — and every
      // interview flow proves the record-then-upload path a site with no media
      // server actually uses.
      const session = StubVoiceSession();
      expect(session.isSupported, isFalse);
      expect(session.isLive, isFalse);
      expect(session.carriesTheVoice, isFalse);
    });

    test('every call is safe, in any order', () async {
      const session = StubVoiceSession();

      // Leaving without joining, muting a room that was never opened, and
      // disposing twice. A screen torn down mid-dial does all three.
      await session.leave();
      await session.setMicrophoneEnabled(true);
      await session.join(
        const VoiceGrant(token: 'abc', url: 'wss://media.example'),
        inputLanguage: 'ta',
        outputLanguage: 'en',
      );
      expect(session.isLive, isFalse);
      await session.dispose();
      await session.dispose();
    });

    test('it hears nothing rather than hanging', () async {
      // An empty stream that closes, not one that never completes: a
      // controller awaiting the first segment would otherwise wait forever.
      const session = StubVoiceSession();
      expect(await session.transcripts.toList(), isEmpty);
      expect(await session.state.toList(), isEmpty);
    });
  });
}
