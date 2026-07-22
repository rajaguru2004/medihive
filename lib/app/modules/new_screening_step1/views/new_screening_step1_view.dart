import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../../../theme/theme.dart';
import '../controllers/new_screening_step1_controller.dart';

class NewScreeningStep1View extends GetView<NewScreeningStep1Controller> {
  const NewScreeningStep1View({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: textPrimary),
          onPressed: () => Get.back(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Pre-Triage Screening',
              style: AppTextStyles.titleMedium(textPrimary),
            ),
            Text(
              'Capture basic information and vitals for a walk-in patient.',
              style: AppTextStyles.bodySmall(textSecondary),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: AppDecorations.borderLG,
              boxShadow: AppDecorations.elevation2(isDark),
              border: Border.all(
                color: isDark
                    ? AppColors.darkGlassBorder
                    : AppColors.lightGlassBorder,
                width: 0.5,
              ),
            ),
            child: Form(
              key: controller.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stepper Indicator Row
                  _buildStepperIndicator(isDark),
                  const SizedBox(height: AppSpacing.lg),

                  // Progress Bar
                  const LinearProgressIndicator(
                    value: 0.5,
                    color: AppColors.secondary,
                    backgroundColor: AppColors.lightSurfaceVariant,
                    minHeight: 4,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Text(
                    'Patient Identity',
                    style: AppTextStyles.titleMedium(textPrimary)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // First Name & Last Name (Row)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'First Name',
                          controller: controller.firstNameCtrl,
                          isDark: isDark,
                          validator: (val) {
                            if (controller.firstNameCtrl.text.trim().isEmpty &&
                                controller.phoneCtrl.text.trim().isEmpty) {
                              return 'First Name or Phone is required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildTextField(
                          label: 'Last Name',
                          controller: controller.lastNameCtrl,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Age & Gender (Row)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'Age',
                          controller: controller.ageCtrl,
                          keyboardType: TextInputType.number,
                          isDark: isDark,
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final ageVal = int.tryParse(val.trim());
                              if (ageVal == null || ageVal <= 0) {
                                return 'Enter valid age';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildGenderDropdown(isDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Phone Number
                  _buildTextField(
                    label: 'Phone',
                    controller: controller.phoneCtrl,
                    keyboardType: TextInputType.phone,
                    isDark: isDark,
                    validator: (val) {
                      if (controller.firstNameCtrl.text.trim().isEmpty &&
                          controller.phoneCtrl.text.trim().isEmpty) {
                        return 'First Name or Phone is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Cancel & Next Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Get.back(),
                        style: TextButton.styleFrom(
                          minimumSize:
                              const Size(100, AppSpacing.buttonHeightMD),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.labelLarge(textPrimary),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: controller.validateAndNavigate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppDecorations.borderMD,
                          ),
                          minimumSize:
                              const Size(120, AppSpacing.buttonHeightMD),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Next',
                              style: AppTextStyles.labelLarge(Colors.white),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 14, color: Colors.white),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepperIndicator(bool isDark) {
    return Row(
      children: [
        // Identity (Active Step)
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.15),
            borderRadius: AppDecorations.borderMD,
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.person_rounded,
                  size: 16, color: AppColors.secondary),
              const SizedBox(width: 6),
              Text(
                'Identity',
                style: AppTextStyles.labelMedium(AppColors.secondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '>',
          style: AppTextStyles.labelMedium(
            isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Clinical (Inactive Step)
        Row(
          children: [
            Icon(
              Icons.healing_outlined,
              size: 16,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              'Clinical',
              style: AppTextStyles.labelMedium(
                isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          'Step 1 of 2',
          style: AppTextStyles.labelSmall(
            isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium(textSecondary)
              .copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: AppTextStyles.bodyMedium(textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: AppDecorations.borderMD,
              borderSide: BorderSide(
                color: isDark ? AppColors.darkGlassBorder : Colors.grey[300]!,
                width: 0.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppDecorations.borderMD,
              borderSide: BorderSide(
                color: isDark ? AppColors.darkGlassBorder : Colors.grey[300]!,
                width: 0.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppDecorations.borderMD,
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown(bool isDark) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: AppTextStyles.labelMedium(textSecondary)
              .copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceVariant : Colors.grey[50],
            borderRadius: AppDecorations.borderMD,
            border: Border.all(
              color: isDark ? AppColors.darkGlassBorder : Colors.grey[300]!,
              width: 0.5,
            ),
          ),
          child: Obx(
            () => DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: controller.selectedGender.value,
                hint: Text(
                  'Select gender',
                  style: AppTextStyles.bodyMedium(textSecondary),
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary),
                dropdownColor:
                    isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: AppDecorations.borderMD,
                isExpanded: true,
                onChanged: (val) {
                  if (val != null) controller.selectGender(val);
                },
                items: controller.genders.map((e) {
                  return DropdownMenuItem<String>(
                    value: e,
                    child: Text(
                      e,
                      style: AppTextStyles.bodyMedium(textPrimary),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
