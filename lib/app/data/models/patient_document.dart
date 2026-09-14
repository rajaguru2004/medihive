/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — a document the patient handed over, as the phone reads it
///
/// `/api/patient-documents/*` answers with a row, a status, two measured
/// confidences and — when the reading worked — the §26 extraction envelope.
/// This file is the only place those shapes are parsed, and four of its
/// decisions are clinical properties rather than parsing conveniences:
///
///  * **Absence is a presence, and its wording comes from the server.**
///    [DocumentFact] carries the sentence the pipeline wrote — "This document
///    does not mention allergies" — and this file has no code path that can
///    turn an empty list into "no known allergies". The label is never
///    rebuilt here from the presence, because the only place that mapping
///    should exist is the one that also holds the evidence for it. Documents
///    §19, and the single most dangerous mistake available on this screen.
///
///  * **The two confidences never meet.** [DocumentConfidence] keeps the OCR
///    measurement and the grounding score apart and refuses to average them.
///    They measure different things — how well the page was read, and how much
///    of what was structured out of it was actually on the page — and one
///    blended number is a figure nobody measured wearing the authority of one
///    somebody did.
///
///  * **A status this build does not recognise is never `verified`.**
///    [DocumentStatus.resolve] lands an unknown token on [processing]: "we do
///    not know yet". Reading it as verified would claim a confirmation the
///    patient never gave, and reading it as `needsReview` would offer them a
///    Confirm button the server is about to refuse.
///
///  * **The sentence on screen is the server's.** [PatientDocument.message] is
///    always populated and always written for a patient; §27's failure mode is
///    an engine's `error.message` reaching somebody who wanted to know whether
///    to take another photograph, and the way that happens is a client
///    deciding it can word the state better itself.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:typed_data';

import 'json.dart';

/// Where a document row has got to.
///
/// Seven states, and the transition that matters is the one that is missing: a
/// document leaves [needsReview] only when the patient says the reading is
/// right. There is no confidence high enough to earn that on its own.
enum DocumentStatus {
  /// Stored, nothing read yet. Also where a duplicate stops.
  uploaded,

  /// Being read.
  processing,

  /// Read and structured, waiting to be moved on by the pipeline.
  extracted,

  /// Read, and waiting for the patient. The only state Confirm is offered in.
  needsReview,

  /// The patient confirmed it.
  verified,

  /// Something went wrong reading it. The row carries a written sentence.
  failed,

  /// The image was never good enough to try. Also a written sentence.
  rejectedQuality;

  /// Reads the server's token.
  ///
  /// An unrecognised token lands here rather than anywhere that would change
  /// what the screen offers. See the file header.
  static DocumentStatus resolve(String? raw) => switch ((raw ?? '').trim()) {
        'uploaded' => uploaded,
        'processing' => processing,
        'extracted' => extracted,
        'needs_review' => needsReview,
        'verified' => verified,
        'failed' => failed,
        'rejected_quality' => rejectedQuality,
        _ => processing,
      };

  /// Still moving. The screen polls while this is true.
  bool get isWorking => this == uploaded || this == processing;

  /// The patient has something to do about it.
  bool get isAwaitingPatient => this == needsReview || this == extracted;

  /// Nothing was read, and the row's sentence says why.
  bool get isRefusal => this == failed || this == rejectedQuality;
}

/// What the classifier thought the page was.
///
/// Never used to decide anything clinical — it chooses which extraction schema
/// ran and which heading a section gets, and that is all it is for.
enum DocumentKind {
  prescription,
  laboratoryReport,
  dischargeSummary,
  imagingReport,
  referralLetter,
  consultationNote,
  other,
  unknown;

  static DocumentKind resolve(String? raw) => switch ((raw ?? '').trim()) {
        'prescription' => prescription,
        'laboratory_report' => laboratoryReport,
        'discharge_summary' => dischargeSummary,
        'imaging_report' => imagingReport,
        'referral_letter' => referralLetter,
        'consultation_note' => consultationNote,
        'other' => other,
        _ => unknown,
      };

  /// What a patient calls it. Deliberately plain, and deliberately hedged for
  /// [unknown] and [other] — "Document" is honest where "Report" is a guess.
  String get label => switch (this) {
        prescription => 'Prescription',
        laboratoryReport => 'Test results',
        dischargeSummary => 'Discharge summary',
        imagingReport => 'Scan report',
        referralLetter => 'Referral letter',
        consultationNote => 'Clinic note',
        other || unknown => 'Document',
      };
}

