// lib/app/modules/inpatient/views/admit_patient_view.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medihive/app/theme/theme.dart';
import '../controllers/inpatient_controller.dart';

class AdmitPatientView extends GetView<InpatientController> {
  const AdmitPatientView({super.key});

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
        scrolledUnderElevation: 1,
        shadowColor: AppColors.primary.withValues(alpha: 0.08),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: textPrimary, size: AppSpacing.iconMD),
          onPressed: () {
            controller.resetAdmitForm();
            Get.back();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admit Patient', style: AppTextStyles.titleMedium(textPrimary)),
            Text('Fill in all required fields',
                style: AppTextStyles.labelSmall(AppColors.primary)),
          ],
        ),
      ),
      body: GetBuilder<InpatientController>(
        builder: (ctrl) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section: Patient ──────────────────────────────────────────
              _SectionHeader(label: '1. Patient Information', isDark: isDark),
              const SizedBox(height: AppSpacing.sm),
              _FormLabel(label: 'Select Patient *', textSecondary: textSecondary),
              const SizedBox(height: AppSpacing.xs),
              _PatientSelector(
                isDark: isDark,
                surface: surface,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                ctrl: ctrl,
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Section: Ward & Bed ───────────────────────────────────────
              _SectionHeader(label: '2. Ward & Bed Assignment', isDark: isDark),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FormLabel(
                            label: 'Select Ward *',
                            textSecondary: textSecondary),
                        const SizedBox(height: AppSpacing.xs),
                        _WardDropdownField(
                          isDark: isDark,
                          surface: surface,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          ctrl: ctrl,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FormLabel(
                            label: 'Assign Bed *',
                            textSecondary: textSecondary),
                        const SizedBox(height: AppSpacing.xs),
                        _BedDropdownField(
                          isDark: isDark,
                          surface: surface,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          ctrl: ctrl,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Section: Admission Details ────────────────────────────────
              _SectionHeader(
                  label: '3. Admission Details', isDark: isDark),
              const SizedBox(height: AppSpacing.sm),
              _FormLabel(
                  label: 'Admission Type *', textSecondary: textSecondary),
              const SizedBox(height: AppSpacing.xs),
              _AdmitTypeDropdown(
                isDark: isDark,
                surface: surface,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                ctrl: ctrl,
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Section: Doctors ──────────────────────────────────────────
              _SectionHeader(label: '4. Assigned Doctors', isDark: isDark),
              const SizedBox(height: AppSpacing.sm),
              _FormLabel(
                  label: 'Admitting Doctor *', textSecondary: textSecondary),
              const SizedBox(height: AppSpacing.xs),
              _DoctorDropdownField(
                isDark: isDark,
                surface: surface,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                ctrl: ctrl,
                isAttending: false,
              ),
              const SizedBox(height: AppSpacing.md),
              _FormLabel(
                  label: 'Attending Doctor *', textSecondary: textSecondary),
              const SizedBox(height: AppSpacing.xs),
              _DoctorDropdownField(
                isDark: isDark,
                surface: surface,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                ctrl: ctrl,
                isAttending: true,
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Section: Reason ───────────────────────────────────────────
              _SectionHeader(label: '5. Admission Reason', isDark: isDark),
              const SizedBox(height: AppSpacing.sm),
              _FormLabel(
                  label: 'Reason for Admission *',
                  textSecondary: textSecondary),
              const SizedBox(height: AppSpacing.xs),
              Container(
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: AppDecorations.borderMD,
                  border: Border.all(
                      color: textSecondary.withValues(alpha: 0.15)),
                  boxShadow: AppDecorations.elevation1(isDark),
                ),
                child: TextField(
                  onChanged: ctrl.setAdmissionReason,
                  maxLines: 5,
                  style: AppTextStyles.bodyMedium(textPrimary),
                  decoration: InputDecoration(
                    hintText:
                        'Document symptoms, diagnosis, and medical reason for admission...',
                    hintStyle: AppTextStyles.bodySmall(textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(AppSpacing.md),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // ── Validation summary (inline) ───────────────────────────────
              if (!ctrl.canSubmitAdmit && ctrl.admissionReason.isNotEmpty ||
                  ctrl.admitSelectedPatient != null)
                _ValidationSummary(ctrl: ctrl, isDark: isDark),

              const SizedBox(height: AppSpacing.md),

              // ── Buttons ───────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ctrl.resetAdmitForm();
                        Get.back();
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: textSecondary.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppDecorations.borderMD),
                      ),
                      child: Text('Cancel',
                          style: AppTextStyles.labelMedium(textSecondary)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: AppDecorations.borderMD,
                      ),
                      child: TextButton(
                        onPressed: ctrl.submitAdmitPatient,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md),
                          shape: RoundedRectangleBorder(
                              borderRadius: AppDecorations.borderMD),
                        ),
                        child: Text(
                          'Admit Patient',
                          style:
                              AppTextStyles.labelLarge(AppColors.lightSurface),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.titleSmall(textPrimary)),
        const SizedBox(height: AppSpacing.xs),
        Container(
          height: 2,
          width: 40,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: AppDecorations.borderFull,
          ),
        ),
      ],
    );
  }
}

// ── Form Label ─────────────────────────────────────────────────────────────────

class _FormLabel extends StatelessWidget {
  const _FormLabel({required this.label, required this.textSecondary});
  final String label;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: AppTextStyles.labelMedium(textSecondary));
}

