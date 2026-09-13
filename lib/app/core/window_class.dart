import 'package:flutter/widgets.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — window size classes
///
/// Structure is decided by how much width the app actually has, never by what
/// device it believes it is on. A tablet in a split-screen window is a phone's
/// width and must get a phone's layout; a phone in landscape on a desk stand is
/// wider than a portrait tablet. A `Platform.isTablet` check gets both wrong.
///
/// The breakpoints are Material 3's, which are also what the Android and
/// iPadOS size classes resolve to, so one table serves both platforms.
/// ─────────────────────────────────────────────────────────────────────────────

enum WindowClass {
  /// Phones, and any window narrower than 600. One pane, bottom navigation.
  compact,

  /// Small tablets and large phones in landscape. One pane, a rail.
  medium,

  /// Tablets. Two panes, an extended rail.
  expanded,

  /// Desktop-class and mounted kiosk screens.
  large,

  /// Very wide screens; the content stops growing and centres instead.
  extraLarge;

  /// Resolves from the current window width.
  static WindowClass of(BuildContext context) =>
      forWidth(MediaQuery.sizeOf(context).width);

  static WindowClass forWidth(double width) {
    if (width < 600) return WindowClass.compact;
    if (width < 840) return WindowClass.medium;
    if (width < 1200) return WindowClass.expanded;
    if (width < 1600) return WindowClass.large;
    return WindowClass.extraLarge;
  }

  bool get isCompact => this == WindowClass.compact;

  /// At least [other]. `WindowClass.of(context) >= WindowClass.expanded` reads
  /// better than comparing indices at every call site.
  bool operator >=(WindowClass other) => index >= other.index;
  bool operator >(WindowClass other) => index > other.index;
  bool operator <=(WindowClass other) => index <= other.index;
  bool operator <(WindowClass other) => index < other.index;

  /// Where the app's top-level destinations live.
  ShellNavMode get navMode => switch (this) {
        WindowClass.compact => ShellNavMode.bottomBar,
        WindowClass.medium => ShellNavMode.rail,
        _ => ShellNavMode.extendedRail,
      };

  /// Whether a list and the record it opens fit side by side.
  ///
  /// Below this the detail is a pushed screen: two panes at 840 leaves a list
  /// too narrow to scan and a detail too narrow to read, which is worse than
  /// either alone.
  bool get isTwoPane => this >= WindowClass.expanded;

  /// Columns a form lays its fields out in.
  int get formColumns => this >= WindowClass.expanded ? 2 : 1;

  /// The widest a column of content is allowed to get.
  ///
  /// Unbounded on a phone, where the window *is* the measure. On a wide screen
  /// a form stretched to 1900 points puts its label and its field a hand's
  /// width apart.
  double get contentMaxWidth => switch (this) {
        WindowClass.compact => double.infinity,
        WindowClass.medium => double.infinity,
        WindowClass.expanded => 960,
        WindowClass.large => 1040,
        WindowClass.extraLarge => 1120,
      };

  /// The list pane's width in a two-pane layout.
  double get listPaneWidth => switch (this) {
        WindowClass.large => 400,
        WindowClass.extraLarge => 440,
        _ => 360,
      };

  /// The smallest a tappable control may be.
  ///
  /// 48 satisfies Material's 48 and Apple's 44, and holds for every screen
  /// somebody holds. Only the kiosk band gets more: that screen is used
  /// standing up, at arm's length, often in a hurry, and frequently by someone
  /// who did not choose the device.
  ///
  /// Deliberately keyed to [extraLarge] rather than [large]: a tablet in
  /// landscape is 1280 points wide and lands in `large`, and it is still a
  /// device held in two hands at reading distance.
  double get minTarget => this >= WindowClass.extraLarge ? 56 : 48;

  /// Row height for a list. Denser where vertical space is the scarce thing;
  /// taller on a mounted screen, where reach and glance distance are.
  double get rowHeight => this >= WindowClass.extraLarge ? 72 : 64;
}

/// How the top-level destinations are presented.
///
/// Named `ShellNavMode` rather than `NavigationMode` because Flutter's material
/// library exports one of its own, and a collision here is a compile error at
/// every screen that lays itself out.
enum ShellNavMode {
  /// Up to four destinations plus "More", along the bottom, in the thumb zone.
  bottomBar,

  /// Icons in a narrow vertical strip.
  rail,

  /// Icons with labels, wide enough to group child destinations under parents.
  extendedRail;

  bool get isBottomBar => this == ShellNavMode.bottomBar;
  bool get isRail => this != ShellNavMode.bottomBar;
}

/// Reads the window class without a `Builder` at every call site.
///
/// ```dart
/// WindowClassBuilder(builder: (context, window) => window.isTwoPane ? … : …)
/// ```
class WindowClassBuilder extends StatelessWidget {
  const WindowClassBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, WindowClass window) builder;

  @override
  Widget build(BuildContext context) => builder(context, WindowClass.of(context));
}
