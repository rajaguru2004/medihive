import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/theme.dart';
import '../chart_palette.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the board's two charts
///
/// Neither is red. The hues come from [ShiftChartPalette], which walks the arc
/// of the wheel that carries no meaning in this app — red is a deteriorating
/// patient, amber is a warning, and a bar that borrows either costs the ward
/// board its scan.
///
/// Both carry **colour and word and number**. A chart whose categories are
/// only colours is unreadable to eight percent of men, to every black-and-white
/// printout of the board, and to anybody standing far enough away to lose the
/// tint.
/// ─────────────────────────────────────────────────────────────────────────────

/// Today's clinic, by where each booking has got to.
class AppointmentStatusChart extends StatelessWidget {
  const AppointmentStatusChart({super.key, required this.series});

  final List<ShiftSeries> series;

  @override
  Widget build(BuildContext context) {
    final tallest = series.fold<int>(0, (m, s) => s.value > m ? s.value : m);
    final step = _step(tallest);
    final ceiling = _ceiling(tallest, step);
    final grid = hairlineColor(context);

    return SizedBox(
      height: 188,
      child: BarChart(
        BarChartData(
          maxY: ceiling,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          // Off. A board is read, not poked, and a built-in tooltip is a
          // second surface that can sit over the figure it explains.
          barTouchData: const BarTouchData(enabled: false),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: step,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: grid, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: step,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(
                    value.toInt().toString(),
                    style: numeralStyle(
                      context,
                      size: 11,
                      weight: FontWeight.w600,
                      color: tertiaryLabelColor(context),
                    ),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= series.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: 6,
                    child: Text(
                      series[index].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.text(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: secondaryLabelColor(context),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < series.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: series[i].value.toDouble(),
                    color: series[i].color,
                    width: 22,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(BentoRadius.rule),
                    ),
                  ),
                ],
              ),
          ],
        ),
        // Through `motionDuration`, which honours Reduce Motion. An implicit
        // animation that ignores it schedules frames the e2e harness then
        // waits out.
        duration: motionDuration(context, const Duration(milliseconds: 220)),
      ),
    );
  }

  /// A whole-number grid step, so the axis never reads `2.5 patients`.
  static double _step(int tallest) {
    if (tallest <= 4) return 1;
    if (tallest <= 10) return 2;
    if (tallest <= 25) return 5;
    if (tallest <= 50) return 10;
    if (tallest <= 100) return 20;
    return (tallest / 5).ceilToDouble();
  }

  static double _ceiling(int tallest, double step) {
    if (tallest <= 0) return step;
    return (tallest / step).ceil() * step;
  }
}

/// Who is waiting, by service area.
///
/// A donut rather than a second bar chart, because the question this one
/// answers is a share — "how much of the room is waiting on us" — and the
/// legend beside it carries the words and the counts, which is what makes a
/// ring readable at all.
class QueueAreaChart extends StatelessWidget {
  const QueueAreaChart({super.key, required this.series});

  final List<ShiftSeries> series;

  @override
  Widget build(BuildContext context) {
    final total = ShiftCharts.total(series);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 132,
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(enabled: false),
                  sections: [
                    for (final one in series)
                      PieChartSectionData(
                        value: one.value.toDouble(),
                        color: one.color,
                        radius: 22,
                        // The arcs carry no labels: at this size they are
                        // unreadable, and a figure a clinician acts on is
                        // never set at a size it has to be guessed at. The
                        // legend carries them instead.
                        showTitle: false,
                      ),
                  ],
                ),
                duration: motionDuration(context, const Duration(milliseconds: 220)),
              ),
              // The total in the hole, where the eye lands first.
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$total',
                    style: numeralStyle(context, size: 24),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'waiting',
                    style: AppTextStyles.overline(
                      Theme.of(context).brightness,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: BentoSpace.action),
        Expanded(child: _Legend(series: series)),
      ],
    );
  }
}

/// The key: a dot, the word, the count.
///
/// The dot keeps the raw series colour — a fill is seen, not read — while the
/// word beside it is set in the row's own ink, so nothing here depends on
/// telling two tints apart.
class _Legend extends StatelessWidget {
  const _Legend({required this.series});

  final List<ShiftSeries> series;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < series.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: series[i].color,
                  borderRadius: BorderRadius.circular(BentoRadius.rule),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  series[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: isDark
                      ? AppTextStyles.darkFootnote()
                      : AppTextStyles.lightFootnote(),
                ),
              ),
              const SizedBox(width: 8),
              // The count itself never elides.
              Text(
                '${series[i].value}',
                style: numeralStyle(context, size: 14),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
