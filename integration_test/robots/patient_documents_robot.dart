import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/keys/app_keys.dart';
import 'package:medihive/app/modules/patient_documents/patient_documents_routes.dart';
import 'package:medihive/app/theme/theme.dart';

import '../support/pump.dart';
import 'robot.dart';

/// The patient's documents: the list they add to, and the reading of one.
///
/// One robot for both, the way `PatientPortalRobot` is one for five. They are
/// one task — somebody photographs a prescription and then checks what was read
/// out of it — and the assertions that matter are about that journey.
///
/// The negative assertions here are the ones worth reading. This screen has
/// four ways to be dangerous and each has a method named after it:
/// [seeNoFabricatedDenial], [seeNoTechnicalDetail], [seeNoBlendedConfidence]
/// and [seeValueSource], which is how "the correction re-labelled it" is said
/// out loud.
final class PatientDocumentsRobot extends Robot {
  PatientDocumentsRobot(super.harness);

  @override
  String? get route => PatientDocumentsRoutes.list;

  @override
  Key get anchor => PatientDocumentsKeys.screen;

  // ── Getting there ─────────────────────────────────────────────────────────

  /// From the patient's own dashboard, the way they would.
  Future<void> openFromDashboard() async {
    await tester.scrollToKey(PatientDocumentsKeys.openFromDashboard);
    await tester.tapKey(PatientDocumentsKeys.openFromDashboard);
    await tester.pumpUntilFound(find.byKey(PatientDocumentsKeys.screen));
    await settle();
  }

  Future<void> assertOnList() => assertVisible();

  /// "There is nothing here yet, and the screen says what to do about it."
  Future<void> seeNothingYet() async {
    await tester.scrollToKey(PatientDocumentsKeys.empty);
    expect(find.byKey(PatientDocumentsKeys.empty), findsOneWidget);
  }

  Future<void> seeDocument(String id) async {
    await tester.scrollToKey(PatientDocumentsKeys.document(id));
    expect(find.byKey(PatientDocumentsKeys.document(id)), findsOneWidget);
  }

  Future<void> openDocument(String id) async {
    await tester.tapKey(PatientDocumentsKeys.document(id));
    await tester.pumpUntilFound(find.byKey(PatientDocumentsKeys.review));
    await settle();
  }

  // ── Adding one ────────────────────────────────────────────────────────────

  /// Takes a photograph and sends it.
  ///
  /// Deliberately asserts nothing about where it landed. A first upload opens
  /// the reading; a second copy of the same file opens a row that says so; and
  /// which of those happened is the caller's assertion to make.
  Future<void> addFromCamera() => _add(PatientDocumentsKeys.addCamera);

  Future<void> addFromGallery() => _add(PatientDocumentsKeys.addGallery);

  Future<void> addPdf() => _add(PatientDocumentsKeys.addPdf);

  Future<void> _add(Key which) async {
    await tester.tapKey(which);
    await settle();
  }

  /// "The app refused the file itself, in words, and never sent it."
  Future<void> seeUploadRefusal({required String containing}) async {
    await tester.pumpUntilFound(find.byKey(PatientDocumentsKeys.uploadError));
    expect(
      find.descendant(
        of: find.byKey(PatientDocumentsKeys.uploadError),
        matching: find.textContaining(containing),
      ),
      findsWidgets,
      reason: 'expected the refusal to say "$containing"',
    );
  }

  void seeNoUploadRefusal() =>
      expect(find.byKey(PatientDocumentsKeys.uploadError), findsNothing);

  // ── The reading ───────────────────────────────────────────────────────────

  Future<void> assertOnReview() async {
    await tester.pumpUntilFound(find.byKey(PatientDocumentsKeys.review));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  }

  /// The server's own sentence about this document is on screen.
  Future<void> seeMessage({required String containing}) async {
    await tester.scrollToKey(PatientDocumentsKeys.message);
    expect(
      find.descendant(
        of: find.byKey(PatientDocumentsKeys.message),
        matching: find.textContaining(containing),
      ),
      findsOneWidget,
      reason: 'expected the document to say "$containing"',
    );
  }

  /// "…and it is a sentence, not a stack trace."
  ///
  /// §27's failure has a name and a shape: an engine's `error.message` passed
  /// up through one layer that did not know where it would end up. The words
  /// below are the ones that would be on screen if that happened.
  void seeNoTechnicalDetail() {
    for (final leak in const [
      'PP-OCR',
      'PaddleOCR',
      'RapidOCR',
      'onnxruntime',
      'Traceback',
      'Exception',
      'DioException',
      'SocketException',
      'stack',
      'status code',
      'null',
      '500',
    ]) {
      expect(
        find.textContaining(leak, skipOffstage: false),
        findsNothing,
        reason: 'the screen showed "$leak", which is not the patient\'s '
            'problem and not their business',
      );
    }
  }

