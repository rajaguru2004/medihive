import 'package:flutter/material.dart';

import 'app_bento.dart';
import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_surfaces.dart';
import 'app_text_styles.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — Async state widgets
///
/// The two things a screen shows while it is not showing its content: the
/// skeleton it wears while loading, and the banner it wears when the load
/// failed. Pair both with `LoadStateMixin`.
/// ─────────────────────────────────────────────────────────────────────────────

/// Inline "this failed, try again" banner for a screen whose data did not
/// load.
///
/// It is inline rather than a toast on purpose: a toast disappears after three
/// seconds and would take the only retry affordance with it, leaving a user
/// staring at an empty list that looks exactly like "you have no invoices".
class ErrorRetryBanner extends StatelessWidget {
  const ErrorRetryBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.margin = const EdgeInsets.only(bottom: 16),
    this.title = "Couldn't load this",
  });

  final String message;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry margin;
  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errorInk = semanticInk(context, AppColors.error);

    return InsetSurface(
      margin: margin,
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              size: 18,
              color: errorInk,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: (isDark
                          ? AppTextStyles.darkSubheadline(
                              weight: FontWeight.w700)
                          : AppTextStyles.lightSubheadline(
                              weight: FontWeight.w700))
                      .copyWith(color: labelColor(context)),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: (isDark
                          ? AppTextStyles.darkFootnote()
                          : AppTextStyles.lightFootnote())
                      .copyWith(color: secondaryLabelColor(context)),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 6),
                  // A real 48 dp target. "Try again" as bare text is a 16 dp
                  // tap target, which is a link you cannot press.
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Try again'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(48, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A pulsing placeholder block.
///
/// Honours Reduce Motion, and that is not only an accessibility courtesy: a
/// `..repeat()` controller schedules a frame forever, so a screen holding one
/// never reaches a settled frame and `pumpAndSettle` hangs until the twelve
/// minute test timeout. Under Reduce Motion — which the e2e harness turns on —
/// this paints a static block and the tree goes quiet.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shouldRun = !MediaQuery.disableAnimationsOf(context);
    if (shouldRun == _running) return;
    _running = shouldRun;
    if (shouldRun) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0.35;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.05);
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.09);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: Color.lerp(baseColor, highlightColor, _controller.value),
          ),
        ),
      ),
    );
  }
}

/// A short, tinted explanation above the thing it is about.
///
/// For the sentence a screen has to say before somebody acts: that this role
/// ships with the product, that the API checks a different node, that adding a
/// page rewrites every role's matrix. Not an error — [ErrorRetryBanner] is for
/// something that went wrong and can be tried again.
///
/// The tint is a semantic colour, never the brand teal: a warning that looks
/// like the brand is a warning nobody reads as one.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.tint = AppColors.acuityStandard,
  });

  final String message;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final ink = semanticInk(context, tint);
    return BentoCard(
      // A tinted fill, not just tinted ink. DESIGN.md §6.1 promises the
      // tint is "always semantic"; drawn on a plain card it was a white box
      // with red text in it, which is what a *data* card looks like when one
      // of its figures happens to be bad news. The banner has to read as a
      // different kind of object before it is read as a sentence.
      fill: Color.alphaBlend(
        tint.withValues(alpha: 0.14),
        surfaceColor(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppFonts.text(fontSize: 13, height: 1.45, color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Three fields above need attention."
///
/// The line every long form needs above its save button. A refused save that
/// only marks the fields is a refusal nobody can see: the field it is
/// complaining about is usually several screens up, and the button just
/// silently does nothing.
class FieldErrorSummary extends StatelessWidget {
  const FieldErrorSummary({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final ink = semanticInk(context, AppColors.error);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline_rounded, size: 15, color: ink),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            count == 1
                ? 'One field above needs attention.'
                : '$count fields above need attention.',
            style: AppFonts.text(fontSize: 12.5, color: ink),
          ),
        ),
      ],
    );
  }
}
