import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/window_class.dart';
import 'app_bento.dart';
import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_surfaces.dart';
import 'app_text_styles.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the clinical layer of the kit
///
/// Everything in `app_bento.dart` is domain-neutral: a card is a card in any
/// app. This file is the part that only a hospital needs, and it exists so
/// that the three screens which show a bed, the four which show an acuity and
/// the two which show a wait time all show them the *same way*.
///
/// Two rules run through all of it, and they are the reason these are
/// components rather than snippets a screen assembles for itself:
///
///  * **Acuity is colour *and* rank *and* word.** A pill that is only a colour
///    is unreadable to eight percent of men, to every screenshot, and to
///    anyone reading a ward screen across a corridor. Every acuity in this
///    file carries its code as a glyph, so the rank survives a colour-blind
///    viewer and a black-and-white printout of the board.
///  * **A figure a clinician acts on is tabular.** Vitals tick. A proportional
///    `7` is narrower than a `0` in every face in the registry, so an
///    observation that refreshes visibly shivers — and a heart rate that
///    shivers is a heart rate somebody reads twice.
/// ─────────────────────────────────────────────────────────────────────────────

// ── Acuity ──────────────────────────────────────────────────────────────────

/// A triage level as a tinted pill: colour, rank and word together.
///
/// The difference from [StatusPill] is the rank. A CRM status has no order —
/// "sent" is not more than "draft" — so a pill showing the word is enough. A
/// triage level *is* an order, and the order is the whole point of the board,
/// so the code travels with it: `P1 Immediate`, not `Immediate` in a red that
/// the reader has to already know the meaning of.
class AcuityPill extends StatelessWidget {
  const AcuityPill({
    super.key,
    required this.code,
    this.label,
    this.compact = false,
  });

  /// The stored triage code — `P1` … `P5`, `ADM`, `REV`. Free text resolves
  /// through [CaseStatus] too, so a site charting words rather than codes gets
  /// a correct pill with no rank glyph.
  final String code;

  /// Overrides the resolved words. For a site that renames its levels.
  final String? label;

  /// Drops the words and keeps the rank. For a dense grid where the column is
  /// already headed "Acuity" — never for a row a clinician reads in isolation.
  final bool compact;

  /// Whether [code] is a ranked triage code rather than a free-text state.
  bool get _ranked => RegExp(r'^P[1-5]$').hasMatch(code.trim().toUpperCase());

