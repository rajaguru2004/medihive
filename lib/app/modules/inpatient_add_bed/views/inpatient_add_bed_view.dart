import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:medihive/app/theme/theme.dart';
import '../controllers/inpatient_add_bed_controller.dart';

class InpatientAddBedView extends StatelessWidget {
  const InpatientAddBedView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    final controller = Get.find<InpatientAddBedController>();
    final formKey = GlobalKey<FormState>();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        toolbarHeight: 80,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: textPrimary,
            size: AppSpacing.iconLG,
          ),
          onPressed: () => Get.back(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add New Bed',
              style: AppTextStyles.headlineSmall(
                textPrimary,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Register a new bed under the selected ward.',
              style: AppTextStyles.bodyMedium(textSecondary),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ward Dropdown Selection
                Text(
                  'Select Ward *',
                  style: AppTextStyles.labelMedium(
                    textPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                GetBuilder<InpatientAddBedController>(
                  builder: (ctrl) {
                    if (ctrl.isLoadingWards) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      );
                    }

                    if (ctrl.activeWards.isEmpty) {
                      return Text(
                        'No active wards available. Create one first.',
                        style: AppTextStyles.bodyMedium(AppColors.error),
                      );
                    }

                    return DropdownButtonFormField<String>(
                      initialValue: ctrl.selectedWardId,
                      dropdownColor: cardBg,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary,
                      ),
                      style: AppTextStyles.bodyMedium(textPrimary),
                      items: ctrl.activeWards.map<DropdownMenuItem<String>>((
                        ward,
                      ) {
                        return DropdownMenuItem<String>(
                          value: ward.id,
                          child: Text('${ward.name} (${ward.code})'),
                        );
                      }).toList(),
                      onChanged: ctrl.setWardId,
                      decoration: _getInputDecoration(isDark, borderColor),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Ward selection is required';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Bed Number Field
                Text(
                  'Bed Number / Code *',
                  style: AppTextStyles.labelMedium(
                    textPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: controller.bedNumberController,
                  style: AppTextStyles.bodyMedium(textPrimary),
                  decoration: _getInputDecoration(
                    isDark,
                    borderColor,
                    hintText: 'e.g. B-101 or ICU-B01',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Bed number is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Bed Type Dropdown
                Text(
                  'Bed Type',
                  style: AppTextStyles.labelMedium(
                    textPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                GetBuilder<InpatientAddBedController>(
                  builder: (ctrl) {
                    return DropdownButtonFormField<String>(
                      initialValue: ctrl.selectedType,
                      dropdownColor: cardBg,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary,
                      ),
                      style: AppTextStyles.bodyMedium(textPrimary),
                      items: ctrl.typeOptions.map<DropdownMenuItem<String>>((
                        String value,
                      ) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: ctrl.setSelectedType,
                      decoration: _getInputDecoration(isDark, borderColor),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppDecorations.borderMD,
                          ),
                          side: BorderSide(color: borderColor),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.labelLarge(
                            isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: GetBuilder<InpatientAddBedController>(
                        builder: (ctrl) {
                          return ElevatedButton(
                            onPressed: ctrl.isSubmitting
                                ? null
                                : () {
                                    if (formKey.currentState!.validate()) {
                                      ctrl.saveBed();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: AppColors.lightSurface,
                              minimumSize: const Size(0, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppDecorations.borderMD,
                              ),
                              elevation: 0,
                            ),
                            child: ctrl.isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Add Bed',
                                    style: AppTextStyles.labelLarge(
                                      AppColors.lightSurface,
                                    ).copyWith(fontWeight: FontWeight.bold),
                                  ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _getInputDecoration(
    bool isDark,
    Color borderColor, {
    String? hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTextStyles.bodyMedium(
        (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
            .withValues(alpha: 0.5),
      ),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.white.withValues(alpha: 0.7),
      border: OutlineInputBorder(
        borderRadius: AppDecorations.borderMD,
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppDecorations.borderMD,
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppDecorations.borderMD,
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
    );
  }
}
