import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/data/models/access_map.dart';
import 'package:medihive/app/modules/home/shell_layout.dart';

/// The permission sets the backend seeds, as `<MODULE>_<VERB>` strings.
///
/// Copied from `hms_v2/prisma/seed.ts`. They are the input to every assertion
/// below, so if a hospital changes what a nurse may do, the navigation follows
/// without anybody editing a tab list.
const _seededPermissions = <String, List<String>>{
  'ADMIN': [
    'USER_CREATE', 'USER_READ', 'USER_UPDATE', 'USER_DELETE',
    'ROLE_READ', 'PATIENT_READ', 'APPOINTMENT_READ', 'AUDIT_READ',
    'DASHBOARD_READ', 'SETTINGS_READ', 'SETTINGS_UPDATE',
  ],
  'DOCTOR': [
    'PATIENT_CREATE', 'PATIENT_READ', 'PATIENT_UPDATE', 'PATIENT_DELETE',
    'APPOINTMENT_CREATE', 'APPOINTMENT_READ', 'APPOINTMENT_UPDATE',
    'APPOINTMENT_DELETE',
    'CONSULTATION_CREATE', 'CONSULTATION_READ', 'CONSULTATION_UPDATE',
    'CONSULTATION_DELETE',
    'INPATIENT_CREATE', 'INPATIENT_READ', 'INPATIENT_UPDATE',
    'INPATIENT_DELETE',
    'LABORATORY_CREATE', 'LABORATORY_READ', 'LABORATORY_UPDATE',
    'LABORATORY_DELETE',
    'RADIOLOGY_CREATE', 'RADIOLOGY_READ', 'RADIOLOGY_UPDATE',
    'RADIOLOGY_DELETE',
    'PHARMACY_CREATE', 'PHARMACY_READ', 'PHARMACY_UPDATE', 'PHARMACY_DELETE',
    'PRE_TRIAGE_CREATE', 'PRE_TRIAGE_READ', 'PRE_TRIAGE_UPDATE',
    'PRE_TRIAGE_DELETE',
    'QUEUE_CREATE', 'QUEUE_READ', 'QUEUE_UPDATE', 'QUEUE_DELETE',
    'DASHBOARD_READ',
  ],
  'NURSE': [
    'PATIENT_READ', 'APPOINTMENT_READ', 'CONSULTATION_READ',
    'INPATIENT_CREATE', 'INPATIENT_READ', 'INPATIENT_UPDATE',
    'PRE_TRIAGE_CREATE', 'PRE_TRIAGE_READ', 'PRE_TRIAGE_UPDATE',
    'QUEUE_CREATE', 'QUEUE_READ', 'QUEUE_UPDATE',
    'DASHBOARD_READ',
  ],
  'RECEPTIONIST': [
    'PATIENT_CREATE', 'PATIENT_READ', 'PATIENT_UPDATE',
    'APPOINTMENT_CREATE', 'APPOINTMENT_READ', 'APPOINTMENT_UPDATE',
    'APPOINTMENT_DELETE',
    'QUEUE_CREATE', 'QUEUE_READ', 'QUEUE_UPDATE', 'QUEUE_DELETE',
    'BILLING_READ', 'DASHBOARD_READ',
  ],
  'PHARMACIST': [
    'PHARMACY_CREATE', 'PHARMACY_READ', 'PHARMACY_UPDATE', 'PHARMACY_DELETE',
    'PATIENT_READ', 'DASHBOARD_READ',
  ],
  'LAB_TECHNICIAN': [
    'LABORATORY_CREATE', 'LABORATORY_READ', 'LABORATORY_UPDATE',
    'LABORATORY_DELETE', 'PATIENT_READ', 'DASHBOARD_READ',
  ],
  'RADIOLOGIST': [
    'RADIOLOGY_CREATE', 'RADIOLOGY_READ', 'RADIOLOGY_UPDATE',
    'RADIOLOGY_DELETE', 'PATIENT_READ', 'DASHBOARD_READ',
  ],
  'BILLING_STAFF': [
    'BILLING_CREATE', 'BILLING_READ', 'BILLING_UPDATE', 'BILLING_DELETE',
    'PATIENT_READ', 'DASHBOARD_READ',
  ],
};

