import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/modules/case_taking/controllers/case_taking_controller.dart';
import 'package:medihive/app/modules/case_taking/interview_turn.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the three bands have to fit
///
/// The interview screen is a rail, a notices band, a scrolling transcript and
/// the live panel, and the middle two are given fractions of the height the
/// column actually has. `livePanelHeightFraction` carries a comment saying every
/// number in it was paid for by a defect — `0.34 + 0.52` starved the transcript
/// until it rendered nothing, and raising the panel to `0.72` overflowed the
/// red-flag screen by 91 points.
///
/// Nothing held those numbers still. This does, and it pins the property rather
/// than the values: whatever the four states are tuned to, the caps plus the
/// rail must leave the transcript something to draw in. A band that renders
/// nothing is the failure mode here — a `ListView.builder` given no room builds
/// no children, so the answer the patient just gave is neither on screen nor in
/// the tree.
/// ─────────────────────────────────────────────────────────────────────────────

/// What the rail takes off the top before the two capped bands get a share.
/// Named in `livePanelHeightFraction`'s own comment.
const double railShare = 0.08;

/// The floor the starved-`ListView` defect established: about a fifth.
const double transcriptFloor = 0.18;

CaseTakingController controllerWith({
  bool conversation = false,
  bool redFlag = false,
  bool spoken = false,
}) {
  final c = CaseTakingController();
  c.rxConversation.value = conversation;
  c.rxRedFlagRaised.value = redFlag;
  if (spoken) c.rxTurns.add(InterviewTurn.asked('How long has this gone on?'));
  return c;
}

void main() {
  group('the bands fit the column', () {
    for (final conversation in [false, true]) {
      for (final redFlag in [false, true]) {
        for (final spoken in [false, true]) {
          final name = [
            conversation ? 'talking' : 'tapping',
            redFlag ? 'a red flag' : 'no notice',
            spoken ? 'a conversation behind it' : 'nothing said yet',
          ].join(', ');

          test('$name leaves the transcript room to build', () {
            final c = controllerWith(
              conversation: conversation,
              redFlag: redFlag,
              spoken: spoken,
            );

            final notices = c.hasNotices ? c.noticesHeightFraction : 0.0;
            final panel = c.livePanelHeightFraction;
            final taken = railShare + notices + panel;

            // Overflow is the first failure: the column is a fixed height and
            // these are caps on it, so anything over 1.0 is drawn off-screen.
            expect(
              taken,
              lessThanOrEqualTo(1.0),
              reason: 'the caps overflow the column by '
                  '${((taken - 1.0) * 100).toStringAsFixed(1)}% of its height',
            );

            // Starvation is the second, and it is quieter: the transcript
            // renders nothing at all rather than rendering small.
            if (spoken) {
              expect(
                1.0 - taken,
                greaterThanOrEqualTo(transcriptFloor),
                reason: 'the transcript is left '
                    '${((1.0 - taken) * 100).toStringAsFixed(1)}% and needs '
                    'at least ${(transcriptFloor * 100).toStringAsFixed(0)}%',
              );
            }
          });
        }
      }
    }

    test('a spoken conversation gives the notice more room than tapping does', () {
      // The reason the fifth case exists. A conversation's panel is a status
      // card, a line of copy and the way out — no tile grid, no keyboard, no
      // send — so the slack belongs to the band that was clipping the patient's
      // own quoted words mid-syllable.
      final talking = controllerWith(conversation: true, redFlag: true, spoken: true);
      final tapping = controllerWith(redFlag: true, spoken: true);

      expect(
        talking.noticesHeightFraction,
        greaterThan(tapping.noticesHeightFraction),
      );
      expect(
        talking.livePanelHeightFraction,
        lessThan(tapping.livePanelHeightFraction),
      );
    });
  });
}
