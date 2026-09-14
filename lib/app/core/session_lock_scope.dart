import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/services/session_lock_service.dart';
import '../modules/session_lock/controllers/session_lock_controller.dart';
import '../modules/session_lock/views/session_lock_view.dart';

/// Wraps the whole app: notices activity, and covers it when there is none.
///
/// A `Listener` rather than a `GestureDetector`: this must see every pointer
/// that reaches the app **without competing for it**. A gesture detector in the
/// arena would win taps from the widgets underneath, which is a lock that
/// breaks the app it is protecting.
///
/// The lock is an overlay over the navigator, not a route. A route would join
/// the back stack — so the system Back gesture would dismiss it, which is not a
/// lock — and would have to be popped from wherever it was pushed, losing the
/// screen underneath.
class SessionLockScope extends StatelessWidget {
  const SessionLockScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<SessionLockService>()) return child;
    final lock = SessionLockService.to;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => lock.touch(),
      // Scrolling a long ward round is activity too, and a board somebody is
      // reading without tapping would otherwise lock under their eyes.
      onPointerSignal: (_) => lock.touch(),
      child: Stack(
        children: [
          child,
          Obx(() {
            if (!lock.isLocked) return const SizedBox.shrink();
            if (!Get.isRegistered<SessionLockController>()) {
              Get.put<SessionLockController>(SessionLockController());
            }
            // Opaque and full-screen: a translucent lock over a ward board
            // still shows the patient names it exists to cover.
            return const Positioned.fill(
              child: Material(child: SessionLockView()),
            );
          }),
        ],
      ),
    );
  }
}
