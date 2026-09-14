import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/modules/role_editor/controllers/role_editor_controller.dart';
import 'package:medihive/app/theme/theme.dart';

import '../../fakes/fake_api.dart';
import '../../fixtures/modules/staff_fixtures.dart';
import '../../fixtures/world_roles.dart';
import '../../robots/staff_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerStaffFlows();
}

/// Users, staff and the role editor.
///
/// The department comes from `installStaffFixtures`, and it validates the way
/// the server validates: every write is checked against the DTO it was posted
/// to, and an unknown or missing key is a 400. That is what makes these flows
/// worth running — the two staff routes take **different bodies for the same
/// row**, both are live, and the failure is invisible until an administrator
/// on a ward cannot create an account.
void registerStaffFlows() {
  group('the staff directory', () {
    testWidgets('an account nobody can sign in with says so in a word',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        overrides: installStaffFixtures,
      );
      final staff = StaffRobot(harness);

      await staff.open();
      await staff.assertOnDirectory();

      // Presence rather than a count: a `SliverList` builds what is on screen
      // and nothing else, so a total is an assertion about the viewport.
      staff.seePerson('d-1');
      staff.seePerson('u-4');
      staff.seePerson('u-9');

      // The **word**, not the tint. A colour alone is unread by a colour-blind
      // reader, by a printed rota, and by anybody a metre from the screen.
      expect(staff.statusWordOf('u-9'), 'Inactive');
      expect(
        staff.statusWordOf('d-1'),
        isNull,
        reason: 'an account that works carries no pill at all',
      );

      // And the tint is neutral. Whether an account is switched on is an
      // administrative category, not a clinical state: a clinician scans a
      // board for red, and every red that is not a deteriorating patient costs
      // that scan its meaning.
      final tint = staff.statusColourOf('u-9');
      expect(tint, AppColors.acuityRoutine);
      expect(tint, isNot(AppColors.acuityCritical));
      expect(tint, isNot(AppColors.error));
    });

    testWidgets('searching narrows in memory, because the route takes no '
        'search parameter', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        overrides: installStaffFixtures,
      );
      final staff = StaffRobot(harness);

      await staff.open();
      await staff.assertOnDirectory();

      await staff.search('adeyinka');
      expect(staff.personIdsInOrder(), ['u-7']);

      // The half a screenshot cannot check. `GET /api/users` binds its query to
      // `PaginationDto` — `page`, `limit`, `orderBy`, `orderDir` and nothing
      // else — and the global `ValidationPipe` runs `forbidNonWhitelisted`, so
      // one `?search=` is a 400 for the whole request and an empty directory
      // with no explanation on it.
      const allowed = {'page', 'limit', 'orderBy', 'orderDir'};
      for (final call in harness.api.callsTo('GET', '/api/users')) {
        expect(
          call.query.keys.where((key) => !allowed.contains(key)),
          isEmpty,
          reason: 'the directory sent a parameter this route rejects outright',
        );
      }

      await staff.search('');
      staff.seePerson('d-1');
      staff.seePerson('u-7');
    });

    testWidgets('both routes refused is a locked panel, not a retry',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        // A nurse holds no users grant at all — see `world_roles.dart` — and
        // the server refuses both directory routes to match.
        role: WorldRole.nurse,
        overrides: (api) {
          installStaffFixtures(api);
          api.forbid('GET', '/api/users');
          api.forbid('GET', '/api/settings/users');
        },
      );
      final staff = StaffRobot(harness);

      await staff.open();
      await staff.assertVisible();

      // Nothing is broken, a retry cannot help, and "something went wrong"
      // over a staff directory sends somebody to IT for a role they were never
      // meant to have.
      staff.seeNoAccess();
      staff.seeNoErrorBanner();
      staff.seeNoAddAction();
      staff.seeNoToast();
    });
  });

  group('creating an account', () {
    testWidgets('the paged route gets two name fields and a split body',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        overrides: installStaffFixtures,
      );
      final staff = StaffRobot(harness);

      await staff.open();
      await staff.assertOnDirectory();
      staff.seeAddAction();

      await staff.tapAdd();
      await staff.assertOnForm();
      expect(
        staff.asksForOneName,
        isFalse,
        reason: '/api/users splits the name, so the form asks for two halves',
      );
      expect(staff.asksForEmail, isTrue, reason: 'create carries a credential');

      await staff.enterFirstName('Nadia');
      await staff.enterLastName('Haddad');
      await staff.enterEmail('n.haddad@example.org');
      await staff.enterPassword('Str0ng@Passw0rd');
      await staff.enterEmployeeId('EMP-0063');
      await staff.pickRole('Pharmacist');
      await staff.saveForm();

      // The wire body. The fixture rejects an unknown key the way the server
      // does, so a `fullName` here would already have failed — this says which
      // keys actually went, which is the thing a reviewer cannot see on screen.
      final posted = harness.api.requireCall('POST', '/api/users');
      expect(posted.jsonBody['firstName'], 'Nadia');
      expect(posted.jsonBody['lastName'], 'Haddad');
      expect(
        posted.jsonBody.containsKey('fullName'),
        isFalse,
        reason: 'fullName belongs to the settings route and is a 400 here',
      );

      // And the round trip: the directory is showing the person the server now
      // holds, not an optimistic row. The fixture numbers a new account from
      // the length of the list it appended to.
      await staff.assertOnDirectory();
      staff.seePerson('u-new-11');

      await staff.letToastsExpire();
    });

    testWidgets('a clinical role cannot be saved without a licence, and the '
        'form says why', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        overrides: installStaffFixtures,
      );
      final staff = StaffRobot(harness);

      await staff.open();
      await staff.tapAdd();
      await staff.assertOnForm();

      await staff.enterFirstName('Wei');
      await staff.enterLastName('Zhang');
      await staff.enterEmail('w.zhang@example.org');
      await staff.enterPassword('Str0ng@Passw0rd');
      await staff.pickRole('Doctor');
      await staff.saveForm();

      // Still on the form, and the message names the reason rather than the
      // rule: a required field with no reason on it reads as bureaucracy and
      // gets filled in with "N/A".
      await staff.assertOnForm();
      staff.seeFieldMessage('signs results under a registration number');
      staff.seeErrorSummary();
      harness.api.requireNoCall('POST', '/api/users');

      await staff.enterLicence('GMC-6620118');
      await staff.saveForm();

      final posted = harness.api.requireCall('POST', '/api/users');
      expect(posted.jsonBody['licenseNumber'], 'GMC-6620118');

      await staff.letToastsExpire();
    });

    testWidgets('an admin refused the users route falls back to the settings '
        'directory, and the form follows it', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.admin,
        overrides: (api) {
          installStaffFixtures(api);
          // The refusal this whole module exists for. `GET /api/users` carries
          // `@Roles(SUPER_ADMIN, ADMIN)` **and** `USER_READ` on the server, and
          // a site whose ADMIN role is shaped differently gets a 403 from a
          // route its access map says it may read.
          api.forbid('GET', '/api/users');
        },
      );
      final staff = StaffRobot(harness);

      await staff.open();
      await staff.assertOnDirectory();

      // The same people, through the other door.
      staff.seePerson('d-1');
      staff.seePerson('u-4');
      expect(harness.api.callCount('GET', '/api/settings/users'), isPositive);

      await staff.tapAdd();
      await staff.assertOnForm();
      expect(
        staff.asksForOneName,
        isTrue,
        reason: 'the settings route stores one fullName, never two halves',
      );

      await staff.enterFullName('Dr Ngozi Eze');
      await staff.enterEmail('n.eze@example.org');
      await staff.enterPassword('Str0ng@Passw0rd');
      // `role` is `@IsNotEmpty()` on `CreateSettingsUserDto` and optional on
      // the other route's DTO — the asymmetry the form has to follow.
      await staff.pickRole('Receptionist');
      await staff.saveForm();

      final posted = harness.api.requireCall('POST', '/api/settings/users');
      expect(posted.jsonBody['fullName'], 'Dr Ngozi Eze');
      expect(posted.jsonBody['role'], 'RECEPTIONIST');
      expect(
        posted.jsonBody.containsKey('firstName'),
        isFalse,
        reason: 'firstName is not on this DTO, so it is a 400 here',
      );
      harness.api.requireNoCall('POST', '/api/users');

      await staff.assertOnDirectory();
      staff.seePerson('u-new-11');

      await staff.letToastsExpire();
    });
  });

  group('one account', () {
    testWidgets('a role can be given and taken away, and the confirmation '
        'says what stops working', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        overrides: installStaffFixtures,
      );
      final staff = StaffRobot(harness);

      await staff.open();
      await staff.openPerson('u-5');
      await staff.assertOnRecord();

      staff.seeRoleHeld('role-receptionist');
      staff.seeRoleNotHeld('role-ward-nurse');

      await staff.giveRole('role-ward-nurse');
      staff.seeRoleHeld('role-ward-nurse');

      final assigned =
          harness.api.requireCall('POST', '/api/roles/:id/users');
      expect(assigned.jsonBody['userId'], 'u-5');
      await staff.letToastsExpire();

      await staff.takeRoleAway('role-ward-nurse');
      staff.seeRoleNotHeld('role-ward-nurse');
      expect(
        harness.api.callCount('DELETE', '/api/roles/:id/users/:userId'),
        1,
      );

      await staff.letToastsExpire();
    });

    testWidgets('removing an account confirms with the consequence in words',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        overrides: installStaffFixtures,
      );
      final staff = StaffRobot(harness);

      await staff.open();
      await staff.openPerson('u-5');
      await staff.assertOnRecord();

      await staff.tapDelete();
      // A confirm that says "are you sure?" is a question nobody can answer.
      // This one names what becomes true, including the half people fear most.
      staff.seeConfirmSaying('can no longer sign in');
      staff.seeConfirmSaying('Their name stays on every record they wrote');

      await staff.cancelConfirm();
      harness.api.requireNoCall('DELETE', '/api/users/:id');

      await staff.tapDelete();
      await staff.confirm();

      harness.api.requireCall('DELETE', '/api/users/:id');
      await staff.assertOnDirectory();
      staff.seeNoPerson('u-5');

      await staff.letToastsExpire();
    });

    testWidgets('the paged route offers no activation switch at all',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        overrides: installStaffFixtures,
      );
      final staff = StaffRobot(harness);

      await staff.open();
      await staff.openPerson('u-9');
      await staff.assertOnRecord();

      // `UpdateUserDto` is `PartialType(OmitType(CreateUserDto, …))` and
      // `CreateUserDto` has no `isActive`, so the key is a 400 on this route.
      // Absent, not disabled: a control that refuses to work is a question the
      // person holding the tablet cannot answer.
      expect(
        staff.offersActivation,
        isFalse,
        reason: 'only /api/settings/users can switch an account on and off',
      );
    });

    testWidgets('the settings route does offer it, and the write carries '
        'isActive', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        role: WorldRole.admin,
        overrides: (api) {
          installStaffFixtures(api);
          api.forbid('GET', '/api/users');
        },
      );
      final staff = StaffRobot(harness);

      await staff.open();
      await staff.openPerson('u-9');
      await staff.assertOnRecord();

      expect(staff.offersActivation, isTrue);
      await staff.toggleActivation();

      final saved = harness.api.requireCall('PUT', '/api/settings/users/:id');
      expect(saved.jsonBody['isActive'], isTrue);

      await staff.letToastsExpire();
    });
  });

  group('the role editor', () {
    testWidgets('a role the product ships opens read-only rather than letting '
        'a save fail', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        overrides: installStaffFixtures,
      );
      final staff = StaffRobot(harness);

      await staff.openRoles();
      await staff.openRoleEditor('role-doctor');
      await staff.assertOnEditor();

      // Said before anybody types. The server answers every edit of a system
      // role with `ROLE_SYSTEM_PROTECTED`, and a screen that let somebody fill
      // the form first would be spending their time to tell them so.
      staff.seeSystemNotice();
      staff.seeNoSaveAction();
      expect(staff.verbIsEditable('patients', 'read'), isFalse);

      // Read-only is not the same as empty: somebody shaping a custom role
      // needs to see what DOCTOR already has.
      expect(staff.verbIsOn('patients', 'read'), isTrue);
      expect(staff.verbIsOn('patients', 'delete'), isFalse);
    });

    testWidgets('a verb the catalogue has no permission for is absent',
        (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        overrides: installStaffFixtures,
      );
      final staff = StaffRobot(harness);

      await staff.openRoles();
      await staff.openRoleEditor('role-ward-nurse');
      await staff.assertOnEditor();

      staff.seeModuleCard('dashboard');
      expect(staff.hasVerbSwitch('dashboard', 'read'), isTrue);
      // There is no `DASHBOARD_DELETE` in the catalogue, and a switch that
      // cannot do anything is a switch somebody will try.
      expect(staff.hasVerbSwitch('dashboard', 'delete'), isFalse);
      expect(staff.hasVerbSwitch('dashboard', 'create'), isFalse);
    });

    testWidgets('taking a read away confirms with the number of people it '
        'happens to, and the PUT drops the row', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        overrides: installStaffFixtures,
      );
      final staff = StaffRobot(harness);

      await staff.openRoles();
      await staff.openRoleEditor('role-ward-nurse');
      await staff.assertOnEditor();

      staff.seeNoSystemNotice();
      expect(staff.verbIsEditable('patients', 'read'), isTrue);
      expect(staff.verbIsOn('patients', 'read'), isTrue);

      await staff.toggleVerb('patients', 'read');
      expect(staff.verbIsOn('patients', 'read'), isFalse);

      await staff.saveRole();

      // The consequence, in words, with the count of people it lands on.
      // Beatrice Achieng holds WARD_NURSE in this department.
      staff.seeConfirmSaying('One person holds this role');
      staff.seeConfirmSaying('Patients');
      staff.seeConfirmSaying('seeing it at all');

      await staff.cancelRevoke();
      harness.api.requireNoCall('PUT', '/api/roles/:id/permissions');

      await staff.saveRole();
      await staff.confirmRevoke();

      final saved =
          harness.api.requireCall('PUT', '/api/roles/:id/permissions');
      final rows = (saved.jsonBody['permissions'] as List)
          .cast<Map<String, dynamic>>();

      // **The row is dropped, not sent with `canRead: false`.**
      // `PermissionsGuard` authorises by *name* — it asks whether
      // `PATIENT_READ` appears at all — and the four booleans only feed the
      // access map. A row written with every flag false would still grant the
      // permission on the server, so the only real revoke is an absent row.
      expect(
        rows.any((row) => row['permissionId'] == 'perm-patients-read'),
        isFalse,
        reason: 'a revoked permission leaves the assignment entirely',
      );
      expect(
        rows.any((row) => row['permissionId'] == 'perm-queue-update'),
        isTrue,
        reason: 'the PUT replaces the whole set, so everything kept is resent',
      );
      // Every row carries all four verbs: `PermissionAssignmentDto` declares
      // them `@IsBoolean()` and required, and a row that drops one fails the
      // whole assignment and leaves the role as it was.
      for (final row in rows) {
        expect(row.keys.toSet(), {
          'permissionId',
          'canRead',
          'canUpdate',
          'canCreate',
          'canDelete',
        });
      }

      await staff.letToastsExpire();
    });

    testWidgets('members are derived when the server has no route for them, '
        'and an addition sticks', (tester) async {
      final harness = await AppHarness.bootSignedIn(
        tester,
        overrides: installStaffFixtures,
      );
      final staff = StaffRobot(harness);

      await staff.openRoles();
      await staff.openRoleEditor('role-ward-nurse');
      await staff.assertOnEditor();

      await staff.showEditorTab(RoleEditorTab.members);
      staff.seeMember('u-4');
      staff.seeNoMember('u-5');

      // `GET /api/roles/:id/users` is not mounted — `RolesController` has a
      // POST and a DELETE at that path and no GET — so the editor asks, takes
      // the 404, and falls back to the staff directory filtered by the role's
      // own name.
      expect(harness.api.callCount('GET', '/api/roles/:id/users'), isPositive);
      expect(harness.api.callCount('GET', '/api/users/staff'), isPositive);

      await staff.addMember('u-5');
      staff.seeMember('u-5');

      final assigned = harness.api.requireCall(
        'POST',
        '/api/roles/:id/users',
        where: (FakeRequest request) => request.jsonBody['userId'] == 'u-5',
      );
      expect(assigned.pathParams['id'], 'role-ward-nurse');

      await staff.letToastsExpire();

      await staff.removeMember('u-5');
      staff.seeNoMember('u-5');
      staff.seeMember('u-4');

      await staff.letToastsExpire();
    });
  });
}