/// A stand-in for the real destination table.
///
/// Deliberately not the app's own list: this test is about the *resolver*, and
/// reading the real table would make it fail every time somebody reorders a
/// tab. The ranks and modules mirror it.
final _destinations = <ShellDestination>[
  _dest('/home', 'Today', ShellGroup.overview, module: null, rank: 0),
  _dest('/queue', 'Queue', ShellGroup.clinical,
      module: Modules.queue, rank: 1),
  _dest('/appointments', 'Clinic', ShellGroup.clinical,
      module: Modules.appointments, rank: 2),
  _dest('/inpatient', 'Wards', ShellGroup.clinical,
      module: Modules.inpatient, rank: 3),
  _dest('/pre-triage', 'Triage', ShellGroup.clinical,
      module: Modules.preTriage, rank: 4),
  _dest('/laboratory', 'Lab', ShellGroup.diagnostics,
      module: Modules.laboratory, rank: 5),
  _dest('/radiology', 'Imaging', ShellGroup.diagnostics,
      module: Modules.radiology, rank: 6),
  _dest('/pharmacy', 'Pharmacy', ShellGroup.operations,
      module: Modules.pharmacy, rank: 7),
  _dest('/billing', 'Billing', ShellGroup.operations,
      module: Modules.billing, rank: 8),
  _dest('/patients', 'Patients', ShellGroup.records,
      module: Modules.patients, rank: 9),
  _dest('/consultations', 'Consults', ShellGroup.clinical,
      module: Modules.consultations, rank: 10),
  _dest('/staff', 'Staff', ShellGroup.administration,
      module: Modules.users, rank: 11),
  _dest('/settings', 'Settings', ShellGroup.administration,
      module: Modules.settings, rank: 12),
];

ShellDestination _dest(
  String route,
  String label,
  ShellGroup group, {
  required String? module,
  required int rank,
}) =>
    ShellDestination(
      route: route,
      label: label,
      group: group,
      module: module,
      rank: rank,
      icon: Icons.circle_outlined,
      activeIcon: Icons.circle,
      body: () => const SizedBox.shrink(),
    );

ShellLayout _layoutFor(
  String role, {
  Map<String, dynamic> modulesEnabled = const {},
}) =>
    ShellLayout.resolve(
      access: AccessMap.fromPermissions(_seededPermissions[role]!),
      destinations: _destinations,
      modulesEnabled: modulesEnabled,
    );

List<String> _labels(List<ShellDestination> destinations) =>
    destinations.map((d) => d.label).toList();

