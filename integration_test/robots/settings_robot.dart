import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/keys/app_keys.dart';
import 'package:medihive/app/modules/settings/settings_routes.dart';
import 'package:medihive/app/routes/app_pages.dart';
import 'package:medihive/app/theme/theme.dart';

import '../support/pump.dart';
import 'robot.dart';

/// Settings: the hub and the five screens it leads to.
///
/// One robot rather than six, because every flow worth writing here crosses
/// them — a hub row opens a form, the form saves, and the claim is about what
/// the *server* was sent. Six robots would make that read as six objects
/// passing a key between them.
///
/// [installPages] is the one piece of scaffolding: `SettingsPages` is not
/// spliced into `AppPages.routes` yet, so a flow registers it on the live route
/// tree exactly as `GetMaterialApp` registers the app's own table. It becomes a
/// no-op the day the splice lands.
final class SettingsRobot extends Robot {
  SettingsRobot(super.harness);

  @override
  String? get route => Routes.SETTINGS;

  @override
  Key get anchor => SettingsKeys.screen;

  // ── Getting there ─────────────────────────────────────────────────────────

  /// Adds this module's pages to the route tree, once.
  ///
  /// Guarded on the tree's own contents rather than on a flag: the tree is a
  /// static that outlives `Get.reset()`, so a second registration in the same
  /// process would pile up duplicates of pages that are already there.
  void installPages() {
    final already = Get.routeTree.routes
        .any((page) => page.name == SettingsRoutes.profile);
    if (!already) Get.addPages(SettingsPages.pages);
  }

  /// Opens the hub by route.
  ///
  /// Never awaited: `Get.toNamed` completes when the route is *popped*, so
  /// awaiting it here would wait for the end of the test.
  Future<void> openHub() async {
    installPages();
    unawaited(Get.toNamed<void>(Routes.SETTINGS) ?? Future<void>.value());
    await tester.pumpUntilRouteSettled();
  }

  /// Asks for one of this module's routes directly, the way a deep link or a
  /// stale shortcut would.
  ///
  /// The only way to exercise a route guard: navigation itself never offers a
  /// destination this account cannot open, so a flow about the guard has to go
  /// round the navigation.
  Future<void> openByRoute(String route) async {
    installPages();
    unawaited(Get.toNamed<void>(route) ?? Future<void>.value());
    await tester.pumpUntilRouteSettled();
  }

  /// Taps the hub row with this id — `profile`, `locale`, `modules`,
  /// `departments`.
  ///
  /// Through the row's key rather than its words: the label is display copy
  /// that changes with the wording, the id is what the row actually opens.
  Future<void> openFromHub(String id) async {
    await tester.tapKey(SettingsKeys.row(id));
    await tester.pumpUntilRouteSettled();
  }

  /// The hub offers this row at all.
  void seeHubRow(String id) => expect(
        find.byKey(SettingsKeys.row(id)),
        findsOneWidget,
        reason: 'expected the settings hub to offer "$id"',
      );

  // ── Hospital profile ──────────────────────────────────────────────────────

  Future<void> assertOnProfile() async {
    await tester.pumpUntilFound(find.byKey(SettingsProfileKeys.screen));
    expect(Get.currentRoute, SettingsRoutes.profile);
  }

  Future<void> typeName(String value) =>
      tester.enterTextByKey(SettingsProfileKeys.name, value);

  Future<void> typeEmail(String value) =>
      tester.enterTextByKey(SettingsProfileKeys.email, value);

  /// The slug is shown and is not a field.
  ///
  /// Both halves asserted: present, because it is identity somebody needs to
  /// read, and not editable, because it is in links and in other systems'
  /// references. A screen that offered it as an input would be offering to
  /// break those.
  void seeSlugIsReadOnly(String slug) {
    final panel = find.byKey(SettingsProfileKeys.slug);
    expect(panel, findsOneWidget, reason: 'the slug should be on screen');
    expect(
      find.descendant(of: panel, matching: find.text(slug)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.byType(EditableText)),
      findsNothing,
      reason: 'the slug is shown, never typed into',
    );
  }

