import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../data/models/role.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../../users/user_routes.dart';
import '../controllers/roles_controller.dart';

/// Who can do what, as roles rather than as a matrix.
///
/// A permission grid is the wrong first screen: it asks somebody to reason
/// about forty switches before they have decided which job they are
/// describing. Each card here says, in plain words, what the role can actually
/// do — which is the same information in the order people think in.
class RolesView extends GetView<RolesController> {
  const RolesView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;

    return Scaffold(
      key: RolesKeys.screen,
      appBar: const DetailHeader(title: 'Roles and access'),
      body: BentoGround(
        child: SafeArea(
          child: Obx(() {
            if (c.rxNoAccess.value) {
              return const Center(
                child: EmptyState(
                  key: RolesKeys.noAccess,
                  icon: Icons.lock_outline_rounded,
                  title: 'Not available to your role',
                  message: 'Ask an administrator if you need to manage roles.',
                ),
              );
            }

            return BentoScreen(
              ground: false,
              bottomClearance: false,
              onRefresh: c.reload,
              slivers: [
                if ((c.rxLoadError.value ?? '').isNotEmpty)
                  BentoSection(
                    top: BentoSpace.section,
                    child: ErrorRetryBanner(
                      message: c.rxLoadError.value!,
                      onRetry: c.reload,
                    ),
                  ),

                if (c.rxFirstLoad.value)
                  const BentoSection(
                    top: BentoSpace.section,
                    child: BentoSkeleton(rows: 4),
                  )
                else ...[
                  if (c.customRoles.isNotEmpty) ...[
                    const BentoSection(
                      top: BentoSpace.section,
                      bottom: BentoSpace.header,
                      child: SectionHeader(title: 'This hospital'),
                    ),
                    for (final role in c.customRoles)
                      BentoSection(
                        bottom: BentoSpace.action,
                        child: _RoleCard(role: role),
                      ),
                  ],

                  BentoSection(
                    top: c.customRoles.isEmpty ? BentoSpace.section : 0,
                    bottom: BentoSpace.header,
                    child: const SectionHeader(title: 'Built in'),
                  ),
                  for (final role in c.systemRoles)
                    BentoSection(
                      bottom: BentoSpace.action,
                      // Built-in roles open, and open read-only: the server
                      // refuses every edit with ROLE_SYSTEM_PROTECTED, and the
                      // editor says so rather than letting a save 403. Being
                      // able to *read* one is the point — somebody shaping a
                      // custom role needs to see what NURSE already has.
                      child: _RoleCard(role: role),
                    ),
                ],
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role});

  final Role role;

  /// What this role can do, in the language of the job.
  ///
  /// Derived from the grants rather than listed as permission names: "Can work
  /// in the queue, the ward board and pre-triage" is a sentence somebody can
  /// check against a job; `QUEUE_UPDATE` is not.
  String _summary() {
    final writes = <String>[];
    final reads = <String>[];

    role.grantsByModule.forEach((module, grants) {
      final canWrite = grants.any((g) => g.canCreate || g.canUpdate);
      final canRead = grants.any((g) => g.canRead);
      final name = Formatters.label(module);
      if (canWrite) {
        writes.add(name);
      } else if (canRead) {
        reads.add(name);
      }
    });

    // `GET /api/roles` answers the role rows and **no** `rolePermissions`, so
    // a card built from the list has nothing to summarise. Saying "no access"
    // there would be a claim about the role rather than about what this route
    // sent — and it is wrong for every built-in role on the screen.
    if (role.permissions.isEmpty) return 'Open it to see what it can do.';
    if (writes.isEmpty && reads.isEmpty) return 'No access to anything yet.';

    final parts = <String>[];
    if (writes.isNotEmpty) parts.add('Works in ${_list(writes)}');
    if (reads.isNotEmpty) parts.add('reads ${_list(reads)}');
    return '${parts.join('; ')}.';
  }

  /// `a, b and c` — an Oxford-comma-free list a person reads as a sentence.
  static String _list(List<String> items) {
    if (items.length == 1) return items.single;
    if (items.length > 4) {
      return '${items.take(3).join(', ')} and ${items.length - 3} more';
    }
    return '${items.take(items.length - 1).join(', ')} and ${items.last}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final members = role.userCount;

    return BentoCard(
      key: RolesKeys.card(role.id),
      // Every card opens, including a built-in one. It used to point at
      // `Routes.SETTINGS_ROLES` — this screen — so a tap reopened the list it
      // came from.
      onTap: () => Get.toNamed<void>(
        StaffRoutes.roleEditor,
        arguments: {'id': role.id, 'role': role},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  role.displayName,
                  style: isDark
                      ? AppTextStyles.darkHeadline(weight: FontWeight.w700)
                      : AppTextStyles.lightHeadline(weight: FontWeight.w700),
                ),
              ),
              if (role.isSystem)
                const StatusPill(
                  // A category, not a clinical state — so it takes one neutral
                  // tint and lets the word carry it, per RULES §0.
                  status: 'built-in',
                  label: 'Built in',
                  color: AppColors.acuityRoutine,
                ),
            ],
          ),
          if ((role.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              role.description!,
              style: isDark
                  ? AppTextStyles.darkSubheadline()
                  : AppTextStyles.lightSubheadline(),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            _summary(),
            style: isDark
                ? AppTextStyles.darkFootnote()
                : AppTextStyles.lightFootnote(),
          ),
          if (members != null) ...[
            const SizedBox(height: 10),
            Text(
              members == 1 ? '1 person' : '$members people',
              style: isDark
                  ? AppTextStyles.darkFootnote(weight: FontWeight.w600)
                  : AppTextStyles.lightFootnote(weight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}