  @override
  Widget build(BuildContext context) {
    final tint = CaseStatus.colorOfCode(code);
    final ink = semanticInk(context, tint);
    final words = label ?? CaseStatus.labelOfCode(code);
    final rank = code.trim().toUpperCase();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(BentoRadius.pill),
        // A hairline in the ramp colour, so the pill has an edge on both the
        // white card and the dark one. At 14% alpha the fill alone does not.
        border: Border.all(color: tint.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_ranked)
            Text(
              rank,
              style: AppFonts.numeric(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: ink,
                letterSpacing: 0.2,
                height: 1.0,
              ),
            )
          else
            Icon(CaseStatus.iconOf(code), size: 12, color: ink),
          if (!compact) ...[
            const SizedBox(width: 5),
            // Flexible and ellipsising: a site names its own levels, so
            // "Urgent" can just as easily be "Very urgent — see within 10
            // minutes", and a pill that sizes itself to that pushes the whole
            // row off screen.
            Flexible(
              child: Text(
                words,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.text(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ink,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The acuity legend: every level on the board, once, with its rank.
///
/// A board that uses colour to carry rank owes the reader the key exactly
/// once. This is that key — placed under the board, not over it.
class AcuityLegend extends StatelessWidget {
  const AcuityLegend({super.key, this.codes = const ['P1', 'P2', 'P3', 'P4', 'P5']});

  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final code in codes)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusMark(color: CaseStatus.colorOfCode(code), size: 7),
              const SizedBox(width: 6),
              Text(
                CaseStatus.labelOfCode(code),
                style: AppFonts.text(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: secondaryLabelColor(context),
                  height: 1.0,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ── Observations ────────────────────────────────────────────────────────────

/// One observation and its unit: `98` `bpm`, `37.2` `°C`, `12` `beds`.
///
/// The figure is tabular and the unit is a step down in tertiary ink, so the
/// pair reads as one object rather than as a number with a tag stuck on it.
/// [tone] colours the *figure* when a reading is out of range — never the
/// label, and never the unit, because an out-of-range reading is one alarm and
/// three coloured words is three.
class VitalFigure extends StatelessWidget {
  const VitalFigure({
    super.key,
    required this.value,
    this.unit,
    this.size = 22,
    this.tone,
    this.weight = FontWeight.w600,
  });

  final String value;
  final String? unit;
  final double size;

  /// An acuity colour when the reading is outside its reference range. Null —
  /// the overwhelmingly common case — is the primary ink.
  final Color? tone;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          // Shrink, never ellipsise. A truncated reading is worse than no
          // reading: "16…" could be 160, 168 or 16, and a clinician has no way
          // to tell which — a blood pressure of 168/96 is the exact case this
          // component exists to show. `scaleDown` only ever reduces, so a
          // figure that fits is drawn at its full size.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTextStyles.vital(
                brightness,
                size: size,
                weight: weight,
                color: tone == null ? null : semanticInk(context, tone!),
              ),
            ),
          ),
        ),
        if (unit != null && unit!.isNotEmpty) ...[
          const SizedBox(width: 3),
          Text(
            unit!,
            style: AppTextStyles.unit(
              brightness,
              size: size >= 28 ? 15 : 12,
            ),
          ),
        ],
      ],
    );
  }
}

/// A labelled observation in a card: the label above, the reading below.
///
/// The label is the overline — small, spaced, tertiary — because on a card of
/// six observations the labels are scaffolding and the readings are the
/// content. Reversing that weight is the single most common way a vitals card
/// becomes unreadable.
class VitalTile extends StatelessWidget {
  const VitalTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.tone,
    this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final String? unit;

  /// An acuity colour when the reading is out of range.
  final Color? tone;

  /// The reference range, or when it was taken. One line, tertiary.
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.overline(brightness),
        ),
        const SizedBox(height: 8),
        VitalFigure(value: value, unit: unit, tone: tone),
        if (caption != null && caption!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: brightness == Brightness.dark
                ? AppTextStyles.darkCaption1()
                : AppTextStyles.lightCaption1(),
          ),
        ],
      ],
    );

    if (onTap == null) return body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BentoRadius.small),
      child: Padding(padding: const EdgeInsets.all(4), child: body),
    );
  }
}

/// A grid of observations, two or three across depending on the window.
///
/// Deliberately not [FigureGrid]: a figure grid centres its cells and sizes
/// its value at the grid's discretion, which is right for a dashboard of
/// counts and wrong for a set of readings that a clinician compares down a
/// column. These are left-aligned and the same size, so the eye can run down
/// them.
class VitalsGrid extends StatelessWidget {
  const VitalsGrid({super.key, required this.tiles, this.columns});

  final List<VitalTile> tiles;

  /// Three across is the phone default and it sets a hard ceiling on the
  /// label: the overline is 11pt with open tracking, so anything past about
  /// **twelve characters ellipsises** on a 411dp screen. "Admitted today"
  /// becomes "ADMITTED TO…", which is not a label.
  ///
  /// Shorten the label rather than widening the grid — a column heading is
  /// scaffolding, and the reading underneath it is what the reader came for.
  /// Drop to two columns only for a compound value like a blood pressure,
  /// which is wide in the *figure* rather than the label.
  final int? columns;

