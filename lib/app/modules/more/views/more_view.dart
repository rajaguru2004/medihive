import 'package:flutter/material.dart';

import '../../../core/keys/app_keys.dart';
import '../../../core/live_obx.dart';
import '../../../theme/theme.dart';
import '../../home/controllers/home_controller.dart';
import '../../home/views/account_sheets.dart';

/// Everything this account can reach that did not fit on the bar.
///
/// A hub, not a menu: it is grouped the way the web console groups its sidebar,
/// because the two are one product and somebody who learned where Billing lives
/// there should not have to hunt for it here.
///
/// It is a shell tab rather than a pushed screen, so switching to it keeps the
/// other tabs' scroll positions and costs no refetch — and so the bar's last
/// slot always behaves like the four beside it.
class MoreView extends StatelessWidget {
  const MoreView({super.key});

  @override
  Widget build(BuildContext context) {
    // LiveObx, not Obx: HomeController is permanent and user-scoped, so during
    // a sign-out it is dropped while this tree is still mounted. LiveObx draws
    // nothing instead of reading a controller that is no longer registered.
    return LiveObx<HomeController>(
      builder: (controller) {
        final layout = controller.layout;

        return BentoScreen(
          key: MoreKeys.screen,
          // The shell paints the ground and reserves the tab bar's height.
          ground: false,
          bottomClearance: false,
          slivers: [
            if (controller.accessIsDegraded)
              const BentoSection(
                child: NoticeBanner(
                  key: MoreKeys.accessNotice,
                  icon: Icons.cloud_off_rounded,
                  // Said plainly because the consequence is real: the account
                  // may be able to do more than this list shows, and a
                  // clinician who cannot find a screen they used yesterday
                  // should know it is the connection and not their account.
                  message: 'Your permissions could not be loaded, so this list '
                      'may be short. Pull down to try again.',
                ),
              ),

            for (final (index, entry)
                in layout.moreByGroup.entries.indexed) ...[
              BentoSection(
                // The first group needs air under the app bar. Without it the
                // heading sits flush against the bar and reads as part of it
                // rather than as the start of the list.
                top: index == 0 ? BentoSpace.section : 0,
                bottom: BentoSpace.header,
                child: SectionHeader(
                  key: MoreKeys.group(entry.key.name),
                  title: entry.key.label,
                ),
              ),
              BentoSection(
                child: BentoCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < entry.value.length; i++) ...[
                        if (i > 0) const Hairline(),
                        _MoreRow(destination: entry.value[i]),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const BentoSection(
              bottom: BentoSpace.header,
              child: SectionHeader(title: 'Account'),
            ),
            BentoSection(
              child: BentoCard(
                key: MoreKeys.account,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    BentoRow(
                      title: controller.user?.name.isNotEmpty ?? false
                          ? controller.user!.name
                          : 'Signed in',
                      subtitle: [
                        if (controller.user?.role.isNotEmpty ?? false)
                          controller.user!.roleLabel,
                        if (controller.user?.department.isNotEmpty ?? false)
                          controller.user!.department,
                      ].join(' · '),
                      icon: Icons.person_outline_rounded,
                      // Opens the same sheet the avatar in the bar opens, so
                      // sign-out looks and behaves identically wherever it is
                      // reached from.
                      onTap: () => openAccountSheet(context, controller),
                    ),
                    const Hairline(),
                    BentoRow(
                      key: MoreKeys.appearance,
                      title: 'Appearance',
                      subtitle: appearanceLabel(),
                      icon: Icons.brightness_6_outlined,
                      onTap: () => openAppearanceSheet(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.destination});

  final ShellDestination destination;

  @override
  Widget build(BuildContext context) {
    return BentoRow(
      key: MoreKeys.item(destination.route),
      title: destination.title ?? destination.label,
      icon: destination.icon,
      onTap: () => HomeController.to.openDestination(destination),
    );
  }
}
