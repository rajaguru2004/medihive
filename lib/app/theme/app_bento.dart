import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;

import '../core/window_class.dart';
import 'app_async_widgets.dart';
import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_surfaces.dart';
import 'app_text_styles.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the bento kit
///
/// Every part a screen is made of, extracted so the rest of the app is
/// composed rather than re-decorated. `DESIGN.md` is the contract; this file is
/// its executable form. A screen that hand-rolls a border, a lift, a status
/// pill or a row that already lives here is a defect, not a variation.
///
/// Read `DESIGN.md` § "Building the next screen" before adding a screen; read
/// this file before adding a widget.
/// ─────────────────────────────────────────────────────────────────────────────

// ── Geometry ────────────────────────────────────────────────────────────────

/// The radius ladder, largest for the container and smaller for what sits in
/// it. Nesting a radius larger than its parent's is what makes a card look
/// dented; the ladder exists so that never happens by accident.
abstract final class BentoRadius {
  /// Progress rules and thin tracks.
  static const double rule = 3;

  /// Strip bands and mini tracks.
  static const double band = 5;

  /// List tracks.
  static const double track = 8;

  /// Row icon boxes (34 dp); a selected row's capsule.
  static const double small = 10;

  /// Status pills; bento icon boxes (36–38 dp).
  static const double pill = 12;

  /// Controls; quick-action tiles; action cards.
  static const double control = 16;

  /// Section cards, data cards, nudges.
  static const double card = 20;

  /// The one hero card on a screen.
  static const double hero = 24;

  /// The top of a sheet.
  static const double sheet = 28;
}

/// The spacing rhythm of a bento screen.
abstract final class BentoSpace {
  /// Page padding, each side.
  static const double page = 16;

  /// Between one section and the next.
  static const double section = 18;

  /// Between a section header and its card.
  static const double header = 10;

  /// Inside a composed card.
  static const double cardPad = 20;

  /// Inside a card that holds a ruled list.
  static const double listPad = 14;

  /// Top and bottom of a card whose rows set their own side margins.
  ///
  /// Such a card passes `EdgeInsets.symmetric(vertical: listCardPad)` rather
  /// than `EdgeInsets.zero`: the sides stay at zero so a hairline divider can
  /// still reach the card's edges, but the first and last rows stop sitting
  /// flush against the border. A row's own 8 pt is the gap *between* rows; on
  /// its own it leaves the top line looking clipped.
  static const double listCardPad = 8;

  /// Between a card and the action card that belongs to it.
  static const double action = 12;
}

/// The hairline border every bento card carries.
///
/// It is what makes a white card legible on cool paper and an ink card legible
/// on ink. Never dropped, never coloured.
Color bentoBorderColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

/// One soft ambient shadow. `hero` is reserved for the single card on a screen
/// that is allowed to sit slightly higher than its siblings.
List<BoxShadow> bentoShadow(BuildContext context, {bool hero = false}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return [
    BoxShadow(
      color: Colors.black.withValues(
        alpha: hero ? (isDark ? 0.34 : 0.05) : (isDark ? 0.24 : 0.035),
      ),
      blurRadius: hero ? 18 : 10,
      offset: Offset(0, hero ? 6 : 4),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass, done cheaply.
//
// A card is glass here without a single `BackdropFilter`: a translucent,
// top-lit fill over the ground's ambient wash, a luminous hairline, and the
// one soft shadow every card already carried. That is three draws — the same
// three an opaque card costs — so a list of forty of them scrolls exactly as
// it did before. A `BackdropFilter` reads back and re-blurs everything under
// it on every frame the content beneath moves; forty of those in a scrolling
// list is the single most expensive thing a Flutter screen can do, and it is
// why "glass cards" have a bad name.
//
// The floating tab bar is the one surface that spends a real blur, because it
// is the one surface with content moving underneath it — and
// `test/one_blur_test.dart` holds the count at one.
// ─────────────────────────────────────────────────────────────────────────────

/// The material's switches.
abstract final class BentoGlass {
  /// One flag. `false` makes every card and the bar opaque and drops the wash;
  /// nothing else in the app changes. That is the point of having it: if a
  /// device class ever shows the material is not free, this is the whole
  /// rollback.
  static const bool enabled = true;

  /// Honours Increase Contrast. Translucency is exactly what that setting asks
  /// to remove, so the material goes opaque and the bar drops its blur.
  static bool on(BuildContext context) =>
      enabled && !MediaQuery.highContrastOf(context);
}

/// The luminous hairline around a pane. In dark it is the rim light that makes
/// the glass read; in light the fill's own top edge does that job, and the
/// border stays dark enough to keep a white card legible on cool paper.
Color bentoGlassEdge(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.13)
        : Colors.black.withValues(alpha: 0.06);

/// The one definition of what a card is made of.
///
/// Every surface that reads as a card paints with this, so the material
/// changes in one place.
///
/// A [fill] opts out of the glass: a tinted action card is its own material.
BoxDecoration bentoCardDecoration(
  BuildContext context, {
  double radius = BentoRadius.card,
  bool hero = false,
  Color? fill,
}) {
  final shape = BorderRadius.circular(radius);
  final shadow = bentoShadow(context, hero: hero);

  if (fill != null || !BentoGlass.on(context)) {
    return BoxDecoration(
      color: fill ?? surfaceColor(context),
      borderRadius: shape,
      border: Border.all(color: bentoBorderColor(context), width: 1),
      boxShadow: shadow,
    );
  }

  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    // Top-lit: a touch brighter along the upper edge, which is where light
    // catches a pane. One gradient shader in place of one flat colour — the
    // same draw count, not an extra layer.
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.06),
            ]
          : [
              Colors.white.withValues(alpha: 0.90),
              Colors.white.withValues(alpha: 0.76),
            ],
    ),
    borderRadius: shape,
    border: Border.all(color: bentoGlassEdge(context), width: 1),
    boxShadow: shadow,
  );
}

