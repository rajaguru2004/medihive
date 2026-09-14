import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/staff_keys.dart';
import '../../../core/window_class.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/role.dart';
import '../../../data/models/staff_user.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../controllers/role_editor_controller.dart';

/// One role: what it is called, what it allows, and who holds it.
///
/// The permission grid is the second screen rather than the first on purpose —
/// `RolesView` asks somebody which job they are describing before it asks them
/// to reason about forty switches. By the time anybody is here, that question
/// has been answered.
class RoleEditorView extends GetView<RoleEditorController> {
  const RoleEditorView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root of `build`; a `GetView` that never touches it never
    // builds the controller, and `onReady` never runs.
    final editor = controller;

    return Scaffold(
      key: StaffKeys.editorScreen,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Obx(
          () => DetailHeader(
            title: editor.role.value.isEmpty
                ? 'Role'
                : editor.role.value.displayName,
            subtitle: 'Roles and access',
          ),
        ),
      ),
      body: Obx(() {
        if (editor.isLoading && editor.rxFirstLoad.value) {
          return const BentoScreen(
            bottomClearance: false,
            slivers: [
              BentoSection(top: BentoSpace.page, child: BentoSkeleton(rows: 6)),
            ],
          );
        }

        if (editor.hasNoAccess) {
          return const BentoScreen(
            bottomClearance: false,
            slivers: [
              BentoSection(
                top: BentoSpace.page,
                child: EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Not available to your role',
                  message: 'Ask an administrator if you need to manage roles.',
                ),
              ),
            ],
          );
        }

        if (editor.missing.value) {
          return const BentoScreen(
            bottomClearance: false,
            slivers: [
              BentoSection(
                top: BentoSpace.page,
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'That role is not here',
                  message: 'Open it from Roles and access — it may have been '
                      'removed, or it belongs to another site.',
                ),
              ),
            ],
          );
        }

