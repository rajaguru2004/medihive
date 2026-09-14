import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../theme/theme.dart';
import '../controllers/home_controller.dart';

/// The account surface, reached from two places.
///
/// The avatar in the shell bar opens it, and so does the More hub. Extracted
/// rather than rebuilt in both because the same action shown two ways is how a
/// user stops trusting either — and because sign-out on a shared ward tablet is
/// the one control that must look and behave identically wherever it is found.

Future<void> openAccountSheet(
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
                  if (user.role.isNotEmpty) user.roleLabel,
                  if (user.department.isNotEmpty) user.department,
                ].join(' · '),
              ),
            ),
          SheetRow(
            icon: Icons.brightness_6_outlined,
            label: 'Appearance',
            sublabel: appearanceLabel(),
            onTap: () {
              Get.back<void>();
              openAppearanceSheet(context);
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

String appearanceLabel() => switch (AppThemeController.to.themeMode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'Match device',
    };

Future<void> openAppearanceSheet(BuildContext context) {
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