/// The six presences, as the document pipeline speaks them.
///
/// Spelled here rather than shared with `case_session.dart`'s [FactPresence]
/// on purpose: this is the *document's* vocabulary and the two files are
/// parsed from two different envelopes. They agree today, and the day one of
/// them gains a state is the day a shared enum would silently give it to both.
enum DocumentPresence {
  /// The document named something.
  recorded,

  /// The document explicitly said there was nothing — "NKDA" printed on a
  /// discharge summary is a clinician asserting something.
  none,

  unknown,
  notApplicable,

  /// The document did not raise the subject. The default, and the safe one.
  notAssessed,

  declined;

  static DocumentPresence resolve(String? raw) => switch ((raw ?? '').trim()) {
        'recorded' => recorded,
        'none' => none,
        'unknown' => unknown,
        'not_applicable' => notApplicable,
        'declined' => declined,
        _ => notAssessed,
      };
}

/// The topics a document can speak to.
enum DocumentTopic {
  allergies,
  medications,
  diagnoses,
  procedures,
  investigations;

  String get wireValue => switch (this) {
        allergies => 'allergies',
        medications => 'medications',
        diagnoses => 'diagnoses',
        procedures => 'procedures',
        investigations => 'investigations',
      };
}

/// What this document says about one topic, **in the server's own words**.
///
/// [label] is not derived. The pipeline decided between "No known allergies —
/// stated in this document" and "This document does not mention allergies" by
/// looking for the phrase on the page, and it is the only party that saw the
/// page. A client that re-derived the wording from [presence] would be
/// guessing at the evidence, and the guess that costs somebody their life is
/// the one that turns silence into a denial.
class DocumentFact {
  const DocumentFact({
    required this.presence,
    required this.label,
    this.values = const [],
  });

  final DocumentPresence presence;

  /// Always safe to print, for every presence.
  final String label;

  /// Populated only for [DocumentPresence.recorded]; empty otherwise, because
  /// there is nothing to list.
  final List<String> values;

  factory DocumentFact.fromJson(Map<String, dynamic> json) => DocumentFact(
        presence: DocumentPresence.resolve(asString(json['presence'])),
        label: asString(json['label']),
        values: asStringList(json['values']),
      );

  /// True when this topic carries something to read out.
  bool get hasValues =>
      presence == DocumentPresence.recorded && values.isNotEmpty;
}

/// One prescribed medicine, exactly as the document wrote it.
class ExtractedMedication {
  const ExtractedMedication({
    required this.name,
    this.strength,
    this.dose,
    this.frequency,
    this.route,
    this.duration,
    this.instructions,
    this.uncertain = false,
  });

  final String name;
  final String? strength;
  final String? dose;
  final String? frequency;
  final String? route;
  final String? duration;
  final String? instructions;

  /// §12: the model was asked for this directly, because it is the only party
  /// that saw the handwriting. A medicine flagged here is shown with a "check
  /// this" mark rather than quietly presented as read.
  final bool uncertain;

  factory ExtractedMedication.fromJson(Map<String, dynamic> json) =>
      ExtractedMedication(
        name: asString(json['name']),
        strength: asStringOrNull(json['strength']),
        dose: asStringOrNull(json['dose']),
        frequency: asStringOrNull(json['frequency']),
        route: asStringOrNull(json['route']),
        duration: asStringOrNull(json['duration']),
        instructions: asStringOrNull(json['instructions']),
        uncertain: asBool(json['uncertain']),
      );

  /// `Amoxicillin 500 mg · three times a day · 5 days`.
  ///
  /// **Never ellipsised by a caller.** A dose is a clinical figure and `500…`
  /// could be 500 or 5000; the row wraps instead.
  String get detail => [
        if ((strength ?? '').isNotEmpty) strength!,
        if ((dose ?? '').isNotEmpty) dose!,
        if ((frequency ?? '').isNotEmpty) frequency!,
        if ((route ?? '').isNotEmpty) route!,
        if ((duration ?? '').isNotEmpty) duration!,
      ].join(' · ');
}

/// One line off a laboratory report.
class ExtractedInvestigation {
  const ExtractedInvestigation({
    required this.test,
    this.result,
    this.unit,
    this.referenceRange,
    this.flag,
  });

  final String test;
  final String? result;
  final String? unit;
  final String? referenceRange;

  /// Whatever the report itself printed — `H`, `L`, `*`, `high`. **Never
  /// derived here**, and never coloured: surfacing a value that sits outside a
  /// stated range is permitted and diagnosing from it is not, and the line
  /// between the two is drawn by not being the one who decided it was
  /// abnormal.
  final String? flag;

