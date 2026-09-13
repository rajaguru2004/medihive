import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:medihive/app/theme/theme.dart';

import '../../../data/models/ward_model.dart';
import '../controllers/inpatient_add_ward_controller.dart';

class InpatientAddWardView extends StatelessWidget {
  final WardModel? ward;
  final bool isEdit;

  const InpatientAddWardView({super.key, this.ward, this.isEdit = false});

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

    final controller = Get.find<InpatientAddWardController>();
    controller.initialize(ward, isEdit);

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
              isEdit ? 'Edit Ward' : 'Create Ward',
              style: AppTextStyles.headlineSmall(
                textPrimary,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Configure hospital ward capacity and type settings.',
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
                // Ward Name field
                Text(
                  'Ward Name *',
                  style: AppTextStyles.labelMedium(
                    textPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: controller.nameController,
                  style: AppTextStyles.bodyMedium(textPrimary),
                  decoration: _getInputDecoration(
                    isDark,
                    borderColor,
                    hintText: 'e.g. ICU Ward B',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Ward Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Code and Capacity row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Code field
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Code *',
                            style: AppTextStyles.labelMedium(
                              textPrimary,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextFormField(
                            controller: controller.codeController,
                            style: AppTextStyles.bodyMedium(textPrimary),
                            decoration: _getInputDecoration(
                              isDark,
                              borderColor,
                              hintText: 'e.g. ICU-B',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Code is required';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Capacity field
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Capacity *',
                            style: AppTextStyles.labelMedium(
                              textPrimary,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextFormField(
                            controller: controller.capacityController,
                            keyboardType: TextInputType.number,
                            style: AppTextStyles.bodyMedium(textPrimary),
                            decoration: _getInputDecoration(
                              isDark,
                              borderColor,
                              hintText: '10',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Capacity is required';
                              }
                              final capacity = int.tryParse(val.trim());
                              if (capacity == null || capacity <= 0) {
                                return 'Capacity must be greater than 0';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Ward Type field
                Text(
                  'Ward Type *',
                  style: AppTextStyles.labelMedium(
                    textPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                GetBuilder<InpatientAddWardController>(
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
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Ward Type is required';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // Bottom Action Buttons
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
                      child: GetBuilder<InpatientAddWardController>(
                        builder: (ctrl) {
                          return ElevatedButton(
                            onPressed: ctrl.isSubmitting
                                ? null
                                : () {
                                    if (formKey.currentState!.validate()) {
                                      ctrl.saveWard();
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
                                    isEdit ? 'Save Changes' : 'Create Ward',
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
    bool isEnabled = true,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTextStyles.bodyMedium(
        (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
            .withValues(alpha: 0.5),
      ),
      filled: true,
      fillColor: !isEnabled
          ? (isDark
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.black.withValues(alpha: 0.03))
          : (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.7)),
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
      disabledBorder: OutlineInputBorder(
        borderRadius: AppDecorations.borderMD,
        borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5)),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
    );
  }
}
