import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../theme/theme.dart';
import '../controllers/inpatient_add_bed_controller.dart';

class InpatientAddBedView extends GetView<InpatientAddBedController> {
  const InpatientAddBedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DetailHeader(title: 'Add bed'),
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
                        key: InpatientKeys.bedForm,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Two failures that want different answers. Wards
                          // that never arrived leave the picker with nothing
                          // in it, so that one carries the retry; a save that
                          // bounced only needs saying, because the thing to
                          // try again is the button already on the screen.
                          Obx(() {
                            final loadError = controller.rxLoadError.value;
                            if (loadError == null) {
                              return const SizedBox.shrink();
                            }
                            return ErrorRetryBanner(
                              message: loadError,
                              onRetry: controller.loadWards,
                            );
                          }),
                          Obx(() {
                            final submitError = controller.errorMessage.value;
                            if (submitError == null) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: NoticeBanner(
                                message: submitError,
                                icon: Icons.error_outline_rounded,
                                tint: AppColors.error,
                              ),
                            );
                          }),
                          FormCard(
                            children: [
                              Obx(
                                () => BentoPicker(
                                  key: InpatientKeys.bedWardPicker,
                                  label: 'Ward',
                                  required: true,
                                  value: controller.ward?.name,
                                  placeholder: controller.isLoading
                                      ? 'Loading wards…'
                                      : 'Choose a ward',
                                  // BentoPicker requires a callback rather
                                  // than accepting null, so a loading picker
                                  // absorbs the tap instead of disabling it.
                                  onTap: () {
                                    if (controller.isLoading) return;
                                    _openWardPicker(controller);
                                  },
                                ),
                              ),
                              BentoInput(
                                fieldKey: InpatientKeys.bedNumberField,
                                label: 'Bed number',
                                controller: controller.bedNumberController,
                                validator: controller.validateBedNumber,
                                required: true,
                                textInputAction: TextInputAction.done,
                                hint: 'As it is labelled on the bay',
                                onSubmitted: (_) => controller.save(),
                              ),
                              Obx(
                                () => BentoPicker(
                                  key: InpatientKeys.bedTypePicker,
                                  label: 'Type',
                                  value: controller.type.value,
                                  onTap: () => _openTypePicker(controller),
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
                        key: InpatientKeys.bedSave,
                        label: 'Add bed',
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

Future<void> _openWardPicker(InpatientAddBedController controller) {
  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Ward',
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final ward in controller.activeWards)
            SheetRow(
              icon: Icons.meeting_room_outlined,
              label: ward.name,
              sublabel: '${ward.beds.length} beds',
              selected: ward.id == controller.wardId.value,
              onTap: () {
                controller.wardId.value = ward.id;
                Get.back<void>();
              },
            ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

Future<void> _openTypePicker(InpatientAddBedController controller) {
  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Bed type',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final type in InpatientAddBedController.types)
            SheetRow(
              icon: Icons.bed_outlined,
              label: type,
              selected: controller.type.value == type,
              onTap: () {
                controller.type.value = type;
                Get.back<void>();
              },
            ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}
