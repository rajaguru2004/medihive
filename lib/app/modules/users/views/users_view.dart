import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/staff_keys.dart';
import '../../../data/models/staff_user.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../controllers/users_controller.dart';
import '../user_routes.dart';

/// The staff directory.
///
/// Who works here, what they do, and — in a word rather than only a tint —
/// whether their account still works. An account nobody can sign in with looks
/// exactly like one that works until something says so, and the person reading
/// this screen is usually reading it because somebody cannot sign in.
class UsersView extends GetView<UsersController> {
  const UsersView({super.key, this.embedded = true});

  /// False when pushed as its own route rather than shown inside the shell.
  ///
  /// The difference is the header and the ground, nothing else — a screen that
  /// renders differently depending on where it is mounted is two screens
  /// pretending to be one.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    // Read first, and at the root: a `GetView` whose build never touches
    // `controller` never constructs its `lazyPut` instance, so `onInit` never
    // runs and the screen sits on an empty list forever.
    final directory = _Directory(controller: controller);

    if (embedded) {
      return KeyedSubtree(key: StaffKeys.screen, child: directory);
    }

    return Scaffold(
      key: StaffKeys.screen,
      appBar: const DetailHeader(title: 'Users and staff'),
      body: BentoGround(child: directory),
    );
  }
}

class _Directory extends StatelessWidget {
  const _Directory({required this.controller});

  final UsersController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rows = controller.rows;
      // Read **here**, inside the closure. `Obx` only tracks what the builder
      // itself touches: an observable read in a child widget's own `build`
      // runs after the reactive scope has closed, so the filter button would
      // never appear when the role catalogue landed.
      final roleOptions = controller.roleOptions;

