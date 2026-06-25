// lib/app/modules/inpatient/views/discharge_patient_view.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:medihive/app/theme/theme.dart';
import 'package:medihive/app/network/app_dio_client.dart';
import '../controllers/inpatient_controller.dart';
import '../models/inpatient_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DISCHARGE PATIENT VIEW
// Full-screen mobile-friendly discharge form
// ─────────────────────────────────────────────────────────────────────────────

class DischargePatientView extends StatefulWidget {
  final String admissionId;
  final String patientName;
  final String bedNumber;

  const DischargePatientView({
    super.key,
    required this.admissionId,
    required this.patientName,
    required this.bedNumber,
  });

  @override
  State<DischargePatientView> createState() => _DischargePatientViewState();
}

class _DischargePatientViewState extends State<DischargePatientView> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _reasonCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _directivesCtrl = TextEditingController();

  // State
  DoctorModel? _selectedDoctor;
  DateTime? _followUpDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _summaryCtrl.dispose();
    _directivesCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.secondary,
                    onPrimary: AppColors.lightSurface,
                    surface: AppColors.darkSurface,
                    onSurface: AppColors.darkTextPrimary,
                  )
                : const ColorScheme.light(
                    primary: AppColors.secondary,
                    onPrimary: AppColors.lightSurface,
                    surface: AppColors.lightSurface,
                    onSurface: AppColors.lightTextPrimary,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _followUpDate = picked);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDoctor == null) {
      _showError('Please select a discharging doctor.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'status': 'discharged',
        'dischargeReason': _reasonCtrl.text.trim(),
        'dischargeSummary': _summaryCtrl.text.trim(),
        'dischargeDoctorId': _selectedDoctor!.id,
        'followUpDate': _followUpDate?.toIso8601String(),
        'followUpNotes': _directivesCtrl.text.trim(),
      };

      final dio = AppDioClient.instance;
      await dio.patch(
        '/api/inpatient/admissions/${widget.admissionId}',
        data: payload,
      );

      // Refresh parent controller
      try {
        Get.find<InpatientController>().onRefresh();
      } catch (_) {}

      if (!mounted) return;
      Get.back();

      Get.snackbar(
        '✓ Patient Discharged',
        '${widget.patientName} has been discharged. Bed ${widget.bedNumber} is now available.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.secondary.withValues(alpha: 0.92),
        colorText: AppColors.lightSurface,
        icon: const Icon(Icons.check_circle_outline_rounded,
            color: AppColors.lightSurface),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppDecorations.radiusMD,
      );
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[DischargeView] DioException: $e');
      _showError(e.response?.data?['message'] as String? ??
          'Network error. Please try again.');
    } catch (e) {
      if (kDebugMode) debugPrint('[DischargeView] Error: $e');
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    Get.snackbar(
      'Error',
      msg,
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.error.withValues(alpha: 0.92),
      colorText: AppColors.lightSurface,
      icon: const Icon(Icons.error_outline_rounded,
          color: AppColors.lightSurface),
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(AppSpacing.md),
      borderRadius: AppDecorations.radiusMD,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = textSecondary.withValues(alpha: 0.18);

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(textPrimary, isDark),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Patient info banner ────────────────────────────────────
              _PatientInfoBanner(
                patientName: widget.patientName,
                bedNumber: widget.bedNumber,
                isDark: isDark,
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Row 1: Discharge Reason | Discharging Doctor ──────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildReasonField(
                        textPrimary, textSecondary, surface, borderColor, isDark),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _buildDoctorDropdown(
                        textPrimary, textSecondary, surface, borderColor, isDark),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Discharge Summary ─────────────────────────────────────
              _buildLabel('Discharge Summary *', textPrimary),
              const SizedBox(height: AppSpacing.xs),
              _buildSummaryField(
                  textPrimary, textSecondary, surface, borderColor, isDark),
              const SizedBox(height: AppSpacing.lg),

              // ── Row 2: Follow-up Date | Follow-up Directives ──────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildFollowUpDate(
                        textPrimary, textSecondary, surface, borderColor, isDark),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _buildDirectivesField(
                        textPrimary, textSecondary, surface, borderColor, isDark),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Bed free info banner ───────────────────────────────────
              _BedFreeBanner(
                  bedNumber: widget.bedNumber, isDark: isDark),
              const SizedBox(height: AppSpacing.xxxl),

              // ── Actions ───────────────────────────────────────────────
              _buildActions(textSecondary, isDark),
              const SizedBox(height: AppSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Color textPrimary, bool isDark) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    return AppBar(
      backgroundColor: surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.secondary.withValues(alpha: 0.08),
      leading: IconButton(
        icon: Icon(Icons.close_rounded, color: textPrimary),
        onPressed: () => Get.back(),
        tooltip: 'Cancel',
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_rounded,
                  color: AppColors.secondary, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text('Discharge Patient',
                  style: AppTextStyles.titleMedium(textPrimary)),
            ],
          ),
          Text(
            'Record discharge summary and follow-up directives for ${widget.patientName}.',
            style: AppTextStyles.labelSmall(AppColors.secondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Field Builders ────────────────────────────────────────────────────────

  Widget _buildLabel(String text, Color textPrimary) => Text(
        text,
        style: AppTextStyles.labelMedium(textPrimary)
            .copyWith(fontWeight: FontWeight.w600),
      );

  Widget _buildReasonField(Color textPrimary, Color textSecondary,
      Color surface, Color borderColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Discharge Reason *', textPrimary),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: _reasonCtrl,
          style: AppTextStyles.bodySmall(textPrimary),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
          decoration: _inputDecoration(
            hint: 'e.g. Fully recovered',
            textSecondary: textSecondary,
            surface: surface,
            borderColor: borderColor,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorDropdown(Color textPrimary, Color textSecondary,
      Color surface, Color borderColor, bool isDark) {
    final ctrl = _safeController();
    final doctors = ctrl?.doctors ?? <DoctorModel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Discharging Doctor *', textPrimary),
        const SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: AppDecorations.borderMD,
            border: Border.all(color: borderColor),
            boxShadow: AppDecorations.elevation1(isDark),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<DoctorModel>(
              value: _selectedDoctor,
              hint: Text('Choose Doctor',
                  style: AppTextStyles.bodySmall(textSecondary)),
              isExpanded: true,
              dropdownColor: surface,
              style: AppTextStyles.bodySmall(textPrimary),
              icon:
                  Icon(Icons.expand_more_rounded, color: textSecondary, size: 18),
              items: doctors
                  .map((d) => DropdownMenuItem<DoctorModel>(
                        value: d,
                        child: Text(
                          'Dr. ${d.fullName}${d.specialization != null && d.specialization!.isNotEmpty ? ' (${d.specialization})' : ''}',
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall(textPrimary),
                        ),
                      ))
                  .toList(),
              onChanged: (d) => setState(() => _selectedDoctor = d),
            ),
          ),
        ),
        if (_selectedDoctor == null && _isSubmitting)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.sm),
            child: Text('Required',
                style: AppTextStyles.labelSmall(AppColors.error)),
          ),
      ],
    );
  }

  Widget _buildSummaryField(Color textPrimary, Color textSecondary,
      Color surface, Color borderColor, bool isDark) {
    return TextFormField(
      controller: _summaryCtrl,
      style: AppTextStyles.bodySmall(textPrimary),
      maxLines: 4,
      minLines: 4,
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Discharge summary is required' : null,
      decoration: _inputDecoration(
        hint:
            'Enter detailed summary of course in hospital, treatment given, and condition on discharge...',
        textSecondary: textSecondary,
        surface: surface,
        borderColor: borderColor,
        isDark: isDark,
      ),
    );
  }

  Widget _buildFollowUpDate(Color textPrimary, Color textSecondary,
      Color surface, Color borderColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Follow-up Date', textPrimary),
        const SizedBox(height: AppSpacing.xs),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: AppDecorations.borderMD,
              border: Border.all(color: borderColor),
              boxShadow: AppDecorations.elevation1(isDark),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    color: textSecondary, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _followUpDate != null
                        ? _formatDate(_followUpDate!)
                        : 'Select Date',
                    style: AppTextStyles.bodySmall(
                        _followUpDate != null ? textPrimary : textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_followUpDate != null)
                  GestureDetector(
                    onTap: () => setState(() => _followUpDate = null),
                    child: Icon(Icons.close_rounded,
                        color: textSecondary, size: 14),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDirectivesField(Color textPrimary, Color textSecondary,
      Color surface, Color borderColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Follow-up Directives', textPrimary),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: _directivesCtrl,
          style: AppTextStyles.bodySmall(textPrimary),
          decoration: _inputDecoration(
            hint: 'e.g. Return in 1 week',
            textSecondary: textSecondary,
            surface: surface,
            borderColor: borderColor,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(Color textSecondary, bool isDark) {
    return Row(
      children: [
        // Cancel
        Expanded(
          child: OutlinedButton(
            onPressed: _isSubmitting ? null : () => Get.back(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              side: BorderSide(color: textSecondary.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius: AppDecorations.borderMD),
            ),
            child: Text(
              'Cancel',
              style: AppTextStyles.labelLarge(textSecondary),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        // Confirm Discharge
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: _isSubmitting
                  ? null
                  : LinearGradient(
                      colors: [
                        AppColors.secondary,
                        AppColors.secondary.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: _isSubmitting
                  ? AppColors.secondary.withValues(alpha: 0.4)
                  : null,
              borderRadius: AppDecorations.borderMD,
            ),
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                    borderRadius: AppDecorations.borderMD),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.lightSurface),
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.lightSurface, size: 18),
              label: Text(
                _isSubmitting ? 'Processing…' : 'Confirm Discharge',
                style: AppTextStyles.labelLarge(AppColors.lightSurface),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Utils ─────────────────────────────────────────────────────────────────

  InpatientController? _safeController() {
    try {
      return Get.find<InpatientController>();
    } catch (_) {
      return null;
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required Color textSecondary,
    required Color surface,
    required Color borderColor,
    required bool isDark,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodySmall(textSecondary),
      filled: true,
      fillColor: surface,
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
        borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppDecorations.borderMD,
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppDecorations.borderMD,
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      errorStyle: AppTextStyles.labelSmall(AppColors.error),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PATIENT INFO BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _PatientInfoBanner extends StatelessWidget {
  const _PatientInfoBanner({
    required this.patientName,
    required this.bedNumber,
    required this.isDark,
  });

  final String patientName;
  final String bedNumber;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderMD,
        border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.25), width: 1),
        boxShadow: AppDecorations.elevation1(isDark),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              borderRadius: AppDecorations.borderSM,
            ),
            child: const Icon(Icons.person_rounded,
                color: AppColors.secondary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patientName,
                    style: AppTextStyles.titleSmall(textPrimary)),
                const SizedBox(height: AppSpacing.xxs),
                Text('Bed: $bedNumber',
                    style: AppTextStyles.bodySmall(textSecondary)),
              ],
            ),
          ),
          StatusBadge(label: 'Active', type: StatusType.success),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BED FREE INFO BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _BedFreeBanner extends StatelessWidget {
  const _BedFreeBanner({required this.bedNumber, required this.isDark});

  final String bedNumber;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: AppDecorations.borderMD,
        border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.secondary, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Discharging this patient will automatically free up bed $bedNumber and mark it as available.',
              style: AppTextStyles.bodySmall(AppColors.secondary),
            ),
          ),
        ],
      ),
    );
  }
}
