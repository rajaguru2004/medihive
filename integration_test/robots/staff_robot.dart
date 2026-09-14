import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/core/keys/roles_keys.dart';
import 'package:medihive/app/core/keys/staff_keys.dart';
import 'package:medihive/app/modules/role_editor/controllers/role_editor_controller.dart';
import 'package:medihive/app/modules/users/bindings/users_binding.dart';
import 'package:medihive/app/modules/users/user_routes.dart';
import 'package:medihive/app/modules/users/views/users_view.dart';
import 'package:medihive/app/routes/app_pages.dart';
import 'package:medihive/app/theme/theme.dart';

import '../support/pump.dart';
import 'robot.dart';

/// The staff directory, one account, the staff form and the role editor.
///
/// One robot for four screens because they are one job — an account is
/// created, read, given a role and taken away again — and a finder for a
/// person's name has to mean the same thing on the directory row, on the
/// record it opens and in the member list of the role they hold.
final class StaffRobot extends Robot {
  StaffRobot(super.harness);

  @override
  Key get anchor => StaffKeys.screen;

  @override
  String? get route => StaffRoutes.list;

  /// Hands the staff pages to GetX, once per isolate.
  ///
  /// Asked of the tree rather than remembered in a flag: `ParseRouteTree`
  /// holds its routes in a `static final` that outlives `Get.reset()`, and
  /// `addRoutes` appends without checking — so a second registration is a
  /// second copy of every route, and a flag that got out of step with the tree
  /// would be worse than either.
  static void _ensurePages() {
    final known = Get.routeTree.routes
        .any((page) => page.name == StaffRoutes.roleEditor);
    if (known) return;
    Get.addPages(StaffPages.pages);
  }

  // ── Getting there ─────────────────────────────────────────────────────────

  /// Opens the directory.
  ///
  /// Two things are going on, and both are about the route table being owned
  /// by another stream:
  ///
  ///   * the **sub-routes** are added to GetX's tree, because nothing has
  ///     registered them yet. Once the table does, these become harmless
  ///     duplicates — `ParseRouteTree._findRoute` takes the first match, and
  ///     both point at the same page.
  ///   * the **root** is pushed with `Get.to` rather than by name, because
  ///     `/staff` is still the shared table's placeholder screen and first
  ///     registration wins. `Get.to` names the route it pushes, so
  ///     `Get.currentRoute` — and therefore [assertVisible] — still reads
  ///     `/staff`.
  ///
  /// `Get.to` is fired and **not awaited**: its future completes when the
  /// route is *popped*, so awaiting it here would wait for something this flow
  /// has not done yet and never return.
  Future<void> open() async {
    _ensurePages();

    unawaited(
      Get.to<void>(
            () => const UsersView(embedded: false),
            binding: UsersBinding(),
            routeName: StaffRoutes.list,
          ) ??
          Future<void>.value(),
    );
    await tester.pumpUntilFound(find.byKey(StaffKeys.screen));
    await settle();
  }

  Future<void> assertOnDirectory() async {
    await assertVisible();
    seeNoErrorBanner();
  }

  // ── The directory ─────────────────────────────────────────────────────────

