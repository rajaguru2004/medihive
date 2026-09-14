import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_clock.dart';
import '../../../core/keys/patient_form_keys.dart';
import '../../../core/unsaved_changes.dart';
import '../../../data/services/settings_service.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../controllers/patient_form_controller.dart';

/// Registering a patient, and editing one.
///
/// Grouped the way a front desk actually collects it: who they are, how to
/// reach them, who to call, who pays, and what a prescriber has to know before
/// they write anything. The clinical group is last on the screen and first in
/// importance, which is why the hub repeats it at the top.
class PatientFormView extends GetView<PatientFormController> {
  const PatientFormView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root: a `GetView` whose build never touches `controller`
    // never constructs it, and the record would never load.
    final isEdit = controller.isEdit;

    return UnsavedChangesGuard(
      isDirty: () => controller.isDirty,
      discardKey: PatientFormKeys.discard,
      keepKey: PatientFormKeys.keepEditing,
      title: 'Leave without saving?',
      message: 'This registration will be lost. This cannot be undone.',
      child: Scaffold(
        key: PatientFormKeys.screen,
        // No subtitle carrying the MRN. `DetailHeader` is a
        // `PreferredSizeWidget` and cannot be wrapped in an `Obx`, so a
        // subtitle read here would be whatever the record held before it
        // loaded — a blank line on every edit, forever.
        appBar: DetailHeader(
          title: isEdit ? 'Edit patient' : 'Register patient',
        ),
        body: BentoGround(
          child: SafeArea(
            child: Obx(() {
              if (controller.hasNoAccess) {
                return const _Centred(
                  child: EmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Not available to your role',
                    message: 'Ask an administrator if you need to change '
                        'patient records.',
                  ),
                );
              }

              if (controller.isLoading && controller.rxFirstLoad.value) {
                return const _Centred(child: BentoSkeleton(rows: 5));
              }

              if (controller.hasLoadError) {
                return _Centred(
                  child: ErrorRetryBanner(
                    key: PatientFormKeys.loadError,
                    message: controller.rxLoadError.value!,
                    onRetry: controller.load,
                  ),
                );
              }

              return _FormBody(controller: controller);
            }),
          ),
        ),
      ),
    );
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({required this.controller});

  final PatientFormController controller;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: controller.formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                BentoSpace.page,
                BentoSpace.action,
                BentoSpace.page,
                BentoSpace.page,
              ),
              child: MaxWidthBody(
                maxWidth: 560,
                child: Column(
                  key: PatientFormKeys.form,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Obx(() {
                      final error = controller.submitError.value;
                      if (error == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: NoticeBanner(
                          key: PatientFormKeys.error,
                          message: error,
                          icon: Icons.error_outline_rounded,
                          tint: AppColors.error,
                        ),
                      );
                    }),
                    _Identity(controller: controller),
                    const SizedBox(height: BentoSpace.section),
                    _Contact(controller: controller),
                    const SizedBox(height: BentoSpace.section),
                    _Emergency(controller: controller),
                    const SizedBox(height: BentoSpace.section),
                    _Insurance(controller: controller),
                    const SizedBox(height: BentoSpace.section),
                    _Clinical(controller: controller),
                    if (controller.isEdit) ...[
                      const SizedBox(height: BentoSpace.section),
                      _Status(controller: controller),
                    ],
                  ],
                ),
              ),
            ),
          ),
          _SaveBar(controller: controller),
        ],
      ),
    );
  }
}

// ── Identity ────────────────────────────────────────────────────────────────

class _Identity extends StatelessWidget {
  const _Identity({required this.controller});

  final PatientFormController controller;

