import 'package:flutter/widgets.dart';

import 'home_keys.dart';

/// The dashboard module's anchor.
///
/// The keys live in [HomeKeys] because the dashboard is the shell's first tab
/// and the two are read together — a test that walks the shell and a test that
/// asserts on the board are usually the same test.
abstract final class DashboardKeys {
  static const Key screen = HomeKeys.dashboard;
}
