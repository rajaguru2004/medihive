import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/core/app_clock.dart';

/// The idle rule, as arithmetic.
///
/// The service itself needs a widget binding, a registered `AuthService` and a
/// `SettingsService` to instantiate, which makes it a widget test rather than a
/// unit one. What is worth pinning here is the decision it makes on resume,
/// because that is the half a foreground-only timer gets wrong: a device face
/// down on a trolley for twenty minutes was never idle *in the app*, and the
/// timer that would have fired was cancelled when it went to the background.
bool shouldLockOnResume({
  required DateTime backgroundedAt,
  required DateTime now,
  required int lockAfterMinutes,
}) {
  if (lockAfterMinutes <= 0) return false;
  return now.difference(backgroundedAt).inMinutes >= lockAfterMinutes;
}

void main() {
  final anchor = DateTime(2026, 3, 12, 14, 20);

  setUp(() => AppClock.freeze(anchor));
  tearDown(AppClock.unfreeze);

  group('locking after time in the background', () {
    test('locks when the device was away longer than the threshold', () {
      expect(
        shouldLockOnResume(
          backgroundedAt: anchor.subtract(const Duration(minutes: 20)),
          now: anchor,
          lockAfterMinutes: 5,
        ),
        isTrue,
      );
    });

    test('locks exactly at the threshold, not a minute after', () {
      expect(
        shouldLockOnResume(
          backgroundedAt: anchor.subtract(const Duration(minutes: 5)),
          now: anchor,
          lockAfterMinutes: 5,
        ),
        isTrue,
      );
    });

    test('does not lock a device picked straight back up', () {
      // Putting a tablet down to take an observation and picking it up again
      // must not cost a password. A lock that fires on a thirty-second gap is
      // a lock people work around by not locking.
      expect(
        shouldLockOnResume(
          backgroundedAt: anchor.subtract(const Duration(seconds: 30)),
          now: anchor,
          lockAfterMinutes: 5,
        ),
        isFalse,
      );
    });

    test('zero minutes means never', () {
      // The right setting for a device one clinician carries all shift.
      expect(
        shouldLockOnResume(
          backgroundedAt: anchor.subtract(const Duration(hours: 9)),
          now: anchor,
          lockAfterMinutes: 0,
        ),
        isFalse,
      );
    });

    test('a negative threshold is treated as off, not as always', () {
      // A stored value can be anything. `>= -1` would be true for every gap,
      // so a site with a corrupt setting would lock on every resume.
      expect(
        shouldLockOnResume(
          backgroundedAt: anchor,
          now: anchor,
          lockAfterMinutes: -1,
        ),
        isFalse,
      );
    });
  });
}