  /// The staff ids on screen, in the order the list lays them out.
  List<String> personIdsInOrder() {
    const prefix = 'staff_row_';
    final rows = <({double top, String id})>[
      for (final element in find
          .byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(prefix),
          )
          .evaluate())
        (
          top: (element.renderObject! as RenderBox)
              .localToGlobal(Offset.zero)
              .dy,
          id: ((element.widget.key! as ValueKey<String>).value)
              .substring(prefix.length),
        ),
    ]..sort((a, b) => a.top.compareTo(b.top));
    return [for (final row in rows) row.id];
  }

  int get personCount => personIdsInOrder().length;

  void seePerson(String id) => expect(
        find.byKey(StaffKeys.row(id)),
        findsOneWidget,
        reason: 'expected $id in the directory',
      );

  void seeNoPerson(String id) =>
      expect(find.byKey(StaffKeys.row(id)), findsNothing);

  /// The words on a row's status pill, or null where the row carries none.
  ///
  /// A row with no pill is an account that works. The pill is the *word*, not
  /// the tint: a colour alone is unread by a colour-blind reader, by a printed
  /// rota, and by anybody a metre from the screen.
  String? statusWordOf(String id) {
    final pill = find.descendant(
      of: find.byKey(StaffKeys.row(id)),
      matching: find.byType(StatusPill),
    );
    if (pill.evaluate().isEmpty) return null;
    final widget = tester.widget<StatusPill>(pill.first);
    return widget.label ?? widget.status;
  }

  /// The colour of that pill, so a flow can prove it is not the acuity red.
  Color? statusColourOf(String id) {
    final pill = find.descendant(
      of: find.byKey(StaffKeys.row(id)),
      matching: find.byType(StatusPill),
    );
    if (pill.evaluate().isEmpty) return null;
    return tester.widget<StatusPill>(pill.first).color;
  }

  Future<void> search(String term) async {
    await tester.enterTextByKey(StaffKeys.search, term);
    // `SearchField` debounces by 350ms; anything shorter reads the list as it
    // was before the term landed.
    await tester.pump(const Duration(milliseconds: 400));
    await settle();
  }

  Future<void> filterByRole(String roleName) async {
    await tester.tapKeyWithoutKeyboard(StaffKeys.filterButton);
    await tester.pumpUntilRouteSettled();
    await tester.tapKey(StaffKeys.roleOption(roleName));
    await tester.tapKey(StaffKeys.filterApply);
    await settle();
  }

  Future<void> clearRoleFilter() async {
    await tester.tapKey(StaffKeys.clearFilters);
    await settle();
  }

  void seeEmptyState() =>
      expect(find.byKey(StaffKeys.empty), findsOneWidget);

  void seeNoAccess() => expect(
        find.byKey(StaffKeys.noAccess),
        findsOneWidget,
        reason: 'both staff routes refused; the screen shows a locked panel',
      );

  void seeAddAction() => expect(find.byKey(StaffKeys.add), findsWidgets);

  void seeNoAddAction() => expect(
        find.byKey(StaffKeys.add),
        findsNothing,
        reason: 'a control this account may not use is absent, not disabled',
      );

  Future<void> tapAdd() async {
    await tester.tapKey(StaffKeys.add);
    await tester.pumpUntilFound(find.byKey(StaffKeys.formScreen));
    await settle();
  }

  Future<void> openPerson(String id) async {
    await tester.tapKey(StaffKeys.row(id));
    await tester.pumpUntilFound(find.byKey(StaffKeys.detailScreen));
    await settle();
  }

  // ── The form ──────────────────────────────────────────────────────────────

  Future<void> assertOnForm() async {
    await tester.pumpUntilFound(find.byKey(StaffKeys.formScreen));
    await settle();
  }

  /// True when the form is asking for one name rather than two — which is what
  /// the settings route's `fullName` column needs, and what proves the form
  /// followed the route the directory could read.
  bool get asksForOneName =>
      find.byKey(StaffKeys.formFullName).evaluate().isNotEmpty;

  bool get asksForEmail =>
      find.byKey(StaffKeys.formEmail).evaluate().isNotEmpty;

  Future<void> enterEmail(String value) =>
      tester.enterTextByKey(StaffKeys.formEmail, value);

  Future<void> enterPassword(String value) =>
      tester.enterTextByKey(StaffKeys.formPassword, value);

  Future<void> enterFirstName(String value) =>
      tester.enterTextByKey(StaffKeys.formFirstName, value);

  Future<void> enterLastName(String value) =>
      tester.enterTextByKey(StaffKeys.formLastName, value);

  Future<void> enterFullName(String value) =>
      tester.enterTextByKey(StaffKeys.formFullName, value);

  Future<void> enterLicence(String value) =>
      tester.enterTextByKey(StaffKeys.formLicence, value);

  Future<void> enterEmployeeId(String value) =>
      tester.enterTextByKey(StaffKeys.formEmployeeId, value);

  /// Chooses a role by the words on its row, which is what somebody filling
  /// this form actually sees — `LAB_TECHNICIAN` is a database word.
  Future<void> pickRole(String label) async {
    await tester.tapKeyWithoutKeyboard(StaffKeys.formRole);
    await pickFromSheet(label);
  }

  Future<void> saveForm() async {
    await tester.tapKeyWithoutKeyboard(StaffKeys.formSave);
    await settle();
  }

  /// The message under a field, by the words it says. A validator's whole job
  /// is the sentence, so the sentence is what an assertion is about.
  void seeFieldMessage(String containing) => expect(
        find.textContaining(containing),
        findsWidgets,
        reason: 'expected the form to say "$containing"',
      );

  void seeNoFieldMessage(String containing) =>
      expect(find.textContaining(containing), findsNothing);

  /// The summary above the save bar, which says how many fields are wrong.
  void seeErrorSummary() =>
      expect(find.byType(FieldErrorSummary), findsOneWidget);

  // ── One account ───────────────────────────────────────────────────────────

  Future<void> assertOnRecord() async {
    await tester.pumpUntilFound(find.byKey(StaffKeys.detailScreen));
    await settle();
  }

  void seeRoleHeld(String roleId) => expect(
        find.byKey(StaffKeys.detailRole(roleId)),
        findsOneWidget,
        reason: 'expected the record to show role $roleId',
      );

  void seeRoleNotHeld(String roleId) =>
      expect(find.byKey(StaffKeys.detailRole(roleId)), findsNothing);

  /// Gives this account a role, choosing it by the words on its row.
  Future<void> giveRole(String roleId) async {
    await tester.scrollToKey(StaffKeys.detailAddRole);
    await tester.tap(
      find.descendant(
        of: find.byKey(StaffKeys.detailAddRole),
        matching: find.text('Give a role'),
      ),
    );
    await tester.pumpUntilRouteSettled();
    await tester.tapKey(StaffKeys.detailAssignOption(roleId));
    await settle();
  }

  Future<void> takeRoleAway(String roleId) async {
    await tester.tapKey(StaffKeys.detailRemoveRole(roleId));
    await tester.pumpUntilRouteSettled();
    await tester.tapKey(StaffKeys.detailConfirm);
    await settle();
  }

  /// True when the record offers to switch the account on or off.
  ///
  /// Absent on the paged route: `UpdateUserDto` has no `isActive`, so the key
  /// is a 400 there and the control would be a button that cannot work.
  bool get offersActivation =>
      find.text('Deactivate').evaluate().isNotEmpty ||
      find.text('Activate').evaluate().isNotEmpty;

  Future<void> toggleActivation() async {
    final label = find.text('Deactivate').evaluate().isNotEmpty
        ? 'Deactivate'
        : 'Activate';
    await tester.scrollToFinder(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpUntilRouteSettled();
    await tester.tapKey(StaffKeys.detailConfirm);
    await settle();
  }

  /// Opens the delete confirmation and reads what it says will happen.
  ///
  /// A confirm that does not say what becomes true is a confirm nobody can
  /// answer, so the wording is the assertion.
  Future<void> tapDelete() async {
    await tester.scrollToFinder(find.text('Remove'));
    await tester.tap(find.text('Remove').first);
    await tester.pumpUntilRouteSettled();
  }

  void seeConfirmSaying(String containing) => expect(
        find.textContaining(containing),
        findsWidgets,
        reason: 'the confirmation has to say what becomes true',
      );

  Future<void> confirm() async {
    await tester.tapKey(StaffKeys.detailConfirm);
    await settle();
  }

  Future<void> cancelConfirm() async {
    await tester.tapKey(StaffKeys.detailCancel);
    await settle();
  }

  // ── Roles and the editor ──────────────────────────────────────────────────

  /// Opens the roles list, which the shared route table already registers.
  Future<void> openRoles() async {
    _ensurePages();
    unawaited(Get.toNamed<void>(Routes.SETTINGS_ROLES));
    await tester.pumpUntilFound(find.byKey(RolesKeys.screen));
    await settle();
  }

  /// Opens one role's editor from its card, which is the only way in.
  Future<void> openRoleEditor(String roleId) async {
    await tester.tapKey(RolesKeys.card(roleId));
    await tester.pumpUntilFound(find.byKey(StaffKeys.editorScreen));
    await settle();
  }

  Future<void> assertOnEditor() async {
    await tester.pumpUntilFound(find.byKey(StaffKeys.editorScreen));
    await settle();
  }

  void seeSystemNotice() => expect(
        find.byKey(StaffKeys.editorSystemNotice),
        findsOneWidget,
        reason: 'a role the product ships says so before anybody types',
      );

  void seeNoSystemNotice() =>
      expect(find.byKey(StaffKeys.editorSystemNotice), findsNothing);

  void seeModuleCard(String module) => expect(
        find.byKey(StaffKeys.editorModuleCard(module)),
        findsOneWidget,
        reason: 'expected a card for the $module permissions',
      );

  /// Whether one module's verb switch exists at all.
  ///
  /// A verb the catalogue has no permission for must be **absent**: there is
  /// no `DASHBOARD_DELETE`, and a switch that cannot do anything is a switch
  /// somebody will try.
  bool hasVerbSwitch(String module, String verb) =>
      find.byKey(StaffKeys.editorVerb(module, verb)).evaluate().isNotEmpty;

  bool verbIsOn(String module, String verb) {
    final finder = find.byKey(StaffKeys.editorVerb(module, verb));
    expect(finder, findsOneWidget, reason: '$module:$verb switch');
    return tester.widget<Switch>(finder).value;
  }

  /// Whether the switch can be moved at all — a system role's cannot.
  bool verbIsEditable(String module, String verb) {
    final finder = find.byKey(StaffKeys.editorVerb(module, verb));
    expect(finder, findsOneWidget, reason: '$module:$verb switch');
    return tester.widget<Switch>(finder).onChanged != null;
  }

  Future<void> toggleVerb(String module, String verb) async {
    await tester.tapKey(StaffKeys.editorVerb(module, verb));
    await tester.pump();
  }

  Future<void> saveRole() async {
    await tester.tapKeyWithoutKeyboard(StaffKeys.editorSave);
    await settle();
  }

  void seeNoSaveAction() => expect(
        find.byKey(StaffKeys.editorSave),
        findsNothing,
        reason: 'a role the server refuses to change offers no Save',
      );

  Future<void> confirmRevoke() async {
    await tester.tapKey(StaffKeys.editorConfirm);
    await settle();
  }

  Future<void> cancelRevoke() async {
    await tester.tapKey(StaffKeys.editorCancel);
    await settle();
  }

  Future<void> showEditorTab(RoleEditorTab tab) async {
    await tester.tapKeyWithoutKeyboard(StaffKeys.editorTab(tab.name));
    await settle();
  }

  void seeMember(String userId) => expect(
        find.byKey(StaffKeys.editorMember(userId)),
        findsWidgets,
        reason: 'expected $userId to hold this role',
      );

  void seeNoMember(String userId) =>
      expect(find.byKey(StaffKeys.editorMember(userId)), findsNothing);

  Future<void> addMember(String userId) async {
    await tester.tap(
      find.descendant(
        of: find.byKey(StaffKeys.editorAddMember),
        matching: find.text('Add somebody'),
      ),
    );
    await tester.pumpUntilRouteSettled();
    await tester.tapKey(StaffKeys.editorMember(userId));
    await settle();
  }

  Future<void> removeMember(String userId) async {
    await tester.tapKey(StaffKeys.editorRemoveMember(userId));
    await tester.pumpUntilRouteSettled();
    await tester.tapKey(StaffKeys.editorConfirm);
    await settle();
  }
}
