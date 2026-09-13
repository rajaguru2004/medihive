import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_text_styles.dart';
import 'app_theme_controller.dart';
import 'brand_palette.dart';
import 'theme_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — Surfaces
///
/// The vocabulary every screen is built from: an inset grouped surface on a
/// flat grouped ground, hairline rules, a section header with a 48 dp trailing
/// action, a 48 dp round icon button, and tabular numerals.
///
/// Colours are read through these helpers rather than from `AppColors`
/// directly, so a widget never branches on brightness by hand — the branch
/// lives here, once.
/// ─────────────────────────────────────────────────────────────────────────────

/// The floating tab bar's geometry, shared with every tab that scrolls under
/// it so content can leave exactly this much room.
const double kFloatingTabBarHeight = 64;
const double kFloatingTabBarMargin = 16;

/// Space a scrolling tab leaves at the bottom so its last row clears the bar.
double floatingTabBarClearance(BuildContext context) =>
    kFloatingTabBarHeight +
    kFloatingTabBarMargin * 2 +
    MediaQuery.paddingOf(context).bottom;

/// A state-change duration that honours Reduce Motion.
///
/// One frame rather than zero under Reduce Motion: an implicitly animated
/// widget given `Duration.zero` completes inside its own layout pass, and
/// `RenderAnimatedSize` asserts that it "was mutated in its own
/// performLayout". One frame is visually instant and stays off that path.
Duration motionDuration(
  BuildContext context, [
  Duration normal = const Duration(milliseconds: 200),
]) =>
    MediaQuery.disableAnimationsOf(context)
        ? const Duration(milliseconds: 1)
        : normal;

// ── Ground and surfaces ─────────────────────────────────────────────────────

/// The flat grouped ground every screen sits on.
Color groundColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkBackground
        : AppColors.lightBackground;

/// The surface an inset group is drawn on.
Color surfaceColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkSurface
        : AppColors.lightSurface;

/// A second, quieter surface for tracks and wells inside a group.
Color wellColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFEBEFF0);

Color hairlineColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkDivider
        : AppColors.lightDivider;

// ── Label colours ───────────────────────────────────────────────────────────

Color labelColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

Color secondaryLabelColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

Color tertiaryLabelColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextTertiary
        : AppColors.lightTextTertiary;

/// A semantic or acuity-ramp colour, lifted or deepened until it reads as
/// **text** on this mode's ground.
///
/// The ramp is chosen for a light ground, where every entry clears 4.5:1 on
/// white. On ink it does not: `#0070C0` on a dark card is 2.7:1 and `#DC2626`
/// is 2.9:1 — both unreadable, and one of them is how this app says a patient
/// is deteriorating.
///
/// Fills and dots keep the raw colour; only words go through here. The
/// comparison is against the worst surface in each mode — the raised card in
/// dark, the ground in light — so a colour that passes here passes everywhere
/// it can land.
Color semanticInk(BuildContext context, Color color) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final against = isDark ? surfaceColor(context) : groundColor(context);
  return BrandPalette.readable(
    color,
    against,
    target: BrandPalette.textContrast,
  );
}

/// The site's brand as words on this screen's ground.
Color brandInkColor(BuildContext context) =>
    Theme.of(context).colorScheme.onPrimaryContainer;

/// The site's brand as a solid shape on this screen's ground.
Color brandFillColor(BuildContext context) =>
    Theme.of(context).colorScheme.primary;

/// The label on a solid brand fill.
///
/// Derived rather than assumed black or white: a site may set any brand
/// colour, and a hard-coded label is unreadable on half of them.
Color onBrandFillColor(BuildContext context) =>
    Theme.of(context).colorScheme.onPrimary;

/// A wash of the site's brand, behind a selected control.
///
/// Pale enough that [labelColor] still reads on it, so a selected row is
/// marked by tint *and* by its own label weight rather than by colour alone.
Color brandTonalColor(BuildContext context) =>
    Theme.of(context).colorScheme.primaryContainer;