  int _columnsFor(BuildContext context) {
    if (columns != null) return columns!;
    final window = WindowClass.of(context);
    if (window >= WindowClass.expanded) return 4;
    if (window >= WindowClass.medium) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final columnCount = _columnsFor(context);
    final rows = <Widget>[];

    for (var i = 0; i < tiles.length; i += columnCount) {
      final slice = tiles.skip(i).take(columnCount).toList();
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < columnCount; c++) ...[
              if (c > 0) const SizedBox(width: 16),
              // An empty Expanded rather than a shrink-wrapped last row: a
              // trailing gap keeps the final row's columns under the ones
              // above them instead of spreading to fill.
              Expanded(child: c < slice.length ? slice[c] : const SizedBox()),
            ],
          ],
        ),
      );
      if (i + columnCount < tiles.length) {
        rows.add(const SizedBox(height: 18));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}

// ── Wait times ──────────────────────────────────────────────────────────────

/// How long somebody has been waiting, flagged once it breaches.
///
/// The flag is the point. A queue screen that shows `47m` in the same ink as
/// `4m` has told a charge nurse nothing they could not have worked out, and
/// has made them work it out forty times. Past [breachMinutes] the chip turns
/// and gains a glyph — colour *and* shape, so it survives a colour-blind
/// reader.
class WaitChip extends StatelessWidget {
  const WaitChip({
    super.key,
    required this.waited,
    this.breachMinutes = 30,
    this.compact = false,
  });

  /// How long the person has been waiting.
  final Duration waited;

  /// The site's escalation threshold. Zero turns the flag off, for sites that
  /// escalate out of band.
  final int breachMinutes;

  final bool compact;

  bool get _breached =>
      breachMinutes > 0 && waited.inMinutes >= breachMinutes;

  /// `8m`, `1h 04m`. Never `64m`: past an hour a reader converts, and a chip
  /// that makes them convert is a chip they misread under load.
  static String format(Duration waited) {
    final minutes = waited.inMinutes;
    if (minutes < 0) return '0m';
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final rest = (minutes % 60).toString().padLeft(2, '0');
    return '${hours}h $rest' 'm';
  }

