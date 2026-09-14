import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/data/models/case_review.dart';
import 'package:medihive/app/data/models/case_session.dart';
import 'package:medihive/app/data/models/patient_document.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — what the document and review parsers are not allowed to do
///
/// Every test here is about a *wrong* answer rather than a right one, because
/// the right ones are uninteresting: a prescription with three medicines on it
/// parses to three medicines whatever anybody does. What matters is the
/// handful of shapes where a reasonable-looking parser produces a clinical
/// statement nobody made, and each of those has a test below with the failure
/// spelled out in it.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  group('DocumentStatus', () {
    test('an unrecognised status is never verified and never needs review', () {
      // A token this build cannot read means "something happened that this
      // version does not know about". Reading it as `verified` claims a
      // confirmation the patient never gave; reading it as `needs_review`
      // offers them a Confirm button the server answers with a 400.
      for (final token in ['', 'quarantined', 'archived', 'null', 'VERIFIED']) {
        final status = DocumentStatus.resolve(token);
        expect(status, isNot(DocumentStatus.verified), reason: token);
        expect(status, isNot(DocumentStatus.needsReview), reason: token);
      }
    });

    test('the only way out of needs_review is the patient', () {
      // Mirrors the server's own rule so the control is absent rather than
      // refused. Nothing else on the row — not a confidence, not a successful
      // extraction — makes a document confirmable.
      for (final status in DocumentStatus.values) {
        final document = PatientDocument(id: 'd-1', status: status);
        expect(
          document.canVerify,
          status == DocumentStatus.needsReview,
          reason: '$status',
        );
      }
    });
  });

  group('DocumentPresence', () {
    test('an unrecognised presence lands on not_assessed', () {
      // The safe landing, and the only default in the file. `none` means the
      // document asserted there was nothing; a token nobody can read is not an
      // assertion of anything.
      for (final token in ['', 'nil', 'absent', 'NONE', 'no']) {
        expect(DocumentPresence.resolve(token), DocumentPresence.notAssessed,
            reason: token);
      }
    });
  });

  group('documents §19 — "not found" never becomes "no"', () {
    /// A prescription that names two medicines and never mentions allergies.
    /// The envelope is the shape `document-pipeline.service.ts` stores.
    Map<String, dynamic> prescription() => {
          'medications': [
            {'name': 'Metformin', 'strength': '500 mg', 'uncertain': false},
            {'name': 'Amlodipin', 'strength': '5 mg', 'uncertain': true},
          ],
          'allergies': <String>[],
          'facts': {
            'allergies': {
              'presence': 'not_assessed',
              'label': 'This document does not mention allergies',
              'values': <String>[],
            },
            'medications': {
              'presence': 'recorded',
              'label': 'Recorded',
              'values': ['Metformin', 'Amlodipin'],
            },
          },
          'confidence': {'ocr': 0.97, 'extraction': 0.5},
          'ungrounded': ['Amlodipin'],
        };

    test('an empty allergies list is not an allergy history', () {
      final extraction = DocumentExtraction.fromJson(prescription());
      final fact = extraction.factFor(DocumentTopic.allergies)!;

      expect(fact.presence, DocumentPresence.notAssessed);
      expect(fact.hasValues, isFalse);
      // The sentence is the server's and it says what actually happened. The
      // failure this guards is the one that gets somebody prescribed the drug
      // that kills them: `allergies?.length ? list : 'No known allergies'`.
      expect(fact.label, 'This document does not mention allergies');
      expect(fact.label.toLowerCase(), isNot(contains('no known')));
    });

    test('a topic the envelope never mentioned produces no sentence at all', () {
      final extraction = DocumentExtraction.fromJson(prescription());
      // Null, not a manufactured `not_assessed` with a wording this file
      // invented. A caller that has to handle "the server said nothing" is a
      // caller that cannot print a safe-sounding line nobody wrote.
      expect(extraction.factFor(DocumentTopic.procedures), isNull);
    });

    test('an explicit denial keeps the words the document earned', () {
      final fact = DocumentFact.fromJson(const {
        'presence': 'none',
        'label': 'No known allergies — stated in this document',
        'values': <String>[],
      });
      // "NKDA" printed on a discharge summary is a clinician asserting
      // something, and it is the one case where this wording is honest.
      expect(fact.presence, DocumentPresence.none);
      expect(fact.label, contains('stated in this document'));
    });
  });

  group('confidence', () {
    test('the two numbers are read separately and never combined', () {
      final document = PatientDocument.fromJson(const {
        'id': 'd-1',
        'status': 'needs_review',
        'ocrConfidence': 0.97,
        'extractionConfidence': 0.5,
        'message': 'We found some information in this document.',
      });

      expect(document.confidence.ocr, 0.97);
      expect(document.confidence.extraction, 0.5);
      // There is deliberately no `overall`, no `score` and no average. A
      // blended figure is a number nobody measured wearing the authority of
      // one somebody did.
      expect(
        document.confidence.toString(),
        isNot(contains('0.735')),
      );
    });

    test('a null extraction confidence is null and not zero', () {
      // A document that yielded no values has an undefined extraction quality.
      // Zero would sort it beside a document whose every value was invented.
      final confidence = DocumentConfidence.fromJson(const {
        'ocr': 0.9,
        'extraction': null,
      });
      expect(confidence.extraction, isNull);
    });
  });

  group('grounding', () {
    test('a value the model produced but the page never carried is flagged',
        () {
      final extraction = DocumentExtraction.fromJson(const {
        'ungrounded': ['Amlodipin'],
        'sources': [
          {
            'field': 'medications[0].name',
            'value': 'Metformin',
            'grounded': true,
            'page': 1,
            'ocrConfidence': 0.97,
          },
        ],
      });

      expect(extraction.isGrounded('Metformin'), isTrue);
      expect(extraction.isGrounded('Amlodipin'), isFalse);
      // Independent of the page's OCR score: a value that is not on the page is
      // not a value the recogniser got slightly wrong.
      expect(extraction.isGrounded('  amlodipin '), isFalse);
    });
  });

  group('duplicates', () {
    test('a duplicate is a row with a sentence, never a failure', () {
      final document = PatientDocument.fromJson(const {
        'id': 'd-2',
        'status': 'uploaded',
        'isDuplicate': true,
        'duplicateOfId': 'd-1',
        'message': 'You have already uploaded this document. We have kept it '
            'with the first copy rather than adding it twice.',
      });

      // §21: recorded and told. The row exists, it says what it is a copy of,
      // and it is not an error state.
      expect(document.isDuplicate, isTrue);
      expect(document.duplicateOfId, 'd-1');
      expect(document.status.isRefusal, isFalse);
      expect(document.message, contains('already uploaded'));
    });
  });

  group('a refusal is a sentence', () {
    test('an unreadable image carries written copy and no component name', () {
      final document = PatientDocument.fromJson(const {
        'id': 'd-3',
        'status': 'rejected_quality',
        'message': "We couldn't read this document clearly. Please upload a "
            'clearer image.',
      });

      expect(document.status.isRefusal, isTrue);
      expect(document.canVerify, isFalse);
      for (final leak in ['PP-OCR', 'Traceback', 'Exception', 'null', '500']) {
        expect(document.message, isNot(contains(leak)), reason: leak);
      }
    });
  });

  group('CaseReviewItem', () {
    test('an unrecognised verification is never a confirmation', () {
      for (final token in ['', 'confirmed', 'ok', 'true']) {
        expect(
          CaseVerification.resolve(token).isConfirmed,
          isFalse,
          reason: token,
        );
      }
      expect(CaseVerification.resolve('patient_confirmed').isConfirmed, isTrue);
    });

    test('an unrecognised source is never clinician_confirmed', () {
      // Reading an unknown token as a clinician's word would put somebody
      // else's name on the patient's own answer.
      for (final token in ['', 'inferred', 'assumed', 'system']) {
        expect(
          CaseFactSource.resolve(token),
          CaseFactSource.patientText,
          reason: token,
        );
      }
    });

    test('display is always printable, for every presence', () {
      final item = CaseReviewItem.fromJson(const {
        'fieldPath': 'allergies.reported',
        'label': 'Allergies',
        'presence': 'unknown',
        'display': 'Patient unsure',
        'presenceText': 'Patient unsure',
      });

      expect(item.presence, FactPresence.unknown);
      expect(item.isRecorded, isFalse);
      expect(item.display, isNotEmpty);
      // The two are sent separately so that a client cannot render a blank
      // where "Patient unsure" belongs.
      expect(item.presenceText, isNotEmpty);
    });
  });

  group('CaseReview', () {
    Map<String, dynamic> review() => {
          'sessionId': 'cs-1',
          'status': 'in_progress',
          'percentComplete': 50,
          'missingInformation': ['hpi.radiation', 'family.any_relevant'],
          'sections': [
            {
              'section': 'hpi',
              'title': 'History of the present illness',
              'items': [
                {
                  'fieldPath': 'hpi.duration',
                  'label': 'Duration',
                  'presence': 'recorded',
                  'display': 'Three days',
                  'presenceText': 'Recorded',
                  'value': 'three days',
                  'source': 'patient_voice',
                  'verification': 'unverified',
                  'outstanding': false,
                },
                {
                  'fieldPath': 'hpi.radiation',
                  'label': 'Does it spread anywhere?',
                  'presence': 'not_assessed',
                  'display': 'Not assessed',
                  'presenceText': 'Not assessed',
                  'outstanding': true,
                },
              ],
            },
          ],
          'safety': {'highestSeverity': 'none', 'triggeredCount': 0},
        };

    test('what is missing is available with the questions own wording', () {
      final parsed = CaseReview.fromJson(review());

      // §36: printed, never omitted. `missingInformation` carries bare field
      // keys, which is the right shape for a machine and the wrong one for a
      // patient — so the screen renders the items, which carry labels.
      expect(parsed.missingInformation, contains('hpi.radiation'));
      expect(parsed.outstandingItems, hasLength(1));
      expect(parsed.outstandingItems.single.label, 'Does it spread anywhere?');
      expect(parsed.recordedItems, hasLength(1));
    });

    test('a narrative nobody asked for is null, not the structured text', () {
      final parsed = CaseReview.fromJson(review());
      // Drafting the prose read-back costs a model call and is opt-in. Falling
      // back to the rendered text would present a transcript as a summary.
      expect(parsed.narrative, isNull);
    });

    test('a safety block that fired nothing says nothing', () {
      final parsed = CaseReview.fromJson(review());
      expect(parsed.safety.hasFired, isFalse);
      expect(parsed.safety.patientMessage, isNull);
    });
  });

  group('DocumentUpload', () {
    test('an oversized file is refused before it is sent', () {
      final tooBig = DocumentUpload(
        bytes: Uint8List(DocumentUpload.maxBytes + 1),
        filename: 'prescription.jpg',
        mimeType: 'image/jpeg',
      );
      expect(tooBig.isTooLarge, isTrue);
      // With a figure on it, because "too large" and no number leaves somebody
      // guessing how much smaller is small enough.
      expect(tooBig.sizeLabel, contains('MB'));
    });

    test('a photograph inside the ceiling is not', () {
      final fine = DocumentUpload(
        bytes: Uint8List(400 * 1024),
        filename: 'prescription.jpg',
        mimeType: 'image/jpeg',
      );
      expect(fine.isTooLarge, isFalse);
      expect(fine.sizeLabel, '400 KB');
    });
  });
}
