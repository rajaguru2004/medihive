import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:medihive/app/theme/theme.dart';
import '../controllers/appointment_create_controller.dart';
import '../models/appointment_create_model.dart';

// ─── Manual date helpers (no intl dependency needed) ──────────────────────────
String _formatDate(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

const _weekDayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _formatDayLabel(DateTime d) {
  // weekday: 1=Mon … 7=Sun
  final weekDay = _weekDayNames[d.weekday - 1];
  final month = _monthNames[d.month - 1];
  return '$weekDay, $month ${d.day}';
}

class AppointmentCreateView extends GetView<AppointmentCreateController> {
  const AppointmentCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(isDark, textPrimary, surface),
      body: GetBuilder<AppointmentCreateController>(
        builder: (ctrl) => SafeArea(
          child: Form(
            key: ctrl.formKey,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Section 1: Patient & Doctor ──────────────────────
                      _SectionCard(
                        isDark: isDark,
                        icon: Icons.person_pin_outlined,
                        title: 'PATIENT & DOCTOR INFO',
                        iconColor: AppColors.secondary,
                        child: _PatientDoctorSection(isDark: isDark),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ── Section 2: Schedule ──────────────────────────────
                      _SectionCard(
                        isDark: isDark,
                        icon: Icons.calendar_month_outlined,
                        title: 'SCHEDULE DETAILS',
                        iconColor: AppColors.secondary,
                        child: _ScheduleSection(isDark: isDark),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ── Section 3: Configuration ─────────────────────────
                      _SectionCard(
                        isDark: isDark,
                        icon: Icons.tune_rounded,
                        title: 'CONFIGURATION',
                        iconColor: AppColors.secondary,
                        child: _ConfigSection(isDark: isDark),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ── Section 4: Clinical Info ─────────────────────────
                      _SectionCard(
                        isDark: isDark,
                        icon: Icons.assignment_outlined,
                        title: 'CLINICAL INFORMATION',
                        iconColor: AppColors.secondary,
                        child: _ClinicalSection(isDark: isDark),
                      ),
                      const SizedBox(height: AppSpacing.xxl),

                      // ── Action Buttons ────────────────────────────────────
                      _ActionButtons(isDark: isDark),
                      const SizedBox(height: AppSpacing.huge),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      bool isDark, Color textPrimary, Color surface) {
    return AppBar(
      backgroundColor: surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.primary.withValues(alpha: 0.08),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: textPrimary, size: AppSpacing.iconMD),
        onPressed: () => Get.back(),
        tooltip: 'Back',
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create New Appointment',
            style: AppTextStyles.titleMedium(textPrimary),
          ),
          Text(
            'Schedule a new patient consultation and doctor assignment',
            style: AppTextStyles.labelSmall(AppColors.primary),
          ),
        ],
      ),
      titleSpacing: 0,
    );
  }
}

// ─── Section Card Wrapper ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.child,
  });

  final bool isDark;
  final IconData icon;
  final String title;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderLG,
        boxShadow: AppDecorations.elevation1(isDark),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(icon, color: iconColor, size: AppSpacing.iconMD),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTextStyles.labelMedium(iconColor).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
            child: Divider(
              color: (isDark ? AppColors.darkDivider : AppColors.lightDivider),
              height: 1,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ─── Section 1: Patient & Doctor ──────────────────────────────────────────────

class _PatientDoctorSection extends GetView<AppointmentCreateController> {
  const _PatientDoctorSection({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppointmentCreateController>(
      builder: (ctrl) => LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 500;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _patientDropdown(ctrl)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _doctorDropdown(ctrl)),
              ],
            );
          }
          return Column(
            children: [
              _patientDropdown(ctrl),
              const SizedBox(height: AppSpacing.md),
              _doctorDropdown(ctrl),
            ],
          );
        },
      ),
    );
  }

  Widget _patientDropdown(AppointmentCreateController ctrl) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor =
        isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final surfaceVar = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: 'Patient', required: true, isDark: isDark),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: ctrl.patientSearchCtrl,
          style: AppTextStyles.bodyMedium(textPrimary),
          decoration: InputDecoration(
            hintText: 'Search patient by name...',
            hintStyle: AppTextStyles.bodyMedium(textSecondary),
            prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
            suffixIcon: ctrl.patientSearchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      ctrl.patientSearchCtrl.clear();
                    },
                  )
                : null,
            filled: true,
            fillColor: surfaceVar,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
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
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<PatientListItem>(
          initialValue: ctrl.selectedPatient,
          isExpanded: true,
          decoration: _inputDecoration(
            isDark: isDark,
            hint: ctrl.patientsLoading ? 'Loading patients…' : 'Select patient...',
            prefixIcon: Icons.person_outline_rounded,
            borderColor: borderColor,
          ),
          style: AppTextStyles.bodyMedium(textPrimary),
          dropdownColor:
              isDark ? AppColors.darkSurface : AppColors.lightSurface,
          hint: Text(
            ctrl.patientsLoading ? 'Loading patients…' : 'Select patient...',
            style: AppTextStyles.bodyMedium(textSecondary),
          ),
          items: ctrl.filteredPatients
              .map(
                (p) => DropdownMenuItem(
                  value: p,
                  child: Text(
                    p.fullName,
                    style: AppTextStyles.bodyMedium(textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: ctrl.patientsLoading ? null : ctrl.setPatient,
          validator: (_) =>
              ctrl.selectedPatient == null ? 'Patient is required' : null,
        ),
      ],
    );
  }

  Widget _doctorDropdown(AppointmentCreateController ctrl) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor =
        isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: 'Doctor', required: true, isDark: isDark),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<DoctorListItem>(
          initialValue: ctrl.selectedDoctor,
          isExpanded: true,
          decoration: _inputDecoration(
            isDark: isDark,
            hint: ctrl.doctorsLoading ? 'Loading doctors…' : 'Select doctor',
            prefixIcon: Icons.medical_services_outlined,
            borderColor: borderColor,
          ),
          style: AppTextStyles.bodyMedium(textPrimary),
          dropdownColor:
              isDark ? AppColors.darkSurface : AppColors.lightSurface,
          hint: Text(
            ctrl.doctorsLoading ? 'Loading doctors…' : 'Select doctor',
            style: AppTextStyles.bodyMedium(textSecondary),
          ),
          items: ctrl.doctors
              .map(
                (d) => DropdownMenuItem(
                  value: d,
                  child: Text(
                    d.displayName,
                    style: AppTextStyles.bodyMedium(textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: ctrl.doctorsLoading ? null : ctrl.setDoctor,
          validator: (_) =>
              ctrl.selectedDoctor == null ? 'Doctor is required' : null,
        ),
      ],
    );
  }
}

