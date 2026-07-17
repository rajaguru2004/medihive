import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../theme/theme.dart';
import '../controllers/inpatient_controller.dart';

class InpatientAdmissionsView extends StatelessWidget {
  const InpatientAdmissionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GetBuilder<InpatientController>(
      builder: (controller) {
        final admissionsList = controller.filteredAllAdmissions;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient Admissions History',
              style: AppTextStyles.titleMedium(textPrimary).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Search Input & Dropdown Row
            TextField(
              onChanged: controller.updateAdmissionsSearch,
              decoration: InputDecoration(
                hintText: 'Search patient by name or MRN...',
                prefixIcon: const Icon(Icons.search_rounded, size: AppSpacing.iconMD),
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                  horizontal: AppSpacing.md,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppDecorations.borderMD,
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppDecorations.borderMD,
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppDecorations.borderMD,
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Status Dropdown selector
            Row(
              children: [
                Text(
                  'Status:',
                  style: AppTextStyles.bodyMedium(textSecondary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: AppDecorations.borderMD,
                      border: Border.all(
                        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: controller.selectedAdmissionStatusFilter,
                        dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Admissions')),
                          DropdownMenuItem(value: 'Active', child: Text('Active Admissions')),
                          DropdownMenuItem(value: 'Discharged', child: Text('Discharged Admissions')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            controller.changeAdmissionStatusFilter(val);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            if (admissionsList.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_edu_rounded,
                        size: AppSpacing.iconXL,
                        color: textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'No admissions found matching filters',
                        style: AppTextStyles.bodyMedium(textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: admissionsList.length,
                itemBuilder: (context, index) {
                  final admission = admissionsList[index];
                  final isActive = admission.status.toLowerCase() == 'admitted';

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: AppDecorations.borderLG,
                      border: Border.all(
                        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Patient Name, MRN & Status Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                admission.patient.fullName,
                                style: AppTextStyles.titleMedium(textPrimary).copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            StatusBadge(
                              label: admission.status.toUpperCase(),
                              type: isActive ? StatusType.success : StatusType.neutral,
                            ),
                          ],
                        ),
                        Text(
                          'MRN: ${admission.patient.mrn}',
                          style: AppTextStyles.bodySmall(textSecondary),
                        ),
                        const Divider(height: AppSpacing.lg),

                        // Detail Rows
                        _buildDetailRow(
                          label: 'Admission Date',
                          value: DateFormat('dd/MM/yyyy HH:mm').format(admission.admissionDate.toLocal()),
                          isDark: isDark,
                        ),
                        _buildDetailRow(
                          label: 'Ward & Bed',
                          value: '${admission.bed.ward?.name ?? 'ICU'} - Bed ${admission.bed.bedNumber}',
                          isDark: isDark,
                        ),
                        _buildDetailRow(
                          label: 'Admission Type',
                          value: admission.admissionType.toUpperCase(),
                          isDark: isDark,
                        ),
                        _buildDetailRow(
                          label: 'Doctor',
                          value: 'Assigned Doctor',
                          isDark: isDark,
                        ),
                        _buildDetailRow(
                          label: 'Discharge Date',
                          value: admission.dischargeDate != null
                              ? DateFormat('dd/MM/yyyy HH:mm').format(admission.dischargeDate!.toLocal())
                              : 'Active',
                          isDark: isDark,
                        ),

                        if (isActive) ...[
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => Get.toNamed('/inpatient/discharge'),
                              icon: const Icon(Icons.logout_rounded, size: AppSpacing.iconSM),
                              label: const Text('Discharge'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: AppColors.lightSurface,
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppDecorations.borderMD,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required bool isDark,
  }) {
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium(textSecondary)),
          Text(value, style: AppTextStyles.bodyMedium(textPrimary).copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