  @override
  Widget build(BuildContext context) {
    final tint = _breached ? AppColors.acuityUrgent : null;
    final ink = tint == null
        ? secondaryLabelColor(context)
        : semanticInk(context, tint);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: tint == null
            ? wellColor(context)
            : tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(BentoRadius.pill),
        border: tint == null
            ? null
            : Border.all(color: tint.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _breached ? Icons.running_with_errors_rounded : Icons.schedule_rounded,
            size: compact ? 11 : 12,
            color: ink,
          ),
          const SizedBox(width: 4),
          Text(
            format(waited),
            style: AppFonts.numeric(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: ink,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// A person waiting to be seen: their position, who they are, and how long.
///
/// The position is a figure, not a bullet: a queue is an ordered thing and the
/// order is what somebody is looking for. It sits in a well rather than a
/// brand-coloured circle, because a queue of twelve tickets each wearing the
/// brand makes the brand mean "row" instead of "action".
class QueueTicketRow extends StatelessWidget {
  const QueueTicketRow({
    super.key,
    required this.position,
    required this.name,
    this.subtitle,
    this.acuityCode,
    this.waited,
    this.breachMinutes = 30,
    this.trailing,
    this.onTap,
  });

  /// One-based position in the queue.
  final int position;
  final String name;

  /// Who they are waiting for, or what for. One line.
  final String? subtitle;

  /// The triage code, when the queue carries one.
  final String? acuityCode;

  final Duration? waited;
  final int breachMinutes;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BentoSpace.listPad,
          vertical: 10,
        ),
        child: Row(
          children: [
            // The position. Fixed width so a two-digit queue does not shunt
            // every name across by six points at ticket ten.
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: wellColor(context),
                borderRadius: BorderRadius.circular(BentoRadius.small),
              ),
              child: Text(
                '$position',
                style: AppFonts.numeric(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: labelColor(context),
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: isDark
                        ? AppTextStyles.darkSubheadline(
                            weight: FontWeight.w600)
                        : AppTextStyles.lightSubheadline(
                            weight: FontWeight.w600),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: isDark
                          ? AppTextStyles.darkFootnote()
                          : AppTextStyles.lightFootnote(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (acuityCode != null && acuityCode!.isNotEmpty)
                  AcuityPill(code: acuityCode!, compact: true),
                if (acuityCode != null && waited != null)
                  const SizedBox(height: 4),
                if (waited != null)
                  WaitChip(
                    waited: waited!,
                    breachMinutes: breachMinutes,
                    compact: true,
                  ),
              ],
            ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

// ── Beds and wards ──────────────────────────────────────────────────────────

/// What a bed is doing right now.
enum BedState {
  vacant,
  occupied,
  reserved,
  blocked;

  Color get color => switch (this) {
        BedState.vacant => AppColors.bedVacant,
        BedState.occupied => AppColors.bedOccupied,
        BedState.reserved => AppColors.bedReserved,
        BedState.blocked => AppColors.bedBlocked,
      };

  String get label => switch (this) {
        BedState.vacant => 'Vacant',
        BedState.occupied => 'Occupied',
        BedState.reserved => 'Reserved',
        BedState.blocked => 'Blocked',
      };

  /// Colour is not enough on a grid read across a room, and a grid is the one
  /// place a pill will not fit. Each state gets a glyph instead.
  IconData get icon => switch (this) {
        BedState.vacant => Icons.check_rounded,
        BedState.occupied => Icons.person_rounded,
        BedState.reserved => Icons.bookmark_rounded,
        BedState.blocked => Icons.block_rounded,
      };

  /// Resolves what the backend stores. Unknown states read as [blocked] rather
  /// than as [vacant]: a bed nobody can account for must not be offered to the
  /// next admission.
  static BedState resolve(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (s == 'vacant' || s == 'available' || s == 'free' || s == 'empty') {
      return BedState.vacant;
    }
    if (s == 'occupied' || s == 'admitted' || s == 'in use') {
      return BedState.occupied;
    }
    if (s == 'reserved' || s == 'booked' || s == 'pending') {
      return BedState.reserved;
    }
    return BedState.blocked;
  }
}

/// One bed on a ward map.
///
/// Square, because a ward is a floor plan and a floor plan made of rectangles
/// of varying width stops being legible as a map. The state is a tinted fill
/// plus a glyph plus — when there is room — the occupant, so the tile answers
/// "is this free?" at a glance and "who is in it?" on a second look.
class BedTile extends StatelessWidget {
  const BedTile({
    super.key,
    required this.number,
    required this.state,
    this.occupant,
    this.acuityCode,
    this.onTap,
  });

  /// The bed's number or label, as the ward writes it.
  final String number;
  final BedState state;

  /// Who is in it. Suppressed by the site's `show_patient_names` on boards
  /// visible from a waiting area — the caller passes null.
  final String? occupant;

  /// The occupant's acuity, when the ward tracks one.
  final String? acuityCode;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = state.color;
    final ink = semanticInk(context, tint);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BentoRadius.control),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(BentoRadius.control),
          border: Border.all(color: tint.withValues(alpha: 0.32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    number,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.numeric(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: labelColor(context),
                      height: 1.0,
                    ),
                  ),
                ),
                Icon(state.icon, size: 14, color: ink),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              occupant?.trim().isNotEmpty == true ? occupant! : state.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.text(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: occupant?.trim().isNotEmpty == true
                    ? secondaryLabelColor(context)
                    : ink,
                height: 1.1,
              ),
            ),
            if (acuityCode != null && acuityCode!.isNotEmpty) ...[
              const SizedBox(height: 8),
              AcuityPill(code: acuityCode!, compact: true),
            ],
          ],
        ),
      ),
    );
  }
}

/// A ward's beds as a map.
///
/// `GridView` is deliberately not used: this is almost always nested inside a
/// scrolling screen, and a nested scrollable that has to be told
/// `shrinkWrap: true` and `NeverScrollableScrollPhysics` is a scrollable
/// pretending to be a column. This is a column.
class BedGrid extends StatelessWidget {
  const BedGrid({super.key, required this.tiles, this.columns, this.spacing = 10});