void main() {
  group('the bar always starts with Today and leaves room for More', () {
    for (final role in _seededPermissions.keys) {
      test(role, () {
        final layout = _layoutFor(role);

        expect(layout.tabs.first.label, 'Today');
        // More takes the last slot whenever anything is left over, so the
        // bar itself never holds more than three real destinations.
        expect(layout.tabs.length, lessThanOrEqualTo(ShellLayout.barSlots));
        if (layout.hasMore) {
          expect(layout.tabs.length, ShellLayout.barSlots - 1);
        }
      });
    }
  });

  group('the tab set fits the role', () {
    test('a nurse gets the board, the wards and triage', () {
      // Everything she can write to, in the order she works in it.
      expect(_labels(_layoutFor('NURSE').tabs),
          ['Today', 'Queue', 'Wards', 'Triage']);
    });

    test('a nurse does not get billing or pharmacy anywhere', () {
      final layout = _layoutFor('NURSE');
      final everything = _labels([...layout.tabs, ...layout.more]);
      expect(everything, isNot(contains('Billing')));
      expect(everything, isNot(contains('Pharmacy')));
      expect(everything, isNot(contains('Lab')));
    });

    test('a nurse still reaches what she can only read, through More', () {
      // Read-only access is not "no access": she consults the clinic list and
      // the patient register, she just does not work in them.
      expect(_labels(_layoutFor('NURSE').more),
          containsAll(<String>['Clinic', 'Patients', 'Consults']));
    });

    test('a receptionist gets the front desk, not the ward', () {
      final layout = _layoutFor('RECEPTIONIST');
      // Four destinations plus Today is exactly the bar, so there is nothing
      // left for More to hold and Billing stays visible. Hiding a destination
      // behind More when the bar has room for it would be hiding it for
      // nothing.
      expect(_labels(layout.tabs),
          ['Today', 'Queue', 'Clinic', 'Patients', 'Billing']);
      expect(layout.hasMore, isFalse);
      expect(_labels(layout.tabs), isNot(contains('Wards')));
    });

    test('a pharmacist gets pharmacy first, patients second', () {
      final layout = _layoutFor('PHARMACIST');
      expect(_labels(layout.tabs), ['Today', 'Pharmacy', 'Patients']);
      // Two real destinations plus Today is three, which fits — so there is
      // nothing for More to hold and no More tab.
      expect(layout.hasMore, isFalse);
    });

    test('a lab technician gets lab, a radiologist gets imaging', () {
      expect(_labels(_layoutFor('LAB_TECHNICIAN').tabs),
          ['Today', 'Lab', 'Patients']);
      expect(_labels(_layoutFor('RADIOLOGIST').tabs),
          ['Today', 'Imaging', 'Patients']);
    });

    test('an admin gets staff and settings, not a ward board', () {
      final tabs = _labels(_layoutFor('ADMIN').tabs);
      expect(tabs.first, 'Today');
      expect(tabs, containsAll(<String>['Staff', 'Settings']));
      expect(tabs, isNot(contains('Queue')));
    });

    test('a doctor keeps the four clinical boards', () {
      expect(_labels(_layoutFor('DOCTOR').tabs),
          ['Today', 'Queue', 'Clinic', 'Wards']);
    });
  });

  group('ordering', () {
    test('a screen the account works in outranks one it only reads', () {
      // A receptionist can write patients (rank 9) and only read billing
      // (rank 8). Rank would put billing first; what they actually do with the
      // screen puts patients first.
      final tabs = _labels(_layoutFor('RECEPTIONIST').tabs);
      expect(tabs.indexOf('Patients'), lessThan(tabs.indexOf('Billing')));
    });

    test('a doctor loses read-only screens to More before writable ones', () {
      // A doctor writes to nine modules and the bar holds four, so the cut is
      // made among equals by rank — but nothing they can only read should ever
      // outrank something they work in.
      final layout = _layoutFor('DOCTOR');
      final access = AccessMap.fromPermissions(_seededPermissions['DOCTOR']!);
      for (final tab in layout.tabs.where((d) => d.module != null)) {
        expect(tab.isWritableBy(access), isTrue,
            reason: '${tab.label} is on the bar but is read-only');
      }
    });

    test('rank breaks the tie among equals', () {
      // A nurse writes to queue, pre-triage and inpatient alike, so only rank
      // separates them: queue 1, wards 3, triage 4.
      expect(_labels(_layoutFor('NURSE').tabs).sublist(1),
          ['Queue', 'Wards', 'Triage']);
    });
  });

  group('site module toggles', () {
    test('an explicitly disabled module disappears entirely', () {
      final layout = _layoutFor('DOCTOR', modulesEnabled: {'laboratory': false});
      final everything = _labels([...layout.tabs, ...layout.more]);
      expect(everything, isNot(contains('Lab')));
    });

    test('an absent key means on, because the stored default says false', () {
      // The backend's own `modulesEnabled` default carries `inpatient: false`,
      // and plenty of sites have never opened the settings screen. Treating a
      // missing key as off would hide the ward board from all of them.
      final layout = _layoutFor('DOCTOR', modulesEnabled: {'pharmacy': true});
      final everything = _labels([...layout.tabs, ...layout.more]);
      expect(everything, contains('Wards'));
    });
  });

  group('degenerate accounts', () {
    test('an empty map leaves only what needs no permission', () {
      final layout = ShellLayout.resolve(
        access: AccessMap.empty,
        destinations: _destinations,
      );
      expect(_labels(layout.tabs), ['Today']);
      expect(layout.hasMore, isFalse);
    });

    test('a super admin sees everything, and most of it through More', () {
      final layout = ShellLayout.resolve(
        access: const AccessMap(isSuperAdmin: true),
        destinations: _destinations,
      );
      expect(layout.tabs.length, ShellLayout.barSlots - 1);
      expect(
        layout.tabs.length + layout.more.length,
        _destinations.length,
        reason: 'every destination must be reachable, not just the ones that fit',
      );
    });

    test('nothing is ever dropped: tabs plus More is everything allowed', () {
      for (final role in _seededPermissions.keys) {
        final layout = _layoutFor(role);
        final access = AccessMap.fromPermissions(_seededPermissions[role]!);
        final allowed =
            _destinations.where((d) => d.isVisibleTo(access)).length;
        expect(
          layout.tabs.length + layout.more.length,
          allowed,
          reason: '$role can reach $allowed destinations',
        );
      }
    });
  });
}
