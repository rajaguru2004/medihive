import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medihive/app/core/keys/settings_locale_keys.dart';
import 'package:medihive/app/core/keys/settings_modules_keys.dart';
import 'package:medihive/app/core/keys/settings_profile_keys.dart';
import 'package:medihive/app/data/services/settings_service.dart';
import 'package:medihive/app/modules/settings/settings_routes.dart';
import 'package:medihive/app/theme/theme_service.dart';

import '../../fixtures/modules/settings_fixtures.dart';
import '../../fixtures/world_roles.dart';
import '../../robots/no_access_robot.dart';
import '../../robots/settings_robot.dart';
import '../../support/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerSettingsFlows();
}

/// Configuring the hospital from a phone.
///
/// The site comes from `installSettingsFixtures`, which merges a `PUT
/// /settings/organization` for real — so the claim these flows can actually
/// make is the one that matters: a screen that saves its own four keys leaves
/// the fourteen it does not own exactly where they were.
void registerSettingsFlows() {
  group('the hospital profile', () {
    testWidgets('a partial save carries only this screen, and the server keeps '
        'the rest', (tester) async {
      final harness = await _boot(tester);
      final settings = SettingsRobot(harness);

      await settings.openHub();
      settings.seeHubRow('profile');
      await settings.openFromHub('profile');
      await settings.assertOnProfile();

      // Identity that is shown and not offered as a field.
      settings.seeSlugIsReadOnly('st-aidans-general');

      // Nothing typed yet, so there is nothing to send.
      settings.seeSaveDisabled(SettingsProfileKeys.save);

      await settings.typeName('St Aidan’s General Hospital');
      settings.seeSaveEnabled(SettingsProfileKeys.save);
      await settings.saveProfile();

      final put = harness.api.requireCall('PUT', '/api/settings/organization');
      final body = put.jsonBody;

      expect(body['name'], 'St Aidan’s General Hospital');

      // The heart of it. This screen owns branding and contact; it must not
      // send `settings.clinical` or `settings.locale` at all, because the
      // backend merges what it is sent and preserves what it is not. A form
      // that helpfully posted everything it could see would stamp the wait
      // threshold a matron set on the web an hour earlier.
      final sent = body['settings'] as Map<String, dynamic>?;
      expect(
        sent?.containsKey('clinical') ?? false,
        isFalse,
        reason: 'the profile screen does not own the clinical settings',
      );
      expect(
        sent?.containsKey('locale') ?? false,
        isFalse,
        reason: 'the profile screen does not own the locale settings',
      );
      expect(
        sent?.containsKey('scheduling') ?? false,
        isFalse,
        reason: 'the profile screen does not own the clinic day',
      );

      // And the proof from the other side: the merged record the server sent
      // back still carries every key this screen never mentioned.
      expect(SettingsService.to.settings.waitBreachMinutes, 30);
      expect(SettingsService.to.settings.workingHoursStart, '08:00');
      expect(SettingsService.to.settings.triageScale, 'p1-p5');
      expect(SettingsService.to.settings.siteName, 'St Aidan’s General Hospital');

      await settings.letToastsExpire();
    });

    testWidgets('a brand colour re-themes the app exactly once', (tester) async {
      final harness = await _boot(tester);
      final settings = SettingsRobot(harness);

      await settings.openHub();
      await settings.openFromHub('profile');
      await settings.assertOnProfile();

      final before = ThemeService.to.lightTheme;

      // Plum's primary — one of the swatches the screen offers, and a colour
      // this site does not already have.
      await settings.pickPrimaryColour('#7A2F62');
      settings.seeSaveEnabled(SettingsProfileKeys.save);

      // Nothing has re-themed yet: the change is pending, not adopted. A screen
      // that themed on selection would leave the app wearing a colour the
      // database never got if somebody backed out.
      expect(identical(ThemeService.to.lightTheme, before), isTrue);

      await settings.saveProfile();

      // Exactly one PUT, and the colours go out on both the branding keys and
      // the appearance group — the branding pair is what the console and the
      // letterhead read, the appearance copy is the one `SiteSettings` folds
      // into the theme signature.
      final put = harness.api.requireCall('PUT', '/api/settings/organization');
      expect(put.jsonBody['primaryColor'], '#7A2F62');

      final appearance = (put.jsonBody['settings']
          as Map<String, dynamic>)['appearance'] as Map<String, dynamic>;
      final custom = appearance['customColors'] as Map<String, dynamic>;
      expect(custom['primary'], '#7A2F62');

      // `themePreset` is the Appearance screen's. A partial save that carried
      // it would stamp whatever somebody chose there.
      expect(
        appearance.containsKey('themePreset'),
        isFalse,
        reason: 'the profile screen does not own the theme preset',
      );

      // One rebuild, through `SettingsService.adopt`, and the app is wearing
      // the answer the server gave rather than the draft it sent.
      expect(identical(ThemeService.to.lightTheme, before), isFalse);
      expect(SettingsService.to.settings.themeCustomColors.isNotEmpty, isTrue);

      await settings.letToastsExpire();
    });

    testWidgets('a logo is posted as multipart and recorded on the save',
        (tester) async {
      final harness = await _boot(tester);
      final settings = SettingsRobot(harness);

      await settings.openHub();
      await settings.openFromHub('profile');
      await settings.assertOnProfile();

      settings.seeNoUnsavedMarkNotice();
      await settings.uploadLogo();

      // The part name is what the route's `FileInterceptor('file')` reads.
      // Sent as anything else it arrives as no file at all, and the handler
      // answers "No file uploaded" over a request that otherwise looks fine.
      final upload = harness.api.requireCall(
        'POST',
        '/api/settings/organization/logo',
      );
      expect(upload.formFiles.containsKey('file'), isTrue);
      expect(upload.formFields['type'], 'logo');

      // Uploaded is not saved. The image is on screen and not on the record,
      // and leaving now would lose it — so the screen says so.
      settings.seeMarkNotSavedYet();
      harness.api.requireNoCall('PUT', '/api/settings/organization');

      await settings.saveProfile();

      final put = harness.api.requireCall('PUT', '/api/settings/organization');
      expect('${put.jsonBody['logoUrl']}'.contains('logo-'), isTrue);

      await settings.letToastsExpire();
    });

    testWidgets('a bad email is refused before it reaches the server',
        (tester) async {
      final harness = await _boot(tester);
      final settings = SettingsRobot(harness);

      await settings.openHub();
      await settings.openFromHub('profile');
      await settings.assertOnProfile();

      await settings.typeEmail('not-an-address');
      await settings.saveProfile();

      settings.seeFieldErrorSummary(count: 1);
      harness.api.requireNoCall('PUT', '/api/settings/organization');
    });
  });

  group('locale and money', () {
    testWidgets('the examples move with the pending value, before any save',
        (tester) async {
      final harness = await _boot(tester);
      final settings = SettingsRobot(harness);

      await settings.openHub();
      settings.seeHubRow('locale');
      await settings.openFromHub('locale');
      await settings.assertOnLocale();

      // The site as it stands: rupees, grouped in threes, two decimal places.
      expect(await settings.moneyExample(), '₹1,234,567.50');
      expect(await settings.dateExample(), '14/09/2026');
      expect(await settings.timeExample(), '16:40');

      // A site that writes 1.234.567,50. Nothing is saved — the point of the
      // example is that somebody sees what a separator does before committing
      // to it.
      await settings.chooseLocaleOption('decimal', 'comma');
      await settings.chooseLocaleOption('thousand', 'dot');
      expect(await settings.moneyExample(), '₹1.234.567,50');

      await settings.chooseLocaleOption('precision', '0');
      expect(await settings.moneyExample(), '₹1.234.568');

      await settings.chooseLocaleOption('position', 'after');
      expect(await settings.moneyExample(), '1.234.568₹');

      // The clock and the calendar, the same way.
      await settings.toggle24Hour();
      expect(await settings.timeExample(), '4:40 PM');

      await settings.chooseDateFormat('yyyy-MM-dd');
      expect(await settings.dateExample(), '2026-09-14');

      harness.api.requireNoCall('PUT', '/api/settings/organization');
    });

    testWidgets('the save carries locale and scheduling and leaves the theme '
        'alone', (tester) async {
      final harness = await _boot(tester);
      final settings = SettingsRobot(harness);

      await settings.openHub();
      await settings.openFromHub('locale');
      await settings.assertOnLocale();

      settings.seeSaveDisabled(SettingsLocaleKeys.save);
      await settings.chooseCurrency('EUR');

      // Picking a currency moves the symbol with it: a site that switches to
      // euros and keeps ₹ prices every invoice in the wrong currency while
      // looking configured.
      expect((await settings.moneyExample()).startsWith('€'), isTrue);

      await settings.saveLocale();

      final put = harness.api.requireCall('PUT', '/api/settings/organization');
      final sent = put.jsonBody['settings'] as Map<String, dynamic>;
      final locale = sent['locale'] as Map<String, dynamic>;

      expect(locale['currency'], 'EUR');
      expect(locale['currencySymbol'], '€');
      // The ICU spelling the DTO's `@IsIn(DATE_FORMATS)` accepts, not the
      // moment tokens the console stored. Without that translation a site
      // provisioned by the console saves a 400 here.
      expect(locale['dateFormat'], 'dd/MM/yyyy');

      expect(
        sent.containsKey('appearance'),
        isFalse,
        reason: 'the locale screen does not own the theme',
      );
      expect(
        sent.containsKey('clinical'),
        isFalse,
        reason: 'the locale screen does not own the clinical settings',
      );

      // The merged record still has everything this screen never mentioned.
      expect(SettingsService.to.settings.waitBreachMinutes, 30);
      expect(SettingsService.to.settings.themeFont, 'montserrat');
      expect(SettingsService.to.settings.money.symbol, '€');

      await settings.letToastsExpire();
    });

    testWidgets('an opening time that is not a clock never leaves the phone',
        (tester) async {
      final harness = await _boot(tester);
      final settings = SettingsRobot(harness);

      await settings.openHub();
      await settings.openFromHub('locale');
      await settings.assertOnLocale();

      await settings.typeOpeningTime('25:99');
      await settings.saveLocale();

      harness.api.requireNoCall('PUT', '/api/settings/organization');
    });
  });

  group('core modules', () {
    testWidgets('turning one off names the tab and says when it goes',
        (tester) async {
      final harness = await _boot(tester);
      final settings = SettingsRobot(harness);

      await settings.openHub();
      settings.seeHubRow('modules');
      await settings.openFromHub('modules');
      await settings.assertOnModules();

      // Said on the screen, not only on the confirm: a toggle whose effect
      // nobody can see is a toggle people flip a second time to check.
      settings.seeRestartNotice();

      expect(settings.moduleIsOn('laboratory'), isTrue);
      settings.seeSaveDisabled(SettingsModulesKeys.save);

      await settings.toggleModule('laboratory');
      expect(settings.moduleIsOn('laboratory'), isFalse);
      settings.seeSaveEnabled(SettingsModulesKeys.save);

      await settings.saveModulesConfirming(namingTab: 'Lab');

      // The dedicated route, with the id its DTO requires.
      final put = harness.api.requireCall('PUT', '/api/settings/modules');
      expect(put.jsonBody['organizationId'], WorldRole.organizationId);

      final map = put.jsonBody['modulesEnabled'] as Map<String, dynamic>;
      expect(map['laboratory'], isFalse);

      // The route **replaces** the column rather than merging it, so every key
      // the screen did not show still has to be in the body. Sending only the
      // six switches would delete the rest on the first save, and nobody would
      // notice for a month.
      expect(map['pharmacy'], isTrue);
      expect(map['radiology'], isTrue);
      expect(map['inpatient'], isTrue);
      expect(map['inventory'], isTrue);
      expect(map['accounting'], isTrue);

      // Adopted, so the next bootstrap builds a shell without the tab.
      expect(SettingsService.to.modulesEnabled['laboratory'], isFalse);

      await settings.letToastsExpire();
    });

    testWidgets('switching one back on asks nothing', (tester) async {
      final harness = await _boot(tester);
      final settings = SettingsRobot(harness);

      await settings.openHub();
      await settings.openFromHub('modules');
      await settings.assertOnModules();

      // Off then on again is a net change of nothing, so the save bar goes
      // back to refusing — and no confirm is raised for a change that takes
      // nothing away.
      await settings.toggleModule('pharmacy');
      settings.seeSaveEnabled(SettingsModulesKeys.save);
      await settings.toggleModule('pharmacy');
      settings.seeSaveDisabled(SettingsModulesKeys.save);

      harness.api.requireNoCall('PUT', '/api/settings/modules');
    });
  });

  group('departments', () {
    testWidgets('the list, and adding one', (tester) async {
      final harness = await _boot(tester);
      final settings = SettingsRobot(harness);

      await settings.openHub();
      settings.seeHubRow('departments');
      await settings.openFromHub('departments');
      await settings.assertOnDepartments();

      expect(settings.departmentCount, 4);
      await settings.seeDepartment('dept-1');

      await settings.addDepartment();
      await settings.assertOnDepartmentForm();

      await settings.typeDepartmentName('Physiotherapy');
      await settings.typeDepartmentCode('physio');
      await settings.chooseHead('Dr Samuel Achterberg');
      await settings.saveDepartment();

      final post = harness.api.requireCall(
        'POST',
        '/api/settings/departments',
      );
      expect(post.jsonBody['name'], 'Physiotherapy');
      // Upper-cased as typed: a code is an identifier, and `physio` beside
      // `PHYSIO` is two departments to anything that groups by them.
      expect(post.jsonBody['code'], 'PHYSIO');
      expect(post.jsonBody['headId'], 'd-3');
      // Required on create, and the one key the update must never carry.
      expect(post.jsonBody['organizationId'], WorldRole.organizationId);

      await settings.assertOnDepartments();
      // The list reloaded itself off the `DataBus` announcement the write
      // made — the form never reached into the list's controller to poke it.
      await settings.seeDepartment('dept-5');

      await settings.letToastsExpire();
    });

    testWidgets('editing one sends a PUT with no organizationId on it',
        (tester) async {
      final harness = await _boot(tester);
      final settings = SettingsRobot(harness);

      await settings.openHub();
      await settings.openFromHub('departments');
      await settings.assertOnDepartments();

      await settings.openDepartment('dept-3');
      await settings.assertOnDepartmentForm();

      await settings.typeDepartmentName('Pathology');
      await settings.saveDepartment();

      final put = harness.api.requireCall(
        'PUT',
        '/api/settings/departments/:id',
      );
      expect(put.jsonBody['name'], 'Pathology');
      // `UpdateDepartmentDto` does not declare it and `forbidNonWhitelisted`
      // is on globally, so sending it is a 400 on a route that exists. The
      // fixture refuses it for the same reason the server does.
      expect(
        put.jsonBody.containsKey('organizationId'),
        isFalse,
        reason: 'organizationId is create-only on this resource',
      );

      await settings.letToastsExpire();
    });

    testWidgets('removing one says what becomes of the staff in it',
        (tester) async {
      final harness = await _boot(tester);
      final settings = SettingsRobot(harness);

      await settings.openHub();
      await settings.openFromHub('departments');
      await settings.assertOnDepartments();

      await settings.openDepartment('dept-1');
      await settings.assertOnDepartmentForm();

      // Backing out changes nothing at all.
      await settings.cancelDepartmentDelete();
      harness.api.requireNoCall('DELETE', '/api/settings/departments/:id');

      // The confirm names what happens to the nine people in Emergency: the
      // server unassigns them and leaves every account alone, and this dialog
      // is the only place anybody will read that.
      await settings.deleteDepartmentConfirming();

      harness.api.requireCall('DELETE', '/api/settings/departments/:id');

      await settings.assertOnDepartments();
      // The first row, so its absence cannot be a scroll position.
      settings.seeNoDepartment('dept-1');
      expect(settings.departmentCount, 3);

      await settings.letToastsExpire();
    });

  });

  group('who may change any of this', () {
    testWidgets('every one of these routes is guarded, and refuses by name',
        (tester) async {
      // A nurse holds no settings grant at all — see `world_roles.dart` — so
      // `AuthMiddleware` turns each of these into the locked panel. Asserted
      // one route at a time rather than once on the hub: each page carries its
      // own middleware, and a screen registered without one would be reachable
      // while the hub still refused.
      final harness = await _boot(tester, role: WorldRole.nurse);
      final settings = SettingsRobot(harness);
      final locked = NoAccessRobot(harness);

      const gated = <String, String>{
        SettingsRoutes.profile: 'Hospital profile',
        SettingsRoutes.locale: 'Locale and money',
        SettingsRoutes.modules: 'Core modules',
        SettingsRoutes.departments: 'Departments',
        SettingsRoutes.departmentForm: 'Departments',
      };

      for (final entry in gated.entries) {
        await settings.openByRoute(entry.key);
        await locked.assertVisible();
        locked.seeModuleName(entry.value);
        // A permission is changed by a person, not by trying again.
        locked.seeNoRetry();
        await locked.back();
      }

      // A refused screen never wrote anything. Asserted on the writes rather
      // than on every request: the shell reads the organisation at boot for
      // its own reasons, so "no GET at all" would be a claim about the
      // dashboard rather than about the guard.
      harness.api.requireNoCall('PUT', '/api/settings/organization');
      harness.api.requireNoCall('PUT', '/api/settings/modules');
      harness.api.requireNoCall('POST', '/api/settings/departments');
      harness.api.requireNoCall('DELETE', '/api/settings/departments/:id');
      locked.seeNoToast();
    });
  });
}

/// Boots with the settings world installed over whatever `World.install`
/// registered.
///
/// Passed as an override rather than relied on from `world.dart`: later
/// registrations win, so this is correct both before the module's fixtures are
/// spliced into the world and after. It also gives each flow its **own** record
/// — the organisation here is written to, and one flow's save must not be
/// visible to the next flow in this file.
Future<AppHarness> _boot(
  WidgetTester tester, {
  WorldRole role = WorldRole.superAdmin,
}) =>
    AppHarness.bootSignedIn(
      tester,
      role: role,
      overrides: installSettingsFixtures,
    );
