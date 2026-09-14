import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../theme/theme.dart';
import '../controllers/appearance_settings_controller.dart';

/// The site's colour and typeface.
///
/// Site-wide, unlike light and dark — that is a device preference and lives in
/// the account sheet, because a clinician picks it every night shift while a
/// hospital picks its colour once.
///
/// Each preset is shown as its actual colours rather than named, because "Plum"
/// tells somebody nothing about what their board will look like.
class AppearanceSettingsView extends GetView<AppearanceSettingsController> {
  const AppearanceSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;

    return Scaffold(
      key: SettingsKeys.appearance,
      appBar: const DetailHeader(title: 'Appearance'),
      body: BentoGround(
        child: SafeArea(
          child: Obx(
            () => BentoScreen(
              ground: false,
              bottomClearance: false,
              slivers: [
                if ((c.rxLoadError.value ?? '').isNotEmpty)
                  BentoSection(
                    top: BentoSpace.section,
                    child: ErrorRetryBanner(
                      message: c.rxLoadError.value!,
                      onRetry: c.save,
                    ),
                  ),

                const BentoSection(
                  top: BentoSpace.section,
                  bottom: BentoSpace.header,
                  child: SectionHeader(title: 'Theme'),
                ),
                BentoSection(
                  child: BentoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final preset in c.presets)
                              _PresetSwatch(
                                key: SettingsKeys.preset(preset.id),
                                palette: preset,
                                selected: c.preset == preset.id,
                                onTap: () => c.selectPreset(preset.id),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Applies to every device at this site. Light and '
                          'dark stay a personal choice, under Account.',
                          style:
                              Theme.of(context).brightness == Brightness.dark
                                  ? AppTextStyles.darkFootnote()
                                  : AppTextStyles.lightFootnote(),
                        ),
                      ],
                    ),
                  ),
                ),

                const BentoSection(
                  bottom: BentoSpace.header,
                  child: SectionHeader(title: 'Typeface'),
                ),
                BentoSection(
                  child: BentoCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < c.fonts.length; i++) ...[
                          if (i > 0) const Hairline(),
                          BentoRow(
                            key: SettingsKeys.preset('font-${c.fonts[i].id}'),
                            title: c.fonts[i].label,
                            // Set in the face being offered, so the choice is
                            // legible rather than a list of names.
                            //
                            // The only place in the app that names a font
                            // family directly. RULES §2.2 bans it because the
                            // site chooses the face and `ThemeService` applies
                            // it — but this *is* the screen where the site
                            // chooses, and a picker that renders every option
                            // in the current face shows nothing.
                            leading: Text(
                              'Aa',
                              style: TextStyle(
                                fontFamily: c.fonts[i].family,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: labelColor(context),
                              ),
                            ),
                            trailing: c.font == c.fonts[i].id
                                ? Icon(
                                    Icons.check_rounded,
                                    color: brandInkColor(context),
                                  )
                                : null,
                            showChevron: false,
                            onTap: () => c.selectFont(c.fonts[i].id),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Obx(
        () => PrimaryBar(
          key: SettingsKeys.appearanceSave,
          label: 'Save',
          busy: c.rxLoading.value,
          enabled: c.canSave,
          onPressed: c.save,
        ),
      ),
    );
  }
}

/// One theme, shown as the colours it actually produces.
class _PresetSwatch extends StatelessWidget {
  const _PresetSwatch({
    super.key,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final BrandPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BentoRadius.control),
      child: Container(
        width: 96,
        // Comfortably past the 48 dp floor: this is a target somebody taps
        // wearing gloves.
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BentoRadius.control),
          border: Border.all(
            color: selected ? palette.primary : hairlineColor(context),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Dot(color: palette.primary),
                const SizedBox(width: 4),
                _Dot(color: palette.accent),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              palette.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).brightness == Brightness.dark
                  ? AppTextStyles.darkFootnote(
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                    )
                  : AppTextStyles.lightFootnote(
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