      // Both staff routes refused this account. Not an error and not an empty
      // directory: there is nothing to retry, nothing is broken, and the only
      // useful next step is a person rather than a button. The controls go
      // with it — a search field over a panel nobody can read is furniture.
      if (controller.isForbidden) {
        return const BentoScreen(
          ground: false,
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

      return BentoScreen(
        // The ground is painted once, by the shell or by this module's own
        // `Scaffold`. A tab that paints its own flat one on top leaves a seam
        // exactly where the two meet.
        ground: false,
        bottomClearance: false,
        onRefresh: () => controller.reload(silent: true),
        slivers: [
          BentoSection(
            top: BentoSpace.page,
            bottom: BentoSpace.action,
            child: _Controls(controller: controller, roleOptions: roleOptions),
          ),
          if (controller.filterCount > 0)
            BentoSection(
              bottom: BentoSpace.action,
              child: Align(
                alignment: Alignment.centerLeft,
                child: ActiveFilterChip(
                  chipKey: StaffKeys.clearFilters,
                  icon: Icons.badge_outlined,
                  label: _filterSummary(controller),
                  onClear: controller.clearFilters,
                ),
              ),
            ),
          InfiniteList(
            key: StaffKeys.list,
            phase: controller.phase.value,
            itemCount: rows.length,
            // Only while nothing is being narrowed. A term applied over rows
            // in hand cannot ask the server for more of them, and a footer
            // spinner under a filtered list reads as "there are more matches
            // coming" when there are not.
            hasMore: controller.hasMore && !controller.isNarrowed,
            loadingMore: controller.loadingMore.value,
            onLoadMore: controller.loadMore,
            error: controller.errorMessage.value,
            onRetry: controller.reload,
            separator: const Hairline(indent: 68),
            empty: _Empty(controller: controller),
            itemBuilder: (context, index) {
              final user = rows[index];
              return _StaffRow(
                key: StaffKeys.row(user.id),
                user: user,
                onTap: () => Get.toNamed<void>(
                  StaffRoutes.record,
                  arguments: controller.recordArgumentsFor(user),
                ),
              );
            },
          ),
        ],
      );
    });
  }

  static String _filterSummary(UsersController controller) {
    final wanted = controller.filters['role'] ?? const <String>[];
    if (wanted.length == 1) return Formatters.label(wanted.single);
    return '${wanted.length} roles';
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller, required this.roleOptions});

  final UsersController controller;

  /// Resolved by the caller, inside its `Obx`. See the note there.
  final List<String> roleOptions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ListControls(
            searchKey: StaffKeys.search,
            // Short enough to read. The field shares its row with three
            // controls, so a hint listing four things is cut after the
            // second — and a truncated hint is a hint that teaches nothing.
            searchHint: 'Name or email',
            onSearch: controller.search,
            // Absent rather than empty when there is nothing to filter by:
            // `GET /api/roles` is gated on `ROLE_READ`, which a user
            // administrator can be without.
            onFilter: roleOptions.isEmpty ? null : _openFilter,
            filterCount: controller.filterCount,
            filterKey: StaffKeys.filterButton,
            onSort: _openSort,
            sortKey: StaffKeys.sortButton,
          ),
        ),
        // Absent, not disabled, for an account without `users.create`. A
        // control that refuses to work is a question the person holding the
        // tablet has no way to answer.
        if (controller.canCreate) ...[
          const SizedBox(width: 8),
          CircleIconButton(
            key: StaffKeys.add,
            icon: Icons.person_add_alt_1_outlined,
            tooltip: 'Add somebody',
            onTap: () => Get.toNamed<void>(StaffRoutes.form),
          ),
        ],
      ],
    );
  }

  Future<void> _openFilter() => Get.bottomSheet<void>(
        FilterSheet(
          groups: [
            FilterGroup(
              field: 'role',
              label: 'Role',
              options: roleOptions,
              // `LAB_TECHNICIAN` is a database word. Nobody says it.
              labelOf: Formatters.label,
            ),
          ],
          selected: Map<String, List<String>>.from(controller.filters),
          optionKey: (field, value) => StaffKeys.roleOption(value),
          applyKey: StaffKeys.filterApply,
          resetKey: StaffKeys.filterReset,
          onApply: (next) {
            Get.back<void>();
            controller.applyFilters(next);
          },
        ),
        isScrollControlled: true,
      );

  Future<void> _openSort() => Get.bottomSheet<void>(
        SortSheet(
          options: controller.sortOptions,
          selected: controller.sort,
          optionKey: (option) => StaffKeys.sortOption(
            option.field,
            descending: option.descending,
          ),
          onSelected: (option) {
            Get.back<void>();
            controller.applySort(option);
          },
        ),
        isScrollControlled: true,
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.controller});

  final UsersController controller;

  @override
  Widget build(BuildContext context) {
    // Three different empties, and they are not the same sentence. "Nobody
    // works here yet" over a filtered list is the single most common way an
    // app is reported to have lost somebody's data.
    if (controller.isNarrowed) {
      return EmptyState(
        key: StaffKeys.empty,
        icon: Icons.person_search_outlined,
        title: 'Nobody matches that',
        message: controller.hasMore
            // The honest version. Neither staff route can be searched on the
            // server, so what is being searched is what has been loaded — and
            // saying so is better than letting somebody conclude the person
            // has been deleted.
            ? 'This searches the people loaded so far. Scroll to load more, '
                'or narrow it differently.'
            : 'The directory is searched by name, email, employee id and '
                'role.',
        actionLabel: controller.filterCount > 0 ? 'Show everyone' : null,
        onAction: controller.filterCount > 0 ? controller.clearFilters : null,
      );
    }

    return EmptyState(
      key: StaffKeys.empty,
      icon: Icons.people_outline_rounded,
      title: 'Nobody here yet',
      message: 'Staff accounts appear here once somebody creates one.',
      actionLabel: controller.canCreate ? 'Add somebody' : null,
      actionKey: StaffKeys.addFromEmpty,
      onAction: controller.canCreate
          ? () => Get.toNamed<void>(StaffRoutes.form)
          : null,
    );
  }
}

// ── One row ─────────────────────────────────────────────────────────────────

class _StaffRow extends StatelessWidget {
  const _StaffRow({super.key, required this.user, required this.onTap});

  final StaffUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final role = Formatters.label(user.role);
    final department = user.departmentName;

    return PersonRow(
      name: user.displayName,
      // The role a person would say, not the token the column holds.
      subtitle: role.isEmpty ? user.email : role,
      detail: department.isEmpty ? (user.employeeId ?? '') : department,
      trailing: user.isActive
          ? null
          // The **word**, not only the tint. An account nobody can sign in
          // with has to say so before somebody spends a morning on it — and a
          // colour alone is unread by a colour-blind reader, by a printout,
          // and by anybody a metre from the screen.
          //
          // Neutral slate rather than the ramp: whether an account is switched
          // on is an administrative category, not a clinical state, and
          // routing it through `CaseStatus` would paint it with the triage
          // blue that "active" resolves to.
          : const StatusPill(
              status: 'inactive',
              label: 'Inactive',
              color: AppColors.acuityRoutine,
              compact: true,
            ),
      onTap: onTap,
    );
  }
}