  final List<BedTile> tiles;
  final int? columns;
  final double spacing;

  int _columnsFor(BuildContext context) {
    if (columns != null) return columns!;
    final window = WindowClass.of(context);
    if (window >= WindowClass.expanded) return 6;
    if (window >= WindowClass.medium) return 4;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final columnCount = _columnsFor(context);
    final rows = <Widget>[];

    for (var i = 0; i < tiles.length; i += columnCount) {
      final slice = tiles.skip(i).take(columnCount).toList();
      rows.add(
        // Beds in one row are the same height whatever their occupants' names
        // do, because a ward map with a ragged bottom edge stops reading as a
        // floor plan.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < columnCount; c++) ...[
                if (c > 0) SizedBox(width: spacing),
                Expanded(child: c < slice.length ? slice[c] : const SizedBox()),
              ],
            ],
          ),
        ),
      );
      if (i + columnCount < tiles.length) rows.add(SizedBox(height: spacing));
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

/// A ward's occupancy, as a bar with the states in it.
///
/// Not [RatioBar] and not [UsedBar]: both draw one filled fraction against a
/// remainder, and a ward has four states that a charge nurse needs at once.
/// The bar is the census — occupied, reserved, blocked, vacant — in that
/// order, so the leftmost segment is always the one that matters most.
class WardCapacityBar extends StatelessWidget {
  const WardCapacityBar({
    super.key,
    required this.occupied,
    required this.total,
    this.reserved = 0,
    this.blocked = 0,
    this.height = 10,
    this.showLegend = true,
  });

  final int occupied;
  final int reserved;
  final int blocked;
  final int total;
  final double height;
  final bool showLegend;

  int get _vacant =>
      (total - occupied - reserved - blocked).clamp(0, total).toInt();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final safeTotal = total <= 0 ? 1 : total;