  factory ExtractedInvestigation.fromJson(Map<String, dynamic> json) =>
      ExtractedInvestigation(
        test: asString(json['test']),
        result: asStringOrNull(json['result']),
        unit: asStringOrNull(json['unit']),
        referenceRange: asStringOrNull(json['referenceRange']),
        flag: asStringOrNull(json['flag']),
      );

  /// `5.4 mmol/L`. The figure and its unit, never one without the other.
  String get reading => [
        if ((result ?? '').isNotEmpty) result!,
        if ((unit ?? '').isNotEmpty) unit!,
      ].join(' ');
}

/// Where one extracted value came from, and whether it was really on the page.
class DocumentValueSource {
  const DocumentValueSource({
    required this.field,
    required this.value,
    required this.grounded,
    this.page,
    this.ocrConfidence,
  });

  /// Where in the extraction this value sits — `medications[0].name`.
  final String field;

  final String value;

  /// Whether this exact text was found in the OCR output. False is the
  /// reviewer's shortlist: a value the model produced that is not on the page.
  final bool grounded;

  /// 1-based, or null when the value could not be located on any page.
  final int? page;

  final double? ocrConfidence;

  factory DocumentValueSource.fromJson(Map<String, dynamic> json) =>
      DocumentValueSource(
        field: asString(json['field']),
        value: asString(json['value']),
        grounded: asBool(json['grounded']),
        page: json['page'] == null ? null : asInt(json['page']),
        ocrConfidence: json['ocrConfidence'] == null
            ? null
            : asDouble(json['ocrConfidence']),
      );
}

/// A difference between this document and what the hospital already holds.
///
/// §20 and §33: **surfaced, never resolved.** Nothing here has been applied to
/// anything; both sides are carried so the screen can show both and change
/// neither.
class DocumentContradiction {
  const DocumentContradiction({
    required this.topic,
    required this.kind,
    required this.documentValue,
    required this.recordValues,
    required this.recordHadEntries,
    required this.message,
  });

  final DocumentTopic topic;

  /// `absent_from_record` — the document names something the record does not
  /// hold. `differs_from_record` — the record holds the same item with a
  /// different value.
  final String kind;

  final String documentValue;

  /// What the record holds on this topic, so a reader sees both sides.
  final List<String> recordValues;

  /// False when the record's list for this topic was empty.
  ///
  /// The difference between a conflict and a first entry. A patient whose
  /// record lists no medications and who uploads a prescription has not
  /// contradicted anything — and wording the two cases identically would tell
  /// half the patients on their first upload that their record disagrees with
  /// itself.
  final bool recordHadEntries;

  /// Written for a patient, by the server.
  final String message;

  factory DocumentContradiction.fromJson(Map<String, dynamic> json) =>
      DocumentContradiction(
        topic: switch (asString(json['topic'])) {
          'medications' => DocumentTopic.medications,
          'diagnoses' => DocumentTopic.diagnoses,
          'procedures' => DocumentTopic.procedures,
          'investigations' => DocumentTopic.investigations,
          _ => DocumentTopic.allergies,
        },
        kind: asString(json['kind'], fallback: 'absent_from_record'),
        documentValue: asString(json['documentValue']),
        recordValues: asStringList(json['recordValues']),
        recordHadEntries: asBool(json['recordHadEntries']),
        message: asString(json['message']),
      );
}

/// §17's two stages, kept apart.
///
/// There is deliberately no `overall` here and there never will be. See the
/// file header.
class DocumentConfidence {
  const DocumentConfidence({this.ocr, this.extraction});

  /// The recogniser's own measurement of how well it read the characters.
  final double? ocr;

  /// The share of extracted values found verbatim in the source text.
  ///
  /// Null when there was nothing to check — **not zero**, which would sort a
  /// document that yielded no values beside one whose every value was
  /// invented.
  final double? extraction;

  factory DocumentConfidence.fromJson(Map<String, dynamic> json) =>
      DocumentConfidence(
        ocr: json['ocr'] == null ? null : asDouble(json['ocr']),
        extraction:
            json['extraction'] == null ? null : asDouble(json['extraction']),
      );
}

/// The §26 envelope: what was read, where each value came from, and what it
/// disagrees with.
class DocumentExtraction {
  const DocumentExtraction({
    this.medications = const [],
    this.investigations = const [],
    this.diagnosesRecorded = const [],
    this.procedures = const [],
    this.followUp = const [],
    this.allergies = const [],
    this.facts = const {},
    this.sources = const [],
    this.ungrounded = const [],
    this.contradictions = const [],
    this.confidence = const DocumentConfidence(),
    this.facility,
    this.documentDate,
  });

  static const DocumentExtraction empty = DocumentExtraction();

