import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — watch mode
///
/// Turns a device run into something a person can actually follow.
///
/// ```sh
/// flutter test integration_test/live/quotes_live_test.dart \
///   -d emulator-5554 --dart-define-from-file=tool/e2e.env \
///   --dart-define=NEX_HIVE_WATCH=true --timeout none
/// ```
///
/// Off, a device run paints correctly and is still invisible. The integration
/// binding only produces a frame when the test pumps one, and the test pumps as
/// fast as the machine allows — so every screen exists for about sixteen
/// milliseconds and the display shows the binding's placeholder in between. The
/// run is real; it simply happens faster than a screen can refresh.
///
/// On, three things change and none of them affect what is asserted:
///
///   * the binding runs **fully live**, driving the device's own vsync, so the
///     app keeps painting between pumps instead of showing the placeholder;
///   * every robot action pauses afterwards, long enough to read;
///   * nothing else. Reduce Motion stays on — it is what stops the skeleton
///     shimmer looping, and `tapKey` waits for the tree to hold still before
///     it taps.
///
/// Kept out of the assertions on purpose. A flow that only passes at human
/// speed is a flow with a race in it, and watch mode must not hide that — so
/// the same tests run unchanged in both modes, and the gate runs them fast.
/// ─────────────────────────────────────────────────────────────────────────────
abstract final class WatchMode {
  static const bool enabled =
      bool.fromEnvironment('NEX_HIVE_WATCH', defaultValue: false);

  /// How long to hold still after each robot action, in milliseconds.
  ///
  /// Long enough to read a screen, short enough that a forty-flow suite still
  /// finishes. Override with `--dart-define=NEX_HIVE_WATCH_PACE=1200`.
  static const int _paceMs =
      int.fromEnvironment('NEX_HIVE_WATCH_PACE', defaultValue: 700);

  static Duration get pace => const Duration(milliseconds: _paceMs);

  /// Puts the binding into continuous-frame mode.
  ///
  /// Called once per test, from the harness. Harmless when watch mode is off,
  /// and harmless under `flutter test` with no device, where the binding is not
  /// an integration binding at all.
  static void arm() {
    if (!enabled) return;
    final binding = TestWidgetsFlutterBinding.instance;
    if (binding is IntegrationTestWidgetsFlutterBinding) {
      // Without this the binding paints only when the test pumps, which is why
      // a device run shows "Test starting…" and nothing else: the frames are
      // produced, they just last sixteen milliseconds each.
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    }
  }

  /// Holds the current screen for [pace], in real time.
  ///
  /// A no-op when watch mode is off, so a robot can call it after every action
  /// without costing the gate anything.
  static Future<void> hold(WidgetTester tester) async {
    if (!enabled) return;
    await tester.pump(pace);
  }
}
