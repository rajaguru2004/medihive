import 'package:flutter/material.dart';

/// The device classes this app ships to, as test viewports.
///
/// A flow asserts *layout*, and layout in this app is driven by window width —
/// so the suite has to be able to say "the same flow, on a tablet" without
/// booting a tablet. Pinning the viewport does that for free in the headless
/// tier; the device tier uses [device] and takes the emulator's real size.
///
/// Never branch a flow on the class itself. Branch on what the layout actually
/// does (`HomeRobot.isExpandedLayout`), or the suite starts encoding device
/// names into assertions and stops testing the breakpoints.
enum DeviceClass {
  /// 1080×2340 at 2.625 → 411×891 logical. The most common Android phone.
  phone(Size(1080, 2340), 2.625),

  /// 2560×1600 at 2.0 → 1280×800 logical, landscape. Pixel Tablet.
  tablet(Size(2560, 1600), 2.0),

  /// 1920×1080 at 1.0. A mounted kiosk screen: wide, low density, landscape.
  kiosk(Size(1920, 1080), 1.0),

  /// Do not pin anything — whatever the running device reports.
  ///
  /// Required on a real device: `LiveTestWidgetsFlutterBinding` scales a pinned
  /// `physicalSize` to fit the real window, so pinning a phone size on a tablet
  /// renders a letterboxed phone and the layout under test never appears.
  device(null, null);

  const DeviceClass(this.physicalSize, this.devicePixelRatio);

  final Size? physicalSize;
  final double? devicePixelRatio;

  /// The logical size a pinned class renders at, or null for [device].
  Size? get logicalSize => physicalSize == null
      ? null
      : Size(
          physicalSize!.width / devicePixelRatio!,
          physicalSize!.height / devicePixelRatio!,
        );

  bool get isPinned => physicalSize != null;

  /// Selected with `--dart-define=NEX_HIVE_DEVICE_CLASS=tablet`.
  ///
  /// Defaults to [phone], which is the viewport a headless run should be
  /// asserting against — 800×600 is not a device anybody holds.
  ///
  /// The device tier does not have to ask for [device]: `AppHarness` pins
  /// nothing when it is running on Android or iOS, whatever this says, because
  /// there a pinned size letterboxes rather than resizes.
  static DeviceClass get fromDefine {
    const name = String.fromEnvironment(
      'NEX_HIVE_DEVICE_CLASS',
      defaultValue: 'phone',
    );
    return DeviceClass.values.firstWhere(
      (c) => c.name == name,
      orElse: () => DeviceClass.phone,
    );
  }
}