  final List<ExtractedMedication> medications;
  final List<ExtractedInvestigation> investigations;

  /// §14's field name, kept: the document recorded these. The app did not
  /// decide them and must never present them as a new finding.
  final List<String> diagnosesRecorded;

  final List<String> procedures;
  final List<String> followUp;
  final List<String> allergies;

  /// §19, by topic. The only place the screen may read a topic's absence from.
  final Map<DocumentTopic, DocumentFact> facts;

  final List<DocumentValueSource> sources;

  /// Values the model produced that are **not** in the source text.
  final List<String> ungrounded;

  final List<DocumentContradiction> contradictions;
  final DocumentConfidence confidence;

  final String? facility;
  final DateTime? documentDate;

  factory DocumentExtraction.fromJson(Map<String, dynamic> json) {
    final document = asMap(json['document']);
    final facts = asMap(json['facts']);

    return DocumentExtraction(
      medications:
          asModelList(json['medications'], ExtractedMedication.fromJson),
      investigations:
          asModelList(json['investigations'], ExtractedInvestigation.fromJson),
      diagnosesRecorded: asStringList(json['diagnosesRecorded']),
      procedures: asStringList(json['procedures']),
      followUp: asStringList(json['followUp']),
      allergies: asStringList(json['allergies']),
      facts: {
        for (final topic in DocumentTopic.values)
          if (facts[topic.wireValue] != null)
            topic: DocumentFact.fromJson(asMap(facts[topic.wireValue])),
      },
      sources: asModelList(json['sources'], DocumentValueSource.fromJson),
      ungrounded: asStringList(json['ungrounded']),
      contradictions:
          asModelList(json['contradictions'], DocumentContradiction.fromJson),
      confidence: DocumentConfidence.fromJson(asMap(json['confidence'])),
      facility: asStringOrNull(document['facility']),
      documentDate: asDate(document['date']),
    );
  }

  /// The topic's fact, or null when the envelope carried none.
  ///
  /// Returning null rather than a manufactured `not_assessed` is deliberate:
  /// a caller that has to handle "the server said nothing about this topic"
  /// separately is a caller that cannot accidentally print a sentence the
  /// server did not write.
  DocumentFact? factFor(DocumentTopic topic) => facts[topic];

  /// Whether this value was located in the page text.
  ///
  /// Anything ungrounded is shown with a "check this" mark whatever the OCR
  /// score was: a value that is not on the page is not a value the recogniser
  /// got slightly wrong.
  bool isGrounded(String value) {
    final needle = value.trim().toLowerCase();
    if (needle.isEmpty) return true;
    if (ungrounded.any((e) => e.trim().toLowerCase() == needle)) return false;
    for (final source in sources) {
      if (source.value.trim().toLowerCase() == needle) return source.grounded;
    }
    return true;
  }

  bool get isEmpty =>
      medications.isEmpty &&
      investigations.isEmpty &&
      diagnosesRecorded.isEmpty &&
      procedures.isEmpty &&
      followUp.isEmpty &&
      allergies.isEmpty;
}

/// One document the patient handed over.
class PatientDocument {
  const PatientDocument({
    required this.id,
    this.sessionId,
    this.mimeType = '',
    this.byteSize = 0,
    this.pageCount = 0,
    this.status = DocumentStatus.processing,
    this.kind = DocumentKind.unknown,
    this.kindConfidence,
    this.confidence = const DocumentConfidence(),
    this.extraction,
    this.visionFallbackUsed = false,
    this.isDuplicate = false,
    this.duplicateOfId,
    this.message = '',
    this.uploadedAt,
    this.processedAt,
    this.verifiedAt,
  });

  static const PatientDocument empty = PatientDocument(id: '');

  final String id;
  final String? sessionId;
  final String mimeType;
  final int byteSize;
  final int pageCount;

  final DocumentStatus status;
  final DocumentKind kind;
  final double? kindConfidence;

  /// The two measured numbers, read off the row rather than off the envelope.
  ///
  /// The row carries them for every document, including the ones whose
  /// extraction never ran, so a screen that only had the envelope would show
  /// nothing for exactly the documents it most needs to explain.
  final DocumentConfidence confidence;

  /// Null for a row that has nothing read out of it yet — a duplicate, a
  /// refusal, or one still in the queue.
  final DocumentExtraction? extraction;

  final bool visionFallbackUsed;

  /// §21: a duplicate is **recorded and reported**, never refused. The row
  /// exists, and the message on it says it is the same document.
  final bool isDuplicate;
  final String? duplicateOfId;

  /// What to show the patient. Always a sentence, never an engine message.
  final String message;

