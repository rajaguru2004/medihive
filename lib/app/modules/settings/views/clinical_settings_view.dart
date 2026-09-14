import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../theme/theme.dart';
import '../controllers/clinical_settings_controller.dart';

/// The four settings that change what a clinical screen does.
///
/// Each is worded as its consequence, not its field name. "Flag a wait after"
/// is what the setting does; `waitBreachMinutes` is what the column is called,
/// and nobody configuring a hospital should have to know that.
class ClinicalSettingsView extends GetView<ClinicalSettingsController> {
  const ClinicalSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;

    return Scaffold(
      key: SettingsKeys.clinical,
      appBar: const DetailHeader(title: 'Clinical settings'),
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

                BentoSection(
                  top: BentoSpace.section,
                  child: FormCard(
                    title: 'The queue board',
                    children: [
                      QuantityField(
                        label: 'Flag a wait after (minutes)',
                        fieldKey: SettingsKeys.waitBreach,
                        controller: c.waitBreach,
                      ),
                      // Zero is a real setting, not an empty one: a clinic
                      // that does not work to a wait target should not have a
                      // board full of flags nobody acts on. Said out loud, or
                      // the field reads as one somebody forgot to fill in.
                      _Helper(text: c.waitBreachHelper),
                      BentoPicker(
                        key: SettingsKeys.triageScale,
                        label: 'Triage scale',
                        value: ClinicalSettingsController.triageScaleLabel(
                          c.triageScale,
                        ),
                        hint: 'Which vocabulary the triage picker offers.',
                        onTap: () => _pickScale(context, c),
                      ),
                    ],
                  ),
                ),

                BentoSection(
                  child: FormCard(
                    title: 'Privacy',
                    children: [
                      BentoSwitchRow(
                        switchKey: SettingsKeys.showNames,
                        label: 'Show patient names on boards',
                        // The reason this exists, stated. A waiting room can
                        // see a wall-mounted board, and the bed map keeps its
                        // shape either way — it just loses the column that
                        // identifies somebody.
                        sublabel: 'Turn off where a screen is visible from a '
                            'waiting area.',
                        value: c.showPatientNames,
                        onChanged: c.setShowNames,
                      ),
                    ],
                  ),
                ),

                BentoSection(
                  child: FormCard(
                    title: 'Shared devices',
                    children: [
                      QuantityField(
                        label: 'Lock this device after (minutes idle)',
                        fieldKey: SettingsKeys.sessionLock,
                        controller: c.sessionLock,
                      ),
                      _Helper(text: c.sessionLockHelper),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Obx(
        () => PrimaryBar(
          key: SettingsKeys.clinicalSave,
          label: 'Save',
          busy: c.rxLoading.value,
          enabled: c.canSave,
          onPressed: c.save,
        ),
      ),
    );
  }

  Future<void> _pickScale(
    BuildContext context,
    ClinicalSettingsController c,
  ) =>
      Get.bottomSheet<void>(
        SheetShell(
          title: 'Triage scale',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final id in ClinicalSettingsController.triageScales)
                SheetRow(
                  icon: Icons.local_hospital_outlined,
                  label: ClinicalSettingsController.triageScaleLabel(id),
                  selected: c.triageScale == id,
                  onTap: () {
                    c.setTriageScale(id);
                    Get.back<void>();
                  },
                ),
            ],
          ),
        ),
        isScrollControlled: true,
      );
}

/// A line of explanation under a field.
///
/// The kit's inputs carry a hint, not a live one — these two change with the
/// value (zero means "off", which is the opposite of what an empty field looks
/// like), so they are drawn separately.
class _Helper extends StatelessWidget {
  const _Helper({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(
        text,
        style: Theme.of(context).brightness == Brightness.dark
            ? AppTextStyles.darkFootnote()
            : AppTextStyles.lightFootnote(),
      ),
    );
  }
}
