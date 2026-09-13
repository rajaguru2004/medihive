import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/models/appointment_model.dart';
import '../../../theme/theme.dart';
import '../controllers/discharge_patient_controller.dart';

class DischargePatientView extends GetView<DischargePatientController> {
  const DischargePatientView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: AppDecorations.borderLG,
                border: Border.all(
                  color: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant,
                ),
                boxShadow: AppDecorations.elevation2(isDark),
              ),
              child: GetBuilder<DischargePatientController>(
                builder: (controller) {
                  final patientName = controller.admission.patient.fullName;
                  final bedNumber = controller.admission.bed.bedNumber;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Title, Heartbeat Icon & Close Button
                      Row(
                        children: [
                          Icon(
                            Icons.show_chart_rounded,
                            color: AppColors.secondary,
                            size: AppSpacing.iconMD * 1.2,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Discharge Patient',
                              style:
                                  AppTextStyles.titleLarge(AppColors.secondary)
                                      .copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: textSecondary.withValues(alpha: 0.6),
                            ),
                            onPressed: () => Get.back(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Record discharge summary and follow-up directives for $patientName.',
                        style: AppTextStyles.bodyMedium(
                            textSecondary.withValues(alpha: 0.8)),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Row 1: Discharge Reason * & Discharging Doctor *
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Discharge Reason *', isDark),
                                const SizedBox(height: AppSpacing.xs),
                                _buildReasonField(controller, isDark),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Discharging Doctor *', isDark),
                                const SizedBox(height: AppSpacing.xs),
                                _buildDoctorDropdown(controller, isDark),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Discharge Summary *
                      _buildLabel('Discharge Summary *', isDark),
                      const SizedBox(height: AppSpacing.xs),
                      _buildSummaryField(controller, isDark),
                      const SizedBox(height: AppSpacing.md),

                      // Row 2: Follow-up Date & Follow-up Directives
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Follow-up Date', isDark),
                                const SizedBox(height: AppSpacing.xs),
                                _buildFollowUpDatePicker(
                                    context, controller, isDark),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Follow-up Directives', isDark),
                                const SizedBox(height: AppSpacing.xs),
                                _buildDirectivesField(controller, isDark),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Information Alert Banner
                      _buildAlertBanner(bedNumber, isDark),
                      const SizedBox(height: AppSpacing.lg),

                      // Bottom Actions: Cancel & Confirm Discharge
                      _buildActionButtons(controller, isDark),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return RichText(
      text: TextSpan(
        text: text.replaceAll('*', '').trim(),
        style: AppTextStyles.labelMedium(textColor).copyWith(
          fontWeight: FontWeight.w600,
        ),
        children: [
          if (text.contains('*'))
            const TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.error),
            ),
        ],
      ),
    );
  }

  InputDecoration _getInputDecoration(
    bool isDark, {
    String? hintText,
    IconData? prefixIcon,
  }) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTextStyles.bodyMedium(textSecondary.withValues(alpha: 0.4)),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.white.withValues(alpha: 0.7),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
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
        borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
      ),
      prefixIcon: prefixIcon != null
          ? Icon(
              prefixIcon,
              size: AppSpacing.iconSM,
              color: textSecondary.withValues(alpha: 0.5),
            )
          : null,
    );
  }

  Widget _buildReasonField(DischargePatientController controller, bool isDark) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return TextFormField(
      controller: controller.reasonController,
      style: AppTextStyles.bodyMedium(textPrimary),
      decoration: _getInputDecoration(
        isDark,
        hintText: 'e.g. Fully recovered',
      ),
    );
  }

  Widget _buildDoctorDropdown(
      DischargePatientController controller, bool isDark) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return DropdownButtonFormField<AppointmentDoctor>(
      initialValue: controller.selectedDoctor,
      hint: Text(
        controller.isLoadingDoctors ? 'Loading doctors...' : 'Choose Doctor',
        style: AppTextStyles.bodyMedium(textSecondary.withValues(alpha: 0.4)),
      ),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.primary,
      ),
      dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      style: AppTextStyles.bodyMedium(textPrimary),
      onChanged: controller.isLoadingDoctors ? null : controller.selectDoctor,
      items: controller.doctors
          .map<DropdownMenuItem<AppointmentDoctor>>((AppointmentDoctor doc) {
        final specialization =
            doc.specialization != null && doc.specialization!.isNotEmpty
                ? ' (${doc.specialization})'
                : '';
        return DropdownMenuItem<AppointmentDoctor>(
          value: doc,
          child: Text(
            'Dr. ${doc.fullName}$specialization',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      decoration: _getInputDecoration(isDark),
      isExpanded: true,
    );
  }

  Widget _buildSummaryField(
      DischargePatientController controller, bool isDark) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return TextFormField(
      controller: controller.summaryController,
      maxLines: 4,
      style: AppTextStyles.bodyMedium(textPrimary),
      decoration: _getInputDecoration(
        isDark,
        hintText:
            'Enter detailed summary of course in hospital, treatment given, and condition on discharge...',
      ),
    );
  }

  Widget _buildFollowUpDatePicker(
    BuildContext context,
    DischargePatientController controller,
    bool isDark,
  ) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final dateText = controller.selectedFollowUpDate != null
        ? DateFormat('dd/MM/yyyy').format(controller.selectedFollowUpDate!)
        : 'Select Date';

    return InkWell(
      onTap: () => controller.selectFollowUpDate(context),
      borderRadius: AppDecorations.borderMD,
      child: InputDecorator(
        decoration: _getInputDecoration(
          isDark,
          prefixIcon: Icons.calendar_today_outlined,
        ),
        child: Text(
          dateText,
          style: AppTextStyles.bodyMedium(
            controller.selectedFollowUpDate != null
                ? textPrimary
                : textSecondary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectivesField(
      DischargePatientController controller, bool isDark) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return TextFormField(
      controller: controller.directivesController,
      style: AppTextStyles.bodyMedium(textPrimary),
      decoration: _getInputDecoration(
        isDark,
        hintText: 'e.g. Return in 1 week',
      ),
    );
  }

  Widget _buildAlertBanner(String bedNumber, bool isDark) {
    final bannerBg = isDark
        ? const Color(0xFF14532D).withValues(alpha: 0.25)
        : const Color(0xFFF0FDF4);
    final bannerBorder = isDark
        ? const Color(0xFF166534).withValues(alpha: 0.4)
        : const Color(0xFFDCFCE7);
    final bannerText =
        isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: AppDecorations.borderMD,
        border: Border.all(color: bannerBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: bannerText,
            size: AppSpacing.iconSM,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.bodySmall(bannerText).copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(
                      text:
                          'Discharging this patient will automatically free up bed '),
                  TextSpan(
                    text: bedNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' and mark it as available.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      DischargePatientController controller, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () => Get.back(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(100, 40),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: AppDecorations.borderMD,
            ),
            side: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            'Cancel',
            style: AppTextStyles.labelMedium(
              isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        ElevatedButton(
          onPressed:
              controller.isSubmitting ? null : controller.submitDischarge,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            minimumSize: const Size(140, 40),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: AppDecorations.borderMD,
            ),
            elevation: 0,
          ),
          child: controller.isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Confirm Discharge',
                  style: AppTextStyles.labelMedium(Colors.white).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }
}
