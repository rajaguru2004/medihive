import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import '../../core/app_log.dart';
import '../../data/models/case_session.dart';
import '../../data/services/auth_service.dart';
import 'interview_turn.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — where the interview is, kept on the phone
///
/// **The server is the source of truth.** Everything clinical lives there: the
/// facts, their presence, their provenance, and what the interview is asking
/// next. This is a write-behind so that a patient whose wifi drops mid-question
/// sees where they had got to instead of an empty screen — `PRODUCT.md` is
/// explicit that hospital wifi is not office wifi, and half an interview lost
/// to a dead spot is half an interview nobody will take again.
///
/// ## Why `flutter_secure_storage` and never `shared_preferences`
///
/// This is a patient's own account of their symptoms. On Android
/// `shared_preferences` is a world-readable-to-the-app plaintext XML file that
/// survives the app being closed, the patient leaving, and the next person
/// picking the device up. `AndroidOptions(encryptedSharedPreferences: true)` is
/// the same arrangement the bearer token and the cached user already use, and
/// this is not less sensitive than either of them.
///
/// ## Why the key carries the account id
///
/// A shared tablet passed between two patients in a waiting room is the case
/// that decides this. Keyed on the signed-in account, patient B's app cannot
/// read patient A's snapshot back even if a sign-out somewhere failed to clear
/// it — the read simply finds nothing, which is the right answer rather than a
/// lucky one.
/// ─────────────────────────────────────────────────────────────────────────────
class CaseTakingCache {
  const CaseTakingCache();

  static const String _prefix = 'case_taking_';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Null when nobody is signed in, which is also the answer to "whose
  /// snapshot is this" — so a read with no account reads nothing.
  String? get _key {
    final id = Get.isRegistered<AuthService>()
        ? (AuthService.to.currentUser?.id ?? '')
        : '';
    return id.isEmpty ? null : '$_prefix$id';
  }

  /// Saves where the interview stands.
  ///
  /// Never awaited on the hot path by the caller: this runs after the next
  /// question is already on screen, and a slow keystore must not be something
  /// a patient waits behind. A failure is logged and swallowed for the same
  /// reason — a snapshot that did not write is a worse resume, not a lost
  /// answer, because the answer is already on the server.
  Future<void> save(CaseInterviewSnapshot snapshot) async {
    final key = _key;
    if (key == null || snapshot.sessionId.isEmpty) return;
    try {
      await _storage.write(key: key, value: jsonEncode(snapshot.toJson()));
    } catch (error, stack) {
      AppLog.error('CaseTakingCache', 'could not save the interview', error,
          stack);
    }
  }

  /// What was saved, or null.
  ///
  /// A snapshot that will not parse is discarded rather than repaired. The
  /// only thing a half-read interview could produce is a conversation with a
  /// question missing from the middle of it, and a patient reading that has no
  /// way to tell it from the interview genuinely not having asked.
  Future<CaseInterviewSnapshot?> read() async {
    final key = _key;
    if (key == null) return null;
    try {
      final raw = await _storage.read(key: key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return CaseInterviewSnapshot.fromJson(decoded.cast<String, dynamic>());
    } catch (error, stack) {
      AppLog.error(
          'CaseTakingCache', 'could not read the saved interview', error,
          stack);
      return null;
    }
  }

  /// Drops it. Called when the interview is finished with — a snapshot of a
  /// submitted case is a copy of a patient's history sitting on a device for no
  /// remaining purpose.
  Future<void> clear() async {
    final key = _key;
    if (key == null) return;
    try {
      await _storage.delete(key: key);
    } catch (error, stack) {
      AppLog.error(
          'CaseTakingCache', 'could not clear the saved interview', error,
          stack);
    }
  }
}

/// The interview as the phone last saw it.
///
/// Holds what is *shown*, not what is known: the conversation so far, the
/// question on the table and the server's own progress figures. There is
/// deliberately no fact map here — a phone that held one would be a second
/// copy of the chart, and two copies of a chart is one of them being wrong.
class CaseInterviewSnapshot {
  const CaseInterviewSnapshot({
    required this.sessionId,
    required this.savedAt,
    this.language = 'en',
    this.progress = CaseProgress.empty,
    this.question,
    this.turns = const [],
  });

  final String sessionId;
  final DateTime savedAt;
  final String language;

  /// The server's count, saved as it arrived. Never recomputed from [turns] —
  /// see `CaseProgress`, which exists to make that impossible to want.
  final CaseProgress progress;

  final CaseQuestion? question;
  final List<InterviewTurn> turns;

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'savedAt': savedAt.toIso8601String(),
        'language': language,
        'progress': progress.toJson(),
        if (question != null)
          'question': {
            'fieldPath': question!.fieldPath,
            'section': question!.section,
            'label': question!.label,
            'kind': question!.kind.name,
            'prompt': question!.prompt,
            'choices': question!.choices,
            'remaining': question!.remaining,
          },
        'turns': turns.map((turn) => turn.toJson()).toList(),
      };

  factory CaseInterviewSnapshot.fromJson(Map<String, dynamic> json) {
    final rawTurns = json['turns'];
    return CaseInterviewSnapshot(
      sessionId: (json['sessionId'] ?? '').toString(),
      savedAt:
          DateTime.tryParse((json['savedAt'] ?? '').toString()) ?? DateTime(0),
      language: (json['language'] ?? 'en').toString(),
      progress: CaseProgress.fromJson(
        json['progress'] is Map
            ? (json['progress'] as Map).cast<String, dynamic>()
            : const {},
      ),
      question: json['question'] is Map
          ? CaseQuestion.fromJson(
              (json['question'] as Map).cast<String, dynamic>())
          : null,
      turns: rawTurns is List
          ? rawTurns
              .whereType<Map>()
              .map((row) => InterviewTurn.fromJson(row.cast<String, dynamic>()))
              .toList()
          : const [],
    );
  }
}