/// The ground with its ambient wash: the site's colour, faint, glowing from
/// a point above the top edge and gone before the fold.
///
/// It is what a translucent card has to show through — over a flat ground,
/// glass is just a greyer card — and it is one gradient shader, the same cost
/// as the flat colour it replaces. The wash is pre-blended into the ground so
/// the whole thing is a single fill, not a colour plus an overlay.
class BentoGround extends StatelessWidget {
  const BentoGround({super.key, required this.child, this.wash = true});

  final Widget child;

  /// Off for a screen that fills its own top (a hero image, a camera feed).
  final bool wash;

  @override
  Widget build(BuildContext context) {
    final ground = groundColor(context);
    if (!wash || !BentoGlass.on(context)) {
      return ColoredBox(color: ground, child: child);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brand = Theme.of(context).colorScheme.primary;

    // On dark, the brand is lightened before it is blended. Deep teal laid
    // straight onto near-black makes a muddy green — a stain on the screen
    // rather than light on it — because what little of the colour survives at
    // 15% is its hue and none of its luminance. Lifting it toward white first
    // keeps the hue and gives the wash something to be made of.
    final washColor = isDark ? Color.lerp(brand, Colors.white, 0.62)! : brand;
    final tinted = Color.alphaBlend(
      // Turned down on dark. At 22% of a 45%-lightened teal the glow was
      // strong enough to sit *on* the text under it rather than behind it,
      // which is what made a dark screen read as tinted rather than lit.
      // The light theme is untouched: cool paper is what it is made of.
      washColor.withValues(alpha: isDark ? 0.14 : 0.13),
      ground,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        // A glow from above the top edge, not a ramp down the page.
        //
        // The ramp banded, and badly: it crossed about fourteen 8-bit levels
        // over seventeen hundred pixels, which puts a hard step every hundred
        // and twenty — the eye reads those as stripes, and the screen looks
        // printed rather than lit. Concentrating the same wash into a radius
        // puts the steps roughly four times closer together, below the
        // threshold where they separate.
        //
        // It is also the more honest shape. Light comes from somewhere; a
        // uniform tint over the top half of every screen is a stain.
        gradient: RadialGradient(
          center: const Alignment(0, -0.85),
          radius: 0.78,
          colors: [tinted, ground],
          // The wash is spent well before the fold, so the rest of the page
          // is one flat colour rather than a slow crawl nobody can see but
          // everybody's screen quantises.
          stops: const [0.0, 0.8],
        ),
      ),
      child: child,
    );
  }
}

// ── Screen shell ────────────────────────────────────────────────────────────

/// The shell every bento screen uses: the washed ground, a scroll view padded
/// to the page rhythm, and bottom clearance for the floating tab bar.
///
/// Takes slivers rather than a column so a long list stays lazy. A screen that
/// wraps a `ListView` in a `Column` inside this has built two scrollables and
/// will be told so by an assertion.
class BentoScreen extends StatelessWidget {
  const BentoScreen({
    super.key,
    required this.slivers,
    this.onRefresh,
    this.bottomClearance = true,
    this.ground = true,
    this.wash = true,
    this.controller,
  });

  final List<Widget> slivers;

  /// Wires pull-to-refresh. Omit for a screen with nothing to refetch.
  final Future<void> Function()? onRefresh;

  /// Leaves room under the last row for the floating tab bar. False on a
  /// pushed sub-screen, which has no bar.
  final bool bottomClearance;

  /// Paints the ground behind this screen.
  ///
  /// **False for a tab hosted in the shell.** The shell already paints the
  /// washed ground; a tab that paints its own flat one on top of it covers the
  /// wash from the header down and leaves a visible horizontal seam exactly
  /// where the two meet.
  final bool ground;

  final bool wash;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final view = CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        ...slivers,
        SliverToBoxAdapter(
          child: SizedBox(
            height: bottomClearance
                ? floatingTabBarClearance(context)
                : MediaQuery.paddingOf(context).bottom + 24,
          ),
        ),
      ],
    );

    final body = onRefresh == null
        ? view
        : RefreshIndicator(
            onRefresh: onRefresh!,
            color: brandInkColor(context),
            backgroundColor: surfaceColor(context),
            child: view,
          );

    // A measure, here rather than at each call site.
    //
    // Text and rows do not get more readable by getting wider. On a 1920 kiosk
    // an unbounded screen put a row's label against the left edge and its
    // figure against the right with fourteen hundred points of nothing in
    // between, which is not a row anybody can read across. `MaxWidthBody` is a
    // no-op below the limit and inside a pane that is already narrower, so
    // every screen can have it and only the wide ones notice.
    final measured = MaxWidthBody(child: body);

    return ground ? BentoGround(wash: wash, child: measured) : measured;
  }
}

/// Stops a column of content growing wider than it can be read at.
///
/// A form stretched across 1900 points puts a label and its field a hand's
/// width apart, and a paragraph at that measure loses the reader between one
/// line and the next.
class MaxWidthBody extends StatelessWidget {
  const MaxWidthBody({super.key, required this.child, this.maxWidth});

  final Widget child;

  /// Overrides the window class's own answer, for content with a different
  /// natural measure.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final limit = maxWidth ?? WindowClass.of(context).contentMaxWidth;
    if (!limit.isFinite) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: limit),
        child: child,
      ),
    );
  }
}

