import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/data/repositories/clinical_repository.dart';

/// The clinic's day, generated from the site's own settings.
///
/// A hard-coded 08:00–17:00 grid passes against the default site and is wrong
/// for every other one: a clinic that opens at seven cannot book its first
/// hour, and one running twenty-minute appointments is offered times its diary
/// does not have. These are the cases that separate the two.
void main() {
  group('slots', () {
    test('the default day is half-hourly from opening to the last full slot',
        () {
      final slots = ClinicSchedule.slots(
        start: '08:00',
        end: '17:00',
        minutes: 30,
      );

      expect(slots.length, 18);
      expect(slots.first, '08:00');
      // The closing time is when the clinic shuts, not a slot: the last
      // appointment starts a full half-hour before it.
      expect(slots.last, '16:30');
      expect(slots.contains('17:00'), isFalse);
    });

    test('a site that opens early on twenty-minute appointments gets its own '
        'grid', () {
      expect(
        ClinicSchedule.slots(start: '07:00', end: '09:00', minutes: 20),
        ['07:00', '07:20', '07:40', '08:00', '08:20', '08:40'],
      );
    });

    test('a closing time before the opening one offers nothing', () {
      expect(
        ClinicSchedule.slots(start: '17:00', end: '08:00', minutes: 30),
        isEmpty,
      );
    });

    test('a day shorter than one appointment still opens', () {
      // A picker with nothing in it reads as a broken screen rather than as a
      // misconfigured site, so the moment the clinic opens is still offered.
      expect(
        ClinicSchedule.slots(start: '08:00', end: '08:10', minutes: 30),
        ['08:00'],
      );
    });

    test('an unreadable setting falls back to the documented default', () {
      expect(
        ClinicSchedule.slots(start: 'half eight', end: '', minutes: 0).first,
        '08:00',
      );
      expect(
        ClinicSchedule.slots(start: 'half eight', end: '', minutes: 0).last,
        '16:30',
      );
    });
  });

  group('clock arithmetic', () {
    test('an hour typed without its leading zero still parses', () {
      // An administrator types a site setting by hand. `"9:30"` sorted
      // lexicographically lands after `"17:00"`, so it is parsed rather than
      // trusted.
      expect(ClinicSchedule.minutesOf('9:30'), 570);
      expect(ClinicSchedule.minutesOf('09:30'), 570);
    });

    test('nonsense is null rather than midnight', () {
      expect(ClinicSchedule.minutesOf(null), isNull);
      expect(ClinicSchedule.minutesOf(''), isNull);
      expect(ClinicSchedule.minutesOf('morning'), isNull);
      expect(ClinicSchedule.minutesOf('25:00'), isNull);
      expect(ClinicSchedule.minutesOf('08:61'), isNull);
    });

    test('minutes come back zero-padded, which is what the column stores', () {
      expect(ClinicSchedule.clockOf(570), '09:30');
      expect(ClinicSchedule.clockOf(0), '00:00');
      expect(ClinicSchedule.clockOf(1439), '23:59');
    });
  });

  group('the appointment ladder', () {
    test('a new booking can be confirmed, arrive, or not turn up', () {
      expect(
        AppointmentStatus.nextFrom(AppointmentStatus.scheduled),
        [
          AppointmentStatus.confirmed,
          AppointmentStatus.checkedIn,
          AppointmentStatus.noShow,
        ],
      );
    });

    test('a booking that has not arrived cannot be completed', () {
      // Completing somebody who never came is how a clinic's own figures stop
      // meaning anything.
      expect(
        AppointmentStatus.allows(
          AppointmentStatus.scheduled,
          AppointmentStatus.completed,
        ),
        isFalse,
      );
      expect(
        AppointmentStatus.allows(
          AppointmentStatus.checkedIn,
          AppointmentStatus.completed,
        ),
        isTrue,
      );
    });

    test('a rescheduled booking starts again from the top', () {
      expect(
        AppointmentStatus.nextFrom(AppointmentStatus.rescheduled),
        AppointmentStatus.nextFrom(AppointmentStatus.scheduled),
      );
      expect(
        AppointmentStatus.canReschedule(AppointmentStatus.rescheduled),
        isTrue,
      );
    });

    test('the three that close a booking offer nothing and move nowhere', () {
      for (final status in const [
        AppointmentStatus.completed,
        AppointmentStatus.cancelled,
        AppointmentStatus.noShow,
      ]) {
        expect(AppointmentStatus.isClosed(status), isTrue, reason: status);
        expect(AppointmentStatus.nextFrom(status), isEmpty, reason: status);
        expect(AppointmentStatus.canReschedule(status), isFalse, reason: status);
      }
    });

    test('a status read back in the wrong case is still that status', () {
      expect(AppointmentStatus.isClosed('Cancelled'), isTrue);
      expect(AppointmentStatus.isClosed(' NO_SHOW '), isTrue);
    });
  });
}
