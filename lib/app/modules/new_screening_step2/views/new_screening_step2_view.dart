import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../theme/theme.dart';
import '../controllers/new_screening_step2_controller.dart';

/// Screening, step two.
///
/// The observations flag themselves as they are typed. A nurse who has just
/// entered a temperature of 39.8 should be told while the keyboard is still
/// up, not after the record is saved and somebody opens it again.
class NewScreeningStep2View extends GetView<NewScreeningStep2Controller> {
  const NewScreeningStep2View({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DetailHeader(
        title: controller.fullName.isEmpty
            ? 'New screening'
            : controller.fullName,
        subtitle: 'Step 2 of 2 · Observations',
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
                        key: ScreeningKeys.step2,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Obx(() {
                            final error = controller.errorMessage.value;
                            if (error == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: NoticeBanner(
                                key: ScreeningKeys.error,
                                message: error,
                                icon: Icons.error_outline_rounded,
                                tint: AppColors.error,
                              ),
                            );
                          }),

                          // The live flag. Appears only when an observation is
                          // actually outside its range.
                          Obx(() {
                            controller.vitalsRevision.value;
                            final flag = controller.worstFlag;
                            if (flag == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: NoticeBanner(
                                message: flag == AppColors.acuityCritical
                                    ? 'One of these readings is well outside '
                                        'the normal adult range. Consider '
                                        'escalating before routing.'
                                    : 'One of these readings is outside the '
                                        'normal adult range.',
                                icon: Icons.monitor_heart_outlined,
                                tint: flag,
                              ),
                            );
                          }),

                          FormCard(
                            title: 'Presentation',
                            children: [
                              BentoInput(
                                fieldKey: ScreeningKeys.complaintField,
                                label: 'Chief complaint',
                                controller: controller.complaintController,
                                validator: controller.validateComplaint,
                                required: true,
                                maxLines: 2,
                                autofocus: true,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                hint: 'In their own words where you can',
                              ),
                              BentoInput(
                                fieldKey: ScreeningKeys.notesField,
                                label: 'Brief history',
                                controller: controller.historyController,
                                maxLines: 4,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                hint: 'Duration, relevant history, '
                                    'medication',
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
                                  fieldKey: ScreeningKeys.temperatureField,
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
                                  fieldKey: ScreeningKeys.pulseField,
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
                              // Systolic and diastolic side by side, because
                              // they are one reading taken once and a nurse
                              // types them as a pair.
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Obx(() {
                                      controller.vitalsRevision.value;
                                      return VitalInput(
                                        fieldKey:
                                            ScreeningKeys.bpSystolicField,
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
                                        fieldKey:
                                            ScreeningKeys.bpDiastolicField,
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
                                  key: ScreeningKeys.acuityPicker,
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
                    child: Row(
                      children: [
                        Expanded(
                          child: SecondaryBar(
                            key: ScreeningKeys.step2Back,
                            label: 'Back',
                            icon: Icons.arrow_back_rounded,
                            onPressed: Get.back,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Obx(
                            () => PrimaryBar(
                              key: ScreeningKeys.submit,
                              label: 'Save screening',
                              busy: controller.isSubmitting.value,
                              onPressed: controller.save,
                            ),
                          ),
                        ),
                      ],
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

Future<void> _openRoutePicker(NewScreeningStep2Controller controller) {
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
            sublabel: 'Leaves the screening open on the board',
            selected: controller.route.value == null,
            onTap: () {
              controller.route.value = null;
              Get.back<void>();
            },
          ),
          const Hairline(),
          for (final route in NewScreeningStep2Controller.routes)
            SheetRow(
              icon: switch (route) {
                'Emergency' => Icons.emergency_outlined,
                'Laboratory' => Icons.science_outlined,
                'Pharmacy' => Icons.medication_outlined,
                'Radiology' => Icons.monitor_heart_outlined,
                'Pediatrics' => Icons.child_care_outlined,
                'Orthopedics' => Icons.accessibility_new_rounded,
                _ => Icons.meeting_room_outlined,
              },
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