  /// Waits for the reading to finish.
  ///
  /// Not a fixed pause: the screen polls while the pipeline is running and the
  /// thing to wait on is the processing sentence going away, which is the same
  /// signal the patient is watching for.
  Future<void> waitUntilFinishedReading() async {
    await tester.pumpUntil(
      () => find
          .descendant(
            of: find.byKey(PatientDocumentsKeys.message),
            matching: find.textContaining('reading your document'),
          )
          .evaluate()
          .isEmpty,
      reason: 'the document was still being read',
    );
    await settle();
  }

  /// §21: the same document twice is reported, not refused.
  ///
  /// One banner, not two. There used to be a second one restating the first in
  /// different words; the server's sentence carries it now, and on a duplicate
  /// of a rejected copy it carries the rejection reason instead — which the
  /// hardcoded second line flatly contradicted.
  Future<void> seeReportedAsDuplicate() async {
    await tester.scrollToKey(PatientDocumentsKeys.message);
    expect(find.byKey(PatientDocumentsKeys.message), findsOneWidget);
    await seeMessage(containing: 'already uploaded');
  }

  /// §17: two measured numbers, each under its own name.
  Future<void> seeBothConfidences() async {
    await tester.scrollToKey(PatientDocumentsKeys.ocrConfidence);
    expect(find.byKey(PatientDocumentsKeys.ocrConfidence), findsOneWidget);
    await tester.scrollToKey(PatientDocumentsKeys.extractionConfidence);
    expect(
      find.byKey(PatientDocumentsKeys.extractionConfidence),
      findsOneWidget,
    );
  }

  /// "…and there is no third number pretending to be both."
  ///
  /// The words a blended figure would be introduced by. A single "accuracy" is
  /// a number nobody measured wearing the authority of one somebody did, and
  /// the way it arrives is always a well-meaning summary line.
  void seeNoBlendedConfidence() {
    for (final word in const ['Accuracy', 'accuracy', 'Overall confidence']) {
      expect(
        find.textContaining(word, skipOffstage: false),
        findsNothing,
        reason: 'the screen blended two measurements into "$word"',
      );
    }
  }

  // ── One extracted value ───────────────────────────────────────────────────

  Future<void> seeValue(String field, {String? reading}) async {
    await tester.scrollToKey(PatientDocumentsKeys.value(field));
    expect(find.byKey(PatientDocumentsKeys.value(field)), findsOneWidget);
    if (reading != null) {
      expect(
        find.descendant(
          of: find.byKey(PatientDocumentsKeys.value(field)),
          matching: find.textContaining(reading),
        ),
        findsWidgets,
        reason: 'expected $field to read "$reading"',
      );
    }
  }

  /// "This value is marked as needing a look."
  ///
  /// The mark is a `ConfidenceMark`, which says "Check this" — a statement
  /// about the app's reading, not about the patient. Asserted through the
  /// component rather than the words so a copy change does not silently drop
  /// the signal.
  Future<void> seeValueNeedsCheck(String field) async {
    await tester.scrollToKey(PatientDocumentsKeys.value(field));
    final mark = find.descendant(
      of: find.byKey(PatientDocumentsKeys.value(field)),
      matching: find.byType(ConfidenceMark),
    );
    expect(mark, findsOneWidget);
    expect(
      tester.widget<ConfidenceMark>(mark).confidence,
      AnswerConfidence.unsure,
      reason: '$field should be marked for checking',
    );
  }

  Future<void> seeValueIsClear(String field) async {
    await tester.scrollToKey(PatientDocumentsKeys.value(field));
    final mark = find.descendant(
      of: find.byKey(PatientDocumentsKeys.value(field)),
      matching: find.byType(ConfidenceMark),
    );
    expect(
      tester.widget<ConfidenceMark>(mark).confidence,
      AnswerConfidence.clear,
    );
  }

  /// Where this value is attributed — and, after a correction, that it moved.
  ///
  /// The `SourceChip` is read through its own type rather than its words, so
  /// this says "the attribution changed" rather than "a string changed".
  Future<void> seeValueSource(String field, AnswerSource expected) async {
    await tester.scrollToKey(PatientDocumentsKeys.value(field));
    final chip = find.descendant(
      of: find.byKey(PatientDocumentsKeys.value(field)),
      matching: find.byType(SourceChip),
    );
    expect(chip, findsOneWidget);
    expect(
      tester.widget<SourceChip>(chip).source,
      expected,
      reason: '$field should be attributed to $expected',
    );
  }

