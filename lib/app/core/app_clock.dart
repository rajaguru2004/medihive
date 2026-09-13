/// The one place the app asks what time it is.
///
/// Exists for a single reason: a screen that reads `DateTime.now()` directly
/// cannot be captured. The dashboard greets by time of day, so its golden
/// passed all afternoon and failed every evening — a test that fails on the
/// clock rather than on the code, which is worse than no test at all.
///
/// Production leaves [now] alone. A test pins it:
///
/// ```dart
/// AppClock.freeze(DateTime(2026, 9, 12, 10, 30));
/// addTearDown(AppClock.unfreeze);
/// ```
///
/// **Anything a screen derives a date from**, which includes the form defaults
/// — today on a new invoice, today + 30 for its expiry, the due date a payment
/// term computes. Those are shown before they are sent, and a golden that
/// captures one fails at the next midnight otherwise. That is exactly what
/// happened to four form goldens the day after they were baked, which is how
/// this rule got its second half.
///
/// Not for elapsed time: the OTP countdown and the splash minimum measure how
/// long something has taken, and a frozen clock makes both of those never
/// finish. They keep the real one.
///
/// In production [freeze] is never called, so every caller here reads the real
/// clock and sends a real date.
abstract final class AppClock {
  static DateTime? _frozen;

  /// What the app should call "now" when it is about to show it to somebody.
  static DateTime now() => _frozen ?? DateTime.now();

  /// Pins the clock. Tests only.
  static void freeze(DateTime instant) => _frozen = instant;

  static void unfreeze() => _frozen = null;

  /// Whether a test has pinned it.
  static bool get isFrozen => _frozen != null;
}