/// Tabular figures, for anything that ticks or lines up in a column.
TextStyle numeralStyle(
  BuildContext context, {
  required double size,
  FontWeight weight = FontWeight.w700,
  Color? color,
  double? letterSpacing,
}) =>
    AppFonts.numeric(
      fontSize: size,
      fontWeight: weight,
      color: color ?? labelColor(context),
      letterSpacing: letterSpacing ?? (size >= 28 ? -1.2 : -0.2),
      height: 1.0,
    );

// ── Widgets ─────────────────────────────────────────────────────────────────

/// An inset grouped surface: a rounded sheet on the ground.
class InsetSurface extends StatelessWidget {
  const InsetSurface({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding = EdgeInsets.zero,
    this.margin,
    this.color,
    this.bordered = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  /// The hairline that keeps a white sheet legible on a near-white ground.
  /// Dropped only when the surface is already inside a bordered parent.
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? surfaceColor(context),
        borderRadius: BorderRadius.circular(radius),
        border: bordered
            ? Border.all(color: hairlineColor(context), width: 0.5)
            : null,
      ),
      child: child,
    );
  }
}

/// A hairline rule between rows of a group. Never a full-bleed line: it starts
/// where the row's content starts, which is what tells the eye the rows belong
/// to one group.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0, this.endIndent = 0});

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsetsDirectional.only(start: indent, end: endIndent),
        child: Container(height: 0.5, color: hairlineColor(context)),
      );
}

