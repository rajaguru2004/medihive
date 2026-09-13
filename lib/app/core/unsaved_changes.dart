import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — not losing somebody's work to a back gesture
///
/// A quote in this app can be twenty minutes of typing: a customer, a dozen
/// line items with their own breakdowns, payment terms that have to reach a
/// hundred. On Android that is one edge swipe away from gone, and the swipe is
/// the same gesture used to scroll a horizontal list — so it is not a rare
/// accident.
///
/// The guard asks. It only asks when there is something to lose: dirtiness is
/// measured against the payload the form would send, so a form opened and
/// closed untouched, or typed into and typed back, goes straight out.
/// ─────────────────────────────────────────────────────────────────────────────

/// A controller whose screen must not be left by accident.
///
/// [snapshot] is taken when the record finishes loading; [isDirty] compares the
/// live payload with it. Using the payload rather than a hand-kept flag means a
/// field added to the form is covered the day it is added, and a value typed
/// and undone is correctly not dirty.
mixin UnsavedChanges on GetxController {
  String? _snapshot;

  /// What this form would send right now.
  Map<String, dynamic> unsavedPayload();

  /// Call once the record is loaded and the form is showing it.
  void markSaved() => _snapshot = _encode(unsavedPayload());

  /// True when the form holds something the server does not.
  ///
  /// False before the first snapshot: a form still loading has nothing of the
  /// user's in it to lose.
  bool get isDirty {
    final saved = _snapshot;
    if (saved == null) return false;
    return _encode(unsavedPayload()) != saved;
  }

  static String _encode(Map<String, dynamic> payload) {
    // Sorted, so a map whose keys were built in a different order is not read
    // as a change.
    Object? normalise(Object? value) {
      if (value is Map) {
        final keys = value.keys.map((k) => '$k').toList()..sort();
        return {for (final key in keys) key: normalise(value[key])};
      }
      if (value is List) return value.map(normalise).toList();
      return value;
    }

    return jsonEncode(normalise(payload));
  }
}

/// Wraps a form screen and asks before a back gesture throws the work away.
///
/// `PopScope` rather than a `WillPopScope`-style interception: on Android 13
/// and later the system runs a predictive-back animation *while* the gesture
/// is in progress, and a route that refuses to pop after the animation has
/// started snaps back. Declaring `canPop: false` up front is what tells the
/// platform not to start it.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.isDirty,
    required this.child,
    this.title = 'Leave without saving?',
    this.message =
        'What you have typed here will be lost. This cannot be undone.',
    this.confirmLabel = 'Discard',
    this.cancelLabel = 'Keep editing',
    this.discardKey,
    this.keepKey,
  });

  /// Asked at the moment of the gesture, not at build time.
  final bool Function() isDirty;

  final Widget child;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final Key? discardKey;
  final Key? keepKey;

  @override
  Widget build(BuildContext context) => PopScope(
        // Always false, and deliberately.
        //
        // `canPop` is read when the widget *builds*, not when the gesture
        // happens, so a true value computed before anything was typed is the
        // value the platform still holds three fields later — the form pops
        // and the work is gone. Making it reactive would mean the guard
        // depending on every field in the form, and a field added later and
        // not wired in would fail silently and invisibly.
        //
        // The cost is Android's predictive-back preview on these two screens:
        // the system will not animate a route that has said it may not pop.
        // A preview animation against losing twenty minutes of typing is not
        // a close call.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;

          // Nothing to lose — leave as though the guard were not here. Asked
          // at the moment of the gesture, which is the whole point.
          if (!isDirty()) {
            Get.back();
            return;
          }

          final discard = await ConfirmDialog.show(
            context,
            title: title,
            message: message,
            confirmLabel: confirmLabel,
            cancelLabel: cancelLabel,
            destructive: true,
            confirmKey: discardKey,
            cancelKey: keepKey,
          );
          if (discard) Get.back();
        },
        child: child,
      );
}
