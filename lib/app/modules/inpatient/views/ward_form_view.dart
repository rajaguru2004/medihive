// lib/app/modules/inpatient/views/ward_form_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:medihive/app/theme/theme.dart';
import '../controllers/inpatient_controller.dart';
import '../models/inpatient_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Ward Form View  (Create / Edit)
// ─────────────────────────────────────────────────────────────────────────────

class WardFormView extends StatefulWidget {
  /// Pass null for Create mode; pass existing ward for Edit mode.
  const WardFormView({super.key, this.ward});
  final WardModel? ward;

  @override
  State<WardFormView> createState() => _WardFormViewState();
}

class _WardFormViewState extends State<WardFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _capacityCtrl;
  String _wardType = 'general';
  bool _isSubmitting = false;

  bool get _isEdit => widget.ward != null;

  static const _wardTypes = [
    _WardTypeOption('general', 'General', Icons.local_hospital_rounded),
    _WardTypeOption('icu', 'ICU', Icons.monitor_heart_rounded),
    _WardTypeOption('emergency', 'Emergency', Icons.emergency_rounded),
    _WardTypeOption('pediatric', 'Pediatric', Icons.child_care_rounded),
    _WardTypeOption('maternity', 'Maternity', Icons.pregnant_woman_rounded),
  ];

  @override
  void initState() {
    super.initState();
    final w = widget.ward;
    _nameCtrl = TextEditingController(text: w?.name ?? '');
    _codeCtrl = TextEditingController(text: w?.code ?? '');
    _capacityCtrl =
        TextEditingController(text: w != null ? '${w.capacity}' : '');
    _wardType = w?.type ?? 'general';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final ctrl = Get.find<InpatientController>();
    if (_isEdit) {
      await ctrl.updateWard(
        wardId: widget.ward!.id,
        name: _nameCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
        type: _wardType,
        capacity: int.parse(_capacityCtrl.text.trim()),
      );
    } else {
      await ctrl.createWard(
        name: _nameCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
        type: _wardType,
        capacity: int.parse(_capacityCtrl.text.trim()),
      );
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

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
      appBar: _buildAppBar(isDark, surface, textPrimary),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // ── Subtitle ──────────────────────────────────────────────────
              Text(
                'Configure hospital ward capacity and type settings.',
                style: AppTextStyles.bodySmall(AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Ward Name ─────────────────────────────────────────────────
              _FieldLabel('Ward Name', textSecondary),
              const SizedBox(height: AppSpacing.xs),
              _buildTextField(
                controller: _nameCtrl,
                hintText: 'e.g. ICU Ward B',
                isDark: isDark,
                surface: surface,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ward name is required' : null,
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Code + Capacity (side by side) ────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('Code', textSecondary),
                        const SizedBox(height: AppSpacing.xs),
                        _buildTextField(
                          controller: _codeCtrl,
                          hintText: 'e.g. ICU-B',
                          isDark: isDark,
                          surface: surface,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Code required'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('Capacity', textSecondary),
                        const SizedBox(height: AppSpacing.xs),
                        _buildTextField(
                          controller: _capacityCtrl,
                          hintText: '10',
                          isDark: isDark,
                          surface: surface,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }
                            final n = int.tryParse(v.trim());
                            if (n == null || n <= 0) return 'Must be > 0';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Ward Type Dropdown ─────────────────────────────────────────
              _FieldLabel('Ward Type', textSecondary),
              const SizedBox(height: AppSpacing.xs),
              _buildTypeDropdown(isDark, surface, textPrimary, textSecondary),
              const SizedBox(height: AppSpacing.xxxl),

              // ── Action Buttons ────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _CancelBtn(
                      isDark: isDark,
                      surface: surface,
                      textSecondary: textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: _SubmitBtn(
                      label: _isEdit ? 'Save Changes' : 'Create Ward',
                      isSubmitting: _isSubmitting,
                      onPressed: _submit,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      bool isDark, Color surface, Color textPrimary) {
    return AppBar(
      backgroundColor: surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.primary.withValues(alpha: 0.08),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: textPrimary, size: AppSpacing.iconMD),
        onPressed: () => Get.back(),
      ),
      title: Text(
        _isEdit ? 'Edit Ward' : 'Create Ward',
        style: AppTextStyles.titleMedium(textPrimary),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required bool isDark,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final borderColor =
        isDark ? AppColors.darkGlass : AppColors.lightTextTertiary;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: AppTextStyles.bodyMedium(textPrimary),
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.bodyMedium(textSecondary),
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
          borderSide:
              const BorderSide(color: AppColors.secondary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDecorations.borderMD,
          borderSide: BorderSide(
              color: AppColors.error.withValues(alpha: 0.7), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppDecorations.borderMD,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        errorStyle: AppTextStyles.labelSmall(AppColors.error),
      ),
    );
  }

  Widget _buildTypeDropdown(bool isDark, Color surface, Color textPrimary,
      Color textSecondary) {
    final borderColor =
        isDark ? AppColors.darkGlass : AppColors.lightTextTertiary;
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderMD,
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _wardType,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          dropdownColor: surface,
          borderRadius: AppDecorations.borderMD,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: textSecondary, size: AppSpacing.iconMD),
          selectedItemBuilder: (_) => _wardTypes.map((t) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(t.icon, size: 16, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(t.label,
                      style: AppTextStyles.bodyMedium(textPrimary)),
                ],
              ),
            );
          }).toList(),
          items: _wardTypes
              .map((t) => DropdownMenuItem(
                    value: t.value,
                    child: Row(
                      children: [
                        Icon(t.icon,
                            size: 16,
                            color: t.value == _wardType
                                ? AppColors.primary
                                : textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        Text(t.label,
                            style: AppTextStyles.bodyMedium(
                                t.value == _wardType
                                    ? textPrimary
                                    : textSecondary)),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _wardType = v);
          },
        ),
      ),
    );
  }
}

// ─── helpers ──────────────────────────────────────────────────────────────────

class _WardTypeOption {
  final String value;
  final String label;
  final IconData icon;
  const _WardTypeOption(this.value, this.label, this.icon);
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(text, style: AppTextStyles.labelMedium(color)),
          Text(' *',
              style: AppTextStyles.labelMedium(AppColors.error)),
        ],
      );
}

class _CancelBtn extends StatelessWidget {
  const _CancelBtn({
    required this.isDark,
    required this.surface,
    required this.textSecondary,
  });
  final bool isDark;
  final Color surface;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => Get.back(),
      style: OutlinedButton.styleFrom(
        padding:
            const EdgeInsets.symmetric(vertical: AppSpacing.md),
        side: BorderSide(
            color: textSecondary.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(
            borderRadius: AppDecorations.borderMD),
      ),
      child: Text('Cancel',
          style: AppTextStyles.labelLarge(textSecondary)),
    );
  }
}

class _SubmitBtn extends StatelessWidget {
  const _SubmitBtn({
    required this.label,
    required this.isSubmitting,
    required this.onPressed,
  });
  final String label;
  final bool isSubmitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppDecorations.borderMD,
      ),
      child: TextButton(
        onPressed: isSubmitting ? null : onPressed,
        style: TextButton.styleFrom(
          padding:
              const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(
              borderRadius: AppDecorations.borderMD),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.lightSurface),
                ),
              )
            : Text(label,
                style: AppTextStyles.labelLarge(AppColors.lightSurface)),
      ),
    );
  }
}
