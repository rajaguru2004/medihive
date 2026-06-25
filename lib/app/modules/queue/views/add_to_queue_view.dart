// lib/app/modules/queue/views/add_to_queue_view.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:medihive/app/theme/theme.dart';
import '../controllers/queue_controller.dart';
import '../models/queue_model.dart';

class AddToQueueView extends StatefulWidget {
  const AddToQueueView({super.key});

  @override
  State<AddToQueueView> createState() => _AddToQueueViewState();
}

class _AddToQueueViewState extends State<AddToQueueView> {
  // ── Form state ────────────────────────────────────────────────────────────
  PatientOption? _selectedPatient;
  String _selectedServiceArea = 'opd';
  String _selectedPriority = 'routine';
  final _serviceTypeCtrl = TextEditingController();
  final _assignedRoomCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String _patientSearchQuery = '';
  bool _isSubmitting = false;

  static const _serviceAreas = [
    ('opd', 'OPD'),
    ('emergency', 'Emergency'),
    ('mch', 'MCH'),
    ('psychiatric', 'Psychiatric'),
    ('laboratory', 'Laboratory'),
    ('pharmacy', 'Pharmacy'),
    ('radiology', 'Radiology'),
  ];

  static const _priorities = [
    ('urgent', 'Urgent'),
    ('normal', 'Normal'),
    ('low', 'Low'),
    ('routine', 'Routine'),
  ];