/// Page-padded sliver content, at the standard rhythm.
class BentoSection extends StatelessWidget {
  const BentoSection({
    super.key,
    required this.child,
    this.top = 0,
    this.bottom = BentoSpace.section,
  });

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            BentoSpace.page,
            top,
            BentoSpace.page,
            bottom,
          ),
          child: child,
        ),
      );
}

// ── Cards ───────────────────────────────────────────────────────────────────

/// The card. Everything with a border and a lift in this app is one of these.
class BentoCard extends StatelessWidget {
  const BentoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BentoSpace.cardPad),
    this.radius = BentoRadius.card,
    this.hero = false,
    this.fill,
    this.onTap,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// The single card on a screen allowed to sit higher than its siblings.
  final bool hero;

  /// Opts out of the glass material for a tinted card.
  final Color? fill;

  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);

    return Container(
      margin: margin,
      decoration: bentoCardDecoration(
        context,
        radius: radius,
        hero: hero,
        fill: fill,
      ),
      child: onTap == null
          ? body
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onTap, child: body),
            ),
    );
  }
}

/// One ruled row inside a card: leading icon box, title, optional sub-line,
/// trailing content, and a chevron when it navigates.
class BentoRow extends StatelessWidget {
  const BentoRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.showChevron = true,
    this.subtitleMaxLines = 1,
    this.padding = const EdgeInsets.symmetric(
      horizontal: BentoSpace.listPad,
      vertical: 12,
    ),
  });

  final String title;
  final String? subtitle;

  /// How many lines the subtitle may take before it elides.
  ///
  /// One by default, because a list of rows that are each a different height
  /// is harder to scan. Raised where the subtitle is genuinely the content —
  /// a library row, whose columns are the whole point and which otherwise
  /// clips in the middle of a word.
  final int subtitleMaxLines;
  final IconData? icon;
  final Color? iconColor;

  /// Replaces the icon box entirely — an avatar, a status mark, a checkbox.
  final Widget? leading;

  final Widget? trailing;
  final VoidCallback? onTap;

  /// The row's secondary actions, as every list in this app offers them.
  final VoidCallback? onLongPress;

  final bool showChevron;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = iconColor ?? brandInkColor(context);

    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null)
            leading!
          else if (icon != null)
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(BentoRadius.pill),
              ),
              child: Icon(icon, size: 19, color: tint),
            ),
          if (leading != null || icon != null) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: isDark
                      ? AppTextStyles.darkCallout(weight: FontWeight.w600)
                      : AppTextStyles.lightCallout(weight: FontWeight.w600),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: subtitleMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: isDark
                        ? AppTextStyles.darkFootnote()
                        : AppTextStyles.lightFootnote(),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          if (onTap != null && showChevron) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: tertiaryLabelColor(context),
            ),
          ],
        ],
      ),
    );

    if (onTap == null && onLongPress == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, onLongPress: onLongPress, child: row),
    );
  }
}

/// A label/value pair, the unit a detail screen is built from.
class FactRow extends StatelessWidget {
  const FactRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueWidget,
    this.dense = false,
    this.stacked = false,
    this.inset = true,
  });

  final String label;
  final String value;
  final Color? valueColor;

  /// Replaces the value text — a pill, a link, a figure.
  final Widget? valueWidget;

  final bool dense;

  /// Puts the label on its own line and gives the value the full width.
  ///
  /// For a value that cannot survive being squeezed into half a phone: an
  /// email address, a subject line, a postal address, a site's directions.
  /// Side by side, those are shown as "accounts@meridianfm.t…", which is not
  /// an email address anybody can act on.
  final bool stacked;

  /// Indents to the card's own text margin.
  ///
  /// On by default, because the common case is a row inside
  /// a card padded only vertically — one that lets its own rows
  /// decide their margins so a full-width divider can reach the edges. Without
  /// it the label and the value sit flush against the card's border, which
  /// reads as a rendering fault. Pass false inside a card that already pads.
  final bool inset;

  EdgeInsets _padding() => EdgeInsets.fromLTRB(
        inset ? BentoSpace.listPad : 0,
        dense ? 5 : 8,
        inset ? BentoSpace.listPad : 0,
        dense ? 5 : 8,
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // A value that already carries line breaks is a block of text — a postal
    // address, a note — and a block set right-aligned has a ragged left edge
    // that nobody can scan. It stacks whether or not the caller said to,
    // because the alternative is three lines of address hanging off the right
    // margin with a gulf between them and their label.
    if (stacked || value.contains('\n')) {
      return Padding(
        padding: _padding().copyWith(
          top: dense ? 6 : 9,
          bottom: dense ? 6 : 9,
        ),
        // Full width, explicitly. A `Column` that shrink-wraps is centred by
        // the card's own column, which puts each stacked row at a different
        // indent and makes a tidy card look like a ransom note.
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: isDark
                    ? AppTextStyles.darkSubheadline()
                    : AppTextStyles.lightSubheadline(),
              ),
              const SizedBox(height: 3),
              valueWidget ??
                  Text(
                    value,
                    style: (isDark
                            ? AppTextStyles.darkSubheadline(
                                weight: FontWeight.w600)
                            : AppTextStyles.lightSubheadline(
                                weight: FontWeight.w600))
                        .copyWith(
                      color: valueColor ?? labelColor(context),
                      height: 1.4,
                    ),
                  ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: _padding(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: isDark
                  ? AppTextStyles.darkSubheadline()
                  : AppTextStyles.lightSubheadline(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: valueWidget ??
                Text(
                  value,
                  textAlign: TextAlign.end,
                  // An address is several lines and shows them; anything else
                  // is one line that ellipsises. An email or a URL is a single
                  // unbroken token, and a wrap puts its last letter alone on a
                  // second line — which reads as a rendering fault, not as a
                  // long address. Counting the newlines the value already has
                  // tells the two apart without the caller having to say which
                  // it is.
                  // One line, always: a multi-line value took the stacked
                  // branch above. An email or a URL is a single unbroken
                  // token, and a wrap puts its last letter alone on a second
                  // line — which reads as a rendering fault rather than as a
                  // long address.
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (isDark
                          ? AppTextStyles.darkSubheadline(
                              weight: FontWeight.w600)
                          : AppTextStyles.lightSubheadline(
                              weight: FontWeight.w600))
                      .copyWith(color: valueColor ?? labelColor(context)),
                ),
          ),
        ],
      ),
    );
  }
}