// ── Validation Summary ─────────────────────────────────────────────────────────

class _ValidationSummary extends StatelessWidget {
  const _ValidationSummary({required this.ctrl, required this.isDark});
  final InpatientController ctrl;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final missing = <String>[];
    if (ctrl.admitSelectedPatient == null) missing.add('• Patient');
    if (ctrl.admitSelectedWard == null) missing.add('• Ward');
    if (ctrl.admitSelectedBed == null) missing.add('• Bed');
    if (ctrl.admittingDoctor == null) missing.add('• Admitting Doctor');
    if (ctrl.attendingDoctor == null) missing.add('• Attending Doctor');
    if (ctrl.admissionReason.trim().isEmpty) missing.add('• Admission Reason');

    if (missing.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: AppDecorations.borderMD,
        border:
            Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.error, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Text('Missing required fields:',
                  style: AppTextStyles.labelMedium(AppColors.error)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ...missing.map((m) => Text(m,
              style: AppTextStyles.bodySmall(AppColors.error))),
        ],
      ),
    );
  }
}

// ── Patient Selector with Search ───────────────────────────────────────────────

class _PatientSelector extends StatefulWidget {
  const _PatientSelector({
    required this.isDark,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.ctrl,
  });
  final bool isDark;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final InpatientController ctrl;

  @override
  State<_PatientSelector> createState() => _PatientSelectorState();
}