  final DateTime? uploadedAt;
  final DateTime? processedAt;
  final DateTime? verifiedAt;

  bool get isEmpty => id.isEmpty;

  /// Whether the patient can confirm this one.
  ///
  /// The server's rule, mirrored so the button is absent rather than refused:
  /// `verify` is a 400 on anything that is not `needs_review`.
  bool get canVerify => status == DocumentStatus.needsReview;

  /// Anything worth putting in front of the patient as a finding.
  bool get hasFindings => extraction != null && !extraction!.isEmpty;

  factory PatientDocument.fromJson(Map<String, dynamic> json) {
    final raw = json['extraction'];
    return PatientDocument(
      id: asString(json['id']),
      sessionId: asStringOrNull(json['sessionId']),
      mimeType: asString(json['mimeType']),
      byteSize: asInt(json['byteSize']),
      pageCount: asInt(json['pageCount']),
      status: DocumentStatus.resolve(asString(json['status'])),
      kind: DocumentKind.resolve(asString(json['docType'])),
      kindConfidence: json['docTypeConfidence'] == null
          ? null
          : asDouble(json['docTypeConfidence']),
      // Read off the row's own two columns. `extraction.confidence` repeats
      // them and is not consulted: one source, so the pair on screen cannot
      // disagree with the pair in the database.
      confidence: DocumentConfidence(
        ocr: json['ocrConfidence'] == null
            ? null
            : asDouble(json['ocrConfidence']),
        extraction: json['extractionConfidence'] == null
            ? null
            : asDouble(json['extractionConfidence']),
      ),
      extraction: raw is Map
          ? DocumentExtraction.fromJson(raw.cast<String, dynamic>())
          : null,
      visionFallbackUsed: asBool(json['visionFallbackUsed']),
      isDuplicate: asBool(json['isDuplicate']),
      duplicateOfId: asStringOrNull(json['duplicateOfId']),
      message: asString(json['message']),
      uploadedAt: asDate(json['uploadedAt']),
      processedAt: asDate(json['processedAt']),
      verifiedAt: asDate(json['verifiedAt']),
    );
  }
}

/// A short-lived signed link to the file the extraction came from.
///
/// §22 requires the original be kept as evidence, and evidence nobody can look
/// at is filing. It expires in minutes, so it is fetched when the patient asks
/// to see it and never held.
class DocumentOriginal {
  const DocumentOriginal({
    required this.url,
    this.expiresInSeconds = 0,
    this.expiresAt,
    this.mimeType = '',
  });

  final String url;
  final int expiresInSeconds;
  final DateTime? expiresAt;
  final String mimeType;

  bool get isEmpty => url.isEmpty;

  factory DocumentOriginal.fromJson(Map<String, dynamic> json) =>
      DocumentOriginal(
        url: asString(json['url']),
        expiresInSeconds: asInt(json['expiresInSeconds']),
        expiresAt: asDate(json['expiresAt']),
        mimeType: asString(json['mimeType']),
      );
}

/// A file chosen but not yet sent.
///
/// One type over both seams. `ImageSource` hands back a [PickedImage] and
/// `FileSource` a [PickedFile]; the upload route and the screen above it care
/// about neither distinction, and two near-identical code paths through the
/// same controller is one of them eventually getting a fix the other does not.
class DocumentUpload {
  const DocumentUpload({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;

  /// One of the four the route accepts — `image/jpeg`, `image/png`,
  /// `image/webp`, `application/pdf`. Sent explicitly rather than guessed from
  /// the extension: Dio types a part it was given no type for as
  /// `application/octet-stream`, which the route's `fileFilter` refuses with a
  /// sentence about the file not being a photo.
  final String mimeType;

  int get sizeInBytes => bytes.length;

  /// `PATIENT_DOCUMENT_MAX_BYTES` in `patient-documents.service.ts`.
  ///
  /// Three places hold this number — here, the route, and the sidecar — and
  /// that is not duplication: each one is the last line for a caller that did
  /// not come through the previous one. This one exists so a patient is told a
  /// fact about their photograph instead of watching ten megabytes climb over
  /// clinic wifi to be dropped at the far end.
  static const int maxBytes = 10 * 1024 * 1024;

  bool get isTooLarge => sizeInBytes > maxBytes;

  /// `2.4 MB`. Beside the refusal, because "too large" without a figure leaves
  /// somebody guessing how much smaller is small enough.
  String get sizeLabel {
    const unit = 1024;
    if (sizeInBytes < unit) return '$sizeInBytes B';
    final kb = sizeInBytes / unit;
    if (kb < unit) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
    return '${(kb / unit).toStringAsFixed(1)} MB';
  }
}