  @override
  Widget build(BuildContext context) {
    final now = AppClock.now();

    return FormCard(
      title: 'Identity',
      children: [
        BentoInput(
          fieldKey: PatientFormKeys.firstName,
          label: 'First name',
          controller: controller.firstName,
          validator: controller.validateGivenName,
          required: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        BentoInput(
          fieldKey: PatientFormKeys.middleName,
          label: 'Middle name',
          controller: controller.middleName,
          validator: controller.validateMiddleName,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        BentoInput(
          fieldKey: PatientFormKeys.lastName,
          label: 'Last name',
          controller: controller.lastName,
          validator: controller.validateFamilyName,
          required: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        Obx(
          () => DateField(
            fieldKey: PatientFormKeys.dateOfBirth,
            label: 'Date of birth',
            value: controller.dateOfBirth.value,
            required: true,
            error: controller.dateOfBirthError.value,
            // No quick picks: "Today" and "In 30 days" are answers to a due
            // date, and a date of birth is always a day on a calendar.
            quickPicks: false,
            firstDate: DateTime(now.year - 120),
            // Nobody is born tomorrow, and a future date of birth makes every
            // age on every screen negative.
            lastDate: now,
            format: SettingsService.to.date,
            onChanged: (value) {
              controller.dateOfBirth.value = value;
              controller.dateOfBirthError.value = null;
            },
          ),
        ),
        Obx(
          () => BentoField(
            label: 'Sex',
            required: true,
            error: controller.sexError.value,
            child: BentoSegmented<String>(
              options: PatientFormController.sexes,
              // Nothing matches the empty string, so no segment is lit until
              // somebody chooses one. A control that pre-selects "male" is a
              // control that records it for every patient nobody touched.
              selected: controller.sex.value ?? '',
              labelOf: Formatters.label,
              keyOf: PatientFormKeys.sex,
              onSelected: (value) {
                controller.sex.value = value;
                controller.sexError.value = null;
              },
            ),
          ),
        ),
        Obx(
          () => BentoPicker(
            fieldKey: PatientFormKeys.bloodGroup,
            label: 'Blood group',
            value: controller.bloodGroup.value,
            placeholder: 'Not recorded',
            hint: 'Leave it unset rather than guessing',
            onTap: () => _pickBloodGroup(controller),
          ),
        ),
      ],
    );
  }
}

Future<void> _pickBloodGroup(PatientFormController controller) {
  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Blood group',
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final group in PatientFormController.bloodGroups)
            SheetRow(
              icon: Icons.water_drop_outlined,
              label: group,
              selected: controller.bloodGroup.value == group,
              onTap: () {
                controller.bloodGroup.value = group;
                Get.back<void>();
              },
            ),
          SheetRow(
            icon: Icons.clear_rounded,
            label: 'Not recorded',
            selected: controller.bloodGroup.value == null,
            onTap: () {
              controller.bloodGroup.value = null;
              Get.back<void>();
            },
          ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

// ── Contact ─────────────────────────────────────────────────────────────────

class _Contact extends StatelessWidget {
  const _Contact({required this.controller});

  final PatientFormController controller;

  @override
  Widget build(BuildContext context) {
    return FormCard(
      title: 'Contact',
      children: [
        BentoInput(
          fieldKey: PatientFormKeys.phonePrimary,
          label: 'Phone',
          controller: controller.phonePrimary,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          hint: 'Searched on, so it is worth getting right',
        ),
        BentoInput(
          fieldKey: PatientFormKeys.phoneSecondary,
          label: 'Second phone',
          controller: controller.phoneSecondary,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        BentoInput(
          fieldKey: PatientFormKeys.email,
          label: 'Email',
          controller: controller.email,
          validator: controller.validateEmail,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        // The address as this backend stores it: region, zone, woreda, kebele,
        // house number, then a free line for the landmark people actually
        // navigate by. Widest unit first, which is the order it is said in.
        BentoInput(
          fieldKey: PatientFormKeys.region,
          label: 'Region',
          controller: controller.region,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        BentoInput(
          fieldKey: PatientFormKeys.zone,
          label: 'Zone or sub-city',
          controller: controller.zone,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        BentoInput(
          fieldKey: PatientFormKeys.woreda,
          label: 'Woreda',
          controller: controller.woreda,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        BentoInput(
          fieldKey: PatientFormKeys.kebele,
          label: 'Kebele',
          controller: controller.kebele,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        BentoInput(
          fieldKey: PatientFormKeys.houseNumber,
          label: 'House number',
          controller: controller.houseNumber,
          textInputAction: TextInputAction.next,
        ),
        BentoInput(
          fieldKey: PatientFormKeys.addressDescription,
          label: 'Directions',
          controller: controller.addressDescription,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          hint: 'The landmark an ambulance would be told',
        ),
      ],
    );
  }
}

// ── Emergency contact ───────────────────────────────────────────────────────

class _Emergency extends StatelessWidget {
  const _Emergency({required this.controller});

  final PatientFormController controller;

  @override
  Widget build(BuildContext context) {
    return FormCard(
      title: 'Emergency contact',
      children: [
        BentoInput(
          fieldKey: PatientFormKeys.emergencyName,
          label: 'Name',
          controller: controller.emergencyName,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        BentoInput(
          fieldKey: PatientFormKeys.emergencyPhone,
          label: 'Phone',
          controller: controller.emergencyPhone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        BentoInput(
          fieldKey: PatientFormKeys.emergencyRelationship,
          label: 'Relationship',
          controller: controller.emergencyRelationship,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          hint: 'Spouse, parent, neighbour',
        ),
      ],
    );
  }
}

// ── Insurance ───────────────────────────────────────────────────────────────

class _Insurance extends StatelessWidget {
  const _Insurance({required this.controller});

  final PatientFormController controller;

  @override
  Widget build(BuildContext context) {
    final now = AppClock.now();

    return Obx(
      () => FormCard(
        title: 'Insurance',
        children: [
          BentoSwitchRow(
            switchKey: PatientFormKeys.hasInsurance,
            label: 'Has cover',
            sublabel: 'Turns the policy details on',
            value: controller.hasInsurance.value,
            onChanged: (value) => controller.hasInsurance.value = value,
          ),
          // Revealed rather than greyed: an empty policy block on every
          // self-paying patient is four fields of furniture on a form that is
          // already long.
          if (controller.hasInsurance.value) ...[
            BentoInput(
              fieldKey: PatientFormKeys.insuranceProvider,
              label: 'Provider',
              controller: controller.insuranceProvider,
              validator: controller.validateInsuranceProvider,
              required: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            BentoInput(
              fieldKey: PatientFormKeys.insuranceId,
              label: 'Policy number',
              controller: controller.insuranceId,
              textInputAction: TextInputAction.next,
            ),
            DateField(
              fieldKey: PatientFormKeys.insuranceExpiry,
              label: 'Cover expires',
              value: controller.insuranceExpiry.value,
              quickPicks: false,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 20),
              format: SettingsService.to.date,
              hint: 'Leave it blank rather than guessing — no date is not the '
                  'same as expired',
              onChanged: (value) => controller.insuranceExpiry.value = value,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Clinical ────────────────────────────────────────────────────────────────

class _Clinical extends StatelessWidget {
  const _Clinical({required this.controller});

  final PatientFormController controller;

  @override
  Widget build(BuildContext context) {
    return FormCard(
      title: 'Clinical',
      children: [
        _ChipListField(
          name: 'allergy',
          label: 'Allergies',
          hint: 'One at a time. A prescriber checks this before every script.',
          placeholder: 'Penicillin',
          icon: Icons.warning_amber_rounded,
          fieldKey: PatientFormKeys.allergyField,
          addKey: PatientFormKeys.allergyAdd,
          controller: controller,
          list: controller.allergies,
        ),
        _ChipListField(
          name: 'condition',
          label: 'Chronic conditions',
          hint: 'Hypertension, diabetes, asthma',
          placeholder: 'Hypertension',
          icon: Icons.monitor_heart_outlined,
          fieldKey: PatientFormKeys.conditionField,
          addKey: PatientFormKeys.conditionAdd,
          controller: controller,
          list: controller.chronicConditions,
        ),
        _ChipListField(
          name: 'medication',
          label: 'Current medications',
          hint: 'What they are already taking, with the dose',
          placeholder: 'Lisinopril 10mg',
          icon: Icons.medication_outlined,
          fieldKey: PatientFormKeys.medicationField,
          addKey: PatientFormKeys.medicationAdd,
          controller: controller,
          list: controller.currentMedications,
        ),
        BentoInput(
          fieldKey: PatientFormKeys.notes,
          label: 'Notes',
          controller: controller.notes,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          hint: 'Anything the desk needs to know — an interpreter, a '
              'wheelchair',
        ),
      ],
    );
  }
}

/// A list of short entries, typed one at a time.
///
/// Deliberately not a comma-separated text field: "Penicillin, Sulfa" in one
/// box is one allergy as far as the column is concerned, and the list a
/// prescriber reads is then one line long whatever is in it.
class _ChipListField extends StatefulWidget {
  const _ChipListField({
    required this.name,
    required this.label,
    required this.hint,
    required this.placeholder,
    required this.icon,
    required this.fieldKey,
    required this.addKey,
    required this.controller,
    required this.list,
  });

  final String name;
  final String label;
  final String hint;
  final String placeholder;
  final IconData icon;
  final Key fieldKey;
  final Key addKey;
  final PatientFormController controller;
  final RxList<String> list;

  @override
  State<_ChipListField> createState() => _ChipListFieldState();
}

class _ChipListFieldState extends State<_ChipListField> {
  final _entry = TextEditingController();

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  void _add() {
    widget.controller.addTo(widget.list, _entry.text);
    _entry.clear();
    // The field empties whether or not the entry was a duplicate: re-typing
    // something already on the list is the one case where saying nothing is
    // right, because the list already says it.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        BentoInput(
          fieldKey: widget.fieldKey,
          label: widget.label,
          controller: _entry,
          hint: widget.hint,
          placeholder: widget.placeholder,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _add(),
          suffix: IconButton(
            key: widget.addKey,
            onPressed: _add,
            icon: const Icon(Icons.add_rounded, size: 20),
            tooltip: 'Add',
          ),
        ),
        Obx(() {
          if (widget.list.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in widget.list)
                  ActiveFilterChip(
                    chipKey: PatientFormKeys.chip(widget.name, value),
                    label: value,
                    icon: widget.icon,
                    onClear: () =>
                        widget.controller.removeFrom(widget.list, value),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Status ──────────────────────────────────────────────────────────────────

class _Status extends StatelessWidget {
  const _Status({required this.controller});

  final PatientFormController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => FormCard(
        title: 'Record',
        children: [
          BentoSwitchRow(
            switchKey: PatientFormKeys.isActive,
            label: 'Active',
            sublabel: 'An inactive record stays on every visit it is already '
                'on. It stops appearing in pickers.',
            value: controller.isActive.value,
            onChanged: (value) => controller.isActive.value = value,
          ),
        ],
      ),
    );
  }
}

// ── Save ────────────────────────────────────────────────────────────────────

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.controller});

  final PatientFormController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BentoSpace.page,
        0,
        BentoSpace.page,
        BentoSpace.page,
      ),
      child: MaxWidthBody(
        maxWidth: 560,
        child: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.invalidCount.value > 0) ...[
                FieldErrorSummary(count: controller.invalidCount.value),
                const SizedBox(height: BentoSpace.action),
              ],
              PrimaryBar(
                key: PatientFormKeys.save,
                label: controller.isEdit ? 'Save changes' : 'Register patient',
                busy: controller.isSubmitting.value,
                onPressed: controller.save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the states that is not the form, at the page's own margin.
class _Centred extends StatelessWidget {
  const _Centred({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(BentoSpace.page),
        child: MaxWidthBody(maxWidth: 560, child: child),
      );
}
