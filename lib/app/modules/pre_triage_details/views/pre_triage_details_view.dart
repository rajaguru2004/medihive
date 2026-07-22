import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../theme/theme.dart';
import '../controllers/pre_triage_details_controller.dart';

class PreTriageDetailsView extends GetView<PreTriageDetailsController> {
  const PreTriageDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final screening = controller.screening;

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
              'Screening Details',
              style: AppTextStyles.titleMedium(textPrimary),
            ),
            Text(
              'Read-only view of screening ${screening.screeningId}',
              style: AppTextStyles.bodySmall(textSecondary),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Section 1: Patient Identity Card
            _buildIdentityCard(context, isDark),
            const SizedBox(height: AppSpacing.md),

            // Section 2: Clinical Assessment Card
            _buildClinicalCard(context, isDark),
            const SizedBox(height: AppSpacing.md),

            // Section 3: Vitals Metrics Card
            _buildVitalsCard(context, isDark),
            const SizedBox(height: AppSpacing.md),

            // Section 4: Routing & Status Card
            _buildStatusCard(context, isDark),
            const SizedBox(height: AppSpacing.xl),

            // Close Button
            SizedBox(
              height: AppSpacing.buttonHeightMD,
              child: OutlinedButton(
                onPressed: () => Get.back(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppDecorations.borderMD,
                  ),
                ),
                child: Text(
                  'Close Details',
                  style: AppTextStyles.labelLarge(AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityCard(BuildContext context, bool isDark) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final screening = controller.screening;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: AppDecorations.borderLG,
        boxShadow: AppDecorations.elevation1(isDark),
        border: Border.all(
          color: isDark
              ? AppColors.darkGlassBorder
              : AppColors.lightGlassBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_rounded, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Patient Identity',
                style: AppTextStyles.titleMedium(
                  textPrimary,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg),
          _buildDetailRow(
            'First Name',
            screening.firstName,
            textPrimary,
            textSecondary,
          ),
          _buildDetailRow(
            'Last Name',
            screening.lastName ?? 'N/A',
            textPrimary,
            textSecondary,
          ),
          _buildDetailRow(
            'Age',
            screening.age != null ? '${screening.age} years' : 'N/A',
            textPrimary,
            textSecondary,
          ),
          _buildDetailRow(
            'Gender',
            screening.gender != null ? screening.gender!.toUpperCase() : 'N/A',
            textPrimary,
            textSecondary,
          ),
          _buildDetailRow(
            'Phone Number',
            screening.phone ?? 'N/A',
            textPrimary,
            textSecondary,
          ),
          if (screening.mrn != null)
            _buildDetailRow(
              'Assigned MRN',
              screening.mrn!,
              AppColors.primary,
              textSecondary,
              isBold: true,
            ),
        ],
      ),
    );
  }

  Widget _buildClinicalCard(BuildContext context, bool isDark) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final screening = controller.screening;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: AppDecorations.borderLG,
        boxShadow: AppDecorations.elevation1(isDark),
        border: Border.all(
          color: isDark
              ? AppColors.darkGlassBorder
              : AppColors.lightGlassBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.healing_rounded, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Clinical Assessment',
                style: AppTextStyles.titleMedium(
                  textPrimary,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg),
          _buildDetailRow(
            'Chief Complaint',
            screening.chiefComplaint,
            textPrimary,
            textSecondary,
            isMultiline: true,
          ),
          _buildDetailRow(
            'Brief History',
            screening.briefHistory ?? 'None recorded',
            textPrimary,
            textSecondary,
            isMultiline: true,
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsCard(BuildContext context, bool isDark) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final screening = controller.screening;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: AppDecorations.borderLG,
        boxShadow: AppDecorations.elevation1(isDark),
        border: Border.all(
          color: isDark
              ? AppColors.darkGlassBorder
              : AppColors.lightGlassBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_rounded, color: AppColors.error),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Vitals Metrics',
                style: AppTextStyles.titleMedium(
                  textPrimary,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg),
          _buildDetailRow(
            'Temperature',
            screening.temperature != null
                ? '${screening.temperature} °C'
                : 'Not recorded',
            textPrimary,
            textSecondary,
          ),
          _buildDetailRow(
            'Pulse Rate',
            screening.pulse != null ? '${screening.pulse} bpm' : 'Not recorded',
            textPrimary,
            textSecondary,
          ),
          _buildDetailRow(
            'Blood Pressure',
            screening.bpSystolic != null || screening.bpDiastolic != null
                ? '${screening.bpSystolic ?? "?"}/${screening.bpDiastolic ?? "?"} mmHg'
                : 'Not recorded',
            textPrimary,
            textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, bool isDark) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final screening = controller.screening;

    String statusLabel = 'Screening';
    Color statusColor = AppColors.primary;

    switch (screening.status) {
      case 'screening':
        statusLabel = 'Screening';
        statusColor = AppColors.primary;
        break;
      case 'routed':
        statusLabel = 'Routed';
        statusColor = AppColors.warning;
        break;
      case 'registered_as_patient':
        statusLabel = 'Registered';
        statusColor = AppColors.secondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: AppDecorations.borderLG,
        boxShadow: AppDecorations.elevation1(isDark),
        border: Border.all(
          color: isDark
              ? AppColors.darkGlassBorder
              : AppColors.lightGlassBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.info),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Status & Routing',
                style: AppTextStyles.titleMedium(
                  textPrimary,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg),
          _buildDetailRow(
            'Screening ID',
            screening.screeningId,
            textPrimary,
            textSecondary,
          ),
          _buildDetailRow(
            'Status',
            statusLabel.toUpperCase(),
            statusColor,
            textSecondary,
            isBold: true,
          ),
          _buildDetailRow(
            'Route Destination',
            screening.route != null && screening.route!.isNotEmpty
                ? screening.route!.toUpperCase()
                : 'NONE',
            AppColors.primary,
            textSecondary,
            isBold: true,
          ),
          _buildDetailRow(
            'Screened At',
            DateFormat('dd/MM/yyyy HH:mm:ss').format(screening.createdAt),
            textPrimary,
            textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    Color valColor,
    Color labelColor, {
    bool isBold = false,
    bool isMultiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: isMultiline
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelSmall(labelColor)),
                const SizedBox(height: 2),
                Text(value, style: AppTextStyles.bodyMedium(valColor)),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: AppTextStyles.labelSmall(labelColor)),
                Text(
                  value,
                  style: isBold
                      ? AppTextStyles.labelMedium(
                          valColor,
                        ).copyWith(fontWeight: FontWeight.bold)
                      : AppTextStyles.bodyMedium(valColor),
                ),
              ],
            ),
    );
  }
}
