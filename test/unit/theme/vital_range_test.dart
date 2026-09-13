import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/theme/theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — `VitalRange`
///
/// `VitalRange` is the only place in the app that decides whether an
/// observation is normal. Three screens each judging for themselves is three
/// screens that eventually disagree, and a clinician who has learned to trust
/// the colour is the one the third screen misleads — so the boundaries are
/// pinned here, at the exact figure they turn on.
///
/// The tests below check each boundary from both sides. An off-by-one in a
/// threshold is invisible in a screenshot and obvious in a diff.
///
/// **Not recorded is not a reading.** The backend stores an unrecorded numeric
/// vital as zero, so every range treats zero the way it treats null: no colour.
/// An unrecorded temperature painted red is a red that is not a deteriorating
/// patient, which is the one thing red is not allowed to be.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  group('temperature', () {
    test('a normal temperature is not coloured', () {
      expect(VitalRange.temperature(36.5), isNull);
      expect(VitalRange.temperature(37.0), isNull);
      expect(VitalRange.temperature(37.9), isNull);
    });

    test('a fever and a low temperature are amber', () {
      expect(VitalRange.temperature(38.0), AppColors.acuityUrgent);
      expect(VitalRange.temperature(38.9), AppColors.acuityUrgent);
      expect(VitalRange.temperature(35.9), AppColors.acuityUrgent);
      expect(VitalRange.temperature(35.0), AppColors.acuityUrgent);
    });

    test('a high fever and hypothermia are red', () {
      expect(VitalRange.temperature(39.5), AppColors.acuityCritical);
      expect(VitalRange.temperature(41.2), AppColors.acuityCritical);
      expect(VitalRange.temperature(34.9), AppColors.acuityCritical);
    });

    test('an unrecorded temperature is not a reading', () {
      expect(VitalRange.temperature(null), isNull);
      expect(VitalRange.temperature(0), isNull);
    });
  });

  group('pulse', () {
    test('a normal pulse is not coloured', () {
      expect(VitalRange.pulse(72), isNull);
      expect(VitalRange.pulse(50), isNull);
      expect(VitalRange.pulse(100), isNull);
    });

    test('a tachycardia and a bradycardia are amber', () {
      expect(VitalRange.pulse(101), AppColors.acuityUrgent);
      expect(VitalRange.pulse(129), AppColors.acuityUrgent);
      expect(VitalRange.pulse(49), AppColors.acuityUrgent);
      expect(VitalRange.pulse(40), AppColors.acuityUrgent);
    });

    test('an extreme rate is red', () {
      expect(VitalRange.pulse(130), AppColors.acuityCritical);
      expect(VitalRange.pulse(180), AppColors.acuityCritical);
      expect(VitalRange.pulse(39), AppColors.acuityCritical);
    });

    test('an unrecorded pulse is not a reading', () {
      expect(VitalRange.pulse(null), isNull);
      expect(VitalRange.pulse(0), isNull);
    });
  });

  group('bloodPressure', () {
    test('a normal pair is not coloured', () {
      expect(VitalRange.bloodPressure(120, 80), isNull);
      expect(VitalRange.bloodPressure(100, 60), isNull);
      expect(VitalRange.bloodPressure(139, 89), isNull);
    });

    test('a raised or low pressure is amber', () {
      expect(VitalRange.bloodPressure(140, 85), AppColors.acuityUrgent);
      expect(VitalRange.bloodPressure(99, 65), AppColors.acuityUrgent);
      // A raised diastolic flags on its own, with a systolic that would not.
      expect(VitalRange.bloodPressure(130, 90), AppColors.acuityUrgent);
    });

    test('a hypertensive crisis or a shocked patient is red', () {
      expect(VitalRange.bloodPressure(180, 95), AppColors.acuityCritical);
      expect(VitalRange.bloodPressure(89, 55), AppColors.acuityCritical);
      // Either figure alone is enough to earn red.
      expect(VitalRange.bloodPressure(130, 120), AppColors.acuityCritical);
      expect(VitalRange.bloodPressure(130, 49), AppColors.acuityCritical);
    });

    test('a missing diastolic still judges the systolic it does have', () {
      // Half a reading is common on a triage form somebody is mid-way through
      // typing, and it is still worth flagging.
      expect(VitalRange.bloodPressure(190, null), AppColors.acuityCritical);
      expect(VitalRange.bloodPressure(145, null), AppColors.acuityUrgent);
      expect(VitalRange.bloodPressure(95, null), AppColors.acuityUrgent);
      expect(VitalRange.bloodPressure(120, null), isNull);
      // Zero reads as "not recorded", not as a diastolic of nothing.
      expect(VitalRange.bloodPressure(120, 0), isNull);
    });

    test('an unrecorded systolic is not a reading', () {
      expect(VitalRange.bloodPressure(null, null), isNull);
      expect(VitalRange.bloodPressure(null, 80), isNull);
      expect(VitalRange.bloodPressure(0, 80), isNull);
    });
  });

  group('oxygenSaturation', () {
    test('a normal saturation is not coloured', () {
      expect(VitalRange.oxygenSaturation(98), isNull);
      expect(VitalRange.oxygenSaturation(95), isNull);
    });

    test('there is deliberately no upper bound', () {
      // The one vital where a small number is the emergency. 100% is a patient
      // on oxygen, not an alarm.
      expect(VitalRange.oxygenSaturation(100), isNull);
    });

    test('a mild desaturation is amber', () {
      expect(VitalRange.oxygenSaturation(94), AppColors.acuityUrgent);
      expect(VitalRange.oxygenSaturation(92), AppColors.acuityUrgent);
    });

    test('a significant desaturation is red', () {
      expect(VitalRange.oxygenSaturation(91), AppColors.acuityCritical);
      expect(VitalRange.oxygenSaturation(80), AppColors.acuityCritical);
    });

    test('an unrecorded saturation is not a reading', () {
      expect(VitalRange.oxygenSaturation(null), isNull);
      expect(VitalRange.oxygenSaturation(0), isNull);
    });
  });

  group('respiratoryRate', () {
    test('a normal rate is not coloured', () {
      expect(VitalRange.respiratoryRate(16), isNull);
      expect(VitalRange.respiratoryRate(12), isNull);
      expect(VitalRange.respiratoryRate(20), isNull);
    });

    test('a raised or slow rate is amber', () {
      expect(VitalRange.respiratoryRate(21), AppColors.acuityUrgent);
      expect(VitalRange.respiratoryRate(24), AppColors.acuityUrgent);
      expect(VitalRange.respiratoryRate(11), AppColors.acuityUrgent);
      expect(VitalRange.respiratoryRate(9), AppColors.acuityUrgent);
    });

    test('an extreme rate is red', () {
      expect(VitalRange.respiratoryRate(25), AppColors.acuityCritical);
      expect(VitalRange.respiratoryRate(40), AppColors.acuityCritical);
      expect(VitalRange.respiratoryRate(8), AppColors.acuityCritical);
    });

    test('an unrecorded rate is not a reading', () {
      expect(VitalRange.respiratoryRate(null), isNull);
      expect(VitalRange.respiratoryRate(0), isNull);
    });
  });

  group('the vocabulary the colours are drawn from', () {
    test('a flagged vital is only ever amber or red', () {
      // A vital tinted with the brand teal, or with a colour outside the ramp,
      // is a vital a clinician cannot read at a glance against the rest of the
      // board. Only two tones ever leave this class.
      final flags = <Object?>[
        VitalRange.temperature(39.9),
        VitalRange.temperature(37.2),
        VitalRange.pulse(140),
        VitalRange.pulse(101),
        VitalRange.bloodPressure(200, 130),
        VitalRange.bloodPressure(145, 85),
        VitalRange.oxygenSaturation(88),
        VitalRange.oxygenSaturation(93),
        VitalRange.respiratoryRate(30),
        VitalRange.respiratoryRate(22),
      ];

      for (final flag in flags) {
        expect(
          flag,
          anyOf(isNull, AppColors.acuityUrgent, AppColors.acuityCritical),
        );
      }
    });

    test('every range has its normal band written out for the caption', () {
      // The colour is a prompt, not a diagnosis — a reader has to be able to
      // see what "normal" meant without leaving the row.
      for (final key in [
        'temperature',
        'pulse',
        'bloodPressure',
        'oxygenSaturation',
        'respiratoryRate',
      ]) {
        expect(VitalRange.captions[key], isNotNull, reason: key);
      }
    });
  });
}
