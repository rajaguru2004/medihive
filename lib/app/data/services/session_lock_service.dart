import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/app_clock.dart';
import '../../core/app_log.dart';
import 'auth_service.dart';
import 'settings_service.dart';

/// Locks an idle device without ending the shift.
///
/// A ward tablet is put down constantly — mid-form, mid-round, mid-sentence —
/// and picked up by whoever is nearest. Signing out on idle would be safe and
/// useless: it discards half-typed work and makes the next interaction a full
/// sign-in, so people stop putting the device down and the lock achieves the
/// opposite of what it is for.
///
/// A lock is the middle setting. The session stays, the screen does not: the
/// data goes behind a password, and the person who left it there gets their
/// work back by typing one.
///
/// Handover is still a deliberate sign-out. This is for the gap between.
class SessionLockService extends GetxService with WidgetsBindingObserver {
  static SessionLockService get to => Get.find<SessionLockService>();

  final _isLocked = false.obs;

  /// True while the lock screen is covering the app.
  bool get isLocked => _isLocked.value;
  RxBool get rx => _isLocked;

  Timer? _timer;

  /// When the app last went to the background, so time spent there counts
  /// toward the idle threshold. It is the most likely way a device is left
  /// unattended, and a timer that only runs in the foreground would miss it
  /// entirely.
  DateTime? _backgroundedAt;

  /// Minutes of inactivity before locking. Zero turns the lock off, which is
  /// the right setting for a device one clinician carries all shift.
  int get lockAfterMinutes => SettingsService.to.settings.sessionLockMinutes;

  bool get isEnabled => lockAfterMinutes > 0 && AuthService.to.isAuthenticated;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.onClose();
  }

  /// Restarts the idle countdown. Called on every interaction.
  void touch() {
    if (!isEnabled) {
      _timer?.cancel();
      return;
    }
    if (_isLocked.value) return;

    _timer?.cancel();
    _timer = Timer(Duration(minutes: lockAfterMinutes), lock);
  }

  void lock() {
    if (!AuthService.to.isAuthenticated || _isLocked.value) return;
    _timer?.cancel();
    _isLocked.value = true;
    AppLog.info('SessionLock', 'device locked after $lockAfterMinutes min idle');
  }

  /// Called by the lock screen once the password has been accepted.
  void unlock() {
    _isLocked.value = false;
    touch();
  }

  /// Drops the lock without unlocking — for sign-out, where the next screen is
  /// the sign-in form and a lock over it would trap the next person.
  void reset() {
    _timer?.cancel();
    _backgroundedAt = null;
    _isLocked.value = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isEnabled) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundedAt = AppClock.now();
        _timer?.cancel();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since == null) {
          touch();
          return;
        }
        // Time in the background counts. A device face-down on a trolley for
        // twenty minutes is exactly the case this exists for, and a
        // foreground-only timer would have been paused through all of it.
        if (AppClock.now().difference(since).inMinutes >= lockAfterMinutes) {
          lock();
        } else {
          touch();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }
}
