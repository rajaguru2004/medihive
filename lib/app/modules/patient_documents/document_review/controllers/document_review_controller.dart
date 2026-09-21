import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/app_log.dart';
import '../../../../core/i18n/patient_text.dart';
import '../../../../data/models/patient_document.dart';
import '../../../../data/repositories/patient_documents_repository.dart';
import '../../../../data/utils/error_handler.dart';
import '../../../../data/utils/load_state.dart';
import '../../../login/demo_accounts.dart';
import '../../patient_documents_routes.dart';

/// What the patient has said about one extracted value.
///
/// Four states, not two, and for the same reason `PatientAnswer` has four: "I
/// am not sure" is a different fact from "that is wrong", and a screen that
/// offers only right and wrong makes somebody choose between two answers that
/// are both untrue. [unchecked] is the fourth and it is the starting state —
/// a value nobody has looked at is not a value anybody has agreed with, and
/// it is never drawn like one.
enum ValueCheck { unchecked, confirmed, corrected, unsure }

/// One extracted value, as a row on the review screen.
///
/// [field] is a stable key built from the topic and the position rather than
/// from the text, so the row keeps its identity — and its key, and the
/// patient's answer about it — when the same document is re-read and a
/// strength comes back spelled differently.
class DocumentValueRow {
  const DocumentValueRow({
    required this.field,
    required this.title,
    this.detail,
    this.needsCheck = false,
  });

  final String field;
  final String title;

  /// The dosing, the reading, the range. **Never ellipsised by the row** — a
  /// strength cut to `50…` could be 50 or 500.
  final String? detail;

  /// True when this particular value is worth a second look: the model said
  /// the text was ambiguous, or the value could not be found on the page at
  /// all. Independent of the document's overall confidence, because a value
  /// that is not on the page is not a value the recogniser got slightly wrong.
  final bool needsCheck;
}

/// One document, and what was read out of it.
///
/// The screen's whole job is to be honest about three things at once: what was
/// found, how sure anybody is about it, and the fact that **none of it has
/// been added to anything yet**. The server stops at `needs_review` for
/// exactly that reason and this controller never routes around it — there is
/// no path here that writes a medication onto a record, and the only write it
/// can make is the patient saying the reading is right.
class DocumentReviewController extends GetxController with LoadStateMixin {
  DocumentReviewController() {
    PatientDocumentsRepositories.register();
  }

  final PatientDocumentsRepository _repository =
      PatientDocumentsRepositories.instance;

  /// How often to ask again while the pipeline is running.
  ///
  /// Measured rather than chosen: OCR is about five seconds a page on the
  /// hardware this was built against and the extraction model fifteen more, so
  /// a second would be four wasted round trips and ten would leave somebody
  /// looking at a static screen after the work had finished.
  static const Duration _pollEvery = Duration(seconds: 2);

  /// A ceiling, so a row stuck at `processing` — a restart mid-read leaves one,
  /// and nothing retries it — does not poll for the rest of the afternoon.
  static const int _maxPolls = 45;

  final Rx<PatientDocument> document = PatientDocument.empty.obs;

  /// What the patient has said about each value, and what they said it should
  /// be. Held here rather than sent: see [canConfirm].
  final RxMap<String, ValueCheck> checks = <String, ValueCheck>{}.obs;
  final RxMap<String, String> corrections = <String, String>{}.obs;

  /// Which row is being corrected, if any. One at a time — two open editors is
  /// two keyboards' worth of screen and a save button that could mean either.
  final RxnString editingField = RxnString();
  final TextEditingController correctionText = TextEditingController();

  /// The original's bytes, once the patient has asked to see them.
  ///
  /// Bytes rather than a URL, and fetched through the authenticated client.
  /// The signed-link route answers with a URL naming the bucket's own host —
  /// `localhost:9010` here — which resolves to the handset itself, and the
  /// widget that loaded it sent no bearer token either. Both failures rendered
  /// as the same sentence, so neither could be told from the other.
  ///
  /// Fetched on the tap and never at load: a document nobody asks to see is a
  /// download nobody needed, over hospital wifi.
  final Rxn<Uint8List> originalBytes = Rxn<Uint8List>();
  final RxBool isFetchingOriginal = false.obs;

