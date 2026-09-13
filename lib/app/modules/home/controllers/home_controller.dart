import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../data/models/auth_user.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/session_manager.dart';
import '../../../data/services/settings_service.dart';

/// One destination in the shell.
///
/// Adding a tab is one entry in `HomeBinding.shellDestinations()` plus its
/// controller registration — not an edit to the tab bar, the `IndexedStack`,
/// the title logic and the key list, which is how the previous shell grew to
/// 1,981 lines with four screens inside it.
class ShellDestination {
  const ShellDestination({
    required this.route,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.body,
    this.title,
  });

  /// The route this tab is also reachable at, so a deep link can open it
  /// directly. Also the tab's key suffix.
  final String route;

  /// What the tab bar says.
  final String label;

  final IconData icon;
  final IconData activeIcon;

  /// The shell's title while this tab is active. Defaults to [label].
  final String? title;

  /// Built once, lazily, and kept alive by the shell's `IndexedStack`.
  final Widget Function() body;
}

/// The shell.
///
/// Owns only cross-cutting state: which tab is active, who is signed in, and
/// the sheets the top bar opens. Every tab's *data* belongs to that tab's own
/// controller — a shell that fetches on behalf of its children is a shell that
/// refetches all of them when one of them changes.
class HomeController extends GetxController {
  static HomeController get to => Get.find<HomeController>();

  HomeController({required this.destinations});

  final List<ShellDestination> destinations;

  final _activeIndex = 0.obs;

  int get activeIndex => _activeIndex.value;
  ShellDestination get active => destinations[_activeIndex.value];

  /// The shell bar's title: the active tab's. The tab body must not repeat it.
  String get title => active.title ?? active.label;

  AuthUser? get user => AuthService.to.currentUser;
  Rxn<AuthUser> get rxUser => AuthService.to.rxUser;

  String get siteName => SettingsService.to.settings.siteName;

  void select(int index) {
    if (index < 0 || index >= destinations.length) return;
    _activeIndex.value = index;
  }

  /// Switches to the tab at [route], if the shell has one. Returns false when
  /// it does not, so a caller can fall back to pushing the route instead.
  bool selectRoute(String route) {
    final index = destinations.indexWhere((d) => d.route == route);
    if (index < 0) return false;
    _activeIndex.value = index;
    return true;
  }

  Future<void> signOut() => SessionManager.to.endSession(
        reason: SessionEndReason.userLogout,
        revokeToken: true,
      );
}
