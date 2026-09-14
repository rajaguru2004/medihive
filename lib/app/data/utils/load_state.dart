import 'package:get/get.dart';

import '../../core/app_log.dart';
import 'api_envelope.dart';
import 'error_handler.dart';

/// Loading and error state for controllers that fetch a screen's data.
///
/// Without it, every list controller catches its failures into a log line, so
/// a request that failed leaves the user on an empty screen with no
/// explanation and no way to retry — indistinguishable from "you have no
/// invoices".
///
/// Works with both reactivity styles: the observables drive `Obx` widgets, and
/// [runGuarded] also calls `update()` for controllers built on `GetBuilder`.
mixin LoadStateMixin on GetxController {
  final rxLoading = false.obs;
  final rxLoadError = RxnString();

  /// True when the server refused for lack of permission.
  ///
  /// Separate from [rxLoadError] because it is not an error in the sense a
  /// banner means: nothing is broken, a retry cannot help, and "something went
  /// wrong — try again" over a panel this account was never granted sends a
  /// nurse to IT for a role they are not supposed to have. The screen shows a
  /// locked state instead, and says so plainly.
  final rxNoAccess = false.obs;

  /// True only for the *first* load, so a pull-to-refresh shows the list it
  /// already has rather than collapsing back to a skeleton.
  final rxFirstLoad = true.obs;

  bool get isLoading => rxLoading.value;
  bool get hasLoadError => rxLoadError.value != null;
  bool get hasNoAccess => rxNoAccess.value;

  /// True when the screen has nothing to show and no reason why — the state
  /// an `EmptyState` belongs in.
  bool get isIdle =>
      !rxLoading.value && rxLoadError.value == null && !rxNoAccess.value;

  /// Runs [body], recording loading and error state around it.
  ///
  /// [fallback] is shown when the failure carries no usable server message.
  /// [silent] suppresses the loading flag, for a background refresh that must
  /// not blank the screen.
  Future<void> runGuarded(
    Future<void> Function() body, {
    required String fallback,
    bool silent = false,
  }) async {
    if (!silent) rxLoading.value = true;
    rxLoadError.value = null;
    rxNoAccess.value = false;
    try {
      await body();
    } on ApiForbiddenException catch (e) {
      // Deliberately no error banner and deliberately no stack: this is the
      // server answering a question correctly, not a fault. Logged at info so
      // a support session can see which module was refused.
      rxNoAccess.value = true;
      AppLog.info('$runtimeType', 'access refused: ${e.message}');
    } catch (e, stack) {
      rxLoadError.value = parseErrorMessage(e, fallback);
      AppLog.error('$runtimeType', fallback, e, stack);
    } finally {
      if (!silent) rxLoading.value = false;
      rxFirstLoad.value = false;
      update();
    }
  }

  /// Clears a failed state so a retry starts clean.
  void clearLoadError() => rxLoadError.value = null;
}
