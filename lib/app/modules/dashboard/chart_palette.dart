import 'package:flutter/material.dart';

import '../../data/models/dashboard_model.dart';
import '../../theme/theme.dart';
import 'shift_board.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — colours for a chart series, and the series themselves
///
/// There is no chart palette in `lib/app/theme/` — nothing in this app drew a
/// chart before the shift board did — so this derives one from the brand token
/// rather than inventing a set of colours beside the design system.
///
/// The derivation exists because of one rule: **red means one thing.** A
/// clinician scans a board for red, and every red that is not a deteriorating
/// patient costs that scan its meaning. Amber is [AppColors.warning] and means
/// something else again. So the series hues are spread across the arc of the
/// wheel that carries neither: they start at the brand's own hue and walk it,
/// skipping the red-through-amber sector entirely.
///
/// A category is not a state, which is the other half of it. A service area or
/// an appointment status is a category; routing one through the acuity ramp
/// would paint "emergency, the department they arrived through" with the ramp's
/// meaning of "immediate". These hues carry no meaning at all, which is exactly
/// what a category wants — the legend's word does the work.
/// ─────────────────────────────────────────────────────────────────────────────
abstract final class ShiftChartPalette {
  /// The arc a series may take a hue from, in degrees.
  ///
  /// Opens after amber and closes before red comes round again. `AppColors`
  /// puts `error` and `acuityCritical` at 0°, `acuityUrgent` near 21° and
  /// `warning` near 33°, and none of those may be lent to a bar.
  static const double _safeFrom = 45;
  static const double _safeTo = 330;

  /// Saturated enough to tell six of them apart, light enough to read as a
  /// fill on cool paper *and* on deep slate. Fills are seen, not read, so they
  /// owe 3:1 rather than 4.5:1 and one value can serve both grounds.
  static const double _saturation = 0.60;
  static const double _lightness = 0.44;

  /// Six, which is more series than either chart on this board has and fewer
  /// than a reader can hold at once. A seventh wraps rather than inventing a
  /// colour nobody chose.
  static const int _count = 6;

  static final List<Color> series = _derive();

  /// The colour for series [index], wrapping.
  static Color of(int index) => series[index % series.length];

  static List<Color> _derive() {
    final brand = HSLColor.fromColor(AppColors.primary);
    const span = _safeTo - _safeFrom;
    const step = span / _count;

    // Where the brand itself sits inside the safe arc, so the first series is
    // the brand's own hue and the rest fan out from it. Teal is 180°, which is
    // comfortably inside; a site whose brand landed in the red sector is
    // clamped into the arc rather than allowed to borrow the meaning.
    final start = (brand.hue.clamp(_safeFrom, _safeTo) - _safeFrom) % span;

    return [
      for (var i = 0; i < _count; i++)
        HSLColor.fromAHSL(
          1,
          _safeFrom + (start + i * step) % span,
          _saturation,
          _lightness,
        ).toColor(),
    ];
  }
}

/// One bar or one arc: a word, a number, and a colour that means nothing on
/// its own.
@immutable
class ShiftSeries {
  const ShiftSeries({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

/// The two charts' data, built from what the dashboard route already answers.
abstract final class ShiftCharts {
  /// Today's clinic, by where each booking has got to.
  ///
  /// In lifecycle order rather than by size: a reader is asking "how much of
  /// today is still to come", and a sorted chart makes them find the order
  /// again on every refresh.
  static List<ShiftSeries> appointments(AppointmentStatuses statuses) {
    const order = ['Scheduled', 'Confirmed', 'Seen', 'Cancelled'];
    final counts = <String, int>{
      'Scheduled': statuses.scheduled,
      'Confirmed': statuses.confirmed,
      'Seen': statuses.completed,
      'Cancelled': statuses.cancelled,
    };

    final out = <ShiftSeries>[];
    for (var i = 0; i < order.length; i++) {
      final value = counts[order[i]] ?? 0;
      // `<= 0`, not `== 0`: this backend stores an uncounted figure as zero and
      // a negative one has been seen from a stats route that subtracted two
      // counts taken a second apart. Neither is a bar worth drawing.
      if (value <= 0) continue;
      // Indexed by position in the lifecycle, not by position in the output,
      // so a status that drops to zero does not recolour the ones after it.
      out.add(
        ShiftSeries(
          label: order[i],
          value: value,
          color: ShiftChartPalette.of(i),
        ),
      );
    }
    return out;
  }

  /// Who is waiting, by service area.
  ///
  /// Sorted by size, because the question this one answers is "where is the
  /// backlog" and the answer is the first arc.
  static List<ShiftSeries> queue(List<QueueServiceCount> areas) {
    final rows = [...areas.where((area) => area.count > 0)]
      ..sort((a, b) => b.count.compareTo(a.count));

    return [
      for (var i = 0; i < rows.length; i++)
        ShiftSeries(
          // A service area arrives as a map key off the server and can be
          // `out_patient` as easily as `Emergency` or `OPD`.
          label: ShiftBoard.areaLabel(rows[i].name),
          value: rows[i].count,
          color: ShiftChartPalette.of(i),
        ),
    ];
  }

  static int total(List<ShiftSeries> series) =>
      series.fold(0, (sum, one) => sum + one.value);
}