  /// The renderer for a PDF original, alive only while one is on screen.
  ///
  /// Held here rather than built in the view because it owns a native document
  /// handle: rebuilt on every frame it would leak one per rebuild, and the
  /// review screen rebuilds on every poll of a processing document.
  final Rxn<PdfController> pdfController = Rxn<PdfController>();

  /// Why the original would not open, shown next to the button that failed.
  ///
  /// Its own field rather than `confirmError`: that one is drawn inside the
  /// confirmation block, which is not on screen at all once a document is
  /// verified or has failed — so on exactly those documents a failed fetch
  /// used to produce a button that flickered and said nothing.
  final RxnString originalError = RxnString();

  final RxBool isConfirming = false.obs;
  final RxnString confirmError = RxnString();

  Timer? _poll;
  int _polls = 0;

  String get documentId =>
      Get.parameters[PatientDocumentsRoutes.documentIdParam] ?? '';

  @override
  void onReady() {
    super.onReady();
    unawaited(reload());
  }

  @override
  void onClose() {
    _poll?.cancel();
    correctionText.dispose();
    _closeOriginal();
    super.onClose();
  }

  /// Re-reads the document.
  ///
  /// **Not `refresh()`** — `GetxController` owns that name and returns void, so
  /// an `onRefresh:` wired to it never awaits.
  Future<void> reload() async {
    if (documentId.isEmpty) return;
    await runGuarded(() async {
      document.value = await _repository.read(documentId);
    }, fallback: PatientText.couldNotOpenDocument);
    _schedulePoll();
  }

  /// Asks again while the pipeline is still running, and stops the moment it
  /// is not.
  void _schedulePoll() {
    _poll?.cancel();
    if (!document.value.status.isWorking) return;
    // A duplicate stops at `uploaded` on purpose — the bytes were already held,
    // so nothing is running and nothing is going to change. Polling it would
    // be forty-five requests about a document that is finished.
    if (document.value.isDuplicate) return;
    if (_polls >= _maxPolls) return;

    _poll = Timer(_pollEvery, () async {
      _polls++;
      await _reloadQuietly();
      _schedulePoll();
    });
  }

  /// A poll that must not blank the screen or raise a banner.
  ///
  /// `silent` on the guard, because the patient is looking at "We're reading
  /// your document now" and a dropped packet on the fourth poll should not
  /// replace that with an error — the next poll answers.
  Future<void> _reloadQuietly() => runGuarded(
    () async {
      document.value = await _repository.read(documentId);
    },
    fallback: PatientText.couldNotOpenDocument,
    silent: true,
  );

  // ── What was found ────────────────────────────────────────────────────────

  DocumentExtraction get extraction =>
      document.value.extraction ?? DocumentExtraction.empty;

  /// The medicines, one row each, with the position baked into the key.
  List<DocumentValueRow> get medications => [
    for (var i = 0; i < extraction.medications.length; i++)
      DocumentValueRow(
        field: 'medications.$i',
        title: extraction.medications[i].name,
        detail: extraction.medications[i].detail.isEmpty
            ? null
            : extraction.medications[i].detail,
        // Two independent reasons, and either is enough. The model flags a
        // medicine whose text was garbled — it is the only party that saw
        // the ambiguity — and the grounding check flags a value that is
        // not in the page text at all.
        needsCheck:
            extraction.medications[i].uncertain ||
            !extraction.isGrounded(extraction.medications[i].name),
      ),
  ];

