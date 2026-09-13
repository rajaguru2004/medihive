import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../theme/theme.dart';
import '../controllers/edit_screening_controller.dart';

/// Edit a screening.
///
/// One screen rather than two, because whoever is correcting a record has the
/// whole record in front of them — the two-step split exists for the door,
/// where identity and observations are two people's jobs.
class EditScreeningView extends GetView<EditScreeningController> {
  const EditScreeningView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DetailHeader(
        title: 'Edit screening',
        subtitle: controller.screening.screeningId,
      ),
      body: BentoGround(
        child: SafeArea(
          child: Form(
            key: controller.formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(BentoSpace.page),
                    child: MaxWidthBody(
                      maxWidth: 520,
                      child: Column(
                        key: ScreeningKeys.edit,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Obx(() {
                            final error = controller.errorMessage.value;
                            if (error == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: NoticeBanner(
                                message: error,
                                icon: Icons.error_outline_rounded,
                                tint: AppColors.error,
                              ),
                            );
                          }),

                          Obx(() {
                            controller.vitalsRevision.value;
                            final flag = controller.worstFlag;
                            if (flag == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: NoticeBanner(
                                message: flag == AppColors.acuityCritical
                                    ? 'One of these readings is well outside '
                                        'the normal adult range.'
                                    : 'One of these readings is outside the '
                                        'normal adult range.',
                                icon: Icons.monitor_heart_outlined,
                                tint: flag,
                              ),
                            );
                          }),

                          FormCard(
                            title: 'Identity',
                            children: [
                              BentoInput(
                                label: 'First name',
                                controller: controller.firstNameController,
                                validator: controller.validateFirstName,
                                required: true,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                              ),
                              BentoInput(
                                label: 'Last name',
                                controller: controller.lastNameController,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                              ),
                              Obx(
                                () => BentoField(
                                  label: 'Sex',
                                  child: BentoSegmented<String>(
                                    options: EditScreeningController.sexes,
                                    selected: controller.sex.value ??
                                        EditScreeningController.sexes.last,
                                    labelOf: (value) => value,
                                    onSelected: (value) =>
                                        controller.sex.value = value,
                                  ),
                                ),
                              ),
                              BentoInput(
                                label: 'Age',
                                controller: controller.ageController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                suffix: Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Text(
                                    'years',
                                    style: AppTextStyles.unit(
                                      Theme.of(context).brightness,
                                    ),
                                  ),
                                ),
                              ),
                              BentoInput(
                                label: 'Phone',
                                controller: controller.phoneController,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                              ),
                            ],
                          ),

                          const SizedBox(height: BentoSpace.section),

                          FormCard(
                            title: 'Presentation',
                            children: [
                              BentoInput(
                                label: 'Chief complaint',
                                controller: controller.complaintController,
                                validator: controller.validateComplaint,
                                required: true,
                                maxLines: 2,
                                textCapitalization:
                                    TextCapitalization.sentences,
                              ),
                              BentoInput(
                                label: 'Brief history',
                                controller: controller.historyController,
                                maxLines: 4,
                                textCapitalization:
                                    TextCapitalization.sentences,
                              ),
                            ],
                          ),

                          const SizedBox(height: BentoSpace.section),

                          FormCard(
                            title: 'Observations',
                            children: [
                              Obx(() {
                                controller.vitalsRevision.value;
                                return VitalInput(
                                  label: 'Temperature',
                                  unit: '°C',
                                  decimal: true,
                                  controller: controller.temperatureController,
                                  onChanged: controller.onVitalChanged,
                                  error: controller.validateTemperature(
                                    controller.temperatureController.text,
                                  ),
                                  hint: VitalRange.captions['temperature'],
                                  tone: VitalRange.temperature(
                                    controller.temperature,
                                  ),
                                );
                              }),
                              Obx(() {
                                controller.vitalsRevision.value;
                                return VitalInput(
                                  label: 'Pulse',
                                  unit: 'bpm',
                                  controller: controller.pulseController,
                                  onChanged: controller.onVitalChanged,
                                  error: controller.validatePulse(
                                    controller.pulseController.text,
                                  ),
                                  hint: VitalRange.captions['pulse'],
                                  tone: VitalRange.pulse(controller.pulse),
                                );
                              }),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Obx(() {
                                      controller.vitalsRevision.value;
                                      return VitalInput(
                                        label: 'BP systolic',
                                        unit: 'mmHg',
                                        controller:
                                            controller.systolicController,
                                        onChanged: controller.onVitalChanged,
                                        error: controller.validateSystolic(
                                          controller.systolicController.text,
                                        ),
                                        tone: VitalRange.bloodPressure(
                                          controller.systolic,
                                          controller.diastolic,
                                        ),
                                      );
                                    }),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Obx(() {
                                      controller.vitalsRevision.value;
                                      return VitalInput(
                                        label: 'BP diastolic',
                                        unit: 'mmHg',
                                        controller:
                                            controller.diastolicController,
                                        onChanged: controller.onVitalChanged,
                                        error: controller.validateDiastolic(
                                          controller.diastolicController.text,
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: BentoSpace.section),

                          FormCard(
                            title: 'Next',
                            children: [
                              Obx(
                                () => BentoPicker(
                                  label: 'Route to',
                                  value: controller.route.value,
                                  placeholder: 'Decide later',
                                  onTap: () => _openRoutePicker(controller),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BentoSpace.page,
                    0,
                    BentoSpace.page,
                    BentoSpace.page,
                  ),
                  child: MaxWidthBody(
                    maxWidth: 520,
                    child: Obx(
                      () => PrimaryBar(
                        key: ScreeningKeys.editSave,
                        label: 'Save changes',
                        busy: controller.isSubmitting.value,
                        onPressed: controller.save,
                      ),
                    ),
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

Future<void> _openRoutePicker(EditScreeningController controller) {
  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Route to',
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetRow(
            icon: Icons.schedule_rounded,
            label: 'Decide later',
            selected: controller.route.value == null,
            onTap: () {
              controller.route.value = null;
              Get.back<void>();
            },
          ),
          const Hairline(),
          for (final route in EditScreeningController.routes)
            SheetRow(
              icon: Icons.meeting_room_outlined,
              label: route,
              selected: controller.route.value == route,
              onTap: () {
                controller.route.value = route;
                Get.back<void>();
              },
            ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}
