import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/settings_modules_keys.dart';
import '../../../theme/theme.dart';
import '../controllers/settings_modules_controller.dart';

/// Which parts of the system this site runs.
///
/// The consequence of a switch here is invisible until the app next starts —
/// the shell resolves its tabs once, at boot — so the screen says that twice:
/// in a banner above the switches, and again on the confirm, naming the tabs
/// that are about to go. A toggle whose effect nobody can see is a toggle
/// people flip a second time to check.
class SettingsModulesView extends GetView<SettingsModulesController> {
  const SettingsModulesView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root of the build, or the `lazyPut` never happens and
    // `onReady` never fetches.
    final c = controller;

    return Scaffold(
      key: SettingsModulesKeys.screen,
      appBar: const DetailHeader(title: 'Core modules'),
      body: BentoGround(
        child: SafeArea(
          child: Obx(() {
            if (c.hasNoAccess) {
              return const Center(
                child: EmptyState(
                  key: SettingsModulesKeys.noAccess,
                  icon: Icons.lock_outline_rounded,
                  title: 'Not yours to change',
                  message: 'An administrator can give your account permission '
                      'to change which modules this site runs.',
                ),
              );
            }

            if (c.rxFirstLoad.value && c.isLoading) {
              return const BentoScreen(
                ground: false,
                bottomClearance: false,
                slivers: [
                  BentoSection(
                    top: BentoSpace.section,
                    child: BentoSkeleton(rows: 6),
                  ),
                ],
              );
            }

            return BentoScreen(
              ground: false,
              bottomClearance: false,
              onRefresh: c.reload,
              slivers: [
                if (c.hasLoadError)
                  BentoSection(
                    top: BentoSpace.section,
                    child: ErrorRetryBanner(
                      message: c.rxLoadError.value!,
                      onRetry: c.load,
                    ),
                  ),
                const BentoSection(
                  top: BentoSpace.section,
                  child: NoticeBanner(
                    key: SettingsModulesKeys.restartNotice,
                    // The whole reason this screen needs words on it. The shell
                    // works out its tabs once, when the app starts, so nothing
                    // here moves under anybody's thumb.
                    message: 'This is what the site licenses, not what you can '
                        'see right now. A module switched off keeps its tab '
                        'until each device next starts the app.',
                    icon: Icons.schedule_rounded,
                  ),
                ),
                BentoSection(
                  child: FormCard(
                    title: 'Modules',
                    children: [
                      for (var i = 0;
                          i < SettingsModulesController.modules.length;
                          i++) ...[
                        if (i > 0)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Hairline(),
                          ),
                        _row(c, SettingsModulesController.modules[i]),
                      ],
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
      bottomNavigationBar: Obx(() {
        // Absent, not disabled, for an account that may read settings and not
        // write them.
        if (!c.canWrite) return const SizedBox.shrink();

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BentoSpace.page,
              BentoSpace.action,
              BentoSpace.page,
              BentoSpace.page,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: FieldErrorSummary(
                    key: SettingsModulesKeys.errors,
                    // Nothing on this screen can be typed wrong — six switches
                    // have no invalid state. The summary stays so the save bar
                    // is laid out the way every other settings screen's is.
                    count: 0,
                  ),
                ),
                PrimaryBar(
                  key: SettingsModulesKeys.save,
                  label: 'Save',
                  busy: c.rxLoading.value,
                  enabled: c.canSave,
                  onPressed: () => _confirmThenSave(context, c),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _row(SettingsModulesController c, SiteModule module) =>
      BentoSwitchRow(
        switchKey: SettingsModulesKeys.module(module.key),
        label: module.title,
        sublabel: module.tab == null
            ? module.subtitle
            : '${module.subtitle} Off takes the ${module.tab} tab away.',
        value: c.isOn(module.key),
        onChanged: (on) => c.setModule(module.key, on: on),
      );

  /// Turning something off is confirmed; turning something on is not.
  ///
  /// Asymmetric on purpose. Switching a module on adds a tab somebody will
  /// find; switching one off takes a screen away from every clinician at this
  /// site, and it will not happen where they can see it — so the confirm names
  /// the tabs and says when they go.
  Future<void> _confirmThenSave(
    BuildContext context,
    SettingsModulesController c,
  ) async {
    final losing = c.turningOff;
    if (losing.isEmpty) {
      await c.save();
      return;
    }

    final tabs = c.tabsLost;
    final names = losing.map((m) => m.title).toList();

    final confirmed = await ConfirmDialog.show(
      context,
      title: names.length == 1
          ? 'Turn off ${names.single}?'
          : 'Turn off ${names.length} modules?',
      message: [
        if (tabs.isEmpty)
          'Nothing on screen changes: this build has no tab for '
              '${_list(names)} yet. The site stops licensing it.'
        else
          '${_list(tabs)} ${tabs.length == 1 ? 'disappears' : 'disappear'} '
              'from the bar on every device at this site — but only the next '
              'time each one starts the app, not now.',
        'Nothing is deleted. Turning it back on brings the tab back the same '
            'way.',
      ].join('\n\n'),
      confirmLabel: 'Turn off',
      destructive: true,
      confirmKey: SettingsModulesKeys.confirm,
      cancelKey: SettingsModulesKeys.cancel,
    );

    if (confirmed) await c.save();
  }

  /// `Lab`, `Lab and Imaging`, `Lab, Imaging and Pharmacy`.
  static String _list(List<String> items) {
    if (items.length <= 1) return items.isEmpty ? '' : items.single;
    return '${items.take(items.length - 1).join(', ')} and ${items.last}';
  }
}
