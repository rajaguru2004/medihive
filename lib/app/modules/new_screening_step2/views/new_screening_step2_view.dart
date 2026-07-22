import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../../../theme/theme.dart';
import '../controllers/new_screening_step2_controller.dart';

class NewScreeningStep2View extends GetView<NewScreeningStep2Controller> {
  const NewScreeningStep2View({super.key});

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
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary),
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

                  // Progress Bar (100% full)
                  const LinearProgressIndicator(
                    value: 1.0,
                    color: AppColors.secondary,
                    backgroundColor: AppColors.lightSurfaceVariant,
                    minHeight: 4,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Text(
                    'Clinical Assessment',
                    style: AppTextStyles.titleMedium(textPrimary)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Chief Complaint *
                  _buildTextField(
                    label: 'Chief Complaint *',
                    controller: controller.chiefComplaintCtrl,
                    maxLines: 3,
                    isDark: isDark,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Chief complaint is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Brief History
                  _buildTextField(
                    label: 'Brief History',
                    controller: controller.briefHistoryCtrl,
                    maxLines: 3,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Temperature & Pulse (Row)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'Temperature (°C)',
                          controller: controller.temperatureCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          isDark: isDark,
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final parsed = double.tryParse(val.trim());
                              if (parsed == null ||
                                  parsed < 30 ||
                                  parsed > 45) {
                                return 'Enter valid temp';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildTextField(
                          label: 'Pulse Rate (bpm)',
                          controller: controller.pulseCtrl,
                          keyboardType: TextInputType.number,
                          isDark: isDark,
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final parsed = int.tryParse(val.trim());
                              if (parsed == null ||
                                  parsed < 20 ||
                                  parsed > 250) {
                                return 'Enter valid pulse';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // BP Systolic & BP Diastolic (Row)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'BP Systolic (mmHg)',
                          controller: controller.bpSystolicCtrl,
                          keyboardType: TextInputType.number,
                          isDark: isDark,
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final parsed = int.tryParse(val.trim());
                              if (parsed == null ||
                                  parsed < 40 ||
                                  parsed > 300) {
                                return 'Enter valid systolic';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildTextField(
                          label: 'BP Diastolic (mmHg)',
                          controller: controller.bpDiastolicCtrl,
                          keyboardType: TextInputType.number,
                          isDark: isDark,
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final parsed = int.tryParse(val.trim());
                              if (parsed == null ||
                                  parsed < 30 ||
                                  parsed > 200) {
                                return 'Enter valid diastolic';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Route To
                  _buildRouteDropdown(isDark),
                  const SizedBox(height: AppSpacing.xxl),

                  // Back & Save Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Get.back(),
                        style: TextButton.styleFrom(
                          minimumSize:
                              const Size(100, AppSpacing.buttonHeightMD),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back_ios_new_rounded,
                                size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Back',
                              style: AppTextStyles.labelLarge(textPrimary),
                            ),
                          ],
                        ),
                      ),
                      Obx(() {
                        if (controller.isSaving.value) {
                          return const SizedBox(
                            width: 150,
                            height: AppSpacing.buttonHeightMD,
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.secondary),
                            ),
                          );
                        }

                        return ElevatedButton(
                          onPressed: controller.saveScreening,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppDecorations.borderMD,
                            ),
                            minimumSize:
                                const Size(150, AppSpacing.buttonHeightMD),
                          ),
                          child: Text(
                            'Save Screening',
                            style: AppTextStyles.labelLarge(Colors.white),
                          ),
                        );
                      }),
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
        // Identity (Completed Step)
        Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                size: 16, color: AppColors.secondary),
            const SizedBox(width: 6),
            Text(
              'Identity',
              style: AppTextStyles.labelMedium(
                isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '>',
          style: AppTextStyles.labelMedium(
            isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Clinical (Active Step)
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
              const Icon(Icons.healing_rounded,
                  size: 16, color: AppColors.secondary),
              const SizedBox(width: 6),
              Text(
                'Clinical',
                style: AppTextStyles.labelMedium(AppColors.secondary),
              ),
            ],
          ),
        ),
        const Spacer(),
        Text(
          'Step 2 of 2',
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
    int maxLines = 1,
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
          maxLines: maxLines,
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

  Widget _buildRouteDropdown(bool isDark) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Route To',
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
                value: controller.selectedRoute.value,
                hint: Text(
                  'Select destination unit',
                  style: AppTextStyles.bodyMedium(textSecondary),
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary),
                dropdownColor:
                    isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: AppDecorations.borderMD,
                isExpanded: true,
                onChanged: (val) {
                  if (val != null) controller.selectRoute(val);
                },
                items: controller.routesList.map((e) {
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
