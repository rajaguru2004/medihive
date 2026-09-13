import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_bento.dart';
import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_surfaces.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — saying one thing, briefly
///
/// The app used to say everything through `Get.snackbar`, which draws a titled
/// card the width of the screen: two lines of chrome for "Copied", and a card
/// sitting over the row somebody was about to tap. A confirmation should cost
/// nothing to read and nothing to dismiss.
///
/// A toast is one line, one colour, and gone. It never takes a title — a
/// message that needs a heading to make sense is not a toast, it is a
/// `NoticeBanner` on the screen it concerns or a `ConfirmDialog` in front of
/// it.
///
/// **An overlay entry, not the `fluttertoast` package.** That package was tried
/// first and cannot be reached from here: `FToast.init` needs a `BuildContext`
/// with an `Overlay` *ancestor*, and GetX exposes none — `Get.overlayContext`
/// hands back the overlay's own child (`_Theater`, ancestor null) and
/// `Get.context` is the `Navigator` above it, so every call threw "Overlay is
/// null". What it does expose is the `OverlayState` directly, which is what the
/// package was reaching for anyway. Inserting the entry here is the same
/// mechanism with one fewer indirection, and it keeps the call sites free of a
/// context none of them have.
/// ─────────────────────────────────────────────────────────────────────────────

/// What a toast is for. Only the tint and the icon change.
enum ToastTone {
  /// Something worked. The commonest one, and the reason toasts exist.
  success,

  /// Something did not. Still a toast only when the screen behind it is
  /// unchanged and there is nothing to retry — otherwise it belongs inline.
  failure,

  /// Neither. A fact worth a second of attention.
  info,
}

/// The toast on screen, if any. One at a time: two stacked toasts is a screen
/// arguing with itself, and the second is always the one that matters.
OverlayEntry? _current;
Timer? _timer;

/// Shows [message] for a few seconds, above the tab bar.
///
/// Context-free on purpose: most call sites are inside a callback that has
/// already popped the sheet it came from, and threading a `BuildContext`
/// through those is how half of them end up using a dead one. If there is no
/// navigator yet there is no screen to show a toast on either, and this
/// returns quietly.
void showBentoToast(
  String message, {
  ToastTone tone = ToastTone.success,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Get.key.currentState?.overlay;
  if (overlay == null || message.trim().isEmpty) return;

  _dismiss();

  final entry = OverlayEntry(
    builder: (context) => BentoToast(message: message, tone: tone),
  );
  _current = entry;
  overlay.insert(entry);
  _timer = Timer(duration, _dismiss);
}

/// Takes the current toast down, whenever that happens to be.
///
/// Guarded on `mounted` because the overlay can go before the timer does — a
/// sign-out, or a test tearing the tree down — and removing an entry twice
/// throws from a callback nobody is holding.
void _dismiss() {
  _timer?.cancel();
  _timer = null;
  final entry = _current;
  _current = null;
  if (entry != null && entry.mounted) entry.remove();
}

/// Removes any toast immediately. For a screen that is about to disappear.
void dismissBentoToasts() => _dismiss();

/// The pill itself. Public only so a robot can assert on it by type — nothing
/// builds one directly; [showBentoToast] is the whole interface.
class BentoToast extends StatelessWidget {
  const BentoToast({super.key, required this.message, required this.tone});

  final String message;
  final ToastTone tone;

  @override
  Widget build(BuildContext context) {
    final (colour, icon) = switch (tone) {
      ToastTone.success => (AppColors.acuityStable, Icons.check_circle_rounded),
      ToastTone.failure => (AppColors.error, Icons.error_outline_rounded),
      ToastTone.info => (AppColors.acuityStandard, Icons.info_outline_rounded),
    };
    final ink = semanticInk(context, colour);

    return Positioned(
      left: BentoSpace.page,
      right: BentoSpace.page,
      // Above the floating tab bar rather than over it: the bar is how
      // somebody leaves the screen, and a toast that covers it for three
      // seconds is three seconds of the app not answering.
      bottom: floatingTabBarClearance(context) + 8,
      child: TweenAnimationBuilder<double>(
        // In only. A toast that fades out needs the entry to outlive its own
        // removal, and the eye forgives something vanishing far more readily
        // than something appearing from nowhere.
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        tween: Tween(begin: 0, end: 1),
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              // The tinted fill a `NoticeBanner` uses, so the two read as the
              // same family — one on the screen, one over it.
              color: Color.alphaBlend(
                colour.withValues(alpha: 0.14),
                surfaceColor(context),
              ),
              borderRadius: BorderRadius.circular(BentoRadius.card),
              border: Border.all(color: colour.withValues(alpha: 0.24)),
              boxShadow: bentoShadow(context, hero: true),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 17, color: ink),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    message,
                    // Three at most. Two clipped the one message long enough to
                    // need the room — the signature refusal, which is the whole
                    // reason somebody cannot admit a patient.
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.text(
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
