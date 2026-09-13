import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — Theme Controller
///
/// Owns the app's light/dark/system preference and persists it across
/// restarts. Wire up in `main.dart` via `Get.put(AppThemeController())`, then
/// `await restore()` before `runApp` so the first frame paints in the right
/// theme.
///
/// This owns the *mode*. `ThemeService` owns what the two modes are made of.
/// ─────────────────────────────────────────────────────────────────────────────
class AppThemeController extends GetxController {
  static AppThemeController get to => Get.find<AppThemeController>();

  static const _key = 'theme_mode';

  /// Reuses flutter_secure_storage rather than pulling in a second storage
  /// package for one string. Encryption is unnecessary here but harmless, and
  /// the session restore already pays the plugin's startup cost.
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final _themeMode = ThemeMode.system.obs;

  ThemeMode get themeMode => _themeMode.value;

  bool get isDark {
    if (_themeMode.value == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode.value == ThemeMode.dark;
  }

  /// Reads the stored preference. Call before `runApp` — restoring after the
  /// first frame produces a visible flash of the wrong theme.
  Future<void> restore() async {
    try {
      final stored = await _storage.read(key: _key);
      if (stored == null) return;
      final mode = ThemeMode.values.firstWhereOrNull((m) => m.name == stored);
      if (mode != null) {
        _themeMode.value = mode;
        Get.changeThemeMode(mode);
      }
    } catch (e) {
      // A missing or unreadable preference is not worth failing startup over —
      // fall back to following the system.
      debugPrint('[AppThemeController] theme restore failed: $e');
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  void setLight() => _setMode(ThemeMode.light);
  void setDark() => _setMode(ThemeMode.dark);
  void setSystem() => _setMode(ThemeMode.system);

  /// Toggle between light ↔ dark (leaves "system" behind).
  void toggle() => _setMode(isDark ? ThemeMode.light : ThemeMode.dark);

  void setMode(ThemeMode mode) => _setMode(mode);

  // ── Private ───────────────────────────────────────────────────────────────
  void _setMode(ThemeMode mode) {
    _themeMode.value = mode;
    Get.changeThemeMode(mode);
    _persist(mode);
    update();
  }

  Future<void> _persist(ThemeMode mode) async {
    try {
      await _storage.write(key: _key, value: mode.name);
    } catch (e) {
      // The theme has already changed on screen; failing to remember it is a
      // degraded experience, not an error worth interrupting the user for.
      debugPrint('[AppThemeController] theme persist failed: $e');
    }
  }
}