  @override
  void dispose() {
    _serviceTypeCtrl.dispose();
    _assignedRoomCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit(QueueController ctrl) async {
    // Validate patient
    if (_selectedPatient == null) {
      Get.snackbar(
        'Validation',
        'Please select a patient',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.warning.withValues(alpha: 0.9),
        colorText: AppColors.lightSurface,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await ctrl.addToQueue(
      patientId: _selectedPatient!.id,
      serviceArea: _selectedServiceArea,
      serviceType: _serviceTypeCtrl.text.trim().isEmpty
          ? null
          : _serviceTypeCtrl.text.trim(),
      priority: _selectedPriority,
      assignedRoom: _assignedRoomCtrl.text.trim().isEmpty
          ? null
          : _assignedRoomCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      // Navigate back first — controller already refreshed inside addToQueue
      Get.back(result: true);
      
      // Show success snackbar on the popped screen
      Get.snackbar(
        '✓ Added to Queue',
        '${_selectedPatient!.fullName} added to '
            '${_selectedServiceArea.toUpperCase()} queue',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
        backgroundColor: AppColors.secondary.withValues(alpha: 0.95),
        colorText: AppColors.lightSurface,
        icon: const Icon(Icons.check_circle_rounded, color: AppColors.lightSurface),
      );
    } else {
      Get.snackbar(
        'Error',
        'Failed to add patient. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.9),
        colorText: AppColors.lightSurface,
      );
    }
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
    final textTertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final divider = isDark ? AppColors.darkDivider : AppColors.lightDivider;

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
          onPressed: () => Get.back(),
        ),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_circle_outline_rounded,
                  size: AppSpacing.iconSM, color: AppColors.secondary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Add to Queue', style: AppTextStyles.titleMedium(textPrimary)),
          ],
        ),
      ),
      body: GetBuilder<QueueController>(
        builder: (ctrl) {
          // Build filtered patient list
          final filtered = ctrl.patients.where((p) {
            if (_patientSearchQuery.isEmpty) return true;
            final q = _patientSearchQuery.toLowerCase();
            return p.fullName.toLowerCase().contains(q) ||
                p.mrn.toLowerCase().contains(q);
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Patient ─────────────────────────────────────────────────
                _FieldLabel('Patient *', textPrimary),
                const SizedBox(height: AppSpacing.xs),
                _PatientSelector(
                  selected: _selectedPatient,
                  patients: filtered,
                  isLoading: ctrl.isPatientsLoading,
                  searchCtrl: _searchCtrl,
                  onSearchChanged: (q) =>
                      setState(() => _patientSearchQuery = q),
                  onSelect: (p) => setState(() => _selectedPatient = p),
                  isDark: isDark,
                  surface: surface,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  textTertiary: textTertiary,
                  divider: divider,
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Service Area ─────────────────────────────────────────────
                _FieldLabel('Service Area *', textPrimary),
                const SizedBox(height: AppSpacing.xs),
                _DropdownField(
                  value: _selectedServiceArea,
                  items: _serviceAreas,
                  onChanged: (v) =>
                      setState(() => _selectedServiceArea = v ?? 'opd'),
                  surface: surface,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  divider: divider,
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Service Type + Priority (same row) ───────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel('Service Type', textPrimary),
                          const SizedBox(height: AppSpacing.xs),
                          _InputField(
                            controller: _serviceTypeCtrl,
                            hint: 'e.g. consultation',
                            surface: surface,
                            textPrimary: textPrimary,
                            textTertiary: textTertiary,
                            divider: divider,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel('Priority', textPrimary),
                          const SizedBox(height: AppSpacing.xs),
                          _PriorityDropdown(
                            value: _selectedPriority,
                            items: _priorities,
                            onChanged: (v) =>
                                setState(() => _selectedPriority = v ?? 'routine'),
                            surface: surface,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            divider: divider,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Assigned Room ────────────────────────────────────────────
                _FieldLabel('Assigned Room', textPrimary),
                const SizedBox(height: AppSpacing.xs),
                _InputField(
                  controller: _assignedRoomCtrl,
                  hint: 'e.g. Room 3',
                  surface: surface,
                  textPrimary: textPrimary,
                  textTertiary: textTertiary,
                  divider: divider,
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Action Buttons — immediately after Assigned Room ──────────
                Row(
                  children: [
                    // Cancel
                    Expanded(
                      child: SizedBox(
                        height: AppSpacing.buttonHeightMD,
                        child: OutlinedButton(
                          onPressed: () => Get.back(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textPrimary,
                            side: BorderSide(color: divider),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.sm),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: AppTextStyles.labelLarge(textPrimary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),

                    // Add to Queue
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: AppSpacing.buttonHeightMD,
                        child: ElevatedButton(
                          onPressed:
                              _isSubmitting ? null : () => _submit(ctrl),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            disabledBackgroundColor:
                                AppColors.secondary.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.sm),
                            ),
                            elevation: 0,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.lightSurface,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: AppSpacing.iconSM,
                                      color: AppColors.lightSurface,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      'Add to Queue',
                                      style: AppTextStyles.labelLarge(
                                          AppColors.lightSurface),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Bottom safe area space
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient Selector with inline search expand
// ─────────────────────────────────────────────────────────────────────────────
class _PatientSelector extends StatefulWidget {
  const _PatientSelector({
    required this.selected,
    required this.patients,
    required this.isLoading,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onSelect,
    required this.isDark,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
  });

  final PatientOption? selected;
  final List<PatientOption> patients;
  final bool isLoading;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<PatientOption> onSelect;
  final bool isDark;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;

  @override
  State<_PatientSelector> createState() => _PatientSelectorState();
}

class _PatientSelectorState extends State<_PatientSelector> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final displayText = widget.selected == null
        ? 'Select a patient'
        : '${widget.selected!.fullName} • ${widget.selected!.mrn}';

    return Column(
      children: [
        // Trigger
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            height: 48,
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: widget.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppSpacing.sm),
                topRight: const Radius.circular(AppSpacing.sm),
                bottomLeft: Radius.circular(_open ? 0 : AppSpacing.sm),
                bottomRight: Radius.circular(_open ? 0 : AppSpacing.sm),
              ),
              border: Border.all(
                color: _open ? AppColors.primary : widget.divider,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.person_search_rounded,
                    size: AppSpacing.iconSM,
                    color: _open ? AppColors.primary : widget.textTertiary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    displayText,
                    style: widget.selected == null
                        ? AppTextStyles.bodyMedium(widget.textTertiary)
                        : AppTextStyles.bodyMedium(widget.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: AppSpacing.iconSM,
                  color: widget.textSecondary,
                ),
              ],
            ),
          ),
        ),

        // Dropdown panel
        if (_open)
          Container(
            decoration: BoxDecoration(
              color: widget.surface,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppSpacing.sm),
                bottomRight: Radius.circular(AppSpacing.sm),
              ),
              border: Border(
                left: BorderSide(color: AppColors.primary),
                right: BorderSide(color: AppColors.primary),
                bottom: BorderSide(color: AppColors.primary),
              ),
            ),
            child: Column(
              children: [
                // Search field
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: TextField(
                    controller: widget.searchCtrl,
                    onChanged: widget.onSearchChanged,
                    autofocus: true,
                    style: AppTextStyles.bodySmall(widget.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search name or MRN…',
                      hintStyle: AppTextStyles.bodySmall(widget.textTertiary),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: widget.textTertiary,
                          size: AppSpacing.iconSM),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.xs + 2),
                        borderSide: BorderSide(color: widget.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.xs + 2),
                        borderSide: BorderSide(color: widget.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.xs + 2),
                        borderSide:
                            const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ),

                // Patient list
                if (widget.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (widget.patients.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'No patients found',
                      style: AppTextStyles.bodySmall(widget.textSecondary),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.patients.length,
                      itemBuilder: (_, i) {
                        final p = widget.patients[i];
                        final isSelected = widget.selected?.id == p.id;
                        return ListTile(
                          dense: true,
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          selectedTileColor:
                              AppColors.primary.withValues(alpha: 0.08),
                          title: Text(p.fullName,
                              style: AppTextStyles.bodySmall(
                                  widget.textPrimary)),
                          subtitle: Text(p.mrn,
                              style: AppTextStyles.labelSmall(
                                  widget.textSecondary)),
                          onTap: () {
                            widget.onSelect(p);
                            widget.searchCtrl.clear();
                            widget.onSearchChanged('');
                            setState(() => _open = false);
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

// ─────────────────────────────────────────────────────────────────────────────
// Reusable form widgets
// ─────────────────────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTextStyles.labelMedium(color));
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    required this.surface,
    required this.textPrimary,
    required this.textTertiary,
    required this.divider,
  });

  final TextEditingController controller;
  final String hint;
  final Color surface;
  final Color textPrimary;
  final Color textTertiary;
  final Color divider;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: AppTextStyles.bodyMedium(textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodySmall(textTertiary),
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
  });

  final String value;
  final List<(String, String)> items;
  final ValueChanged<String?> onChanged;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: textSecondary, size: AppSpacing.iconSM),
          dropdownColor: surface,
          style: AppTextStyles.bodyMedium(textPrimary),
          onChanged: onChanged,
          items: items
              .map((item) => DropdownMenuItem(
                    value: item.$1,
                    child:
                        Text(item.$2, style: AppTextStyles.bodyMedium(textPrimary)),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _PriorityDropdown extends StatelessWidget {
  const _PriorityDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
  });

  final String value;
  final List<(String, String)> items;
  final ValueChanged<String?> onChanged;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;

  Color _dotColor(String p) {
    switch (p) {
      case 'urgent':
        return AppColors.error;
      case 'normal':
        return AppColors.info;
      case 'low':
        return AppColors.secondary;
      default:
        return AppColors.darkTextSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: textSecondary, size: AppSpacing.iconSM),
          dropdownColor: surface,
          style: AppTextStyles.bodyMedium(textPrimary),
          onChanged: onChanged,
          selectedItemBuilder: (_) => items
              .map(
                (item) => Row(
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: _dotColor(item.$1)),
                    const SizedBox(width: AppSpacing.xs),
                    Text(item.$2, style: AppTextStyles.bodyMedium(textPrimary)),
                  ],
                ),
              )
              .toList(),
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item.$1,
                  child: Row(
                    children: [
                      CircleAvatar(
                          radius: 4, backgroundColor: _dotColor(item.$1)),
                      const SizedBox(width: AppSpacing.xs),
                      Text(item.$2,
                          style: AppTextStyles.bodyMedium(textPrimary)),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