// ── Status ──────────────────────────────────────────────────────────────────

/// Maps a backend status string onto the clinical acuity ramp.
///
/// Statuses arrive as free text from site configuration (triage categories,
/// admission states, appointment states), not as an enum, so this normalises
/// and matches rather than switching — and an unrecognised status resolves to
/// [AppColors.acuityRoutine] instead of throwing. A site that invents
/// "awaiting porter" gets a neutral pill, never a crash and never a wrong
/// colour.
///
/// Never returns the brand teal, and never returns red for anything that is
/// not clinically critical: see the notes at the top of `app_colors.dart`.
abstract final class CaseStatus {
  /// Deteriorating, or triaged immediate. The only states that earn red.
  static const _critical = {
    'critical',
    'immediate',
    'resuscitation',
    'red',
    'emergency',
    'p1',
    'esi-1',
    'deteriorating',
  };

  /// Seen soon, not now.
  static const _urgent = {
    'urgent',
    'very urgent',
    'orange',
    'p2',
    'esi-2',
    'high',
    'priority',
  };

  /// The ordinary case: triaged, waiting, in progress, nothing flagged.
  static const _standard = {
    'standard',
    'in progress',
    'in-progress',
    'active',
    'admitted',
    'waiting',
    'in queue',
    'queued',
    'scheduled',
    'booked',
    'confirmed',
    'yellow',
    'p3',
    'esi-3',
  };

  /// Non-urgent, or routine follow-up. Also the resting state of a screening
  /// nobody has flagged.
  static const _routine = {
    'routine',
    'non-urgent',
    'non urgent',
    'green',
    'blue',
    'low',
    'p4',
    'p5',
    'esi-4',
    'esi-5',
    'draft',
    'new',
    'open',
  };

  /// Observed and stable, or seen and closed out well.
  static const _stable = {
    'stable',
    'completed',
    'complete',
    'seen',
    'resolved',
    'closed',
    'fit',
    'cleared',
    'done',
  };

  /// Off the board.
  static const _discharged = {
    'discharged',
    'transferred',
    'transferred out',
    'cancelled',
    'canceled',
    'did not attend',
    'dna',
    'no show',
    'no-show',
    'left',
    'lwbs',
    'absconded',
    'inactive',
  };

  /// Waiting on a clinician's sign-off.
  static const _review = {
    'review',
    'in review',
    'under review',
    'awaiting review',
    'pending review',
    'awaiting sign-off',
    'submitted',
    'pending',
  };

  static String normalise(String? status) =>
      (status ?? '').trim().toLowerCase();

  static Color colorOf(String? status) {
    final s = normalise(status);
    if (s.isEmpty) return AppColors.acuityRoutine;
    if (_critical.contains(s)) return AppColors.acuityCritical;
    if (_urgent.contains(s)) return AppColors.acuityUrgent;
    if (_review.contains(s)) return AppColors.acuityReview;
    if (_stable.contains(s)) return AppColors.acuityStable;
    if (_discharged.contains(s)) return AppColors.acuityDischarged;
    if (_standard.contains(s)) return AppColors.acuityStandard;
    if (_routine.contains(s)) return AppColors.acuityRoutine;
    return AppColors.acuityRoutine;
  }

  /// The status as a reader should see it: `in progress` → `In progress`.
  static String labelOf(String? status) {
    final s = normalise(status);
    if (s.isEmpty) return '—';
    return s[0].toUpperCase() + s.substring(1);
  }

  static IconData iconOf(String? status) {
    final c = colorOf(status);
    if (c == AppColors.acuityCritical) return Icons.priority_high_rounded;
    if (c == AppColors.acuityUrgent) return Icons.warning_amber_rounded;
    if (c == AppColors.acuityReview) return Icons.rate_review_outlined;
    if (c == AppColors.acuityStable) return Icons.check_circle_rounded;
    if (c == AppColors.acuityDischarged) return Icons.logout_rounded;
    if (c == AppColors.acuityStandard) return Icons.schedule_rounded;
    return Icons.circle_outlined;
  }

  // ── Triage codes ──────────────────────────────────────────────────────────
  //
  // What a screening actually stores. Sites run one of two scales and both
  // arrive here: the five-level Manchester/ESI codes, and the colour words
  // some departments still chart in. Both resolve, so a board mixing two
  // wards' conventions still reads as one board.

  static const Map<String, String> _codeLabels = {
    'P1': 'Immediate',
    'P2': 'Very urgent',
    'P3': 'Urgent',
    'P4': 'Standard',
    'P5': 'Non-urgent',
    'ADM': 'Admitted',
    'OBS': 'Observation',
    'DIS': 'Discharged',
    'TRF': 'Transferred',
    'REV': 'Awaiting review',
    'DNA': 'Did not attend',
  };