    final segments = <(int, Color, String)>[
      (occupied, AppColors.bedOccupied, 'Occupied'),
      (reserved, AppColors.bedReserved, 'Reserved'),
      (blocked, AppColors.bedBlocked, 'Blocked'),
      (_vacant, AppColors.bedVacant, 'Vacant'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            VitalFigure(
              value: '$occupied',
              unit: 'of $total beds',
              size: 22,
            ),
            const Spacer(),
            Text(
              '${((occupied / safeTotal) * 100).round()}%',
              style: AppFonts.numeric(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: secondaryLabelColor(context),
                height: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(BentoRadius.band),
          child: SizedBox(
            height: height,
            // An empty track when there is nothing to divide up. Without it a
            // ward with no beds — or a board whose fetch failed — renders the
            // bar as a gap, which reads as a rendering fault rather than as
            // "no beds".
            child: total <= 0
                ? ColoredBox(color: wellColor(context))
                : Row(
                    children: [
                      for (final (count, color, _) in segments)
                        if (count > 0)
                          Expanded(
                            flex: count,
                            child: ColoredBox(color: color),
                          ),
                    ],
                  ),
          ),
        ),
        if (showLegend) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final (count, color, label) in segments)
                if (count > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusMark(color: color, size: 7),
                      const SizedBox(width: 6),
                      Text(
                        '$label $count',
                        style: AppFonts.numeric(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: brightness == Brightness.dark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Patients ────────────────────────────────────────────────────────────────

/// The identity band at the top of anything about one patient.
///
/// Every clinical screen owes the reader the same four facts in the same
/// place: who, which record, how old, and what state. This is that band, and
/// it is a component so that the answer never moves between screens — a
/// clinician checking they are looking at the right patient should not have to
/// re-find the MRN on each one.
class PatientIdentityBand extends StatelessWidget {
  const PatientIdentityBand({
    super.key,
    required this.name,
    this.mrn,
    this.age,
    this.sex,
    this.acuityCode,
    this.extra,
  });

  final String name;

  /// The medical record number. Tabular, because a clinician reads it against
  /// a wristband character by character.
  final String? mrn;

  final String? age;
  final String? sex;
  final String? acuityCode;

  /// One more fact this screen needs — a ward, a consultant, an admission
  /// date. Kept to one, because the band is a check, not a summary.
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // An em-dash is what `Formatters.age` returns for an unknown date of
    // birth. In a fact list that placeholder is honest; joined into an
    // identity line it reads as "— · Male", which looks like a rendering
    // fault rather than like a missing date.
    bool present(String? value) =>
        value != null && value.trim().isNotEmpty && value.trim() != '—';

    final facts = <String>[
      if (present(age)) age!,
      if (present(sex)) sex!,
      if (present(extra)) extra!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: isDark
                    ? AppTextStyles.darkTitle3()
                    : AppTextStyles.lightTitle3(),
              ),
            ),
            if (acuityCode != null && acuityCode!.isNotEmpty) ...[
              const SizedBox(width: 10),
              AcuityPill(code: acuityCode!),
            ],
          ],
        ),
        if (mrn != null && mrn!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'MRN ',
                style: AppTextStyles.overline(brightness),
              ),
              Flexible(
                child: Text(
                  mrn!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.numeric(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: secondaryLabelColor(context),
                    letterSpacing: 0.3,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (facts.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            facts.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: isDark
                ? AppTextStyles.darkFootnote()
                : AppTextStyles.lightFootnote(),
          ),
        ],
      ],
    );
  }
}

// ── Reference ranges ────────────────────────────────────────────────────────

/// Whether an observation is inside its normal adult range.
///
/// This is the one piece of clinical judgement in the design system, and it
/// exists here rather than on each screen for a single reason: a temperature
/// of 38.9 must be the same colour on the screening form, on the screening
/// detail and on the ward board. Three screens each deciding for themselves is
/// three screens that eventually disagree, and a clinician who has learned to
/// trust the colour is a clinician the third screen misleads.
///
/// **These are adult ranges and a triage aid, not a diagnosis.** They are
/// deliberately wide: the job is to catch a figure worth a second look, not to
/// flag every patient who is slightly off. Paediatric ranges differ by age and
/// are not modelled — a site running a paediatric department should read
/// [VitalRange.paediatricWarning] before relying on the colours.
abstract final class VitalRange {
  /// Shown beside vitals on a paediatric record.
  static const paediatricWarning =
      'Ranges shown are adult. Check against the paediatric chart for age.';

  /// Body temperature, °C.
  ///
  /// Below 36 is hypothermia; 38 and above is a fever. 39.5 and above earns
  /// red rather than amber.
  ///
  /// Zero is "not recorded", exactly as it is for the four ranges below: the
  /// backend stores an unobserved numeric vital as zero, and a blank field on a
  /// half-typed triage form parses the same way. Judging it as a reading paints
  /// an empty row red — a red that is not a deteriorating patient, which is the
  /// one thing red is not allowed to be.
  static Color? temperature(double? celsius) {
    if (celsius == null || celsius <= 0) return null;
    if (celsius >= 39.5 || celsius < 35.0) return AppColors.acuityCritical;
    if (celsius >= 38.0 || celsius < 36.0) return AppColors.acuityUrgent;
    return null;
  }

  /// Heart rate, beats per minute.
  static Color? pulse(int? bpm) {
    if (bpm == null || bpm <= 0) return null;
    if (bpm >= 130 || bpm < 40) return AppColors.acuityCritical;
    if (bpm > 100 || bpm < 50) return AppColors.acuityUrgent;
    return null;
  }

  /// Blood pressure, from both figures.
  ///
  /// Takes the pair because they are read as a pair: 90/60 is one reading, and
  /// judging the systolic alone calls a healthy young adult hypotensive.
  static Color? bloodPressure(int? systolic, int? diastolic) {
    if (systolic == null || systolic <= 0) return null;
    if (systolic >= 180 || systolic < 90) return AppColors.acuityCritical;
    if (diastolic != null && diastolic > 0) {
      if (diastolic >= 120 || diastolic < 50) return AppColors.acuityCritical;
      if (diastolic >= 90) return AppColors.acuityUrgent;
    }
    if (systolic >= 140 || systolic < 100) return AppColors.acuityUrgent;
    return null;
  }

  /// Oxygen saturation, percent.
  ///
  /// The one vital where a small number is the emergency and there is no upper
  /// bound to worry about.
  static Color? oxygenSaturation(int? percent) {
    if (percent == null || percent <= 0) return null;
    if (percent < 92) return AppColors.acuityCritical;
    if (percent < 95) return AppColors.acuityUrgent;
    return null;
  }

  /// Respiratory rate, breaths per minute.
  static Color? respiratoryRate(int? perMinute) {
    if (perMinute == null || perMinute <= 0) return null;
    if (perMinute >= 25 || perMinute < 9) return AppColors.acuityCritical;
    if (perMinute > 20 || perMinute < 12) return AppColors.acuityUrgent;
    return null;
  }

  /// The most serious flag across several readings, or null when every one of
  /// them is in range.
  ///
  /// The reduction lives here rather than in each screen that needs it. A form
  /// that escalates on a critical reading and a detail screen that does not is
  /// two screens disagreeing about the same patient, which is the failure this
  /// whole class exists to prevent.
  static Color? worst(Iterable<Color?> flags) {
    final raised = flags.whereType<Color>();
    if (raised.isEmpty) return null;
    return raised.contains(AppColors.acuityCritical)
        ? AppColors.acuityCritical
        : AppColors.acuityUrgent;
  }

  /// The normal range as words, for the caption under a reading.
  static const captions = <String, String>{
    'temperature': '36.0–38.0 °C',
    'pulse': '50–100 bpm',
    'bloodPressure': '100–140 systolic',
    'oxygenSaturation': '95% and above',
    'respiratoryRate': '12–20 /min',
  };
}

// ── Observation entry ───────────────────────────────────────────────────────

/// A numeric observation field that colours its own unit when out of range.
///
/// The colour lands on the **unit**, not the border. A red border in a form
/// already means "this field is invalid", and 39.8 °C is a perfectly valid
/// entry that happens to describe a patient with a fever — so a form that uses
/// the same signal for both teaches its users to ignore one of them.
///
/// [tone] is passed in rather than computed here, so the caller decides which
/// range applies (a blood pressure needs both figures) and the field stays a
/// plain widget. Wrap it in an `Obx` to recolour as the reading is typed.
class VitalInput extends StatelessWidget {
  const VitalInput({
    super.key,
    required this.label,
    required this.unit,
    required this.controller,
    this.fieldKey,
    this.tone,
    this.error,
    this.hint,
    this.onChanged,
    this.decimal = false,
    this.textInputAction = TextInputAction.next,
  });

  final String label;
  final String unit;
  final TextEditingController controller;
  final Key? fieldKey;

  /// An acuity colour when the reading is outside its range.
  final Color? tone;

  /// A validation message. Distinct from [tone]: this means the entry is not a
  /// number the field can accept, not that the patient is unwell.
  final String? error;

  /// The normal range, as a hint under the field.
  final String? hint;

  final ValueChanged<String>? onChanged;

  /// Allows a decimal point. Temperature only, in practice.
  final bool decimal;

  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return BentoInput(
      fieldKey: fieldKey,
      label: label,
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      textInputAction: textInputAction,
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimal ? RegExp(r'[\d.]') : RegExp(r'\d'),
        ),
        LengthLimitingTextInputFormatter(decimal ? 5 : 3),
      ],
      onChanged: onChanged,
      error: error,
      hint: hint,
      suffix: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Text(
          unit,
          style: AppTextStyles.unit(
            Theme.of(context).brightness,
            color: tone == null ? null : semanticInk(context, tone!),
          ),
        ),
      ),
    );
  }
}