  /// What the patient has said about this value, in the screen's own words.
  Future<void> seeValueState(String field, String saying) async {
    await tester.scrollToKey(PatientDocumentsKeys.value(field));
    expect(
      find.descendant(
        of: find.byKey(PatientDocumentsKeys.value(field)),
        matching: find.textContaining(saying),
      ),
      findsOneWidget,
      reason: 'expected $field to say "$saying"',
    );
  }

  Future<void> confirmValue(String field) async {
    await tester.tapKey(PatientDocumentsKeys.confirmValue(field));
    await settle();
  }

  Future<void> markValueUnsure(String field) async {
    await tester.tapKey(PatientDocumentsKeys.unsureValue(field));
    await settle();
  }

  /// Corrects one value: opens the editor, types, saves.
  Future<void> correctValue(String field, String text) async {
    await tester.tapKey(PatientDocumentsKeys.correctValue(field));
    await tester.pumpUntilFound(
      find.byKey(PatientDocumentsKeys.correctionField),
    );
    await tester.enterTextByKey(PatientDocumentsKeys.correctionField, text);
    await tester.tapKeyWithoutKeyboard(PatientDocumentsKeys.correctionSave);
    await settle();
  }

  // ── What the document did not say ─────────────────────────────────────────

  /// The §19 line: the document's silence, in the server's own words.
  Future<void> seeSilenceOn(String topic, {required String saying}) async {
    await tester.scrollToKey(PatientDocumentsKeys.topic(topic));
    expect(
      find.descendant(
        of: find.byKey(PatientDocumentsKeys.topic(topic)),
        matching: find.textContaining(saying),
      ),
      findsOneWidget,
      reason: 'expected the $topic line to read "$saying"',
    );
  }

  /// **The assertion this screen exists for.**
  ///
  /// A prescription with no allergy section says so. It does not say the
  /// patient has no allergies, in any of the ways a reasonable renderer would
  /// arrive at that: `list.isEmpty ? 'None' : …` gets there, and so does a
  /// heading with nothing under it.
  void seeNoFabricatedDenial() {
    for (final denial in const [
      'No known allergies',
      'No allergies',
      'None known',
      'Allergies: none',
      'Allergies: None',
      'No known drug allergies',
      'NKDA',
    ]) {
      expect(
        find.textContaining(denial, skipOffstage: false),
        findsNothing,
        reason: 'the screen turned a document\'s silence into "$denial", '
            'which is a clinical statement nobody made',
      );
    }
  }

  // ── The evidence, and the confirmation ────────────────────────────────────

  /// Asks for the original and waits for the viewer to appear.
  Future<void> openOriginal() async {
    await tester.tapKey(PatientDocumentsKeys.original);
    await settle();
    await tester.pumpUntilFound(find.byType(Image));
  }

  /// The confirmation is offered, and it is not yet pressable.
  Future<void> seeConfirmOfferedButNotReady() async {
    await tester.scrollToKey(PatientDocumentsKeys.confirm);
    final bar = find.byKey(PatientDocumentsKeys.confirm);
    expect(bar, findsOneWidget);
    expect(
      tester.widget<PrimaryBar>(bar).enabled,
      isFalse,
      reason: 'a document with unchecked values must not be confirmable',
    );
  }

  Future<void> seeConfirmReady() async {
    await tester.scrollToKey(PatientDocumentsKeys.confirm);
    expect(
      tester.widget<PrimaryBar>(find.byKey(PatientDocumentsKeys.confirm))
          .enabled,
      isTrue,
    );
  }

  /// The confirmation is gone, and the screen says what happens instead.
  Future<void> seeConfirmWithheld() async {
    await tester.scrollToKey(PatientDocumentsKeys.confirmBlocked);
    expect(find.byKey(PatientDocumentsKeys.confirmBlocked), findsOneWidget);
    expect(
      find.byKey(PatientDocumentsKeys.confirm),
      findsNothing,
      reason: 'a document the patient has contradicted must not offer to be '
          'confirmed as read',
    );
  }

  Future<void> confirmDocument() async {
    await tester.tapKey(PatientDocumentsKeys.confirm);
    await settle();
  }

  /// Back to the list, from the reading.
  ///
  /// Waits for the reading to **go**, not for the list to appear. A route below
  /// the top of the stack is still built and still findable, so waiting on the
  /// list's own key returns on the frame the pop starts — and the next tap then
  /// lands on the screen that is still sliding off, which absorbs it silently.
  Future<void> backToList() async {
    Get.back();
    await tester.pumpUntilGone(find.byKey(PatientDocumentsKeys.review));
    await tester.pumpUntilRouteSettled(
      expectRoute: PatientDocumentsRoutes.list,
    );
    await settle();
  }
}