  static const Map<String, Color> _codeColors = {
    'P1': AppColors.acuityCritical,
    'P2': AppColors.acuityUrgent,
    'P3': AppColors.acuityUrgent,
    'P4': AppColors.acuityStandard,
    'P5': AppColors.acuityRoutine,
    'ADM': AppColors.acuityStandard,
    'OBS': AppColors.acuityStable,
    'DIS': AppColors.acuityDischarged,
    'TRF': AppColors.acuityDischarged,
    'REV': AppColors.acuityReview,
    // Amber, not red: a missed appointment is an administrative problem, and
    // red on a ward board means a patient is deteriorating.
    'DNA': AppColors.warning,
  };

  /// The stored codes a screening or an admission can hold. A picker offering
  /// a status reads this rather than hard-coding a list per screen.
  static List<String> get codes => _codeLabels.keys.toList();

  static bool isCode(String? status) =>
      _codeColors.containsKey((status ?? '').trim().toUpperCase());

  /// The colour for a stored code, falling back to the word ramp.
  static Color colorOfCode(String? status) {
    final code = (status ?? '').trim().toUpperCase();
    return _codeColors[code] ?? colorOf(status);
  }

  /// The words for a stored code.
  static String labelOfCode(String? status) {
    final code = (status ?? '').trim().toUpperCase();
    return _codeLabels[code] ?? labelOf(status);
  }

  /// How urgent a code is, lowest number first. A queue sorted by arrival time
  /// alone will seat a sprained ankle ahead of a chest pain that walked in two
  /// minutes later, so every list that shows mixed acuity sorts on this first.
  static int priorityOf(String? status) {
    final c = colorOfCode(status);
    if (c == AppColors.acuityCritical) return 0;
    if (c == AppColors.acuityUrgent) return 1;
    if (c == AppColors.acuityReview) return 2;
    if (c == AppColors.acuityStandard) return 3;
    if (c == AppColors.acuityRoutine) return 4;
    if (c == AppColors.acuityStable) return 5;
    return 6;
  }

  /// States a record can no longer be edited in.
  ///
  /// The backend refuses the write, so an app that offers it is an app that
  /// collects a clinician's notes and then loses them to a 400.
  static const Set<String> lockedCodes = {'DIS', 'TRF', 'DNA'};

  static bool isLocked(String? status) =>
      lockedCodes.contains((status ?? '').trim().toUpperCase());

  /// States only a clinician may set. Everyone else may move a record between
  /// the triage levels and no further — a receptionist does not discharge.
  static const Set<String> clinicianOnlyCodes = {'ADM', 'OBS', 'DIS', 'TRF'};

  static bool isClinicianOnlyCode(String? status) =>
      clinicianOnlyCodes.contains((status ?? '').trim().toUpperCase());
}

/// A status as a tinted pill. Colour *and* word, always — a pill that is only
/// a colour is unreadable to eight percent of men and to every screenshot.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.status,
    this.color,
    this.label,
    this.icon,
    this.compact = false,
  });

  /// The raw backend status. Resolved through [CaseStatus] unless [color] and
  /// [label] are both given.
  final String status;

  final Color? color;
  final String? label;
  final IconData? icon;

  /// Drops the icon and tightens the padding, for a dense list row.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = color ?? CaseStatus.colorOf(status);
    final text = label ?? CaseStatus.labelOf(status);
    final glyph = icon ?? CaseStatus.iconOf(status);
    final ink = semanticInk(context, tint);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(BentoRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            Icon(glyph, size: 12, color: ink),
            const SizedBox(width: 5),
          ],
          // Flexible, and it ellipsises. A site names its own triage levels,
          // so "Urgent" can just as easily be "Very urgent — see within 10
          // minutes" — and a pill that sizes itself to that pushes the whole
          // row off screen.
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.text(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: ink,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A count in a filled capsule — unread notifications, items in a queue.
class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.count,
    this.color,
    this.max = 99,
  });

  final int count;
  final Color? color;
  final int max;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final tint = color ?? AppColors.error;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > max ? '$max+' : '$count',
        style: AppFonts.numeric(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

// ── Figures ─────────────────────────────────────────────────────────────────

/// One headline number with its label. The unit a summary card is built from.
class Figure {
  const Figure({
    required this.label,
    required this.value,
    this.caption,
    this.color,
    this.icon,
    this.onTap,
  });

  final String label;

  /// Already formatted. A `Figure` never formats money — the caller passes the
  /// site's `MoneyFormat` output, because only the caller knows whether this
  /// is money, a count, or a percentage.
  final String value;

  final String? caption;
  final Color? color;
  final IconData? icon;
  final VoidCallback? onTap;
}

/// A grid of [Figure]s, two per row, each in its own bordered cell.
class FigureGrid extends StatelessWidget {
  const FigureGrid({
    super.key,
    required this.figures,
    this.columns,
    this.valueSize = 22,
  });

  final List<Figure> figures;

  /// Fixed column count. Left null the grid widens with the window, which is
  /// what keeps a tablet from showing a phone's two-column block with twice
  /// the white space around each cell.
  final int? columns;

  final double valueSize;

  /// Two cells on a phone, four once there is room — the figures on this grid
  /// are meant to be compared, and a single row compares better than a square.
  int _columnsFor(BuildContext context) {
    if (columns != null) return columns!;
    final window = WindowClass.of(context);
    if (window >= WindowClass.expanded) return 4;
    if (window >= WindowClass.medium) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    if (figures.isEmpty) return const SizedBox.shrink();
    final columns = _columnsFor(context);
    final rows = <Widget>[];
    for (var i = 0; i < figures.length; i += columns) {
      final slice = figures.skip(i).take(columns).toList();
      rows.add(
        // IntrinsicHeight, not CrossAxisAlignment.stretch: a stretched Row
        // inside a sliver is asked to lay out at infinite height and asserts.
        // This gives every cell in a row the height of the tallest one, which
        // is what "stretch" was there for.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < columns; j++) ...[
                if (j > 0) const SizedBox(width: 10),
                Expanded(
                  child: j < slice.length
                      ? _FigureCell(figure: slice[j], valueSize: valueSize)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
      if (i + columns < figures.length) rows.add(const SizedBox(height: 10));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _FigureCell extends StatelessWidget {
  const _FigureCell({required this.figure, required this.valueSize});

  final Figure figure;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = figure.color == null
        ? labelColor(context)
        : semanticInk(context, figure.color!);

    return BentoCard(
      radius: BentoRadius.control,
      padding: const EdgeInsets.all(14),
      onTap: figure.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (figure.icon != null) ...[
                Icon(figure.icon, size: 14, color: tertiaryLabelColor(context)),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  figure.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.overline(
                    Theme.of(context).brightness,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              figure.value,
              style: numeralStyle(context, size: valueSize, color: tint),
            ),
          ),
          if (figure.caption != null) ...[
            const SizedBox(height: 4),
            Text(
              figure.caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: isDark
                  ? AppTextStyles.darkFootnote()
                  : AppTextStyles.lightFootnote(),
            ),
          ],
        ],
      ),
    );
  }
}

/// The one hero figure on a screen: a large tabular amount over its label,
/// with an optional secondary line.
class MoneyFigure extends StatelessWidget {
  const MoneyFigure({
    super.key,
    required this.label,
    required this.amount,
    this.caption,
    this.color,
    this.size = 34,
    this.alignment = CrossAxisAlignment.start,
  });

  final String label;

  /// Already formatted by the site's `MoneyFormat`.
  final String amount;

  final String? caption;
  final Color? color;
  final double size;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.overline(Theme.of(context).brightness)),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            amount,
            style: numeralStyle(
              context,
              size: size,
              color: color ?? labelColor(context),
            ),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 6),
          Text(
            caption!,
            style: isDark
                ? AppTextStyles.darkFootnote()
                : AppTextStyles.lightFootnote(),
          ),
        ],
      ],
    );
  }
}