/// A group's title, with an optional trailing action.
///
/// The action is a real 48 dp target even though it looks like a word — a
/// "See all" that is 14 pt tall is a 14 pt tap target.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding,
    this.inset = false,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Overrides both [inset] and the default.
  final EdgeInsetsGeometry? padding;

  /// Indents to the text margin a vertically-padded `BentoCard` gives
  /// its rows.
  ///
  /// A card that pads nothing lets its own children decide, so that a divider
  /// can still reach the edges — but then the heading and the rows have to
  /// agree on the margin, or the card reads as two columns that missed each
  /// other by ten points.
  final bool inset;

  // 14 is `BentoSpace.listPad`, spelled out because `app_bento.dart` imports
  // this file and cannot be imported back.
  EdgeInsetsGeometry get _padding =>
      padding ??
      (inset
          ? const EdgeInsets.fromLTRB(14, 0, 14, 10)
          : const EdgeInsets.fromLTRB(4, 0, 4, 10));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: _padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: isDark
                  ? AppTextStyles.darkHeadline(weight: FontWeight.w700)
                  : AppTextStyles.lightHeadline(weight: FontWeight.w700),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// A 48 dp round icon button on a well fill. The app's only icon-only control.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 48,
    this.iconSize = 20,
    this.background,
    this.foreground,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? background;
  final Color? foreground;

  /// Draws an unread pip when greater than zero.
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: background ?? wellColor(context),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: iconSize,
            color: foreground ?? labelColor(context),
          ),
        ),
      ),
    );

    final withBadge = badgeCount <= 0
        ? button
        : Stack(
            clipBehavior: Clip.none,
            children: [
              button,
              PositionedDirectional(
                top: 8,
                end: 8,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: groundColor(context), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: AppFonts.numeric(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          );

    if (tooltip == null) return withBadge;
    return Tooltip(message: tooltip!, child: withBadge);
  }
}

/// The shell every bottom sheet in the app uses: a rounded top, a title, and
/// safe-area padding at the bottom so the last row clears the home indicator.
class SheetShell extends StatelessWidget {
  const SheetShell({
    super.key,
    required this.child,
    this.title,
    this.scrollable = false,
  });

  final Widget child;
  final String? title;

  /// Scrolls [child] when the room runs out.
  ///
  /// Off by default, and deliberately opt-in rather than automatic: most
  /// sheets here already scroll *part* of themselves — the fields scroll and
  /// the one primary button stays pinned below them — and wrapping that shape
  /// in a second scroll view hands its `Flexible` an unbounded height, which
  /// asserts rather than degrades. Turn it on for a sheet that is nothing but
  /// a column of rows, where the number of rows is a permission or a site
  /// setting and not a constant.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // What the keyboard covers, and whether this sheet still owes it.
    //
    // `Get.bottomSheet` has already paid by the time this builds:
    // `GetModalBottomSheetRoute.buildPage` wraps the whole sheet in a
    // `Padding` of `viewInsets.bottom`, and leaves the MediaQuery underneath
    // reporting the full inset anyway — so a sheet that reads the inset and
    // lifts itself as well is lifted twice, once clear of the keyboard and
    // once clear of nothing. Flutter's own `showModalBottomSheet` lifts
    // nothing and hands the sheet the whole screen to lay out in, which is
    // the case the lift below exists for. The two cannot both be assumed.
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final lift =
        ModalRoute.of(context) is GetModalBottomSheetRoute ? 0.0 : insets;

    // Re-assert the mode the app is actually in.
    //
    // `Get.bottomSheet` snapshots `Theme.of(...)` when the route is pushed and
    // wraps the sheet in it for the route's whole life. A sheet therefore does
    // not follow a later theme change — it keeps the mode it was opened in,
    // and renders a white sheet over a dark app. The same staleness applies
    // when `ThemeService` rebuilds the theme for new site branding while a
    // sheet is open.
    //
    // `AppThemeController` is the source of truth for the mode (it resolves
    // "system" too, which `Get.isDarkMode` reads off the snapshotted theme and
    // so gets wrong here). Falls back to the inherited theme when the
    // controller is not registered, which is the case in a bare widget test.
    final themeMode = Get.isRegistered<AppThemeController>() &&
            Get.isRegistered<ThemeService>()
        ? (AppThemeController.to.isDark
            ? ThemeService.to.darkTheme
            : ThemeService.to.lightTheme)
        : null;
    if (themeMode != null && themeMode.brightness != Theme.of(context).brightness) {
      return Theme(
        data: themeMode,
        child: SheetShell(title: title, scrollable: scrollable, child: child),
      );
    }

    // The sheet paints its own surface.
    //
    // It cannot rely on the route to do it: `Get.bottomSheet` does not read
    // `ThemeData.bottomSheetTheme`, so the `backgroundColor` set there never
    // reaches it and the sheet renders straight onto the barrier — the rows
    // legible, the ground behind them showing through, and the whole thing
    // reading as a rendering fault. Painting here rather than at the fifteen
    // call sites also means a sheet shown with Flutter's own
    // `showModalBottomSheet` looks identical.
    //
    // `Material` rather than a `DecoratedBox`: the rows inside are `InkWell`s
    // and their splashes need something to paint on.
    return Material(
      color: surfaceColor(context),
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BentoSheetRadius.top),
        ),
      ),
      child: SafeArea(
      top: false,
      child: ConstrainedBox(
        // A ceiling, and the reason it has to be here rather than at each call
        // site: `showModalBottomSheet(isScrollControlled: true)` will happily
        // lay a sheet out taller than the screen, and nothing complains — the
        // content simply continues below the bottom edge, so the save button a
        // form pinned there is unreachable and untappable. A tenth of the
        // screen is left showing what the sheet covers, which is also what
        // tells a reader it is a sheet.
        //
        // The keyboard is **not** subtracted here, and that is the whole of a
        // bug worth remembering. It used to be, and the lift below then spent
        // the same inset a second time inside the box the first subtraction
        // had already shrunk — so a sheet gave up twice the keyboard's height
        // to it. On an 891-point phone with a 380-point keyboard that leaves
        // forty points to draw a title, a search field and a list of results
        // in, and what the reader saw was the heading, the field, and then the
        // keyboard, with the options the sheet exists to offer nowhere on
        // screen. The lift is what keeps content clear of the keyboard; this
        // only stops the sheet growing past the screen.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: lift),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The grab handle. Drawn here for the same reason as the
              // surface: the theme's `showDragHandle` belongs to Flutter's
              // sheet route, not to GetX's, so without this there is nothing
              // saying the sheet can be dragged away.
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 10),
                  decoration: BoxDecoration(
                    color: tertiaryLabelColor(context).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(BentoSheetRadius.handle),
                  ),
                ),
              ),
              if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  kSheetInset,
                  0,
                  kSheetInset,
                  12,
                ),
                child: Text(
                  title!,
                  style: isDark
                      ? AppTextStyles.darkTitle3(weight: FontWeight.w700)
                      : AppTextStyles.lightTitle3(weight: FontWeight.w700),
                ),
              ),
              Flexible(
                child: scrollable
                    ? SingleChildScrollView(child: child)
                    : child,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// The two radii a sheet needs, kept here because `app_bento.dart` imports
/// this file rather than the other way round.
/// The horizontal inset a sheet's own content sits at.
///
/// `SheetRow` pads itself — it needs its ink to reach wider than its text —
/// so [SheetShell] leaves its child alone and anything that is *not* a row
/// goes through [SheetSection] to line up with them.
const double kSheetInset = 20;

abstract final class BentoSheetRadius {
  /// The top corners of the sheet itself.
  static const double top = 28;

  /// The grab handle.
  static const double handle = 2;
}

/// Non-row content inside a [SheetShell], at the sheet's own inset.
///
/// Exists because a sheet's rows pad themselves and its headers do not, so an
/// identity band dropped straight into a [SheetShell] sits flush against the
/// screen edge while the rows beneath it are inset — and anything on its right,
/// an acuity pill in particular, runs off the edge entirely.
class SheetSection extends StatelessWidget {
  const SheetSection({super.key, required this.child, this.bottom = 0});

  final Widget child;

  /// Space under the section. For separating a header from the rows.
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(kSheetInset, 0, kSheetInset, bottom),
        child: child,
      );
}

