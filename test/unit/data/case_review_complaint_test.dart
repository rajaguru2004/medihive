import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/data/models/case_review.dart';
import 'package:medihive/app/data/models/case_session.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — what may cross from an interview into a booking
///
/// `CaseReview.complaintSummary` is the one place a clinical answer becomes
/// text a clinic reads as the reason somebody came in, so what it refuses
/// matters more than what it produces. Every case here is a way of quietly
/// getting it wrong:
///
///   * a denial, an "I don't know" and a question nobody asked all render a
///     *presence* in `display` — safe under their own question on the review
///     screen, and nonsense as a booking's complaint, where "Not assessed"
///     would arrive at a desk as the reason for the visit;
///   * lines from the rest of the case are somebody's family history, not
///     what brought them in today;
///   * an interview that never reached the complaint has nothing to say, and
///     saying nothing is the correct answer — the booking screen then asks.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  CaseReviewItem item({
    required String field,
    required String display,
    required FactPresence presence,
  }) =>
      CaseReviewItem(
        fieldPath: field,
        label: field,
        presence: presence,
        display: display,
        presenceText: display,
      );

  CaseReview reviewOf(List<CaseReviewSection> sections) =>
      CaseReview(sessionId: 's-1', sections: sections);

  group('complaintSummary', () {
    test('carries the recorded lines of the chief complaint', () {
      final review = reviewOf([
        CaseReviewSection(
          section: 'chief_complaint',
          title: 'What brought you in',
          items: [
            item(
              field: 'chief_complaint.symptom',
              display: 'Pain in the middle of my chest',
              presence: FactPresence.recorded,
            ),
            item(
              field: 'chief_complaint.duration',
              display: 'Three days',
              presence: FactPresence.recorded,
            ),
          ],
        ),
      ]);

      expect(
        review.complaintSummary,
        'Pain in the middle of my chest, Three days',
      );
    });

    test('never carries a presence the patient did not state', () {
      final review = reviewOf([
        CaseReviewSection(
          section: 'chief_complaint',
          title: 'What brought you in',
          items: [
            item(
              field: 'chief_complaint.symptom',
              display: 'A cough',
              presence: FactPresence.recorded,
            ),
            item(
              field: 'chief_complaint.onset',
              display: 'Not assessed',
              presence: FactPresence.notAssessed,
            ),
            item(
              field: 'chief_complaint.fever',
              display: 'None reported',
              presence: FactPresence.none,
            ),
            item(
              field: 'chief_complaint.severity',
              display: 'Patient unsure',
              presence: FactPresence.unknown,
            ),
          ],
        ),
      ]);

      expect(review.complaintSummary, 'A cough');
    });

    test('ignores every other section of the case', () {
      final review = reviewOf([
        CaseReviewSection(
          section: 'chief_complaint',
          title: 'What brought you in',
          items: [
            item(
              field: 'chief_complaint.symptom',
              display: 'A cough',
              presence: FactPresence.recorded,
            ),
          ],
        ),
        CaseReviewSection(
          section: 'family',
          title: 'Your family',
          items: [
            item(
              field: 'family.diabetes',
              display: 'Mother has diabetes',
              presence: FactPresence.recorded,
            ),
          ],
        ),
      ]);

      expect(review.complaintSummary, 'A cough');
    });

    test('an interview that never got that far says nothing', () {
      expect(CaseReview.empty.complaintSummary, isEmpty);
      expect(
        reviewOf([
          const CaseReviewSection(section: 'hpi', title: 'Your symptoms'),
        ]).complaintSummary,
        isEmpty,
      );
    });
  });
}
