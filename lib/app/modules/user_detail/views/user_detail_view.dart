import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/staff_keys.dart';
import '../../../data/models/role.dart';
import '../../../data/models/staff_user.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../../users/staff_directory.dart';
import '../../users/user_routes.dart';
import '../controllers/user_detail_controller.dart';

/// One staff account: the facts, the roles it holds, and the three things that
/// can be done to it.
class UserDetailView extends GetView<UserDetailController> {
  const UserDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root of `build`; a `GetView` that never touches it never
    // builds the controller, and `onReady` never runs.
    final detail = controller;

    return Scaffold(
      key: StaffKeys.detailScreen,
      // `DetailHeader` is a `PreferredSizeWidget` and an `Obx` is not, so the
      // reactive half sits inside a `PreferredSize` of the same height. Worth
      // the wrapper: a deep link arrives with nothing but an id, and a header
      // reading "Staff account" for the whole first load is a screen that
      // cannot say whose account it is.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Obx(
          () => DetailHeader(
            title: detail.user.value.isEmpty
                ? 'Staff account'
                : detail.user.value.displayName,
            subtitle: Formatters.label(detail.user.value.role),
          ),
        ),
      ),
      body: Obx(() {
        if (detail.isLoading && detail.rxFirstLoad.value) {
          return const BentoScreen(
            bottomClearance: false,
            slivers: [
              BentoSection(top: BentoSpace.page, child: BentoSkeleton(rows: 5)),
            ],
          );
        }

        if (detail.hasNoAccess) {
          return const BentoScreen(
            bottomClearance: false,
            slivers: [
              BentoSection(
                top: BentoSpace.page,
                child: EmptyState(
                  key: StaffKeys.noAccess,
                  icon: Icons.lock_outline_rounded,
                  title: 'Not available to your role',
                  message: 'Ask an administrator if you need to manage staff '
                      'accounts.',
                ),
              ),
            ],
          );
        }

        if (detail.missing.value) {
          return const BentoScreen(
            bottomClearance: false,
            slivers: [
              BentoSection(
                top: BentoSpace.page,
                child: EmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'That account is not here',
                  message: 'Open it from the staff directory — it may have '
                      'been removed, or it belongs to another site.',
                ),
              ),
            ],
          );
        }

        return _Body(detail: detail);
      }),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.detail});

  final UserDetailController detail;

  /// Every observable this screen draws is read **inside** this closure.
  ///
  /// `Obx` tracks what its own builder touches, and a child widget's `build`
  /// runs after that scope has closed — so a role assigned through the section
  /// below, which moves `memberships` and nothing else, would not repaint the
  /// list it was added to. The values go down as plain data.
  @override
  Widget build(BuildContext context) => Obx(() {
        final user = detail.user.value;
        final held = detail.memberships.toList();
        final assignable = detail.assignableRoles;
        final refusal = detail.actionError.value ?? '';

        return BentoScreen(
          onRefresh: detail.reload,
          bottomClearance: false,
          slivers: [
            if (detail.hasLoadError)
              BentoSection(
                top: BentoSpace.page,
                child: ErrorRetryBanner(
                  message: detail.rxLoadError.value!,
                  onRetry: detail.load,
                ),
              ),
            BentoSection(
              top: detail.hasLoadError ? 0 : BentoSpace.page,
              bottom: BentoSpace.header,
              child: RecordHeader(
                title: user.displayName,
                subtitle: user.email,
                // A category, not a clinical state: whether an account is
                // switched on takes one neutral tint and lets the word carry
                // it. Routing it through `CaseStatus` would paint "active" in
                // the triage blue.
                status: user.isActive ? 'Active' : 'Inactive',
                statusColor: AppColors.acuityRoutine,
                actions: _actions(context, user),
              ),
            ),
            if (refusal.isNotEmpty)
              BentoSection(
                bottom: BentoSpace.header,
                child: NoticeBanner(
                  message: refusal,
                  icon: Icons.error_outline_rounded,
                  tint: AppColors.error,
                ),
              ),
            BentoSection(
              bottom: BentoSpace.header,
              child: _Facts(user: user),
            ),
            BentoSection(
              child: _Roles(detail: detail, held: held, assignable: assignable),
            ),
          ],
        );
      });

  List<Widget> _actions(BuildContext context, StaffUser user) {
    return [
      // Every one of these is absent rather than disabled for an account that
      // may not use it: a greyed-out control on a ward tablet is a question
      // the person holding it cannot answer.
      if (detail.canUpdate)
        RecordAction(
          icon: Icons.edit_outlined,
          label: 'Edit',
          onPressed: () => Get.toNamed<void>(
            StaffRoutes.form,
            arguments: {'user': user},
          ),
        ),
      // Only the settings route can switch an account on and off:
      // `CreateUserDto` has no `isActive`, so `UpdateUserDto` — a
      // `PartialType(OmitType(...))` of it — has none either, and the key is
      // a 400 on `/api/users`.
      if (detail.canSetActive)
        RecordAction(
          icon: user.isActive
              ? Icons.person_off_outlined
              : Icons.person_outline_rounded,
          label: user.isActive ? 'Deactivate' : 'Activate',
          onPressed: () => _confirmActive(context),
        ),
      if (detail.canDelete)
        RecordAction(
          icon: Icons.delete_outline_rounded,
          label: 'Remove',
          destructive: true,
          onPressed: () => _confirmDelete(context),
        ),
    ];
  }

  Future<void> _confirmActive(BuildContext context) async {
    final user = detail.user.value;
    final turningOff = user.isActive;

    final agreed = await ConfirmDialog.show(
      context,
      title: turningOff
          ? 'Deactivate ${user.displayName}?'
          : 'Activate ${user.displayName}?',
      // What becomes true, not what the button does.
      message: turningOff
          ? 'They can no longer sign in. Everything they have already '
              'recorded stays on the patients it belongs to, and their name '
              'stays on it.'
          : 'They can sign in again, with the same password and the same '
              'roles they had before.',
      confirmLabel: turningOff ? 'Deactivate' : 'Activate',
      destructive: turningOff,
      confirmKey: StaffKeys.detailConfirm,
      cancelKey: StaffKeys.detailCancel,
    );
    if (!agreed) return;

    await detail.setActive(isActive: !turningOff);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final user = detail.user.value;

    final agreed = await ConfirmDialog.show(
      context,
      title: 'Remove ${user.displayName}?',
      message: 'They can no longer sign in, and the account stops appearing '
          'in the pickers that assign work. Their name stays on every record '
          'they wrote — this does not erase anything a clinician relied on.',
      confirmLabel: 'Remove',
      destructive: true,
      confirmKey: StaffKeys.detailConfirm,
      cancelKey: StaffKeys.detailCancel,
    );
    if (!agreed) return;

    await detail.deleteAccount();
  }
}