class _PatientSelectorState extends State<_PatientSelector> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final selected = ctrl.admitSelectedPatient;

    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: widget.surface,
              borderRadius: _expanded
                  ? const BorderRadius.vertical(
                      top: Radius.circular(AppDecorations.radiusMD))
                  : AppDecorations.borderMD,
              border: Border.all(
                  color: widget.textSecondary.withValues(alpha: 0.15)),
              boxShadow: AppDecorations.elevation1(widget.isDark),
            ),
            child: Row(
              children: [
                Icon(Icons.person_search_rounded,
                    color: widget.textSecondary, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    selected?.displayLabel ?? 'Choose a patient...',
                    style: AppTextStyles.bodyMedium(selected != null
                        ? widget.textPrimary
                        : widget.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: widget.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            decoration: BoxDecoration(
              color: widget.surface,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppDecorations.radiusMD)),
              border: Border.all(
                  color: widget.textSecondary.withValues(alpha: 0.15)),
              boxShadow: AppDecorations.elevation1(widget.isDark),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: TextField(
                    onChanged: ctrl.setPatientSearchQuery,
                    autofocus: true,
                    style: AppTextStyles.bodyMedium(widget.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search by name or MRN...',
                      hintStyle:
                          AppTextStyles.bodySmall(widget.textSecondary),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: widget.textSecondary, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: AppDecorations.borderSM,
                        borderSide: BorderSide(
                            color: widget.textSecondary
                                .withValues(alpha: 0.3)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ctrl.filteredPatients.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text('No patients found',
                              style: AppTextStyles.bodySmall(
                                  widget.textSecondary)),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: ctrl.filteredPatients.length,
                          itemBuilder: (_, i) {
                            final p = ctrl.filteredPatients[i];
                            final isSelected = selected?.id == p.id;
                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              selectedTileColor: AppColors.primary
                                  .withValues(alpha: 0.08),
                              title: Text(p.fullName,
                                  style: AppTextStyles.bodySmall(
                                      widget.textPrimary)),
                              subtitle: Text(p.mrn,
                                  style: AppTextStyles.labelSmall(
                                      widget.textSecondary)),
                              trailing: isSelected
                                  ? const Icon(Icons.check_rounded,
                                      color: AppColors.primary, size: 16)
                                  : null,
                              onTap: () {
                                ctrl.setAdmitPatient(p);
                                setState(() => _expanded = false);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Ward Dropdown ──────────────────────────────────────────────────────────────

class _WardDropdownField extends StatelessWidget {
  const _WardDropdownField({
    required this.isDark,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.ctrl,
  });
  final bool isDark;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final InpatientController ctrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderMD,
        border:
            Border.all(color: textSecondary.withValues(alpha: 0.15)),
        boxShadow: AppDecorations.elevation1(isDark),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: ctrl.admitSelectedWard?.id,
          hint: Text('Select Ward',
              style: AppTextStyles.bodySmall(textSecondary)),
          isExpanded: true,
          dropdownColor: surface,
          style: AppTextStyles.bodySmall(textPrimary),
          icon:
              Icon(Icons.expand_more_rounded, color: textSecondary, size: 18),
          items: ctrl.activeWards
              .map((w) => DropdownMenuItem(
                    value: w.id,
                    child: Text(w.name.trim(),
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) {
            final ward =
                ctrl.activeWards.firstWhereOrNull((w) => w.id == v);
            ctrl.setAdmitWard(ward);
          },
        ),
      ),
    );
  }
}

// ── Bed Dropdown ───────────────────────────────────────────────────────────────

class _BedDropdownField extends StatelessWidget {
  const _BedDropdownField({
    required this.isDark,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.ctrl,
  });
  final bool isDark;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final InpatientController ctrl;

  @override
  Widget build(BuildContext context) {
    final enabled = ctrl.admitSelectedWard != null;
    final beds = ctrl.availableBedsForAdmitWard;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: enabled ? surface : surface.withValues(alpha: 0.5),
        borderRadius: AppDecorations.borderMD,
        border: Border.all(
            color: textSecondary.withValues(alpha: enabled ? 0.15 : 0.08)),
        boxShadow: AppDecorations.elevation1(isDark),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: ctrl.admitSelectedBed?.id,
          hint: Text(
            enabled ? 'Choose Bed' : 'Choose Ward First',
            style: AppTextStyles.bodySmall(textSecondary),
          ),
          isExpanded: true,
          dropdownColor: surface,
          style: AppTextStyles.bodySmall(textPrimary),
          icon:
              Icon(Icons.expand_more_rounded, color: textSecondary, size: 18),
          items: enabled
              ? beds
                  .map((b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(b.bedNumber,
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList()
              : null,
          onChanged: enabled
              ? (v) {
                  final bed = beds.firstWhereOrNull((b) => b.id == v);
                  ctrl.setAdmitBed(bed);
                }
              : null,
        ),
      ),
    );
  }
}

// ── Admission Type Dropdown ────────────────────────────────────────────────────

class _AdmitTypeDropdown extends StatelessWidget {
  const _AdmitTypeDropdown({
    required this.isDark,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.ctrl,
  });
  final bool isDark;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final InpatientController ctrl;

  static const _types = ['Routine Admission', 'Emergency', 'Ward Transfer'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderMD,
        border:
            Border.all(color: textSecondary.withValues(alpha: 0.15)),
        boxShadow: AppDecorations.elevation1(isDark),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: ctrl.admitType,
          isExpanded: true,
          dropdownColor: surface,
          style: AppTextStyles.bodySmall(textPrimary),
          icon:
              Icon(Icons.expand_more_rounded, color: textSecondary, size: 18),
          items: _types
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) {
            if (v != null) ctrl.setAdmitType(v);
          },
        ),
      ),
    );
  }
}

// ── Doctor Dropdown ────────────────────────────────────────────────────────────

class _DoctorDropdownField extends StatelessWidget {
  const _DoctorDropdownField({
    required this.isDark,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.ctrl,
    required this.isAttending,
  });
  final bool isDark;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final InpatientController ctrl;
  final bool isAttending;

  @override
  Widget build(BuildContext context) {
    final selected = isAttending ? ctrl.attendingDoctor : ctrl.admittingDoctor;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderMD,
        border:
            Border.all(color: textSecondary.withValues(alpha: 0.15)),
        boxShadow: AppDecorations.elevation1(isDark),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected?.id,
          hint: Text(
            isAttending ? 'Select Attending Doctor' : 'Select Admitting Doctor',
            style: AppTextStyles.bodySmall(textSecondary),
          ),
          isExpanded: true,
          dropdownColor: surface,
          style: AppTextStyles.bodySmall(textPrimary),
          icon:
              Icon(Icons.expand_more_rounded, color: textSecondary, size: 18),
          items: ctrl.doctors
              .map((d) => DropdownMenuItem(
                    value: d.id,
                    child:
                        Text(d.displayName, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) {
            final doc = ctrl.doctors.firstWhereOrNull((d) => d.id == v);
            isAttending
                ? ctrl.setAttendingDoctor(doc)
                : ctrl.setAdmittingDoctor(doc);
          },
        ),
      ),
    );
  }
}
