import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Bumped once every time a session ends.
///
/// Lives here rather than on `SessionManager` so [LiveObx] does not have to
/// import a service to guard a widget, and so it survives `Get.reset()` — the
/// counter is the *event*, not the session.
final RxInt liveScopeEpoch = 0.obs;

/// An [Obx] that draws nothing instead of throwing once its controller has
/// been dropped.
///
/// Signing out tears down in two steps: `SessionManager` drops the user-scoped
/// controllers, then `AuthService.clearSession()` nulls the current user. The
/// shell is still mounted between those two, and its tab bodies reach for
/// controllers that are already gone — so a plain `GetView.controller` throws
/// "not found" while rebuilding.
///
/// A guard in the view's `build` does not cover this: only the `Obx` element
/// is dirty, so Flutter rebuilds it without rebuilding its parent.
///
/// Reading [liveScopeEpoch] inside the builder does two jobs at once. It gives
/// this `Obx` a real dependency — GetX throws "improper use of a GetX" for a
/// builder that observes nothing, which a pure registration guard otherwise
/// does — and it makes the rebuild happen on exactly the event the guard
/// exists for.
///
/// Use it for any section of a screen whose controller is user-scoped. The
/// builder receives the live instance, so the view never reaches for
/// `controller` inside the closure.
class LiveObx<T> extends StatelessWidget {
  const LiveObx({super.key, required this.builder, this.placeholder});

  final Widget Function(T controller) builder;

  /// Drawn while the controller is absent. Defaults to nothing, which is right
  /// for a teardown; pass a skeleton where the absence is a real loading
  /// state.
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) => Obx(() {
        // Registers the dependency. Do not remove: without a read, Obx has
        // nothing to listen to and GetX reports it as misuse.
        liveScopeEpoch.value;
        if (!Get.isRegistered<T>()) {
          return placeholder ?? const SizedBox.shrink();
        }
        return builder(Get.find<T>());
      });
}