// ── Facts ───────────────────────────────────────────────────────────────────

class _Facts extends StatelessWidget {
  const _Facts({required this.user});

  final StaffUser user;

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stacked, because an email address squeezed into half a phone is
          // shown as "a.okonkwo@exampl…", which is not an address anybody can
          // act on.
          FactRow(label: 'Email', value: user.email, stacked: true),
          FactRow(label: 'Phone', value: _orDash(user.phone)),
          FactRow(label: 'Employee id', value: _orDash(user.employeeId)),
          FactRow(label: 'Department', value: _orDash(user.departmentName)),
          FactRow(
            label: 'Specialisation',
            value: _orDash(user.specialization),
          ),
          FactRow(label: 'Licence', value: _orDash(user.licenseNumber)),
          FactRow(
            label: 'Last signed in',
            // Never invented: an account nobody has ever used answers with a
            // dash rather than with the day the record was created.
            value: user.lastLoginAt == null
                ? 'Never'
                : Formatters.dateTime(user.lastLoginAt),
          ),
          FactRow(label: 'Added', value: Formatters.date(user.createdAt)),
        ],
      ),
    );
  }

  static String _orDash(String? value) =>
      (value ?? '').trim().isEmpty ? '—' : value!.trim();
}

// ── Roles ───────────────────────────────────────────────────────────────────