/// A two-tone proportion bar with its own legend — collected versus
/// outstanding, won versus lost.
class RatioBar extends StatelessWidget {
  const RatioBar({
    super.key,
    required this.fraction,
    required this.filledLabel,
    required this.remainderLabel,
    this.filledColor,
    this.remainderColor,
  });

  final double fraction;
  final String filledLabel;
  final String remainderLabel;
  final Color? filledColor;
  final Color? remainderColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filled = filledColor ?? AppColors.acuityStable;
    final rest = remainderColor ?? tertiaryLabelColor(context);
    final value = fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UsedBar(fraction: value, color: filled),
        const SizedBox(height: 8),
        // Both legends are Flexible: these carry formatted money, and a
        // site with a long symbol and six-figure totals overflows a fixed
        // Row on a narrow phone. Ellipsis beats a striped overflow bar.
        Row(
          children: [
            StatusMark(color: filled, size: 7),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                filledLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: isDark
                    ? AppTextStyles.darkFootnote()
                    : AppTextStyles.lightFootnote(),
              ),
            ),
            const SizedBox(width: 12),
            StatusMark(color: rest, size: 7),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                remainderLabel,
                maxLines: 1,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: isDark
                    ? AppTextStyles.darkFootnote()
                    : AppTextStyles.lightFootnote(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Empty and error states ──────────────────────────────────────────────────

/// What a screen shows when there is genuinely nothing to show.
///
/// Not a spinner and not a blank page: an empty list and a failed request look
/// identical to a user, and only one of them is worth waiting through. This is
/// the "nothing here" half; `ErrorRetryBanner` is the "it broke" half.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: compact ? 24 : 48,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 52 : 64,
            height: compact ? 52 : 64,
            decoration: BoxDecoration(
              color: wellColor(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: compact ? 24 : 28,
              color: tertiaryLabelColor(context),
            ),
          ),
          SizedBox(height: compact ? 14 : 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: isDark
                ? AppTextStyles.darkHeadline(weight: FontWeight.w700)
                : AppTextStyles.lightHeadline(weight: FontWeight.w700),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: isDark
                  ? AppTextStyles.darkSubheadline()
                  : AppTextStyles.lightSubheadline(),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// A loading placeholder shaped like the content it stands in for.
///
/// Shaped, not generic: a skeleton that does not match its content produces a
/// visible jump when the data lands, which reads as a bug even though nothing
/// failed.
class BentoSkeleton extends StatelessWidget {
  const BentoSkeleton({
    super.key,
    this.rows = 3,
    this.hasHeader = true,
  });

  final int rows;
  final bool hasHeader;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasHeader) ...[
            const ShimmerBox(width: 120, height: 14),
            const SizedBox(height: BentoSpace.header),
          ],
          BentoCard(
            padding: const EdgeInsets.all(BentoSpace.listPad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < rows; i++) ...[
                  if (i > 0) ...[
                    const SizedBox(height: 12),
                    const Hairline(),
                    const SizedBox(height: 12),
                  ],
                  const Row(
                    children: [
                      ShimmerBox(
                        width: 38,
                        height: 38,
                        borderRadius: BentoRadius.pill,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 140, height: 12),
                            SizedBox(height: 7),
                            ShimmerBox(width: 90, height: 10),
                          ],
                        ),
                      ),
                      ShimmerBox(width: 54, height: 20, borderRadius: 10),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );
}

// ── Actions ─────────────────────────────────────────────────────────────────

/// The one full-width primary action on a screen.
///
/// A bar, not a floating button: a FAB covers the last row of a list, and a
/// CRM's last row is as likely to matter as its first.
class PrimaryBar extends StatelessWidget {
  const PrimaryBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Swaps the label for a spinner and blocks the tap. The width does not
  /// change, so the bar does not jump as it submits.
  final bool busy;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: (!enabled || busy) ? null : onPressed,
        child: busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: scheme.onPrimary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 19),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The quieter sibling of [PrimaryBar]. Never two primaries on one screen.
class SecondaryBar extends StatelessWidget {
  const SecondaryBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tint = destructive
        ? semanticInk(context, AppColors.error)
        : brandInkColor(context);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: tint,
          side: BorderSide(color: tint.withValues(alpha: 0.45), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tinted card that offers one next step, with a reason above it.
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.icon,
    this.tint,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData? icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = tint ?? brandInkColor(context);

    return BentoCard(
      radius: BentoRadius.control,
      fill: accent.withValues(alpha: isDark ? 0.14 : 0.09),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: accent),
            const SizedBox(width: 12),
          ],
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
                const SizedBox(height: 3),
                Text(
                  message,
                  style: isDark
                      ? AppTextStyles.darkFootnote()
                      : AppTextStyles.lightFootnote(),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: FilledButton(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor:
                          accent.computeLuminance() > 0.45
                              ? const Color(0xFF17130B)
                              : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      textStyle: AppFonts.text(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(actionLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One tile in the quick-actions grid: an icon box over a two-word label.
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? tint;
  final int badgeCount;

  /// Breaks the label after its first word, so a row of these is one height.
  ///
  /// Left to wrap naturally, "New screening" fitted on one line while "Admit
  /// patient", "Add to queue" and "Discharge patient" each took two — so one
  /// tile in four was shorter than its neighbours and its label sat higher. A
  /// quick action is always a verb and its object, which is exactly where that
  /// break belongs anyway.
  static String _twoLines(String label) {
    final space = label.indexOf(' ');
    if (space < 0) return label;
    return '${label.substring(0, space)}\n${label.substring(space + 1)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = tint ?? brandInkColor(context);

    return BentoCard(
      radius: BentoRadius.control,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(BentoRadius.pill),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              if (badgeCount > 0)
                PositionedDirectional(
                  top: -5,
                  end: -5,
                  child: CountBadge(count: badgeCount),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            _twoLines(label),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: (isDark
                    ? AppTextStyles.darkCaption1(weight: FontWeight.w600)
                    : AppTextStyles.lightCaption1(weight: FontWeight.w600))
                .copyWith(color: labelColor(context), height: 1.25),
          ),
        ],
      ),
    );
  }
}

/// A horizontally scrolling filter row. Selection is single-choice: a CRM list
/// filtered by two statuses at once is a query nobody can read back.
class FilterChips<T> extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.labelOf,
    this.countOf,
    this.keyOf,
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final String Function(T) labelOf;

  /// Draws the number of matches beside each label when supplied.
  final int Function(T)? countOf;

  /// A widget key per option, so a flow test can tap one by name.
  final Key? Function(T)? keyOf;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BentoSpace.page),
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final option = options[i];
          final isSelected = option == selected;
          final count = countOf?.call(option);
          final tint = brandInkColor(context);

          return Material(
            key: keyOf?.call(option),
            color: isSelected
                ? tint.withValues(alpha: isDark ? 0.20 : 0.14)
                : wellColor(context),
            borderRadius: BorderRadius.circular(BentoRadius.pill),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelected(option),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      labelOf(option),
                      style: AppFonts.text(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? tint : secondaryLabelColor(context),
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '$count',
                        style: AppFonts.numeric(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? tint
                              : tertiaryLabelColor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The header of a pushed detail screen: back, title, subtitle, one action.
///
/// Never the shell's top bar. See `.agents/RULES.md` §6.3 — a sub-screen that
/// repeats the shell's global actions leaves the user with no way to tell
/// where they are.
class DetailHeader extends StatelessWidget implements PreferredSizeWidget {
  const DetailHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.action,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? action;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: isDark
                        ? AppTextStyles.darkTitle3(weight: FontWeight.w700)
                        : AppTextStyles.lightTitle3(weight: FontWeight.w700),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: isDark
                          ? AppTextStyles.darkFootnote()
                          : AppTextStyles.lightFootnote(),
                    ),
                ],
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

/// A sliver section header, for use inside [BentoScreen].
class BentoSectionHeader extends StatelessWidget {
  const BentoSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.top = 0,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Extra air above the header. Pass it on the **first** header of a screen
  /// whose shell already drew a bold title: two bold lines stacked with only
  /// the shell's own padding between them read as one cramped block.
  final double top;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            BentoSpace.page + 4,
            top,
            BentoSpace.page,
            0,
          ),
          child: SectionHeader(
            title: title,
            actionLabel: actionLabel,
            onAction: onAction,
            padding: const EdgeInsets.only(bottom: BentoSpace.header),
          ),
        ),
      );
}

// ── Forms ───────────────────────────────────────────────────────────────────

/// The card a form's fields are grouped into.
class FormCard extends StatelessWidget {
  const FormCard({super.key, required this.children, this.title});

  final List<Widget> children;
  final String? title;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) SectionHeader(title: title!),
          BentoCard(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ],
      );
}

