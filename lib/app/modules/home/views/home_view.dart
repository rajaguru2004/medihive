import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../theme/theme.dart';
import '../controllers/home_controller.dart';

/// The shell: one top bar, one tab bar, and the active tab's body.
///
/// The bar shows the **active tab's** title and the global actions. A tab body
/// must not repeat that title, and a pushed sub-screen must not copy this bar
/// — it gets a `DetailHeader` instead. Two top bars on one screen is the most
/// common way a phone app loses a third of its viewport.
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: HomeKeys.screen,
      appBar: _ShellBar(controller: controller),
      body: Obx(
        () => LazyIndexedStack(
          index: controller.activeIndex,
          children: [
            for (final destination in controller.destinations)
              destination.body(),
          ],
        ),
      ),
      bottomNavigationBar: _ShellTabBar(controller: controller),
    );
  }
}

class _ShellBar extends StatelessWidget implements PreferredSizeWidget {
  const _ShellBar({required this.controller});

  final HomeController controller;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      key: HomeKeys.appBar,
      titleSpacing: BentoSpace.page,
      title: Obx(
        () => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.title,
              key: HomeKeys.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
            // The site, under the screen. A clinician who covers two sites on
            // one device needs to know which one this tablet is pointed at,
            // and needs it without tapping anything.
            Text(
              controller.siteName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.overline(Theme.of(context).brightness),
            ),
          ],
        ),
      ),
      actions: [
        CircleIconButton(
          key: HomeKeys.themeToggle,
          icon: AppThemeController.to.isDark
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
          tooltip: 'Switch theme',
          onTap: AppThemeController.to.toggle,
        ),
        Padding(
          padding: const EdgeInsets.only(right: BentoSpace.page - 8),
          child: _ProfileButton(controller: controller),
        ),
      ],
    );
  }
}

/// The signed-in clinician, as an avatar that opens the account sheet.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = controller.rxUser.value;
      return Tooltip(
        message: user?.name.isNotEmpty == true ? user!.name : 'Account',
        child: InkWell(
          key: HomeKeys.profileButton,
          onTap: () => _openAccountSheet(context, controller),
          borderRadius: BorderRadius.circular(AppTheme.minTapTarget / 2),
          child: SizedBox(
            width: AppTheme.minTapTarget,
            height: AppTheme.minTapTarget,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: brandTonalColor(context),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  user?.initials ?? '·',
                  style: AppFonts.text(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: brandInkColor(context),
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

Future<void> _openAccountSheet(
  BuildContext context,
  HomeController controller,
) {
  final user = controller.user;
  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Account',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (user != null)
            SheetSection(
              bottom: BentoSpace.section,
              child: PatientIdentityBand(
                name: user.name.isEmpty ? user.email : user.name,
                extra: [
                  if (user.role.isNotEmpty) user.role,
                  if (user.department.isNotEmpty) user.department,
                ].join(' · '),
              ),
            ),
          SheetRow(
            icon: Icons.brightness_6_outlined,
            label: 'Appearance',
            sublabel: _appearanceLabel(),
            onTap: () {
              Get.back<void>();
              _openAppearanceSheet(context);
            },
          ),
          const Hairline(),
          SheetRow(
            key: HomeKeys.signOut,
            icon: Icons.logout_rounded,
            label: 'Sign out',
            // Destructive in the sense that matters on a shared ward tablet:
            // the next person gets a sign-in screen, and anything half-typed
            // is gone.
            destructive: true,
            onTap: () async {
              Get.back<void>();
              await controller.signOut();
            },
          ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

String _appearanceLabel() => switch (AppThemeController.to.themeMode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'Match device',
    };

Future<void> _openAppearanceSheet(BuildContext context) {
  final themeCtrl = AppThemeController.to;
  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Appearance',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final mode in ThemeMode.values)
            SheetRow(
              icon: switch (mode) {
                ThemeMode.light => Icons.light_mode_outlined,
                ThemeMode.dark => Icons.dark_mode_outlined,
                ThemeMode.system => Icons.phone_android_outlined,
              },
              label: switch (mode) {
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
                ThemeMode.system => 'Match device',
              },
              sublabel: mode == ThemeMode.dark
                  // Worth saying, because on a night shift it is the whole
                  // reason somebody opened this sheet.
                  ? 'Easier on the eyes on a night shift'
                  : null,
              selected: themeCtrl.themeMode == mode,
              onTap: () {
                themeCtrl.setMode(mode);
                Get.back<void>();
              },
            ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

/// The tab bar.
///
/// Flat on the ground rather than floating over it: a floating bar needs a
/// blur to stay legible above scrolling content, and a blur is the single most
/// expensive thing a Flutter screen can do — it reads back and re-blurs
/// everything under it on every frame the content moves. On a ward tablet
/// running a list that refreshes every thirty seconds, that is a cost paid
/// continuously for decoration.
class _ShellTabBar extends StatelessWidget {
  const _ShellTabBar({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(
      () => DecoratedBox(
        decoration: BoxDecoration(
          color: surfaceColor(context),
          border: Border(top: BorderSide(color: hairlineColor(context))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            key: HomeKeys.tabBar,
            height: 60,
            child: Row(
              children: [
                for (var i = 0; i < controller.destinations.length; i++)
                  Expanded(
                    child: _Tab(
                      key: HomeKeys.tab(controller.destinations[i].route),
                      destination: controller.destinations[i],
                      selected: controller.activeIndex == i,
                      isDark: isDark,
                      onTap: () => controller.select(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.destination,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final ShellDestination destination;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Brand ink, not the brand fill: the fill is for shapes, and a tab label
    // set in a mid-luminance brand on a white bar is 4.35:1 at best.
    final tint = selected ? brandInkColor(context) : tertiaryLabelColor(context);

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: motionDuration(context),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? brandTonalColor(context) : Colors.transparent,
                borderRadius: BorderRadius.circular(BentoRadius.pill),
              ),
              child: Icon(
                selected ? destination.activeIcon : destination.icon,
                size: 22,
                color: tint,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.text(
                fontSize: 11,
                // Weight as well as colour, so the active tab is still
                // identifiable in a screenshot printed in black and white —
                // and to anyone who cannot separate the two tints.
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: tint,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
