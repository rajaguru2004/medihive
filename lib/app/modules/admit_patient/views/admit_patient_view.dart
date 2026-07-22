import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../../../models/appointment_model.dart';
import '../../../models/bed_model.dart';
import '../../../models/patient_lookup.dart';
import '../../../models/ward_model.dart';
import '../../../theme/theme.dart';
import '../controllers/admit_patient_controller.dart';

class AdmitPatientView extends GetView<AdmitPatientController> {
  const AdmitPatientView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showDiscardConfirmation(context, isDark);
        if (shouldPop) {
          Get.back();
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor:
              isDark ? AppColors.darkSurface : AppColors.lightSurface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: textPrimary,
              size: AppSpacing.iconLG,
            ),
            onPressed: () async {
              final shouldPop = await _showDiscardConfirmation(context, isDark);
              if (shouldPop) {
                Get.back();
              }
            },
          ),
          title: Row(
            children: [
              const Icon(
                Icons.person_add_alt_1_rounded,
                color: AppColors.secondary,
                size: AppSpacing.iconLG,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Admit Patient',
                style: AppTextStyles.titleLarge(
                  textPrimary,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: GetBuilder<AdmitPatientController>(
            builder: (controller) {
              if (controller.isLoadingPatients ||
                  controller.isLoadingWards ||
                  controller.isLoadingDoctors) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  // Determine if we are on a desktop/wide screen or mobile
                  final isWide = constraints.maxWidth > 600;

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.xl,
                    ),
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: isWide ? 650 : double.infinity,
                        ),
                        decoration: isWide
                            ? BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurface
                                    : AppColors.lightSurface,
                                borderRadius: AppDecorations.borderLG,
                                boxShadow: AppDecorations.elevation2(isDark),
                              )
                            : null,
                        padding: isWide
                            ? const EdgeInsets.all(AppSpacing.xxl)
                            : EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Complete the form to assign a bed and doctors for the inpatient admission.',
                              style: AppTextStyles.bodyMedium(textSecondary),
                            ),
                            const SizedBox(height: AppSpacing.xxl),

                            // 1. Select Patient Dropdown
                            _buildSectionHeader('Select Patient *', isDark),
                            const SizedBox(height: AppSpacing.sm),
                            _buildPatientDropdown(controller, isDark),
                            const SizedBox(height: AppSpacing.xl),

                            // 2. Select Ward & Assign Bed (Row on wide, Column on mobile)
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildSectionHeader(
                                          'Select Ward *',
                                          isDark,
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        _buildWardDropdown(controller, isDark),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.lg),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildSectionHeader(
                                          'Assign Bed *',
                                          isDark,
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        _buildBedDropdown(controller, isDark),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _buildSectionHeader('Select Ward *', isDark),
                              const SizedBox(height: AppSpacing.sm),
                              _buildWardDropdown(controller, isDark),
                              const SizedBox(height: AppSpacing.xl),
                              _buildSectionHeader('Assign Bed *', isDark),
                              const SizedBox(height: AppSpacing.sm),
                              _buildBedDropdown(controller, isDark),
                            ],
                            const SizedBox(height: AppSpacing.xl),

                            // 3. Admission Type & Admitting Doctor (Row on wide, Column on mobile)
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildSectionHeader(
                                          'Admission Type *',
                                          isDark,
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        _buildAdmissionTypeDropdown(
                                          controller,
                                          isDark,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.lg),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildSectionHeader(
                                          'Admitting Doctor *',
                                          isDark,
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        _buildDoctorDropdown(
                                          controller: controller,
                                          selectedValue: controller
                                              .selectedAdmittingDoctor,
                                          hintText: 'Select Admitting Doctor',
                                          onChanged:
                                              controller.selectAdmittingDoctor,
                                          isDark: isDark,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _buildSectionHeader('Admission Type *', isDark),
                              const SizedBox(height: AppSpacing.sm),
                              _buildAdmissionTypeDropdown(controller, isDark),
                              const SizedBox(height: AppSpacing.xl),
                              _buildSectionHeader('Admitting Doctor *', isDark),
                              const SizedBox(height: AppSpacing.sm),
                              _buildDoctorDropdown(
                                controller: controller,
                                selectedValue:
                                    controller.selectedAdmittingDoctor,
                                hintText: 'Select Admitting Doctor',
                                onChanged: controller.selectAdmittingDoctor,
                                isDark: isDark,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.xl),

                            // 4. Attending Doctor
                            _buildSectionHeader('Attending Doctor *', isDark),
                            const SizedBox(height: AppSpacing.sm),
                            _buildDoctorDropdown(
                              controller: controller,
                              selectedValue: controller.selectedAttendingDoctor,
                              hintText: 'Select Attending Doctor',
                              onChanged: controller.selectAttendingDoctor,
                              isDark: isDark,
                            ),
                            const SizedBox(height: AppSpacing.xl),

                            // 5. Admission Reason
                            _buildSectionHeader('Admission Reason *', isDark),
                            const SizedBox(height: AppSpacing.sm),
                            _buildAdmissionReasonField(controller, isDark),
                            const SizedBox(height: AppSpacing.xxl * 1.5),

                            // 6. Action Buttons
                            _buildActionButtons(controller, isDark),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Component Builders ───────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, bool isDark) {
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return RichText(
      text: TextSpan(
        text: title.replaceAll('*', ''),
        style: AppTextStyles.labelMedium(
          textColor,
        ).copyWith(fontWeight: FontWeight.w600),
        children: [
          if (title.contains('*'))
            const TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.error),
            ),
        ],
      ),
    );
  }

  Widget _buildPatientDropdown(AdmitPatientController controller, bool isDark) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return DropdownButtonFormField<PatientLookup>(
      initialValue: controller.selectedPatient,
      isExpanded: true,
      hint: Text(
        'Choose a patient...',
        style: AppTextStyles.bodyMedium(textSecondary.withValues(alpha: 0.5)),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.primary,
      ),
      dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      style: AppTextStyles.bodyMedium(textPrimary),
      onChanged: controller.selectPatient,
      items: controller.patients.map<DropdownMenuItem<PatientLookup>>((
        PatientLookup patient,
      ) {
        return DropdownMenuItem<PatientLookup>(
          value: patient,
          child: Text(
            '${patient.fullName} (${patient.mrn})',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      }).toList(),
      decoration: _getInputDecoration(isDark, borderColor),
    );
  }

  Widget _buildWardDropdown(AdmitPatientController controller, bool isDark) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return DropdownButtonFormField<WardModel>(
      initialValue: controller.selectedWard,
      hint: Text(
        'Select Ward',
        style: AppTextStyles.bodyMedium(textSecondary.withValues(alpha: 0.5)),
      ),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.primary,
      ),
      dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      style: AppTextStyles.bodyMedium(textPrimary),
      onChanged: controller.selectWard,
      items: controller.wards.map<DropdownMenuItem<WardModel>>((
        WardModel ward,
      ) {
        return DropdownMenuItem<WardModel>(value: ward, child: Text(ward.name));
      }).toList(),
      decoration: _getInputDecoration(isDark, borderColor),
    );
  }

  Widget _buildBedDropdown(AdmitPatientController controller, bool isDark) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final isEnabled =
        controller.selectedWard != null && !controller.isLoadingBeds;
    final hint = controller.selectedWard == null
        ? 'Choose Ward First'
        : (controller.isLoadingBeds
            ? 'Loading beds...'
            : (controller.beds.isEmpty
                ? 'No available beds in this ward'
                : 'Select available bed'));

    return DropdownButtonFormField<BedModel>(
      initialValue: controller.selectedBed,
      hint: Text(
        hint,
        style: AppTextStyles.bodyMedium(
          textSecondary.withValues(alpha: isEnabled ? 0.5 : 0.3),
        ),
      ),
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: isEnabled
            ? AppColors.primary
            : textSecondary.withValues(alpha: 0.3),
      ),
      dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      style: AppTextStyles.bodyMedium(textPrimary),
      onChanged: isEnabled ? controller.selectBed : null,
      items: isEnabled
          ? controller.beds.map<DropdownMenuItem<BedModel>>((BedModel bed) {
              return DropdownMenuItem<BedModel>(
                value: bed,
                child: Text('Bed ${bed.bedNumber} (${bed.type.toUpperCase()})'),
              );
            }).toList()
          : null,
      decoration: _getInputDecoration(
        isDark,
        borderColor,
        isEnabled: isEnabled,
      ),
    );
  }

  Widget _buildAdmissionTypeDropdown(
    AdmitPatientController controller,
    bool isDark,
  ) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return DropdownButtonFormField<String>(
      initialValue: controller.selectedAdmissionType,
      hint: Text(
        'Routine Admission',
        style: AppTextStyles.bodyMedium(textSecondary.withValues(alpha: 0.5)),
      ),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.primary,
      ),
      dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      style: AppTextStyles.bodyMedium(textPrimary),
      onChanged: controller.selectAdmissionType,
      items: controller.admissionTypes.map<DropdownMenuItem<String>>((
        String type,
      ) {
        return DropdownMenuItem<String>(value: type, child: Text(type));
      }).toList(),
      decoration: _getInputDecoration(isDark, borderColor),
    );
  }

  Widget _buildDoctorDropdown({
    required AdmitPatientController controller,
    required AppointmentDoctor? selectedValue,
    required String hintText,
    required ValueChanged<AppointmentDoctor?> onChanged,
    required bool isDark,
  }) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return DropdownButtonFormField<AppointmentDoctor>(
      initialValue: selectedValue,
      hint: Text(
        hintText,
        style: AppTextStyles.bodyMedium(textSecondary.withValues(alpha: 0.5)),
      ),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.primary,
      ),
      dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      style: AppTextStyles.bodyMedium(textPrimary),
      onChanged: onChanged,
      items: controller.doctors.map<DropdownMenuItem<AppointmentDoctor>>((
        AppointmentDoctor doc,
      ) {
        final specialization =
            doc.specialization != null ? ' (${doc.specialization})' : '';
        return DropdownMenuItem<AppointmentDoctor>(
          value: doc,
          child: Text('${doc.fullName}$specialization'),
        );
      }).toList(),
      decoration: _getInputDecoration(isDark, borderColor),
    );
  }

  Widget _buildAdmissionReasonField(
    AdmitPatientController controller,
    bool isDark,
  ) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return TextFormField(
      controller: controller.reasonController,
      maxLines: 4,
      style: AppTextStyles.bodyMedium(textPrimary),
      decoration: InputDecoration(
        hintText: 'Document symptoms, diagnosis, and medical reason...',
        hintStyle: AppTextStyles.bodyMedium(
          textSecondary.withValues(alpha: 0.5),
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
      ),
    );
  }

  Widget _buildActionButtons(AdmitPatientController controller, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () async {
            final shouldPop = await _showDiscardConfirmation(
              Get.context!,
              isDark,
            );
            if (shouldPop) {
              Get.back();
            }
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(100, 48),
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
              controller.isSubmitting ? null : controller.submitAdmission,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: AppColors.lightSurface,
            minimumSize: const Size(140, 48),
            shape: RoundedRectangleBorder(
              borderRadius: AppDecorations.borderMD,
            ),
            elevation: 0,
          ),
          child: controller.isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Admit Patient',
                  style: AppTextStyles.labelMedium(
                    Colors.white,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  InputDecoration _getInputDecoration(
    bool isDark,
    Color borderColor, {
    bool isEnabled = true,
  }) {
    return InputDecoration(
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

  Future<bool> _showDiscardConfirmation(
    BuildContext context,
    bool isDark,
  ) async {
    // If nothing has been selected/entered, we can discard immediately
    if (controller.selectedPatient == null &&
        controller.selectedWard == null &&
        controller.selectedBed == null &&
        controller.selectedAdmissionType == null &&
        controller.selectedAdmittingDoctor == null &&
        controller.selectedAttendingDoctor == null &&
        controller.reasonController.text.isEmpty) {
      return true;
    }

    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: Text(
          'Discard Changes?',
          style: AppTextStyles.titleMedium(
            textPrimary,
          ).copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to discard this admission form?',
          style: AppTextStyles.bodyMedium(textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              'Cancel',
              style: AppTextStyles.labelMedium(
                AppColors.primary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(
              'Discard',
              style: AppTextStyles.labelMedium(
                AppColors.error,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }
}
