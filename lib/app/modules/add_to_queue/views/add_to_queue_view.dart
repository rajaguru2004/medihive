import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medihive/app/theme/theme.dart';
import '../controllers/add_to_queue_controller.dart';

class AddToQueueView extends StatefulWidget {
  const AddToQueueView({super.key});

  @override
  State<AddToQueueView> createState() => _AddToQueueViewState();
}

class _AddToQueueViewState extends State<AddToQueueView> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: textPrimary,
            size: AppSpacing.iconLG,
          ),
          onPressed: () => Get.back(),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.secondary,
              size: AppSpacing.iconLG,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Add to Queue',
              style: AppTextStyles.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: GetBuilder<AddToQueueController>(
        builder: (controller) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xl,
              ),
              children: [
                // 1. Patient Dropdown / Search field
                _buildSectionHeader('Patient *', isDark),
                const SizedBox(height: AppSpacing.sm),
                if (controller.selectedPatient != null)
                  _buildSelectedPatientCard(controller, isDark)
                else
                  _buildPatientSearchField(controller, isDark),
                const SizedBox(height: AppSpacing.xl),

                // 2. Service Area Dropdown
                _buildSectionHeader('Service Area *', isDark),
                const SizedBox(height: AppSpacing.sm),
                _buildServiceAreaDropdown(controller, isDark),
                const SizedBox(height: AppSpacing.xl),

                // 3. Service Type & Priority (Same Row)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Service Type', isDark),
                          const SizedBox(height: AppSpacing.sm),
                          _buildServiceTypeField(controller, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Priority *', isDark),
                          const SizedBox(height: AppSpacing.sm),
                          _buildPriorityDropdown(controller, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // 4. Assigned Room
                _buildSectionHeader('Assigned Room', isDark),
                const SizedBox(height: AppSpacing.sm),
                _buildAssignedRoomField(controller, isDark),
                const SizedBox(height: AppSpacing.xxl + AppSpacing.xl),

                // 5. Actions row
                _buildActionsRow(controller, isDark, _formKey),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Input Builders ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, bool isDark) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return Text(
      title,
      style: AppTextStyles.labelMedium(textColor).copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildSelectedPatientCard(AddToQueueController controller, bool isDark) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final patient = controller.selectedPatient!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: AppDecorations.borderMD,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.fullName,
                  style: AppTextStyles.titleSmall(textPrimary).copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  patient.mrn,
                  style: AppTextStyles.numeric(textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            onPressed: () => controller.clearSelectedPatient(),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientSearchField(AddToQueueController controller, bool isDark) {
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Column(
      children: [
        TextFormField(
          controller: controller.searchController,
          onChanged: controller.onPatientSearchChanged,
          style: AppTextStyles.bodyMedium(textPrimary),
          decoration: InputDecoration(
            hintText: 'Search patient by name or MRN...',
            hintStyle: AppTextStyles.bodyMedium(textSecondary.withValues(alpha: 0.5)),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.7),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 18),
            suffixIcon: controller.isLoadingPatients
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                  )
                : null,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          ),
        ),
        if (controller.patientsList.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: AppDecorations.borderMD,
              boxShadow: AppDecorations.elevation2(isDark),
              border: Border.all(color: borderColor),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: controller.patientsList.length,
              itemBuilder: (context, index) {
                final p = controller.patientsList[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : '',
                      style: AppTextStyles.labelMedium(AppColors.primary),
                    ),
                  ),
                  title: Text(p.fullName, style: AppTextStyles.bodyMedium(textPrimary).copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text(p.mrn, style: AppTextStyles.numeric(textSecondary, fontSize: 11)),
                  trailing: Icon(Icons.keyboard_arrow_right_rounded, color: textSecondary, size: 18),
                  onTap: () => controller.selectPatient(p),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildServiceAreaDropdown(AddToQueueController controller, bool isDark) {
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return DropdownButtonFormField<String>(
      initialValue: controller.selectedServiceArea,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
      dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      style: AppTextStyles.bodyMedium(textPrimary),
      onChanged: (val) {
        if (val != null) controller.selectServiceArea(val);
      },
      items: controller.serviceAreas.map<DropdownMenuItem<String>>((String val) {
        return DropdownMenuItem<String>(
          value: val,
          child: Text(val),
        );
      }).toList(),
      validator: (val) => val == null || val.isEmpty ? 'Service area is required' : null,
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.7),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      ),
    );
  }

  Widget _buildServiceTypeField(AddToQueueController controller, bool isDark) {
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return TextFormField(
      controller: controller.serviceTypeController,
      style: AppTextStyles.bodyMedium(textPrimary),
      decoration: InputDecoration(
        hintText: 'e.g. consultation',
        hintStyle: AppTextStyles.bodyMedium(textSecondary.withValues(alpha: 0.5)),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.7),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      ),
    );
  }

  Widget _buildPriorityDropdown(AddToQueueController controller, bool isDark) {
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return DropdownButtonFormField<String>(
      initialValue: controller.selectedPriority,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
      dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      style: AppTextStyles.bodyMedium(textPrimary),
      onChanged: (val) {
        if (val != null) controller.selectPriority(val);
      },
      items: controller.priorities.map<DropdownMenuItem<String>>((String val) {
        return DropdownMenuItem<String>(
          value: val,
          child: Text(val),
        );
      }).toList(),
      validator: (val) => val == null || val.isEmpty ? 'Priority is required' : null,
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.7),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      ),
    );
  }

  Widget _buildAssignedRoomField(AddToQueueController controller, bool isDark) {
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return TextFormField(
      controller: controller.assignedRoomController,
      style: AppTextStyles.bodyMedium(textPrimary),
      decoration: InputDecoration(
        hintText: 'e.g. Room 3',
        hintStyle: AppTextStyles.bodyMedium(textSecondary.withValues(alpha: 0.5)),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.7),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      ),
    );
  }

  Widget _buildActionsRow(AddToQueueController controller, bool isDark, GlobalKey<FormState> formKey) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Cancel Button
        OutlinedButton(
          onPressed: () => Get.back(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(120, 52),
            side: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
            shape: RoundedRectangleBorder(borderRadius: AppDecorations.borderMD),
          ),
          child: Text(
            'Cancel',
            style: AppTextStyles.labelLarge(isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        // Add to Queue Button
        ElevatedButton.icon(
          onPressed: controller.isSaving ? null : () => controller.submit(formKey.currentState, context),
          icon: controller.isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.add_circle_outline_rounded, size: 18),
          label: const Text('Add to Queue'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(160, 52),
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
            shape: RoundedRectangleBorder(borderRadius: AppDecorations.borderMD),
          ),
        ),
      ],
    );
  }
}
