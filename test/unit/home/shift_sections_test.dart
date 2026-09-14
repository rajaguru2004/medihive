import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/data/models/access_map.dart';
import 'package:medihive/app/modules/dashboard/shift_sections.dart';

const _perms = <String, List<String>>{
  'DOCTOR': [
    'PATIENT_READ', 'APPOINTMENT_CREATE', 'APPOINTMENT_READ',
    'APPOINTMENT_UPDATE', 'CONSULTATION_CREATE', 'CONSULTATION_READ',
    'INPATIENT_CREATE', 'INPATIENT_READ', 'INPATIENT_UPDATE',
    'LABORATORY_CREATE', 'LABORATORY_READ', 'RADIOLOGY_CREATE',
    'RADIOLOGY_READ', 'PHARMACY_CREATE', 'PHARMACY_READ',
    'PRE_TRIAGE_CREATE', 'PRE_TRIAGE_READ', 'QUEUE_CREATE', 'QUEUE_READ',
    'QUEUE_UPDATE', 'DASHBOARD_READ',
  ],
  'NURSE': [
    'PATIENT_READ', 'APPOINTMENT_READ', 'CONSULTATION_READ',
    'INPATIENT_CREATE', 'INPATIENT_READ', 'INPATIENT_UPDATE',
    'PRE_TRIAGE_CREATE', 'PRE_TRIAGE_READ', 'PRE_TRIAGE_UPDATE',
    'QUEUE_CREATE', 'QUEUE_READ', 'QUEUE_UPDATE', 'DASHBOARD_READ',
  ],
  'LAB_TECHNICIAN': [
    'LABORATORY_CREATE', 'LABORATORY_READ', 'LABORATORY_UPDATE',
    'LABORATORY_DELETE', 'PATIENT_READ', 'DASHBOARD_READ',
  ],
  'BILLING_STAFF': [
    'BILLING_CREATE', 'BILLING_READ', 'BILLING_UPDATE', 'BILLING_DELETE',
    'PATIENT_READ', 'DASHBOARD_READ',
  ],
  'RECEPTIONIST': [
    'PATIENT_CREATE', 'PATIENT_READ', 'PATIENT_UPDATE',
    'APPOINTMENT_CREATE', 'APPOINTMENT_READ', 'APPOINTMENT_UPDATE',
    'APPOINTMENT_DELETE', 'QUEUE_CREATE', 'QUEUE_READ', 'QUEUE_UPDATE',
    'QUEUE_DELETE', 'BILLING_READ', 'DASHBOARD_READ',
  ],
};

final _catalogue = ShiftSections.catalogue(
  queueRoute: '/queue',
  clinicRoute: '/appointments',
  wardsRoute: '/inpatient',
  triageRoute: '/pre-triage',
  labRoute: '/laboratory',
  imagingRoute: '/radiology',
  pharmacyRoute: '/pharmacy',
  billingRoute: '/billing',
);

List<String> _bandsFor(String role) => ShiftSections.forAccess(
      AccessMap.fromPermissions(_perms[role]!),
      _catalogue,
    ).map((s) => s.id).toList();

void main() {
  group('what each role is shown first', () {
    test('a nurse gets the board, screenings and the ward', () {
      expect(_bandsFor('NURSE'), ['waiting', 'screenings', 'clinic', 'ward']);
    });

    test('a lab technician gets lab work and nothing else', () {
      expect(_bandsFor('LAB_TECHNICIAN'), ['lab']);
    });

    test('billing staff get what is owed, not a ward board', () {
      expect(_bandsFor('BILLING_STAFF'), ['unpaid']);
    });

    test('a receptionist gets the front desk', () {
      expect(_bandsFor('RECEPTIONIST'),
          containsAll(<String>['waiting', 'clinic', 'unpaid']));
    });
  });

  group('what the board refuses to show', () {
    test('never a band whose module the account cannot read', () {
      for (final role in _perms.keys) {
        final access = AccessMap.fromPermissions(_perms[role]!);
        for (final section
            in ShiftSections.forAccess(access, _catalogue)) {
          expect(access.can(section.module, section.verb), isTrue,
              reason: '$role was offered ${section.id}');
        }
      }
    });

    test('never work a read-only account cannot do', () {
      // A nurse can read consultations but not write them, and a band called
      // "to dispense" is an offer of work. Offering it to somebody who cannot
      // act is the dashboard version of a dead-end shortcut.
      final nurse = AccessMap.fromPermissions(_perms['NURSE']!);
      final bands = ShiftSections.forAccess(nurse, _catalogue);
      for (final section in bands.where((s) => s.needsWrite)) {
        expect(
          nurse.can(section.module, AccessVerb.create) ||
              nurse.can(section.module, AccessVerb.update),
          isTrue,
          reason: '${section.id} is work the nurse cannot do',
        );
      }
    });

    test('never more than four, for anybody', () {
      // A board scanned between patients answers "what needs me" in one look.
      // A fifth band is a band nobody reaches, and a scroll is not a look.
      for (final role in _perms.keys) {
        expect(_bandsFor(role).length, lessThanOrEqualTo(4), reason: role);
      }
      expect(
        ShiftSections.forAccess(
          const AccessMap(isSuperAdmin: true),
          _catalogue,
        ).length,
        4,
      );
    });

    test('an account with nothing gets nothing, not an error', () {
      expect(ShiftSections.forAccess(AccessMap.empty, _catalogue), isEmpty);
    });
  });

  group('every band is honest', () {
    test('each says what an empty one means', () {
      // "Nobody is waiting" is a good shift. A blank space is a bug.
      for (final section in _catalogue) {
        expect(section.emptyMessage.trim(), isNotEmpty, reason: section.id);
        expect(section.emptyMessage.endsWith('.'), isTrue,
            reason: '${section.id} should read as a sentence');
      }
    });

    test('titles do not just repeat the tab they link to', () {
      // The tab is already called Queue. A band called Queue tells somebody
      // nothing they did not already know.
      for (final section in _catalogue) {
        expect(section.title.toLowerCase(), isNot('queue'));
        expect(section.title.toLowerCase(), isNot('clinic'));
      }
    });

    test('ids and ranks are unique', () {
      final ids = _catalogue.map((s) => s.id).toList();
      final ranks = _catalogue.map((s) => s.rank).toList();
      expect(ids.toSet().length, ids.length);
      expect(ranks.toSet().length, ranks.length);
    });
  });
}