/// A labelled form field wrapper.
///
/// The label sits above the control rather than floating inside it: a floating
/// label that has moved out of the way takes the field's meaning with it, and
/// a form filled from a phone is filled with the keyboard covering half the
/// screen.
class BentoField extends StatelessWidget {
  const BentoField({
    super.key,
    required this.label,
    required this.child,
    this.hint,
    this.error,
    this.required = false,
  });

  final String label;
  final Widget child;

  /// Help text under the control. Hidden while [error] is showing — two lines
  /// of guidance under one field is one line too many.
  final String? hint;

  final String? error;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                label,
                style: (isDark
                        ? AppTextStyles.darkFootnote(weight: FontWeight.w600)
                        : AppTextStyles.lightFootnote(weight: FontWeight.w600))
                    .copyWith(color: secondaryLabelColor(context)),
              ),
              if (required)
                Text(
                  ' *',
                  style: AppFonts.text(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: semanticInk(context, AppColors.error),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          child,
          if (error != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 13,
                  color: semanticInk(context, AppColors.error),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    error!,
                    style: AppFonts.text(
                      fontSize: 12,
                      color: semanticInk(context, AppColors.error),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              style: isDark
                  ? AppTextStyles.darkCaption1()
                  : AppTextStyles.lightCaption1(),
            ),
          ],
        ],
      ),
    );
  }
}

