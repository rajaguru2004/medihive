import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../theme/theme.dart';
import '../controllers/new_screening_step1_controller.dart';

/// Screening, step one.
class NewScreeningStep1View extends GetView<NewScreeningStep1Controller> {
  const NewScreeningStep1View({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DetailHeader(
        title: 'New screening',
        subtitle: 'Step 1 of 2 · Who',
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
                        key: ScreeningKeys.step1,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FormCard(
                            title: 'Identity',
                            children: [
                              BentoInput(
                                fieldKey: ScreeningKeys.nameField,
                                label: 'First name',
                                controller: controller.firstNameController,
                                validator: controller.validateFirstName,
                                required: true,
                                autofocus: true,
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
                                    key: ScreeningKeys.sexPicker,
                                    options:
                                        NewScreeningStep1Controller.sexes,
                                    selected: controller.sex.value ??
                                        NewScreeningStep1Controller.sexes.last,
                                    labelOf: (value) => value,
                                    keyOf: ScreeningKeys.sexOption,
                                    onSelected: (value) =>
                                        controller.sex.value = value,
                                  ),
                                ),
                              ),
                              BentoInput(
                                fieldKey: ScreeningKeys.ageField,
                                label: 'Age',
                                controller: controller.ageController,
                                validator: controller.validateAge,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                hint: 'Leave blank if unknown',
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
                                fieldKey: ScreeningKeys.phoneField,
                                label: 'Phone',
                                controller: controller.phoneController,
                                validator: controller.validatePhone,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.done,
                                hint: 'For follow-up, if they have one',
                                onSubmitted: (_) => controller.next(),
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
                    child: PrimaryBar(
                      key: ScreeningKeys.step1Next,
                      label: 'Next: observations',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: controller.next,
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