/// One tappable row inside a [SheetShell] or an [InsetSurface].
class SheetRow extends StatelessWidget {
  const SheetRow({
    super.key,
    required this.icon,
    required this.label,
    this.sublabel,
    this.onTap,
    this.trailing,
    this.selected = false,
    this.tint,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool selected;
  final Color? tint;

  /// Paints the row in the error colour. Sign-out and delete only.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errorInk = semanticInk(context, AppColors.error);
    final accent = destructive
        ? errorInk
        : (tint ?? (selected ? brandInkColor(context) : labelColor(context)));

    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: (isDark
                              ? AppTextStyles.darkCallout(
                                  weight: FontWeight.w600)
                              : AppTextStyles.lightCallout(
                                  weight: FontWeight.w600))
                          .copyWith(
                        color: destructive ? errorInk : labelColor(context),
                      ),
                    ),
                    if (sublabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sublabel!,
                        style: isDark
                            ? AppTextStyles.darkFootnote()
                            : AppTextStyles.lightFootnote(),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// A proportion bar — how much of a total is used, collected or elapsed.
class UsedBar extends StatelessWidget {
  const UsedBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 6,
  });

  /// Clamped to 0…1 by the widget; a caller dividing by a zero total need not
  /// guard.
  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final value = fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(
        children: [
          Container(height: height, color: wellColor(context)),
          FractionallySizedBox(
            widthFactor: value,
            child: Container(height: height, color: color),
          ),
        ],
      ),
    );
  }
}

/// A small filled dot that carries a status colour into a dense row, where a
/// full pill would not fit.
///
/// Never the only carrier of meaning — always paired with the status word, so
/// the row still reads for a colour-blind user and in a screenshot.
class StatusMark extends StatelessWidget {
  const StatusMark({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