class _Roles extends StatelessWidget {
  const _Roles({
    required this.detail,
    required this.held,
    required this.assignable,
  });

  final UserDetailController detail;

  /// Both resolved by the caller, inside its `Obx`. See the note there.
  final List<Role> held;
  final List<Role> assignable;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: StaffKeys.detailRoles,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: StaffKeys.detailAddRole,
          child: SectionHeader(
            title: 'Roles',
            // Absent, not disabled: `POST /roles/:id/users` is gated on
            // `ROLE_UPDATE`, which a user administrator can be without.
            actionLabel: detail.canAssignRoles && assignable.isNotEmpty
                ? 'Give a role'
                : null,
            onAction: detail.canAssignRoles && assignable.isNotEmpty
                ? () => _openAssign(context)
                : null,
          ),
        ),
        BentoCard(
          padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
          child: held.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: BentoSpace.listPad,
                    vertical: 8,
                  ),
                  child: EmptyState(
                    compact: true,
                    icon: Icons.key_outlined,
                    title: 'No role yet',
                    message: 'Until somebody gives them one, this account can '
                        'sign in and see nothing.',
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < held.length; i++) ...[
                      if (i > 0) const Hairline(indent: BentoSpace.listPad),
                      BentoRow(
                        key: StaffKeys.detailRole(held[i].id),
                        title: held[i].displayName,
                        subtitle: held[i].description,
                        icon: Icons.key_outlined,
                        showChevron: false,
                        trailing: detail.canAssignRoles
                            ? CircleIconButton(
                                key: StaffKeys.detailRemoveRole(held[i].id),
                                icon: Icons.close_rounded,
                                size: 40,
                                iconSize: 18,
                                tooltip: 'Take this role away',
                                onTap: () => _confirmRemove(context, held[i]),
                              )
                            : null,
                      ),
                    ],
                  ],
                ),
        ),
        if (StaffDirectory.usesSettingsRoute) ...[
          const SizedBox(height: BentoSpace.action),
          const NoticeBanner(
            message: 'This directory is read through the settings route, '
                'because this account may not list users directly. The same '
                'people, a slightly different record.',
            icon: Icons.info_outline_rounded,
            tint: AppColors.info,
          ),
        ],
      ],
    );
  }

  Future<void> _openAssign(BuildContext context) async {
    final chosen = await Get.bottomSheet<Role>(
      SheetShell(
        title: 'Give a role',
        scrollable: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final role in assignable)
              SheetRow(
                key: StaffKeys.detailAssignOption(role.id),
                icon: Icons.key_outlined,
                label: role.displayName,
                sublabel: role.description,
                onTap: () => Get.back<Role>(result: role),
              ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
    if (chosen == null) return;

    await detail.assignRole(chosen);
  }

  Future<void> _confirmRemove(BuildContext context, Role role) async {
    final user = detail.user.value;

    final agreed = await ConfirmDialog.show(
      context,
      title: 'Take ${role.displayName} away from ${user.displayName}?',
      // Names what stops working, not what the button does. "Are you sure?"
      // is a question nobody can answer.
      message: 'They keep their account and lose everything this role '
          'allowed — every screen it opened, and every record it let them '
          'write.',
      confirmLabel: 'Take it away',
      destructive: true,
      confirmKey: StaffKeys.detailConfirm,
      cancelKey: StaffKeys.detailCancel,
    );
    if (!agreed) return;

    await detail.removeRole(role);
  }
}
