import 'package:flutter/painting.dart' show Color;

import '../../theme/theme.dart';
import 'consultation_model.dart';

/// One set of observations, and what they mean.
///
/// It exists because the consultation form and the consultation detail have to
/// say the *same thing* about the same patient. The app shipped a bug once
/// where the form flagged a reading and the record that opened on it did not,
/// which is worse than neither flagging it: a clinician who has learned to
/// trust the warning is one the second screen misleads.
///
/// The judgement itself is [VitalRange]'s and nothing here second-guesses it.
/// What lives here is the other two thirds of the clinical rule — the **rank**
/// (which reading is worst) and the **word** (what to call it), so that neither
/// screen has to work them out for itself.
class VitalsReading {
  const VitalsReading({
    this.temperature,
    this.systolic,
    this.diastolic,
    this.pulse,
    this.respiratoryRate,
    this.oxygenSaturation,
    this.weight,
    this.height,
  });

  /// A consultation's observations, as the server stored them.
  ///
  /// **Zero is not a reading.** This backend stores an unobserved numeric vital
  /// as `0`, so a record that was never examined arrives as 0 °C, 0 bpm, 0/0 —
  /// and a zero temperature judged as an observation renders as hypothermia,
  /// which is a red that is not a deteriorating patient. Every field goes
  /// through the guards below, not through a null check alone.
  factory VitalsReading.ofConsultation(ConsultationModel record) =>
      VitalsReading(
        temperature: positive(record.temperature),
        systolic: positiveInt(record.bloodPressureSystolic),
        diastolic: positiveInt(record.bloodPressureDiastolic),
        pulse: positiveInt(record.pulseRate),
        respiratoryRate: positiveInt(record.respiratoryRate),
        oxygenSaturation: positiveInt(record.oxygenSaturation),
        weight: positive(record.weight),
        height: positive(record.height),
      );

  final double? temperature;
  final int? systolic;
  final int? diastolic;
  final int? pulse;
  final int? respiratoryRate;
  final int? oxygenSaturation;
  final double? weight;
  final double? height;

  /// A stored number that is actually an observation, or null.
  static double? positive(double? value) =>
      value == null || value <= 0 ? null : value;

  static int? positiveInt(int? value) =>
      value == null || value <= 0 ? null : value;

  bool get isEmpty =>
      temperature == null &&
      systolic == null &&
      pulse == null &&
      respiratoryRate == null &&
      oxygenSaturation == null &&
      weight == null &&
      height == null;

  // ── Judgement ─────────────────────────────────────────────────────────────

  Color? get temperatureTone => VitalRange.temperature(temperature);
  Color? get bloodPressureTone => VitalRange.bloodPressure(systolic, diastolic);
  Color? get pulseTone => VitalRange.pulse(pulse);
  Color? get respiratoryTone => VitalRange.respiratoryRate(respiratoryRate);
  Color? get saturationTone => VitalRange.oxygenSaturation(oxygenSaturation);

  /// Which readings are outside their adult range, named in the order a
  /// clinician charts them.
  List<String> get flagged => [
        if (temperatureTone != null) 'Temperature',
        if (bloodPressureTone != null) 'Blood pressure',
        if (pulseTone != null) 'Pulse',
        if (respiratoryTone != null) 'Respiratory rate',
        if (saturationTone != null) 'Oxygen saturation',
      ];

  /// The most serious flag across the set, or null when everything is in range.
  Color? get flag => VitalRange.worst([
        temperatureTone,
        bloodPressureTone,
        pulseTone,
        respiratoryTone,
        saturationTone,
      ]);

  /// The warning in words, naming the readings it is about.
  ///
  /// Null when nothing is flagged — a warning that is always up is a warning
  /// nobody reads.
  String? get warning {
    final names = flagged;
    final tone = flag;
    if (tone == null || names.isEmpty) return null;

    final list = names.length == 1
        ? names.single
        : '${names.take(names.length - 1).join(', ')} and ${names.last}';
    final verb = names.length == 1 ? 'is' : 'are';

    return tone == AppColors.acuityCritical
        ? '$list $verb well outside the normal adult range. Consider '
            'escalating.'
        : '$list $verb outside the normal adult range.';
  }
}