/// The app's text input. Wraps [BentoField] so a caller writes one widget.
class BentoInput extends StatelessWidget {
  const BentoInput({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.placeholder,
    this.error,
    this.required = false,
    this.obscure = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffix,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.fieldKey,
    this.focusNode,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? placeholder;
  final String? error;
  final bool required;
  final bool obscure;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  /// Sentence case for prose, word case for names.
  ///
  /// Worth setting rather than leaving to the keyboard: a phone's own
  /// auto-capitalisation is off inside a field whose type is not text, so a
  /// name typed into a field that also takes a phone number arrives lowercase.
  final TextCapitalization textCapitalization;

  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? maxLength;
  final IconData? prefixIcon;
  final Widget? suffix;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// The key a flow test drives this field by. Goes on the `TextField`, not on
  /// the wrapper, so `enterText` finds exactly one editable.
  final Key? fieldKey;

  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return BentoField(
      label: label,
      hint: hint,
      error: error,
      required: required,
      child: TextField(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        obscureText: obscure,
        enabled: enabled,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        maxLines: obscure ? 1 : maxLines,
        maxLength: maxLength,
        autofillHints: autofillHints,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: AppFonts.text(fontSize: 16, color: labelColor(context)),
        decoration: InputDecoration(
          hintText: placeholder,
          counterText: '',
          prefixIcon: prefixIcon == null
              ? null
              : Icon(prefixIcon, size: 19, color: tertiaryLabelColor(context)),
          // Centred here rather than at each call site. Material gives a
          // `suffixIcon` a 48×48 minimum and a child that can stretch — a
          // `Text`, a `Row` — fills it, drawing its one line at the top of a
          // box half again as tall as the glyph. A currency symbol or a "%"
          // then rides a clear 16 pt above the figures it belongs to.
          suffixIcon:
              suffix == null ? null : Center(widthFactor: 1, child: suffix),
          // The error is drawn by BentoField, so the decoration must not draw
          // it a second time — but it still needs to know, to paint the red
          // border.
          errorText: null,
          enabledBorder: error == null
              ? null
              : OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: AppColors.error, width: 1.5),
                ),
        ),
      ),
    );
  }
}

/// A field that opens a picker rather than a keyboard — a date, a client, a
/// status. Looks like an input so a form reads as one thing.
class BentoPicker extends StatelessWidget {
  const BentoPicker({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder = 'Select',
    this.hint,
    this.error,
    this.required = false,
    this.enabled = true,
    this.icon = Icons.expand_more_rounded,
    this.leadingIcon,
    this.fieldKey,
  });

  final String label;

  /// Null or empty renders [placeholder] in the hint colour.
  final String? value;

  final VoidCallback onTap;
  final String placeholder;
  final String? hint;
  final String? error;
  final bool required;
  final bool enabled;
  final IconData icon;
  final IconData? leadingIcon;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final hasValue = (value ?? '').trim().isNotEmpty;
    final theme = Theme.of(context);

    return BentoField(
      label: label,
      hint: hint,
      error: error,
      required: required,
      child: Material(
        key: fieldKey,
        color: theme.inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: error == null
                    ? hairlineColor(context)
                    : AppColors.error,
                width: error == null ? 0.5 : 1.5,
              ),
            ),
            child: Row(
              children: [
                if (leadingIcon != null) ...[
                  Icon(
                    leadingIcon,
                    size: 19,
                    color: tertiaryLabelColor(context),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    hasValue ? value! : placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.text(
                      fontSize: 16,
                      color: hasValue
                          ? labelColor(context)
                          : tertiaryLabelColor(context),
                    ),
                  ),
                ),
                Icon(icon, size: 20, color: tertiaryLabelColor(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A segmented control for two to four mutually exclusive options.
///
/// Above four, use a [BentoPicker]: segments below about 72 dp cannot hold a
/// readable label and stop being tappable targets.
class BentoSegmented<T> extends StatelessWidget {
  const BentoSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.labelOf,
    this.keyOf,
  }) : assert(
          options.length >= 2 && options.length <= 4,
          'BentoSegmented holds 2–4 options; use BentoPicker above that.',
        );

  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final String Function(T) labelOf;
  final Key? Function(T)? keyOf;

  @override
  Widget build(BuildContext context) {
    final tint = brandFillColor(context);
    final onTint = Theme.of(context).colorScheme.onPrimary;

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: wellColor(context),
        borderRadius: BorderRadius.circular(BentoRadius.control),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: GestureDetector(
                key: keyOf?.call(option),
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(option),
                child: AnimatedContainer(
                  duration: motionDuration(context, const Duration(milliseconds: 160)),
                  curve: Curves.easeOut,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: option == selected ? tint : Colors.transparent,
                    borderRadius: BorderRadius.circular(BentoRadius.pill),
                  ),
                  child: Text(
                    labelOf(option),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.text(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: option == selected
                          ? onTint
                          : secondaryLabelColor(context),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