  List<DocumentValueRow> get investigations => [
    for (var i = 0; i < extraction.investigations.length; i++)
      DocumentValueRow(
        field: 'investigations.$i',
        title: extraction.investigations[i].test,
        detail: [
          extraction.investigations[i].reading,
          if ((extraction.investigations[i].referenceRange ?? '').isNotEmpty)
            extraction.investigations[i].referenceRange!,
          // The report's own flag, printed as the report printed it. Never
          // derived and never coloured: surfacing a value outside a stated
          // range is allowed and deciding it is abnormal is not.
          if ((extraction.investigations[i].flag ?? '').isNotEmpty)
            extraction.investigations[i].flag!,
        ].where((part) => part.isNotEmpty).join(' · '),
        needsCheck: !extraction.isGrounded(extraction.investigations[i].test),
      ),
  ];

  List<DocumentValueRow> _plain(String topic, List<String> values) => [
    for (var i = 0; i < values.length; i++)
      DocumentValueRow(
        field: '$topic.$i',
        title: values[i],
        needsCheck: !extraction.isGrounded(values[i]),
      ),
  ];

  List<DocumentValueRow> get diagnoses =>
      _plain('diagnosesRecorded', extraction.diagnosesRecorded);
  List<DocumentValueRow> get procedures =>
      _plain('procedures', extraction.procedures);
  List<DocumentValueRow> get followUp =>
      _plain('followUp', extraction.followUp);
  List<DocumentValueRow> get allergies =>
      _plain('allergies', extraction.allergies);

  /// Every row on the screen, which is what the confirmation gate counts.
  List<DocumentValueRow> get allRows => [
    ...medications,
    ...investigations,
    ...diagnoses,
    ...procedures,
    ...allergies,
    ...followUp,
  ];

  /// What the document says about a topic it listed nothing for.
  ///
  /// Returns the server's own sentence and **never invents one**. This is the
  /// single most dangerous line on the screen: an empty allergies array
  /// rendered as "no known allergies" is an assertion nobody made, and it is
  /// the one that gets somebody prescribed the drug that kills them. The
  /// pipeline looked for a phrase on the page before it would say "none"; this
  /// controller has no way to reach that conclusion on its own, and null here
  /// means the screen says nothing at all rather than something safe-sounding.
  DocumentFact? silenceOn(DocumentTopic topic) {
    final fact = extraction.factFor(topic);
    if (fact == null) return null;
    return fact.hasValues ? null : fact;
  }

  // ── What the patient says about it ────────────────────────────────────────

  ValueCheck checkOf(String field) => checks[field] ?? ValueCheck.unchecked;

  /// The value as it now stands: the patient's words when they corrected it,
  /// the document's otherwise.
  String valueOf(DocumentValueRow row) => corrections[row.field] ?? row.title;

  void confirmValue(String field) {
    checks[field] = ValueCheck.confirmed;
    _closeEditor();
  }

  void markUnsure(String field) {
    checks[field] = ValueCheck.unsure;
    _closeEditor();
  }

  /// Opens the editor on one row, pre-filled with what is there now.
  void startCorrecting(DocumentValueRow row) {
    editingField.value = row.field;
    correctionText.text = valueOf(row);
  }

  void cancelCorrecting() => _closeEditor();

  /// Keeps the patient's wording for this value.
  ///
  /// **Held on the phone, not sent.** There is no route that corrects one value
  /// inside a document's extraction — the API has an upload, a read, a signed
  /// link and a whole-document confirmation, and nothing between. So what this
  /// does is real but local: it re-labels the value as the patient's rather
  /// than the document's, and it stops the document being confirmed as read,
  /// which is the honest consequence of the patient saying the reading is
  /// wrong. The gap is worth closing server-side; pretending it is closed by
  /// showing a corrected value as filed would be worse than the gap.
  void saveCorrection() {
    final field = editingField.value;
    if (field == null) return;
    final text = correctionText.text.trim();
    if (text.isEmpty) return;

    corrections[field] = text;
    checks[field] = ValueCheck.corrected;
    _closeEditor();
  }

  void _closeEditor() {
    editingField.value = null;
    correctionText.clear();
  }