// ─── Section 2: Schedule Details ──────────────────────────────────────────────

class _ScheduleSection extends GetView<AppointmentCreateController> {
  const _ScheduleSection({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppointmentCreateController>(
      builder: (ctrl) => LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 500;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _datePicker(context, ctrl)),
                const SizedBox(width: AppSpacing.md),
                Expanded(flex: 2, child: _timeDropdown(ctrl)),
                const SizedBox(width: AppSpacing.md),
                Expanded(flex: 2, child: _durationDropdown(ctrl)),
              ],
            );
          }
          return Column(
            children: [
              _datePicker(context, ctrl),
              const SizedBox(height: AppSpacing.md),
              _timeDropdown(ctrl),
              const SizedBox(height: AppSpacing.md),
              _durationDropdown(ctrl),
            ],
          );
        },
      ),
    );
  }

  Widget _datePicker(BuildContext context, AppointmentCreateController ctrl) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final borderColor =
        isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final surfaceVar = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurfaceVariant;
    final formatted = _formatDate(ctrl.selectedDate);
    final dayLabel = _formatDayLabel(ctrl.selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: 'Date', required: true, isDark: isDark),
        const SizedBox(height: AppSpacing.xs),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: ctrl.selectedDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (ctx, child) => Theme(
                data: isDark ? ThemeData.dark() : ThemeData.light(),
                child: child!,
              ),
            );
            if (picked != null) ctrl.setDate(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: surfaceVar,
              borderRadius: AppDecorations.borderMD,
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    color: AppColors.primary, size: AppSpacing.iconMD),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatted,
                        style: AppTextStyles.bodyMedium(textPrimary)
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text(dayLabel,
                        style: AppTextStyles.labelSmall(AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _timeDropdown(AppointmentCreateController ctrl) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor =
        isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: 'Time', required: true, isDark: isDark),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<String>(
          initialValue: ctrl.selectedTime,
          isExpanded: true,
          decoration: _inputDecoration(
            isDark: isDark,
            hint: 'Select time',
            prefixIcon: Icons.access_time_rounded,
            borderColor: borderColor,
          ),
          style: AppTextStyles.bodyMedium(textPrimary),
          dropdownColor:
              isDark ? AppColors.darkSurface : AppColors.lightSurface,
          hint: Text('Select time',
              style: AppTextStyles.bodyMedium(textSecondary)),
          items: AppointmentCreateController.timeSlots
              .map(
                (slot) => DropdownMenuItem(
                  value: slot,
                  child: Text(
                    AppointmentCreateController.formatTimeSlot(slot),
                    style: AppTextStyles.bodyMedium(textPrimary),
                  ),
                ),
              )
              .toList(),
          onChanged: ctrl.setTime,
          validator: (_) =>
              ctrl.selectedTime == null ? 'Time is required' : null,
        ),
      ],
    );
  }

  Widget _durationDropdown(AppointmentCreateController ctrl) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final borderColor =
        isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: 'Duration', required: false, isDark: isDark),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<int>(
          initialValue: ctrl.durationMinutes,
          isExpanded: true,
          decoration: _inputDecoration(
            isDark: isDark,
            hint: 'Duration',
            prefixIcon: Icons.hourglass_bottom_rounded,
            borderColor: borderColor,
          ),
          style: AppTextStyles.bodyMedium(textPrimary),
          dropdownColor:
              isDark ? AppColors.darkSurface : AppColors.lightSurface,
          items: AppointmentCreateController.durationOptions
              .map(
                (o) => DropdownMenuItem(
                  value: o.value,
                  child: Text(o.label,
                      style: AppTextStyles.bodyMedium(textPrimary)),
                ),
              )
              .toList(),
          onChanged: ctrl.setDuration,
        ),
      ],
    );
  }
}