  /// Chooses a brand colour by the hex it stores.
  Future<void> pickPrimaryColour(String hex) async {
    await tester.tapKeyWithoutKeyboard(
      SettingsProfileKeys.primarySwatch(hex),
    );
    await tester.pump();
  }

  Future<void> pickSecondaryColour(String hex) async {
    await tester.tapKeyWithoutKeyboard(
      SettingsProfileKeys.secondarySwatch(hex),
    );
    await tester.pump();
  }

  /// Picks and uploads a logo through the injected [ImageSource].
  ///
  /// The stub answers with a real one-pixel PNG rather than with null, so the
  /// multipart post, the URL the server answers with and the save that records
  /// it are all exercised on a build that has no picker plugin in it.
  Future<void> uploadLogo() async {
    await tester.tapKeyWithoutKeyboard(SettingsProfileKeys.logoUpload);
    await settle();
  }

  Future<void> uploadWordmark() async {
    await tester.tapKeyWithoutKeyboard(SettingsProfileKeys.logoTextUpload);
    await settle();
  }

  /// The screen admits the mark is not on the record yet.
  void seeMarkNotSavedYet() => expect(
        find.byKey(SettingsProfileKeys.logoPending),
        findsOneWidget,
        reason: 'an uploaded mark that is not saved has to say so — an upload '
            'that visibly worked reads as done',
      );

  void seeNoUnsavedMarkNotice() =>
      expect(find.byKey(SettingsProfileKeys.logoPending), findsNothing);

  Future<void> saveProfile() async {
    await tester.tapKeyWithoutKeyboard(SettingsProfileKeys.save);
    await settle();
  }

  /// The save bar refuses, and says how many fields are in the way.
  void seeFieldErrorSummary({required int count}) {
    final summary = find.byKey(SettingsProfileKeys.errors);
    expect(summary, findsOneWidget);
    expect(
      find.descendant(
        of: summary,
        matching: find.textContaining(
          count == 1 ? 'One field' : '$count fields',
        ),
      ),
      findsOneWidget,
      reason: 'expected the summary above the save bar to count $count',
    );
  }

  // ── Locale and money ──────────────────────────────────────────────────────

  Future<void> assertOnLocale() async {
    await tester.pumpUntilFound(find.byKey(SettingsLocaleKeys.screen));
    expect(Get.currentRoute, SettingsRoutes.locale);
  }

  /// What the money preview currently reads.
  ///
  /// Off the render tree rather than out of the controller: a preview that only
  /// updates in a field nobody paints is the same bug wearing a passing test.
  String moneyExample() => _textOf(SettingsLocaleKeys.moneyExample);

  String dateExample() => _textOf(SettingsLocaleKeys.dateExample);

  String timeExample() => _textOf(SettingsLocaleKeys.timeExample);

  /// Taps a segment of one of the segmented controls, by the value it selects.
  Future<void> chooseLocaleOption(String control, String value) async {
    await tester.tapKeyWithoutKeyboard(
      SettingsLocaleKeys.option(control, value),
    );
    await tester.pump();
  }

  /// Opens the date-format picker and takes the row reading [label].
  Future<void> chooseDateFormat(String label) async {
    await tester.tapKeyWithoutKeyboard(SettingsLocaleKeys.dateFormat);
    await tester.pumpUntilRouteSettled();
    await pickFromSheet(label);
  }

  Future<void> chooseCurrency(String code) async {
    await tester.tapKeyWithoutKeyboard(SettingsLocaleKeys.currency);
    await tester.pumpUntilRouteSettled();
    await pickFromSheet(code);
  }

  Future<void> toggle24Hour() async {
    await tester.tapKeyWithoutKeyboard(SettingsLocaleKeys.clock24);
    await tester.pump();
  }