  /// Whether the document-level confirmation may be offered.
  ///
  /// Mirrors the server's own rule so the control is **absent** rather than
  /// refused — `verify` is a 400 on anything that is not `needs_review` — and
  /// adds the one the server cannot know: every value on the screen has been
  /// agreed with. Confirming means "what was extracted is correct", and a
  /// screen that let somebody confirm a document while one line on it was
  /// marked wrong would be filing that word against something they disagreed
  /// with.
  /// In demo builds the second rule is relaxed — see
  /// [DemoAccounts.confirmAnyway]. The server's own rule is not: `canVerify`
  /// still gates the control, because a flag on a phone cannot make a 400 a
  /// 200. [isBlocked] is deliberately left alone, so the notice saying a
  /// clinician will look at the document stays on screen beside the button.
  bool get canConfirm {
    if (!document.value.canVerify) return false;
    final rows = allRows;
    if (rows.isEmpty) return false;
    if (DemoAccounts.confirmAnyway) return true;
    return rows.every((row) => checkOf(row.field) == ValueCheck.confirmed);
  }

  /// Something on this screen is wrong or uncertain, so the document stays
  /// unconfirmed and the patient is told what happens instead.
  bool get isBlocked => allRows.any((row) {
    final check = checkOf(row.field);
    return check == ValueCheck.corrected || check == ValueCheck.unsure;
  });

  /// The patient confirming the reading. The only write this screen makes.
  Future<bool> confirmDocument() async {
    if (isConfirming.value || !canConfirm) return false;

    isConfirming.value = true;
    confirmError.value = null;
    try {
      document.value = await _repository.confirm(documentId);
      return true;
    } catch (e, stack) {
      AppLog.error('$runtimeType', 'confirming a document failed', e, stack);
      confirmError.value = parseErrorMessage(
        e,
        PatientText.couldNotConfirmDocument,
      );
      return false;
    } finally {
      isConfirming.value = false;
    }
  }

  // ── The evidence ──────────────────────────────────────────────────────────

  /// Fetches the original and shows it inline.
  ///
  /// A second tap hides it again, which is what a disclosure does, and does not
  /// fetch a file already on screen a second time.
  Future<void> toggleOriginal() async {
    if (originalBytes.value != null) {
      _closeOriginal();
      return;
    }
    if (isFetchingOriginal.value) return;

    isFetchingOriginal.value = true;
    originalError.value = null;
    try {
      final bytes = await _repository.originalBytes(documentId);
      // An empty body is a failure that would otherwise reach the screen as a
      // broken image frame with nothing to say about it.
      if (bytes.isEmpty) throw StateError('the original came back empty');
      originalBytes.value = bytes;
      if (originalIsPdf) {
        pdfController.value = PdfController(
          document: PdfDocument.openData(bytes),
        );
      }
    } catch (e, stack) {
      AppLog.error('$runtimeType', 'fetching the original failed', e, stack);
      originalError.value = parseErrorMessage(
        e,
        PatientText.couldNotOpenOriginal,
      );
    } finally {
      isFetchingOriginal.value = false;
    }
  }

  /// Puts the original away and releases the renderer with it.
  ///
  /// One place, because there are two ways out — the second tap and leaving the
  /// screen — and a `PdfController` that outlives its widget holds a native
  /// document open.
  void _closeOriginal() {
    originalBytes.value = null;
    originalError.value = null;
    pdfController.value?.dispose();
    pdfController.value = null;
  }

  /// Whether the original can be shown on the phone at all.
  ///
  /// Photographs and PDFs — the two things the upload route accepts. It used to
  /// be photographs alone, because the app shipped no PDF renderer and a button
  /// that opened nothing is worse than no button. `pdfx` renders one now, so a
  /// patient who sent a discharge letter can read it back instead of being told
  /// to ask at the desk.
  ///
  /// Rendered **inside the app** rather than handed to the phone's PDF viewer:
  /// that would mean writing a medical document to shared storage and passing
  /// it to whatever app claims the type.
  bool get canShowOriginal =>
      document.value.mimeType.startsWith('image/') || originalIsPdf;

  /// Which of the two renderers the bytes need.
  bool get originalIsPdf => document.value.mimeType == 'application/pdf';
}
