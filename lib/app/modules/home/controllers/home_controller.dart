import 'package:get/get.dart';

import '../../../data/models/auth_user.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/session_manager.dart';
import '../../../data/services/settings_service.dart';
import '../../../routes/app_pages.dart';
import '../shell_layout.dart';

export '../shell_layout.dart' show ShellDestination, ShellGroup, ShellLayout;

/// The shell.
///
/// Owns only cross-cutting state: which tab is active, who is signed in, and
/// the sheets the top bar opens. Every tab's *data* belongs to that tab's own
/// controller — a shell that fetches on behalf of its children is a shell that
/// refetches all of them when one of them changes.
class HomeController extends GetxController {
  static HomeController get to => Get.find<HomeController>();

  HomeController({required this.allDestinations});

  /// Every destination the app has, before access is applied.
  final List<ShellDestination> allDestinations;

  final _layout = const ShellLayout(tabs: [], more: []).obs;

  /// The active tab, tracked by **route rather than index**.
  ///
  /// The tab list is derived from the access map and can change while the
  /// shell is mounted — an administrator grants a module, the map refreshes,
  /// and a destination appears. An index would then silently point at a
  /// different screen than the one the user was looking at.
  final _activeRoute = Routes.HOME.obs;

  ShellLayout get layout => _layout.value;

  /// The bar's destinations plus More, which is what the tab bar renders.
  List<ShellDestination> get tabs => _layout.value.tabs;

  bool get hasMore => _layout.value.hasMore;

  String get activeRoute => _activeRoute.value;

  /// Where the active route sits in the bar, or the More slot when the active
  /// screen is one More holds.
  int get activeIndex {
    final index = tabs.indexWhere((d) => d.route == _activeRoute.value);
    if (index >= 0) return index;
    return hasMore ? tabs.length : 0;
  }

  ShellDestination? get active {
    final index = tabs.indexWhere((d) => d.route == _activeRoute.value);
    return index >= 0 ? tabs[index] : null;
  }

  /// The shell bar's title. The tab body must not repeat it.
  String get title {
    final destination = active;
    if (destination != null) return destination.title ?? destination.label;
    return _activeRoute.value == Routes.MORE ? 'More' : siteName;
  }

  AuthUser? get user => AuthService.to.currentUser;
  Rxn<AuthUser> get rxUser => AuthService.to.rxUser;

  String get siteName => SettingsService.to.settings.siteName;

  /// True when the navigation was built from the token rather than the server.
  ///
  /// `AccessService` leaves its timestamp null on that path deliberately, so
  /// this is the honest signal that the list may be short. Worth surfacing:
  /// a clinician who cannot find a screen they used yesterday should know it
  /// is the connection and not their account.
  bool get accessIsDegraded =>
      AccessService.to.loadedAt == null && !AccessService.to.map.isEmpty;

  @override
  void onInit() {
    super.onInit();
    _resolve();
    // Re-resolve when the server's verdict changes. A role edit reaches the
    // device on the next refresh, and the navigation should follow it without
    // a sign-out.
    ever(AccessService.to.rx, (_) => _resolve());
  }

  void _resolve() {
    final next = ShellLayout.resolve(
      access: AccessService.to.map,
      destinations: allDestinations,
      modulesEnabled: SettingsService.to.modulesEnabled,
    );
    _layout.value = next;

    // If the screen being looked at just became unavailable, fall back to
    // Today rather than showing a tab that is no longer in the bar.
    final stillThere = next.tabs.any((d) => d.route == _activeRoute.value) ||
        next.more.any((d) => d.route == _activeRoute.value) ||
        _activeRoute.value == Routes.MORE;
    if (!stillThere) _activeRoute.value = Routes.HOME;
  }

  /// Selects the bar slot at [index]. The last slot is More when one exists.
  void select(int index) {
    if (index < 0) return;
    if (index < tabs.length) {
      _activeRoute.value = tabs[index].route;
      return;
    }
    if (hasMore && index == tabs.length) _activeRoute.value = Routes.MORE;
  }

  /// Switches to the tab at [route], if the shell has one.
  ///
  /// Returns false when it does not, so a caller can fall back to pushing the
  /// route instead of silently doing nothing.
  bool selectRoute(String route) {
    if (route == Routes.MORE && hasMore) {
      _activeRoute.value = Routes.MORE;
      return true;
    }
    if (!tabs.any((d) => d.route == route)) return false;
    _activeRoute.value = route;
    return true;
  }

  /// Opens a destination from the More hub.
  ///
  /// Pushed, not swapped into the bar: the bar's membership is the resolved
  /// layout, and quietly rewriting it on a tap would move the ground under
  /// somebody who was only visiting.
  void openDestination(ShellDestination destination) {
    Get.toNamed<void>(destination.route);
  }

  Future<void> signOut() => SessionManager.to.endSession(
        reason: SessionEndReason.userLogout,
        revokeToken: true,
      );
}