  Future<void> typeOpeningTime(String value) =>
      tester.enterTextByKey(SettingsLocaleKeys.workingHoursStart, value);

  Future<void> saveLocale() async {
    await tester.tapKeyWithoutKeyboard(SettingsLocaleKeys.save);
    await settle();
  }

  // ── Core modules ──────────────────────────────────────────────────────────

  Future<void> assertOnModules() async {
    await tester.pumpUntilFound(find.byKey(SettingsModulesKeys.screen));
    expect(Get.currentRoute, SettingsRoutes.modules);
  }

  /// The screen says the change is invisible until the app next starts.
  void seeRestartNotice() => expect(
        find.byKey(SettingsModulesKeys.restartNotice),
        findsOneWidget,
        reason: 'a toggle whose consequence is invisible until a restart has '
            'to say so on the screen',
      );

  /// `BentoSwitchRow` puts its `switchKey` on the `Switch` itself, not on the
  /// row around it, so this reads the control rather than searching under it.
  bool moduleIsOn(String key) =>
      tester.widget<Switch>(find.byKey(SettingsModulesKeys.module(key))).value;

  Future<void> toggleModule(String key) async {
    await tester.tapKeyWithoutKeyboard(SettingsModulesKeys.module(key));
    await tester.pump();
  }

  /// Presses Save and confirms, asserting the confirm names [tab] first.
  ///
  /// The naming is the assertion: a confirm that says "are you sure" about a
  /// change nobody can see for a day is a confirm people click through.
  Future<void> saveModulesConfirming({required String namingTab}) async {
    await tester.tapKeyWithoutKeyboard(SettingsModulesKeys.save);
    await tester.pumpUntilFound(find.byKey(SettingsModulesKeys.confirm));

    expect(
      find.descendant(
        of: find.byType(ConfirmDialog),
        matching: find.textContaining(namingTab),
      ),
      findsOneWidget,
      reason: 'the confirm should name the $namingTab tab that is about to go',
    );
    expect(
      find.descendant(
        of: find.byType(ConfirmDialog),
        matching: find.textContaining('starts the app'),
      ),
      findsOneWidget,
      reason: 'the confirm should say when the tab actually disappears',
    );

    await tester.tapKey(SettingsModulesKeys.confirm);
    await settle();
  }

  /// Presses Save with nothing being switched off, so no confirm is raised.
  Future<void> saveModules() async {
    await tester.tapKeyWithoutKeyboard(SettingsModulesKeys.save);
    await settle();
  }

  // ── Departments ───────────────────────────────────────────────────────────

  Future<void> assertOnDepartments() async {
    await tester.pumpUntilFound(find.byKey(SettingsDepartmentsKeys.screen));
    expect(Get.currentRoute, SettingsRoutes.departments);
  }

  /// Brings the row into the tree first: a sliver below the fold is not built
  /// at all, so a bare `findsNothing` on a long list would be an assertion
  /// about the scroll position rather than about the data.
  Future<void> seeDepartment(String id) async {
    await tester.scrollToKey(SettingsDepartmentsKeys.department(id));
    expect(
      find.byKey(SettingsDepartmentsKeys.department(id)),
      findsOneWidget,
    );
  }

  void seeNoDepartment(String id) => expect(
        find.byKey(SettingsDepartmentsKeys.department(id)),
        findsNothing,
      );

  int get departmentCount => find
      .byWidgetPredicate(
        (widget) =>
            widget is LookupRow &&
            (widget.key as ValueKey<String>?)
                    ?.value
                    .startsWith('settings_department_') ==
                true,
        description: 'a department row',
      )
      .evaluate()
      .length;

  void seeEmptyDepartments() =>
      expect(find.byKey(SettingsDepartmentsKeys.empty), findsOneWidget);

