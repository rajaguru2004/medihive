import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../theme/theme.dart';
import '../controllers/settings_hub_controller.dart';

/// Where a hospital configures itself, from a phone.
///
/// An inset grouped list rather than a dashboard: these are settings, and a
/// settings screen that tries to be interesting is a settings screen people
/// misread. Each row says what it changes, because a list of single nouns makes
/// somebody open every one to find the one they want.
class SettingsHubView extends GetView<SettingsHubController> {
  const SettingsHubView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;

    return Scaffold(
      key: SettingsKeys.screen,
      appBar: const DetailHeader(title: 'Settings'),
      body: BentoGround(
        child: SafeArea(
          child: c.isEmpty
              ? const Center(
                  child: EmptyState(
                    key: SettingsKeys.noAccess,
                    icon: Icons.lock_outline_rounded,
                    title: 'Nothing here for your role',
                    message:
                        'An administrator can give your account access to the '
                        "hospital's settings.",
                  ),
                )
              : BentoScreen(
                  ground: false,
                  bottomClearance: false,
                  slivers: [
                    BentoSection(
                      top: BentoSpace.section,
                      child: BentoCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < c.visible.length; i++) ...[
                              if (i > 0) const Hairline(),
                              BentoRow(
                                key: SettingsKeys.row(c.visible[i].id),
                                title: c.visible[i].title,
                                subtitle: c.visible[i].subtitle,
                                subtitleMaxLines: 2,
                                onTap: () => Get.toNamed<void>(
                                  c.visible[i].route,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    BentoSection(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: BentoSpace.listPad,
                        ),
                        child: Text(
                          // Says which hospital is being configured. On a
                          // shared device an administrator covering two sites
                          // has no other way to be sure.
                          'These settings apply to ${c.siteName}.',
                          style: Theme.of(context).brightness == Brightness.dark
                              ? AppTextStyles.darkFootnote()
                              : AppTextStyles.lightFootnote(),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
