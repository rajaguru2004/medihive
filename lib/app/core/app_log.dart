import 'package:flutter/foundation.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — Logging
///
/// One entry point for every diagnostic line the app writes, so that:
///
///  * **Release builds are silent.** Every method short-circuits on
///    `kReleaseMode`. A stray `print()` in a release build writes to logcat,
///    where any other app with log access can read it.
///  * **Lines are greppable.** `[Tag] message` — the tag is the class or
///    subsystem, and the console filter that finds one screen's logs is
///    `[Invoices]`.
///  * **The level is visible at a glance.** Colour in a terminal that supports
///    it, and a leading glyph in one that does not.
///
/// The network layer does not use this — `LoggingInterceptor` owns HTTP, and
/// it redacts the bearer token, which a generic logger cannot know to do.
/// ─────────────────────────────────────────────────────────────────────────────
enum LogLevel { debug, info, warn, error }

abstract final class AppLog {
  /// The floor. Nothing below this is written. Raise it to
  /// [LogLevel.warn] while chasing a specific problem.
  static LogLevel minimum = kDebugMode ? LogLevel.debug : LogLevel.warn;

  /// Silences everything. The e2e harness sets this so a 200-flow suite does
  /// not bury its own failure output under app chatter.
  static bool enabled = !kReleaseMode;

  static const _reset = '\x1B[0m';
  static const _grey = '\x1B[90m';
  static const _cyan = '\x1B[36m';
  static const _yellow = '\x1B[33m';
  static const _red = '\x1B[31m';

  static void debug(String tag, Object? message) =>
      _write(LogLevel.debug, tag, message);

  static void info(String tag, Object? message) =>
      _write(LogLevel.info, tag, message);

  static void warn(String tag, Object? message) =>
      _write(LogLevel.warn, tag, message);

  /// An error, with the stack trace when one is available.
  ///
  /// Pass the `catch (e, stack)` pair straight through: a caught exception
  /// without its stack names what broke but not where, which is the half that
  /// does not help.
  static void error(
    String tag,
    Object? message, [
    Object? error,
    StackTrace? stack,
  ]) {
    if (!_should(LogLevel.error)) return;
    _write(LogLevel.error, tag, message);
    if (error != null) debugPrint('$_red  ↳ $error$_reset');
    if (stack != null) debugPrint('$_grey$stack$_reset');
  }

  static bool _should(LogLevel level) =>
      enabled && level.index >= minimum.index;

  static void _write(LogLevel level, String tag, Object? message) {
    if (!_should(level)) return;
    final (colour, glyph) = switch (level) {
      LogLevel.debug => (_grey, '·'),
      LogLevel.info => (_cyan, 'i'),
      LogLevel.warn => (_yellow, '!'),
      LogLevel.error => (_red, '✗'),
    };
    debugPrint('$colour$glyph [$tag] $message$_reset');
  }
}
