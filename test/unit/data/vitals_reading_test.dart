import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/data/models/consultation_model.dart';
import 'package:medihive/app/data/models/vitals_reading.dart';
import 'package:medihive/app/theme/theme.dart';

/// The observations a consultation carries, and what two screens say about
/// them.
///
/// The form warns while a reading is typed and the record warns when somebody
/// opens it afterwards. They are the same object here precisely so they cannot
/// drift — the app shipped a bug once where the form flagged a reading and the
/// detail that opened on it did not.
void main() {
  group('an unobserved vital', () {
    test('is not a reading, however the backend stored it', () {
      // This backend writes an unobserved numeric vital as `0`. A screen that
      // guards only against null judges those as readings and paints an empty
      // record red — a red that is not a deteriorating patient, which is the
      // one thing red is not allowed to be.
      const reading = VitalsReading(
        temperature: 0,
        systolic: 0,
        diastolic: 0,
        pulse: 0,
        respiratoryRate: 0,
        oxygenSaturation: 0,
      );

      expect(reading.flag, isNull);
      expect(reading.flagged, isEmpty);
      expect(reading.warning, isNull);
    });

    test('is dropped rather than charted when the record is read back', () {
      final consultation = _consultation(
        temperature: 0,
        systolic: 0,
        diastolic: 0,
        pulse: 0,
        respiratory: 0,
        saturation: 0,
        weight: 0,
        height: 0,
      );
      final reading = VitalsReading.ofConsultation(consultation);

      expect(reading.temperature, isNull);
      expect(reading.systolic, isNull);
      expect(reading.pulse, isNull);
      expect(reading.weight, isNull);
      expect(reading.isEmpty, isTrue);
      expect(reading.warning, isNull);
    });
  });

  group('a reading outside its range', () {
    test('is named, not merely coloured', () {
      const reading = VitalsReading(temperature: 39.8, pulse: 128);

      expect(reading.flag, AppColors.acuityCritical);
      expect(reading.flagged, ['Temperature', 'Pulse']);
      // Colour alone fails a colour-blind reader, a printed record, and
      // anybody reading the screen from across a corridor.
      expect(reading.warning, contains('Temperature and Pulse'));
      expect(reading.warning, contains('well outside the normal adult range'));
    });

    test('one flag reads as one, and several read as several', () {
      const one = VitalsReading(temperature: 38.4);
      expect(one.warning, 'Temperature is outside the normal adult range.');

      const three = VitalsReading(
        temperature: 38.4,
        systolic: 150,
        diastolic: 88,
        pulse: 104,
      );
      expect(
        three.warning,
        'Temperature, Blood pressure and Pulse are outside the normal adult '
        'range.',
      );
    });

    test('the worst one decides how loudly it is said', () {
      // Amber and red in the same set: the sentence escalates, because a
      // clinician scanning a record needs the worst figure, not the first.
      const reading = VitalsReading(temperature: 38.4, oxygenSaturation: 88);
      expect(reading.flag, AppColors.acuityCritical);
      expect(reading.warning, contains('well outside'));
    });
  });

  test('readings inside their ranges say nothing at all', () {
    const reading = VitalsReading(
      temperature: 37.0,
      systolic: 120,
      diastolic: 78,
      pulse: 76,
      respiratoryRate: 16,
      oxygenSaturation: 98,
    );

    expect(reading.flag, isNull);
    // A warning that is always up is a warning nobody reads.
    expect(reading.warning, isNull);
    expect(reading.isEmpty, isFalse);
  });

  test('the form and the record read the same numbers the same way', () {
    final consultation = _consultation(
      temperature: 39.8,
      systolic: 168,
      diastolic: 96,
      pulse: 128,
      respiratory: 24,
      saturation: 91,
    );

    final fromRecord = VitalsReading.ofConsultation(consultation);
    const asTyped = VitalsReading(
      temperature: 39.8,
      systolic: 168,
      diastolic: 96,
      pulse: 128,
      respiratoryRate: 24,
      oxygenSaturation: 91,
    );

    expect(fromRecord.warning, asTyped.warning);
    expect(fromRecord.flagged, asTyped.flagged);
    expect(fromRecord.flag, asTyped.flag);
  });
}

ConsultationModel _consultation({
  required double temperature,
  required int systolic,
  required int diastolic,
  required int pulse,
  required int respiratory,
  required int saturation,
  double weight = 72.5,
  double height = 174,
}) =>
    ConsultationModel.fromJson({
      'id': 'c-1',
      'patientId': 'p-1',
      'doctorId': 'd-1',
      'visitDate': '2026-03-12T00:00:00.000Z',
      'visitType': 'outpatient',
      'temperature': temperature,
      'bloodPressureSystolic': systolic,
      'bloodPressureDiastolic': diastolic,
      'pulseRate': pulse,
      'respiratoryRate': respiratory,
      'oxygenSaturation': saturation,
      'weight': weight,
      'height': height,
      'chiefComplaint': 'See history',
      'createdAt': '2026-03-12T00:00:00.000Z',
      'updatedAt': '2026-03-12T00:00:00.000Z',
    });