  void seeNoAddDepartment() => expect(
        find.byKey(SettingsDepartmentsKeys.add),
        findsNothing,
        reason: 'an account that may not write settings gets no add button — '
            'absent, not disabled',
      );

  Future<void> openDepartment(String id) async {
    await tester.tapKey(SettingsDepartmentsKeys.department(id));
    await tester.pumpUntilRouteSettled();
  }

  Future<void> addDepartment() async {
    await tester.tapKey(SettingsDepartmentsKeys.add);
    await tester.pumpUntilRouteSettled();
  }

  Future<void> assertOnDepartmentForm() async {
    await tester.pumpUntilFound(find.byKey(SettingsDepartmentsKeys.form));
    expect(Get.currentRoute, SettingsRoutes.departmentForm);
  }

  Future<void> typeDepartmentName(String value) =>
      tester.enterTextByKey(SettingsDepartmentsKeys.name, value);

  Future<void> typeDepartmentCode(String value) =>
      tester.enterTextByKey(SettingsDepartmentsKeys.code, value);

  /// Opens the head-of-department picker and takes the row reading [label].
  Future<void> chooseHead(String label) async {
    await tester.tapKeyWithoutKeyboard(SettingsDepartmentsKeys.head);
    await tester.pumpUntilRouteSettled();
    await pickFromSheet(label);
  }

  Future<void> saveDepartment() async {
    await tester.tapKeyWithoutKeyboard(SettingsDepartmentsKeys.save);
    await settle();
  }

  /// Presses Remove and confirms, asserting the confirm says what becomes of
  /// the staff assigned to it.
  ///
  /// The fear at this dialog is "does this delete my people". The honest answer
  /// is no — the server unassigns them and leaves every account alone — and
  /// this is the only place anybody will read it.
  Future<void> deleteDepartmentConfirming() async {
    await tester.tapKeyWithoutKeyboard(SettingsDepartmentsKeys.delete);
    await tester.pumpUntilFound(
      find.byKey(SettingsDepartmentsKeys.deleteConfirm),
    );

    expect(
      find.descendant(
        of: find.byType(ConfirmDialog),
        matching: find.textContaining('account'),
      ),
      findsWidgets,
      reason: 'the confirm has to say what happens to the staff in it',
    );

    await tester.tapKey(SettingsDepartmentsKeys.deleteConfirm);
    await settle();
  }

  /// Opens Remove and backs out of it, leaving the department alone.
  Future<void> cancelDepartmentDelete() async {
    await tester.tapKeyWithoutKeyboard(SettingsDepartmentsKeys.delete);
    await tester.pumpUntilFound(
      find.byKey(SettingsDepartmentsKeys.deleteCancel),
    );
    await tester.tapKey(SettingsDepartmentsKeys.deleteCancel);
    await tester.pumpUntilRouteSettled();
  }

  void seeNoDeleteAction() => expect(
        find.byKey(SettingsDepartmentsKeys.delete),
        findsNothing,
        reason: 'absent, not disabled, for an account that may not delete one',
      );

  // ── Shared ────────────────────────────────────────────────────────────────

  /// The one save button on whichever settings screen is open is refusing.
  void seeSaveDisabled(Key saveKey) {
    final bar = tester.widget<PrimaryBar>(find.byKey(saveKey));
    expect(
      bar.enabled,
      isFalse,
      reason: 'a form nobody has changed has nothing to save',
    );
  }

  void seeSaveEnabled(Key saveKey) {
    final bar = tester.widget<PrimaryBar>(find.byKey(saveKey));
    expect(bar.enabled, isTrue);
  }

  /// No save bar at all — the shape an account that may not write gets.
  void seeNoSaveBar(Key saveKey) => expect(
        find.byKey(saveKey),
        findsNothing,
        reason: 'controls are absent, not disabled, for an account without the '
            'grant',
      );

  String _textOf(Key key) => tester.widget<Text>(find.byKey(key)).data ?? '';
}
