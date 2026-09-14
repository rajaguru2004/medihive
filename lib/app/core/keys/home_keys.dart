import 'package:flutter/widgets.dart';

/// Widget keys for the shell and the dashboard it opens on.
abstract final class HomeKeys {
  static const screen = Key('home_screen');
  static const appBar = Key('home_app_bar');
  static const title = Key('home_title');
  static const tabBar = Key('home_tab_bar');

  /// The rail that replaces the tab bar above 600 dp.
  static const rail = Key('home_rail');
  static const profileButton = Key('home_profile_button');
  static const themeToggle = Key('home_theme_toggle');
  static const signOut = Key('home_sign_out');

  /// One per shell destination, so a test names the tab it wants rather than
  /// counting positions — a count that changes the day a tab is added.
  static Key tab(String route) => Key('home_tab_$route');

  // ── Dashboard ─────────────────────────────────────────────────────────────
  static const dashboard = Key('dashboard_screen');
  static const census = Key('dashboard_census');
  static const occupancy = Key('dashboard_occupancy');
  static const queueLoad = Key('dashboard_queue_load');
  static const quickActions = Key('dashboard_quick_actions');
  static const attention = Key('dashboard_attention');
  static const error = Key('dashboard_error');
  static const empty = Key('dashboard_empty');

  static Key quickAction(String id) => Key('dashboard_quick_action_$id');
  static Key figure(String id) => Key('dashboard_figure_$id');
}
