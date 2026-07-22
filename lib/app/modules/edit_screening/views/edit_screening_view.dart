import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../../../theme/theme.dart';
import '../controllers/edit_screening_controller.dart';

class EditScreeningView extends GetView<EditScreeningController> {
  const EditScreeningView({super.key});

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
              'Edit Screening',
              style: AppTextStyles.titleMedium(textPrimary),
            ),
            Text(
              'Update pre-triage information for ${controller.screeningNumber}',
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
                  Text(
                    'Patient Details',
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
                            if (val == null || val.trim().isEmpty) {
                              return 'Required';
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
                            if (val == null || val.trim().isEmpty) {
                              return 'Required';
                            }
                            final parsed = int.tryParse(val.trim());
                            if (parsed == null || parsed <= 0) {
                              return 'Invalid age';
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
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Chief Complaint
                  _buildTextField(
                    label: 'Chief Complaint *',
                    controller: controller.chiefComplaintCtrl,
                    maxLines: 3,
                    isDark: isDark,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Required';
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

                  // Temperature, BP Systolic, BP Diastolic (Three-column layout / Stacked)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'Temp (°C)',
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
                                return 'Invalid';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _buildTextField(
                          label: 'Sys (mmHg)',
                          controller: controller.bpSystolicCtrl,
                          keyboardType: TextInputType.number,
                          isDark: isDark,
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final parsed = int.tryParse(val.trim());
                              if (parsed == null ||
                                  parsed < 40 ||
                                  parsed > 300) {
                                return 'Invalid';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _buildTextField(
                          label: 'Dia (mmHg)',
                          controller: controller.bpDiastolicCtrl,
                          keyboardType: TextInputType.number,
                          isDark: isDark,
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final parsed = int.tryParse(val.trim());
                              if (parsed == null ||
                                  parsed < 30 ||
                                  parsed > 200) {
                                return 'Invalid';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Pulse & Route To (Row)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'Pulse (bpm)',
                          controller: controller.pulseCtrl,
                          keyboardType: TextInputType.number,
                          isDark: isDark,
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final parsed = int.tryParse(val.trim());
                              if (parsed == null ||
                                  parsed < 20 ||
                                  parsed > 250) {
                                return 'Invalid';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildRouteDropdown(isDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Cancel & Save Changes Buttons
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
                          onPressed: controller.saveChanges,
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
                            'Save Changes',
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
                  'Select unit',
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