// ─── Section 3: Configuration ──────────────────────────────────────────────────

class _ConfigSection extends GetView<AppointmentCreateController> {
  const _ConfigSection({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppointmentCreateController>(
      builder: (ctrl) => LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 500;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _typeDropdown(ctrl)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _priorityDropdown(ctrl)),
              ],
            );
          }
          return Column(
            children: [
              _typeDropdown(ctrl),
              const SizedBox(height: AppSpacing.md),
              _priorityDropdown(ctrl),
            ],
          );
        },
      ),
    );
  }

  Widget _typeDropdown(AppointmentCreateController ctrl) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final borderColor =
        isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: 'Appointment Type', required: false, isDark: isDark),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<String>(
          initialValue: ctrl.appointmentType,
          isExpanded: true,
          decoration: _inputDecoration(
            isDark: isDark,
            hint: 'Type',
            prefixIcon: Icons.category_outlined,
            borderColor: borderColor,
          ),
          style: AppTextStyles.bodyMedium(textPrimary),
          dropdownColor:
              isDark ? AppColors.darkSurface : AppColors.lightSurface,
          items: AppointmentCreateController.appointmentTypes
              .map(
                (o) => DropdownMenuItem(
                  value: o.value,
                  child: Text(o.label,
                      style: AppTextStyles.bodyMedium(textPrimary)),
                ),
              )
              .toList(),
          onChanged: ctrl.setAppointmentType,
        ),
      ],
    );
  }

  Widget _priorityDropdown(AppointmentCreateController ctrl) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final borderColor =
        isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: 'Priority', required: false, isDark: isDark),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<String>(
          initialValue: ctrl.priority,
          isExpanded: true,
          decoration: _inputDecoration(
            isDark: isDark,
            hint: 'Priority',
            prefixIcon: Icons.flag_outlined,
            borderColor: borderColor,
          ),
          style: AppTextStyles.bodyMedium(textPrimary),
          dropdownColor:
              isDark ? AppColors.darkSurface : AppColors.lightSurface,
          items: AppointmentCreateController.priorityOptions
              .map(
                (o) => DropdownMenuItem(
                  value: o.value,
                  child: Text(o.label,
                      style: AppTextStyles.bodyMedium(textPrimary)),
                ),
              )
              .toList(),
          onChanged: ctrl.setPriority,
        ),
      ],
    );
  }
}

// ─── Section 4: Clinical Information ──────────────────────────────────────────