        return _Body(editor: editor);
      }),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.editor});

  final RoleEditorController editor;

  /// Every observable this screen draws is read **inside** this closure.
  ///
  /// `Obx` tracks what its own builder touches, and a child widget's `build`
  /// runs after that scope has closed — so a switch flipped in a module card,
  /// which moves `granted` and nothing else, would not repaint the card it
  /// sits in.
  @override
  Widget build(BuildContext context) => Obx(() => _layout(context));

  Widget _layout(BuildContext context) {
    final showingAccess = editor.tab.value == RoleEditorTab.access;

    return Column(
      children: [
        Expanded(
          child: BentoScreen(
            onRefresh: editor.reload,
            bottomClearance: false,
            slivers: [
              if (editor.hasLoadError)
                BentoSection(
                  top: BentoSpace.page,
                  child: ErrorRetryBanner(
                    message: editor.rxLoadError.value!,
                    onRetry: editor.load,
                  ),
                ),
              BentoSection(
                top: editor.hasLoadError ? 0 : BentoSpace.page,
                bottom: BentoSpace.section,
                child: BentoSegmented<RoleEditorTab>(
                  key: StaffKeys.editorTabs,
                  options: RoleEditorTab.values,
                  selected: editor.tab.value,
                  labelOf: (value) => value.label,
                  keyOf: (value) => StaffKeys.editorTab(value.name),
                  onSelected: editor.showTab,
                ),
              ),
              if ((editor.actionError.value ?? '').isNotEmpty)
                BentoSection(
                  bottom: BentoSpace.header,
                  child: NoticeBanner(
                    message: editor.actionError.value!,
                    icon: Icons.error_outline_rounded,
                    tint: AppColors.error,
                  ),
                ),
              if (showingAccess)
                ..._accessSlivers(context)
              else
                ..._memberSlivers(context),
            ],
          ),
        ),
        // Saving belongs to the access tab. The member tab writes as it goes —
        // adding somebody to a role is one call, and a Save button over it
        // would imply there is something pending when there is not.
        if (showingAccess && editor.canEditPermissions)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                BentoSpace.page,
                0,
                BentoSpace.page,
                BentoSpace.page,
              ),
              child: MaxWidthBody(
                child: PrimaryBar(
                  key: StaffKeys.editorSave,
                  label: 'Save',
                  busy: editor.isWorking.value,
                  onPressed: () => _save(context),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── What it can do ────────────────────────────────────────────────────────

  List<Widget> _accessSlivers(BuildContext context) {
    final window = WindowClass.of(context);
    // The task's own line: a phone gets one card per module, a tablet gets a
    // grid. Keyed to the rail rather than to `formColumns`, because the rail is
    // the point at which this screen has a second column of room.
    final columns = window.navMode.isRail
        ? (window >= WindowClass.large ? 3 : 2)
        : 1;

    final modules = editor.modules;

    return [
      if (editor.isProtected)
        const BentoSection(
          bottom: BentoSpace.header,
          child: KeyedSubtree(
            key: StaffKeys.editorSystemNotice,
            child: NoticeBanner(
              // Said before anybody types, rather than discovered as a 403
              // after they have spent five minutes on it. The server answers
              // `ROLE_SYSTEM_PROTECTED` to every edit of a role the product
              // ships.
              message: 'This role ships with the product. Its name and its '
                  'permissions cannot be changed here — copy it into a role of '
                  'your own if you need something close to it.',
              icon: Icons.lock_outline_rounded,
              tint: AppColors.info,
            ),
          ),
        ),
      BentoSection(
        bottom: BentoSpace.section,
        child: _Naming(editor: editor),
      ),
      const BentoSection(
        bottom: BentoSpace.header,
        child: SectionHeader(title: 'What it opens'),
      ),
      if (modules.isEmpty)
        const BentoSection(
          child: EmptyState(
            icon: Icons.key_off_outlined,
            title: 'No permission catalogue',
            message: 'The server did not send the list of things a role can '
                'be granted, so there is nothing to switch on.',
          ),
        )
      else
        BentoSection(
          child: KeyedSubtree(
            key: StaffKeys.editorGrid,
            child: _ModuleGrid(
              editor: editor,
              modules: modules,
              columns: columns,
            ),
          ),
        ),
    ];
  }

  Future<void> _save(BuildContext context) async {
    // The name first: a blank one is dropped by `draftBody` rather than sent,
    // so the save would look like it worked and the role would keep its old
    // name.
    if (!(editor.formKey.currentState?.validate() ?? true)) return;

    // A revoke is the change worth stopping on. Adding a permission gives
    // somebody a screen they did not have; removing one takes away a screen
    // they are already using, and the people it happens to are not in the room.
    final warning = editor.revokeWarning;
    if (warning != null) {
      final agreed = await ConfirmDialog.show(
        context,
        title: 'Take access away from ${editor.role.value.displayName}?',
        message: warning,
        confirmLabel: 'Take it away',
        destructive: true,
        confirmKey: StaffKeys.editorConfirm,
        cancelKey: StaffKeys.editorCancel,
      );
      if (!agreed) return;
    }

    await editor.save();
  }

  // ── Who holds it ──────────────────────────────────────────────────────────

  List<Widget> _memberSlivers(BuildContext context) {
    final members = editor.members;

    return [
      BentoSection(
        bottom: BentoSpace.header,
        child: KeyedSubtree(
          key: StaffKeys.editorAddMember,
          child: SectionHeader(
            title: members.length == 1
                ? '1 person holds this'
                : '${members.length} people hold this',
            // Absent, not disabled, without `roles.update`.
            actionLabel: editor.canEditMembers ? 'Add somebody' : null,
            onAction: editor.canEditMembers ? () => _openAdd(context) : null,
          ),
        ),
      ),
      if (editor.membersAreDerived.value)
        const BentoSection(
          bottom: BentoSpace.header,
          child: NoticeBanner(
            // Honest about where the list came from. The server has no route
            // that lists a role's members, so this is the staff directory read
            // back by the role each person's record names — which is the same
            // set for anybody created or edited through a staff form.
            message: 'Read from the staff directory, because the server has no '
                'route that lists a role. Somebody added here appears straight '
                'away; the directory catches up when their record is next '
                'edited.',
            icon: Icons.info_outline_rounded,
            tint: AppColors.info,
          ),
        ),
      if (members.isEmpty)
        BentoSection(
          child: EmptyState(
            key: StaffKeys.editorMembers,
            icon: Icons.person_search_outlined,
            title: 'Nobody holds this role',
            message: 'A role nobody holds changes nothing. Add somebody, or '
                'leave it here as a template.',
            actionLabel: editor.canEditMembers ? 'Add somebody' : null,
            onAction: editor.canEditMembers ? () => _openAdd(context) : null,
          ),
        )
      else
        BentoSection(
          child: BentoCard(
            key: StaffKeys.editorMembers,
            padding:
                const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < members.length; i++) ...[
                  if (i > 0) const Hairline(indent: 68),
                  _MemberRow(
                    key: StaffKeys.editorMember(members[i].id),
                    editor: editor,
                    person: members[i],
                  ),
                ],
              ],
            ),
          ),
        ),
    ];
  }

  Future<void> _openAdd(BuildContext context) async {
    final addable = await editor.addableStaff();
    if (addable.isEmpty) {
      showBentoToast(
        'Everybody in the directory already holds this role.',
        tone: ToastTone.info,
      );
      return;
    }

    final chosen = await Get.bottomSheet<StaffUser>(
      SheetShell(
        title: 'Add somebody',
        scrollable: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final person in addable)
              SheetRow(
                key: StaffKeys.editorMember(person.id),
                icon: Icons.person_outline_rounded,
                label: person.displayName,
                sublabel: Formatters.label(person.role),
                onTap: () => Get.back<StaffUser>(result: person),
              ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
    if (chosen == null) return;

    await editor.addMember(chosen);
  }
}

// ── Name and description ────────────────────────────────────────────────────

class _Naming extends StatelessWidget {
  const _Naming({required this.editor});

  final RoleEditorController editor;

  @override
  Widget build(BuildContext context) {
    final locked = !editor.canEditPermissions;

    return Form(
      key: editor.formKey,
      child: FormCard(
        children: [
          BentoInput(
            fieldKey: StaffKeys.editorName,
            label: 'Name',
            controller: editor.nameController,
            validator: editor.validateName,
            enabled: !locked,
            required: true,
            textCapitalization: TextCapitalization.words,
            // Said here rather than discovered as a 409. The server
            // upper-cases whatever it is sent, so "Ward Nurse" and "WARD
            // NURSE" are the same role and the second one collides.
            hint: 'Stored upper-cased, so "Ward nurse" and "WARD NURSE" are '
                'the same role.',
          ),
          BentoInput(
            fieldKey: StaffKeys.editorDescription,
            label: 'Description',
            controller: editor.descriptionController,
            enabled: !locked,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            hint: 'What job this is, in the words the rota uses',
          ),
        ],
      ),
    );
  }
}

// ── The grid ────────────────────────────────────────────────────────────────

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid({
    required this.editor,
    required this.modules,
    required this.columns,
  });

  final RoleEditorController editor;
  final List<String> modules;
  final int columns;

  @override
  Widget build(BuildContext context) {
    if (columns == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < modules.length; i++) ...[
            if (i > 0) const SizedBox(height: BentoSpace.action),
            _ModuleCard(editor: editor, module: modules[i]),
          ],
        ],
      );
    }

    final rows = <Widget>[];
    for (var start = 0; start < modules.length; start += columns) {
      final slice = modules.skip(start).take(columns).toList();
      rows.add(
        // `IntrinsicHeight`, not `CrossAxisAlignment.stretch` on its own: a
        // stretched `Row` inside a sliver is laid out at infinite height and
        // asserts. See `.agents/RULES.md` §2.5.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < columns; i++) ...[
                if (i > 0) const SizedBox(width: BentoSpace.action),
                Expanded(
                  child: i < slice.length
                      ? _ModuleCard(editor: editor, module: slice[i])
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: BentoSpace.action),
          rows[i],
        ],
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.editor, required this.module});

  final RoleEditorController editor;
  final String module;

  /// Its own `Obx`, because a sliver's children are built during layout —
  /// outside the enclosing reactive scope — so a card reading `granted` from
  /// there would subscribe to nothing and the switch would not move.
  @override
  Widget build(BuildContext context) => Obx(() => _card(context));

  Widget _card(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final extras = editor.extrasFor(module);
    final enabled = editor.canEditPermissions;

    return BentoCard(
      key: StaffKeys.editorModuleCard(module),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            // `pre-triage` is a database word. Nobody says it.
            Formatters.label(module),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: isDark
                ? AppTextStyles.darkHeadline(weight: FontWeight.w700)
                : AppTextStyles.lightHeadline(weight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            editor.summaryFor(module),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: isDark
                ? AppTextStyles.darkFootnote()
                : AppTextStyles.lightFootnote(),
          ),
          const SizedBox(height: 6),
          for (final verb in RoleEditorController.verbs)
            // A verb the catalogue has no permission for is left out rather
            // than drawn off: there is no `DASHBOARD_DELETE`, and a switch
            // that cannot do anything is a switch somebody will try.
            if (editor.rowFor(module, verb) case final row?)
              BentoSwitchRow(
                switchKey: StaffKeys.editorVerb(module, verb.name),
                label: _verbLabel(verb),
                sublabel: _verbHint(verb, module),
                value: editor.isOn(row),
                enabled: enabled,
                onChanged: enabled
                    ? (value) => editor.toggle(row, on: value)
                    : null,
              ),
          for (final extra in extras)
            BentoSwitchRow(
              switchKey: StaffKeys.editorVerb(module, _actionKey(extra)),
              label: Formatters.label(_actionKey(extra)),
              sublabel: extra.description,
              value: editor.isOn(extra),
              enabled: enabled,
              onChanged:
                  enabled ? (value) => editor.toggle(extra, on: value) : null,
            ),
        ],
      ),
    );
  }

  static String _verbLabel(AccessVerb verb) => switch (verb) {
        AccessVerb.read => 'See it',
        AccessVerb.create => 'Add',
        AccessVerb.update => 'Change',
        AccessVerb.delete => 'Remove',
      };

  static String? _verbHint(AccessVerb verb, String module) => switch (verb) {
        AccessVerb.read => 'Open the ${Formatters.label(module).toLowerCase()} '
            'screens and read what is on them',
        AccessVerb.delete => 'Take rows off. Most sites grant this to nobody.',
        _ => null,
      };

  /// The action half of a permission, for a row the four verbs do not cover.
  static String _actionKey(PermissionGrant row) {
    final code = row.code ?? '';
    if (code.contains(':')) return code.split(':').last.toLowerCase();
    final cut = row.name.lastIndexOf('_');
    return cut == -1
        ? row.name.toLowerCase()
        : row.name.substring(cut + 1).toLowerCase();
  }
}

// ── One member ──────────────────────────────────────────────────────────────

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    super.key,
    required this.editor,
    required this.person,
  });

  final RoleEditorController editor;
  final StaffUser person;

  @override
  Widget build(BuildContext context) {
    return PersonRow(
      name: person.displayName,
      subtitle: person.email,
      detail: Formatters.label(person.role),
      trailing: editor.canEditMembers
          ? CircleIconButton(
              key: StaffKeys.editorRemoveMember(person.id),
              icon: Icons.close_rounded,
              size: 40,
              iconSize: 18,
              tooltip: 'Take this role away',
              onTap: () => _confirmRemove(context),
            )
          : null,
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final agreed = await ConfirmDialog.show(
      context,
      title: 'Take ${editor.role.value.displayName} away from '
          '${person.displayName}?',
      message: 'They keep their account and lose everything this role '
          'allowed — every screen it opened, and every record it let them '
          'write.',
      confirmLabel: 'Take it away',
      destructive: true,
      confirmKey: StaffKeys.editorConfirm,
      cancelKey: StaffKeys.editorCancel,
    );
    if (!agreed) return;

    await editor.removeMember(person);
  }
}
