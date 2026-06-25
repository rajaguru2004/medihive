// lib/app/modules/inpatient/views/add_bed_view.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medihive/app/theme/theme.dart';
import '../controllers/inpatient_controller.dart';

class AddBedView extends StatefulWidget {
  const AddBedView({super.key});

  @override
  State<AddBedView> createState() => _AddBedViewState();
}

class _AddBedViewState extends State<AddBedView> {
  final _bedNumberCtrl = TextEditingController();
  String _selectedType = 'standard';
  bool _isValid = false;
  bool _isSubmitting = false;

  final List<(String, String)> _types = [
    ('standard', 'Standard'),
    ('icu', 'ICU Spec'),
    ('electric', 'Electric Adjustable'),
    ('pediatric', 'Pediatric Crib'),
  ];

  @override
  void initState() {
    super.initState();
    _bedNumberCtrl.addListener(_validate);
  }

  @override
  void dispose() {
    _bedNumberCtrl.dispose();
    super.dispose();
  }

  void _validate() {
    final valid = _bedNumberCtrl.text.trim().isNotEmpty;
    if (valid != _isValid) {
      setState(() {
        _isValid = valid;
      });
    }
  }

  Future<void> _submit() async {
    if (!_isValid || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    final ctrl = Get.find<InpatientController>();
    final wardId = ctrl.selectedWardId;
    if (wardId.isEmpty) {
      Get.snackbar(
        'Error',
        'No ward selected. Please choose a ward first.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.92),
        colorText: AppColors.lightSurface,
      );
      setState(() => _isSubmitting = false);
      return;
    }

    await ctrl.createBed(
      wardId: wardId,
      bedNumber: _bedNumberCtrl.text.trim(),
      type: _selectedType,
    );

    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkGlass : AppColors.lightTextTertiary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: AppDecorations.borderXL,
                boxShadow: AppDecorations.elevation3(isDark),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header Row ─────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add New Bed',
                        style: AppTextStyles.titleLarge(textPrimary).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: Icon(Icons.close_rounded, color: textSecondary),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Register a new bed under the selected ward.',
                    style: AppTextStyles.bodySmall(textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Bed Number Field ────────────────────────────────────────
                  Row(
                    children: [
                      Text(
                        'Bed Number / Code',
                        style: AppTextStyles.labelMedium(textSecondary).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ' *',
                        style: AppTextStyles.labelMedium(AppColors.error),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _bedNumberCtrl,
                    style: AppTextStyles.bodyMedium(textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. B-101 or ICU-B01',
                      hintStyle: AppTextStyles.bodyMedium(textSecondary),
                      filled: true,
                      fillColor: surface,
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
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: AppDecorations.borderMD,
                        borderSide: BorderSide(color: AppColors.secondary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Bed Type Dropdown ───────────────────────────────────────
                  Text(
                    'Bed Type',
                    style: AppTextStyles.labelMedium(textSecondary).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: AppDecorations.borderMD,
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedType,
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        dropdownColor: surface,
                        borderRadius: AppDecorations.borderMD,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: textSecondary,
                          size: AppSpacing.iconMD,
                        ),
                        items: _types
                            .map((t) => DropdownMenuItem<String>(
                                  value: t.$1,
                                  child: Text(
                                    t.$2,
                                    style: AppTextStyles.bodyMedium(textPrimary),
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _selectedType = v;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // ── Buttons Row ─────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Cancel Button
                      OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.md,
                          ),
                          side: BorderSide(
                            color: textSecondary.withValues(alpha: 0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppDecorations.borderMD,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.labelLarge(textSecondary),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Add Bed Button
                      ElevatedButton(
                        onPressed: _isValid && !_isSubmitting ? _submit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          disabledBackgroundColor: isDark
                              ? AppColors.darkSurfaceVariant
                              : AppColors.lightSurfaceVariant,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppDecorations.borderMD,
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.lightSurface,
                                  ),
                                ),
                              )
                            : Text(
                                'Add Bed',
                                style: AppTextStyles.labelLarge(
                                  _isValid
                                      ? AppColors.lightSurface
                                      : textSecondary.withValues(alpha: 0.6),
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
