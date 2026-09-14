import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/settings_profile_keys.dart';
import '../../../data/network/endpoints.dart';
import '../../../theme/theme.dart';
import '../controllers/settings_profile_controller.dart';

/// The hospital, as it introduces itself.
///
/// Grouped the way somebody filling it in thinks about it rather than the way
/// the column is laid out: who we are, how to reach us, what we look like. The
/// slug sits in the first group, shown and not editable — it is in other
/// systems' references and in every link anybody has bookmarked, so a form that
/// offered to change it would be offering to break those.
class SettingsProfileView extends GetView<SettingsProfileController> {
  const SettingsProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root of the build, or the `lazyPut` never happens and
    // `onReady` never fetches.
    final c = controller;

    return Scaffold(
      key: SettingsProfileKeys.screen,
      appBar: const DetailHeader(title: 'Hospital profile'),
      body: BentoGround(
        child: SafeArea(
          child: Obx(() {
            if (c.hasNoAccess) return const _NoAccess();
            if (c.rxFirstLoad.value && c.isLoading) return const _Skeleton();

            return Form(
              key: c.formKey,
              child: BentoScreen(
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
                  BentoSection(
                    top: BentoSpace.section,
                    child: _identity(context, c),
                  ),
                  BentoSection(child: _contact(c)),
                  BentoSection(child: _marks(context, c)),
                  BentoSection(child: _brand(context, c)),
                ],
              ),
            );
          }),
        ),
      ),
      bottomNavigationBar: Obx(() {
        // Absent, not disabled. The route guard already asks for
        // `settings.update`, but an access map in hand can be a minute older
        // than the role it describes.
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FieldErrorSummary(
                    key: SettingsProfileKeys.errors,
                    count: c.rxSubmitted.value ? c.invalidFieldCount : 0,
                  ),
                ),
                PrimaryBar(
                  key: SettingsProfileKeys.save,
                  label: 'Save',
                  busy: c.rxLoading.value,
                  enabled: c.canSave,
                  onPressed: c.save,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _identity(BuildContext context, SettingsProfileController c) =>
      FormCard(
        title: 'This hospital',
        children: [
          BentoInput(
            fieldKey: SettingsProfileKeys.name,
            label: 'Name',
            controller: c.name,
            required: true,
            validator: c.validateName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            hint: 'What the shell, the sign-in screen and every document call '
                'this site',
          ),
          BentoField(
            label: 'Short name',
            hint: 'Fixed when the site was created. It is in links and in '
                'other systems’ references, so it is not changed from here.',
            child: InsetSurface(
              key: SettingsProfileKeys.slug,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              child: Text(
                c.rxSlug.value.isEmpty ? '—' : c.rxSlug.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.text(
                  fontSize: 16,
                  color: secondaryLabelColor(context),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _contact(SettingsProfileController c) => FormCard(
        title: 'How to reach it',
        children: [
          BentoInput(
            fieldKey: SettingsProfileKeys.email,
            label: 'Email',
            controller: c.email,
            validator: c.validateEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            hint: 'Where replies to this hospital’s documents go',
          ),
          BentoInput(
            fieldKey: SettingsProfileKeys.phone,
            label: 'Phone',
            controller: c.phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          BentoInput(
            fieldKey: SettingsProfileKeys.address,
            label: 'Address',
            controller: c.address,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
          ),
          BentoInput(
            fieldKey: SettingsProfileKeys.city,
            label: 'City',
            controller: c.city,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          BentoInput(
            fieldKey: SettingsProfileKeys.region,
            label: 'Region or state',
            controller: c.region,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          BentoInput(
            fieldKey: SettingsProfileKeys.country,
            label: 'Country',
            controller: c.country,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
          ),
        ],
      );

  Widget _marks(BuildContext context, SettingsProfileController c) => FormCard(
        title: 'Marks',
        children: [
          const SizedBox(height: 8),
          _MarkRow(
            label: 'Logo',
            sublabel: 'The symbol on the sign-in screen and on documents',
            url: c.rxLogoUrl.value,
            busy: c.rxUploading.value,
            buttonKey: SettingsProfileKeys.logoUpload,
            onPick: () => c.pickLogo(wordmark: false),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Hairline(),
          ),
          _MarkRow(
            label: 'Wordmark',
            sublabel: 'Where a site draws its name separately from its symbol',
            url: c.rxLogoTextUrl.value,
            busy: c.rxUploading.value,
            buttonKey: SettingsProfileKeys.logoTextUpload,
            onPick: () => c.pickLogo(wordmark: true),
          ),
          if (c.rxUploadError.value != null) ...[
            const SizedBox(height: 14),
            NoticeBanner(
              key: SettingsProfileKeys.uploadError,
              message: c.rxUploadError.value!,
              icon: Icons.error_outline_rounded,
              tint: AppColors.error,
            ),
          ] else if (c.hasUnsavedMark) ...[
            const SizedBox(height: 14),
            // The image on screen is not yet on the record. Said out loud,
            // because an upload that has visibly worked reads as done — and
            // leaving the screen now would lose it.
            const NoticeBanner(
              key: SettingsProfileKeys.logoPending,
              message: 'Uploaded, but not on the record until you save.',
              icon: Icons.schedule_rounded,
              tint: AppColors.warning,
            ),
          ],
        ],
      );

  Widget _brand(BuildContext context, SettingsProfileController c) => FormCard(
        title: 'Brand colours',
        children: [
          BentoField(
            label: 'Primary',
            hint: 'The brand as a fill — buttons, the active tab, the '
                'letterhead band.',
            child: _SwatchRow(
              swatches: c.primarySwatches,
              selected: c.rxPrimary.value,
              onSelected: c.selectPrimary,
              keyOf: SettingsProfileKeys.primarySwatch,
            ),
          ),
          BentoField(
            label: 'Secondary',
            hint: 'Used sparingly beside the primary. Never for a patient’s '
                'state — those have their own colours and this must not '
                'collide with them.',
            child: _SwatchRow(
              swatches: c.secondarySwatches,
              selected: c.rxSecondary.value,
              onSelected: c.selectSecondary,
              keyOf: SettingsProfileKeys.secondarySwatch,
            ),
          ),
        ],
      );
}

/// One mark, its preview and the control that replaces it.
class _MarkRow extends StatelessWidget {
  const _MarkRow({
    required this.label,
    required this.sublabel,
    required this.url,
    required this.busy,
    required this.buttonKey,
    required this.onPick,
  });

  final String label;
  final String sublabel;
  final String url;
  final bool busy;
  final Key buttonKey;
  final Future<bool> Function() onPick;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        InsetSurface(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 44,
            height: 44,
            child: url.isEmpty
                ? Icon(
                    Icons.image_outlined,
                    size: 22,
                    color: tertiaryLabelColor(context),
                  )
                : Image.network(
                    Endpoints.fileUrl(url),
                    fit: BoxFit.contain,
                    // A mark that will not load must not take the row with it:
                    // the upload still worked, and the placeholder says so
                    // better than a broken-image glyph would.
                    errorBuilder: (context, error, stack) => Icon(
                      Icons.broken_image_outlined,
                      size: 22,
                      color: tertiaryLabelColor(context),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: isDark
                    ? AppTextStyles.darkCallout(weight: FontWeight.w600)
                    : AppTextStyles.lightCallout(weight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: isDark
                    ? AppTextStyles.darkFootnote()
                    : AppTextStyles.lightFootnote(),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        TextButton(
          key: buttonKey,
          onPressed: busy ? null : () => onPick(),
          child: Text(url.isEmpty ? 'Add' : 'Replace'),
        ),
      ],
    );
  }
}

/// A row of brand colours, drawn as the colours they are.
///
/// Named would tell somebody nothing: "Plum" does not say what the ward board
/// will look like. Each swatch carries a check when it is the chosen one, so
/// the selection is readable without relying on the ring alone.
class _SwatchRow extends StatelessWidget {
  const _SwatchRow({
    required this.swatches,
    required this.selected,
    required this.onSelected,
    required this.keyOf,
  });

  final List<String> swatches;
  final String selected;
  final ValueChanged<String> onSelected;
  final Key Function(String hex) keyOf;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final hex in swatches)
          _Swatch(
            key: keyOf(hex),
            hex: hex,
            selected: hex.toLowerCase() == selected.trim().toLowerCase(),
            onTap: () => onSelected(hex),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  /// `#0E7C7B` or `#0E7`, as the DTO's own pattern allows. Anything else
  /// paints as the ground's hairline rather than throwing inside a form.
  Color get _color {
    var digits = hex.trim().replaceFirst('#', '');
    if (digits.length == 3) {
      digits = digits.split('').map((c) => '$c$c').join();
    }
    final value = int.tryParse(digits, radix: 16);
    return value == null || digits.length != 6
        ? const Color(0xFF94A3B8)
        : Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return InkWell(
      key: ValueKey('${hex}_tap'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(BentoRadius.control),
      // Comfortably past the 48 dp floor: some of these users are wearing
      // gloves.
      child: SizedBox(
        width: 52,
        height: 52,
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? labelColor(context) : hairlineColor(context),
                width: selected ? 2.5 : 1,
              ),
            ),
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    size: 20,
                    // Measured against the swatch rather than assumed: a pale
                    // brand with a white tick on it is a swatch nobody can see
                    // the selection on.
                    color:
                        BrandPalette.contrastRatio(color, Colors.white) >= 3.0
                            ? Colors.white
                            : const Color(0xFF0B1416),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => const BentoScreen(
        ground: false,
        bottomClearance: false,
        slivers: [
          BentoSection(top: BentoSpace.section, child: BentoSkeleton(rows: 3)),
          BentoSection(child: BentoSkeleton(rows: 5)),
        ],
      );
}

class _NoAccess extends StatelessWidget {
  const _NoAccess();

  @override
  Widget build(BuildContext context) => const Center(
        child: EmptyState(
          key: SettingsProfileKeys.noAccess,
          icon: Icons.lock_outline_rounded,
          title: 'Not yours to change',
          message: 'An administrator can give your account permission to edit '
              'this hospital’s profile.',
        ),
      );
}