class _ClinicalSection extends GetView<AppointmentCreateController> {
  const _ClinicalSection({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor =
        isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final surfaceVar = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chief Complaint
        _FieldLabel(label: 'Chief Complaint', required: true, isDark: isDark),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller.chiefComplaintCtrl,
          minLines: 3,
          maxLines: 5,
          style: AppTextStyles.bodyMedium(textPrimary),
          decoration: InputDecoration(
            hintText:
                "Describe patient's main complaint or reason for visit (min 5 characters)...",
            hintStyle: AppTextStyles.bodyMedium(textSecondary),
            filled: true,
            fillColor: surfaceVar,
            contentPadding: const EdgeInsets.all(AppSpacing.md),
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
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppDecorations.borderMD,
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppDecorations.borderMD,
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Chief complaint is required';
            }
            if (val.trim().length < 5) {
              return 'Minimum 5 characters required';
            }
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.lg),

        // Additional Notes
        _FieldLabel(label: 'Additional Notes', required: false, isDark: isDark),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller.notesCtrl,
          minLines: 3,
          maxLines: 6,
          style: AppTextStyles.bodyMedium(textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter any additional instructions or patient history...',
            hintStyle: AppTextStyles.bodyMedium(textSecondary),
            filled: true,
            fillColor: surfaceVar,
            contentPadding: const EdgeInsets.all(AppSpacing.md),
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
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Action Buttons ────────────────────────────────────────────────────────────

class _ActionButtons extends GetView<AppointmentCreateController> {
  const _ActionButtons({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor =
        isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return GetBuilder<AppointmentCreateController>(
      builder: (ctrl) => LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 400;
          final cancelBtn = OutlinedButton(
            onPressed: ctrl.submitting ? null : () => Get.back(),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: borderColor),
              backgroundColor: surface,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                  borderRadius: AppDecorations.borderMD),
              minimumSize: const Size(0, AppSpacing.buttonHeightMD),
            ),
            child: Text('Cancel',
                style: AppTextStyles.labelLarge(textPrimary)),
          );

          final createBtn = Container(
            height: AppSpacing.buttonHeightMD,
            decoration: BoxDecoration(
              gradient: ctrl.submitting ? null : AppColors.primaryGradient,
              color: ctrl.submitting
                  ? (isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant)
                  : null,
              borderRadius: AppDecorations.borderMD,
            ),
            child: ElevatedButton(
              onPressed: ctrl.submitting ? null : ctrl.submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                    borderRadius: AppDecorations.borderMD),
                minimumSize: const Size(0, AppSpacing.buttonHeightMD),
                disabledBackgroundColor: Colors.transparent,
              ),
              child: ctrl.submitting
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Creating…',
                            style: AppTextStyles.labelLarge(AppColors.primary)),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            color: AppColors.lightSurface,
                            size: AppSpacing.iconSM),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Create Appointment',
                            style: AppTextStyles.labelLarge(
                                AppColors.lightSurface)),
                      ],
                    ),
            ),
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(child: cancelBtn),
                const SizedBox(width: AppSpacing.md),
                Expanded(flex: 2, child: createBtn),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              createBtn,
              const SizedBox(height: AppSpacing.sm),
              cancelBtn,
            ],
          );
        },
      ),
    );
  }
}

// ─── Shared helpers ────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.label,
    required this.required,
    required this.isDark,
  });

  final String label;
  final bool required;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.labelMedium(textPrimary)),
        if (required) ...[
          const SizedBox(width: AppSpacing.xxs),
          const Text('*',
              style: TextStyle(color: AppColors.error, fontSize: 14)),
        ],
      ],
    );
  }
}

InputDecoration _inputDecoration({
  required bool isDark,
  required String hint,
  required IconData prefixIcon,
  required Color borderColor,
}) {
  final textSecondary =
      isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  final surfaceVar =
      isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;

  return InputDecoration(
    hintText: hint,
    hintStyle: AppTextStyles.bodyMedium(textSecondary),
    filled: true,
    fillColor: surfaceVar,
    prefixIcon: Icon(prefixIcon, color: AppColors.primary, size: AppSpacing.iconMD),
    contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: AppSpacing.md),
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
    errorBorder: OutlineInputBorder(
      borderRadius: AppDecorations.borderMD,
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: AppDecorations.borderMD,
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
  );
}
