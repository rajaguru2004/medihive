import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../theme/theme.dart';
import '../controllers/inpatient_add_ward_controller.dart';

class InpatientAddWardView extends GetView<InpatientAddWardController> {
  const InpatientAddWardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DetailHeader(
        title: controller.isEdit ? 'Edit ward' : 'Add ward',
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
                        key: InpatientKeys.wardForm,
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
                          FormCard(
                            children: [
                              BentoInput(
                                fieldKey: InpatientKeys.wardNameField,
                                label: 'Ward name',
                                controller: controller.nameController,
                                validator: controller.validateName,
                                required: true,
                                textInputAction: TextInputAction.next,
                                hint: 'How staff refer to it on the floor',
                              ),
                              BentoInput(
                                label: 'Short code',
                                controller: controller.codeController,
                                validator: controller.validateCode,
                                required: true,
                                textInputAction: TextInputAction.next,
                                hint: 'Appears on bed labels and handovers',
                                inputFormatters: [
                                  // Upper-cased as typed: a code is an
                                  // identifier, and "icu" beside "ICU" is two
                                  // wards to anything that groups by it.
                                  TextInputFormatter.withFunction(
                                    (_, next) => next.copyWith(
                                      text: next.text.toUpperCase(),
                                    ),
                                  ),
                                ],
                              ),
                              Obx(
                                () => BentoPicker(
                                  key: InpatientKeys.wardTypePicker,
                                  label: 'Type',
                                  required: true,
                                  value: controller.type.value,
                                  placeholder: 'Choose a type',
                                  onTap: () => _openTypePicker(controller),
                                ),
                              ),
                              BentoInput(
                                fieldKey: InpatientKeys.wardCapacityField,
                                label: 'Beds',
                                controller: controller.capacityController,
                                validator: controller.validateCapacity,
                                required: true,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                hint: 'How many beds this ward holds',
                                onSubmitted: (_) => controller.save(),
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
                        key: InpatientKeys.wardSave,
                        label: controller.isEdit ? 'Save changes' : 'Add ward',
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

Future<void> _openTypePicker(InpatientAddWardController controller) {
  return Get.bottomSheet<void>(
    SheetShell(
      title: 'Ward type',
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final type in InpatientAddWardController.types)
            SheetRow(
              icon: Icons.meeting_room_outlined,
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
