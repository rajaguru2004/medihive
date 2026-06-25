// lib/app/modules/inpatient/views/inpatient_view.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medihive/app/theme/theme.dart';
import '../controllers/inpatient_controller.dart';
import '../models/inpatient_models.dart';
import 'discharge_patient_view.dart';
import 'ward_form_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MAIN VIEW
// ─────────────────────────────────────────────────────────────────────────────

class InpatientView extends GetView<InpatientController> {
  const InpatientView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(context, isDark),
      body: GetBuilder<InpatientController>(
        builder: (ctrl) {
          if (ctrl.isLoading) return _InpatientSkeleton(isDark: isDark);
          if (ctrl.hasError) {
            return _ErrorState(
              message: ctrl.errorMessage,
              onRetry: ctrl.fetchAll,
              isDark: isDark,
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor:
                isDark ? AppColors.darkSurface : AppColors.lightSurface,
            onRefresh: ctrl.onRefresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _SummaryGrid(isDark: isDark)),
                SliverToBoxAdapter(child: _TabSwitcher(isDark: isDark)),
                SliverToBoxAdapter(
                    child: _buildTabContent(ctrl, isDark)),
                const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.huge)),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inpatient Ward Control',
              style: AppTextStyles.titleMedium(textPrimary)),
          Text(
            'Manage beds, wards & admissions',
            style: AppTextStyles.labelSmall(AppColors.primary),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded,
              color: AppColors.primary, size: AppSpacing.iconMD),
          onPressed: () => controller.onRefresh(),
          tooltip: 'Refresh',
        ),
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: AppDecorations.borderMD,
            ),
            child: TextButton.icon(
              onPressed: () => Get.toNamed('/inpatient/admit'),
              icon: const Icon(Icons.add_rounded,
                  color: AppColors.lightSurface, size: AppSpacing.iconSM),
              label: Text(
                'Admit',
                style: AppTextStyles.labelMedium(AppColors.lightSurface),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent(InpatientController ctrl, bool isDark) {
    switch (ctrl.selectedTab) {
      case InpatientTab.overview:
        return _OverviewTab(isDark: isDark);
      case InpatientTab.wards:
        return _WardsTab(isDark: isDark);
      case InpatientTab.bedsGrid:
        return _BedsGridTab(isDark: isDark);
      case InpatientTab.admissions:
        return _AdmissionsTab(isDark: isDark);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY GRID (2-column)
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryGrid extends GetView<InpatientController> {
  const _SummaryGrid({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<InpatientController>(
      builder: (ctrl) {
        final s = ctrl.stats;
        final cards = [
          _SummaryData(
              label: 'Occupancy Rate',
              value: '${s.occupancyRate.toStringAsFixed(0)}%',
              icon: Icons.donut_large_rounded,
              color: AppColors.primary),
          _SummaryData(
              label: 'Active Patients',
              value: '${s.occupiedBeds}',
              icon: Icons.person_rounded,
              color: AppColors.secondary),
          _SummaryData(
              label: 'Available Beds',
              value: '${s.availableBeds}',
              icon: Icons.bed_rounded,
              color: AppColors.info),
          _SummaryData(
              label: 'Total Beds',
              value: '${s.totalBeds}',
              icon: Icons.local_hospital_rounded,
              color: AppColors.warning),
          _SummaryData(
              label: 'Today Admissions',
              value: '${s.todayAdmissions}',
              icon: Icons.login_rounded,
              color: AppColors.tertiary),
          _SummaryData(
              label: 'Today Discharges',
              value: '${s.todayDischarges}',
              icon: Icons.logout_rounded,
              color: AppColors.error),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 2.4,
          ),
          itemCount: cards.length,
          itemBuilder: (_, i) => _SummaryCard(data: cards[i], isDark: isDark),
        );
      },
    );
  }
}

class _SummaryData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryData(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data, required this.isDark});
  final _SummaryData data;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderMD,
        border: Border.all(
            color: data.color.withValues(alpha: 0.18), width: 1),
        boxShadow: AppDecorations.elevation1(isDark),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: AppDecorations.borderSM,
                ),
                child: Icon(data.icon, color: data.color, size: 14),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  data.value,
                  style: AppTextStyles.titleMedium(textPrimary)
                      .copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            data.label,
            style: AppTextStyles.labelSmall(data.color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB SWITCHER
// ─────────────────────────────────────────────────────────────────────────────

class _TabSwitcher extends GetView<InpatientController> {
  const _TabSwitcher({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surfaceVariant =
        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GetBuilder<InpatientController>(
      builder: (ctrl) => Container(
        margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: surfaceVariant,
          borderRadius: AppDecorations.borderLG,
        ),
        child: Row(
          children: [
            _TabBtn(
              label: 'Overview',
              icon: Icons.dashboard_rounded,
              selected: ctrl.selectedTab == InpatientTab.overview,
              isDark: isDark,
              surface: surface,
              textSecondary: textSecondary,
              onTap: () => ctrl.setTab(InpatientTab.overview),
            ),
            _TabBtn(
              label: 'Wards',
              icon: Icons.holiday_village_rounded,
              selected: ctrl.selectedTab == InpatientTab.wards,
              isDark: isDark,
              surface: surface,
              textSecondary: textSecondary,
              onTap: () => ctrl.setTab(InpatientTab.wards),
            ),
            _TabBtn(
              label: 'Beds',
              icon: Icons.bed_rounded,
              selected: ctrl.selectedTab == InpatientTab.bedsGrid,
              isDark: isDark,
              surface: surface,
              textSecondary: textSecondary,
              onTap: () => ctrl.setTab(InpatientTab.bedsGrid),
            ),
            _TabBtn(
              label: 'Admissions',
              icon: Icons.people_rounded,
              selected: ctrl.selectedTab == InpatientTab.admissions,
              isDark: isDark,
              surface: surface,
              textSecondary: textSecondary,
              onTap: () => ctrl.setTab(InpatientTab.admissions),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.isDark,
    required this.surface,
    required this.textSecondary,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool isDark;
  final Color surface;
  final Color textSecondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color: selected ? surface : Colors.transparent,
            borderRadius: AppDecorations.borderMD,
            boxShadow: selected ? AppDecorations.elevation1(isDark) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? AppColors.primary : textSecondary),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.labelSmall(
                    selected ? AppColors.primary : textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OVERVIEW TAB
// ─────────────────────────────────────────────────────────────────────────────

class _OverviewTab extends GetView<InpatientController> {
  const _OverviewTab({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<InpatientController>(
      builder: (ctrl) {
        final list = ctrl.filteredAdmissions;
        final textPrimary =
            isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        final textSecondary =
            isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
        final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              // ── Header row ───────────────────────────────────────────────
              Row(
                children: [
                  Text('Active Patient Admissions',
                      style: AppTextStyles.titleSmall(textPrimary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: AppDecorations.borderFull,
                    ),
                    child: Text(
                      '${ctrl.activeAdmissions.length} active',
                      style: AppTextStyles.labelSmall(AppColors.secondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // ── Search + Filter row ──────────────────────────────────────
              _AdmissionSearchBar(isDark: isDark, ctrl: ctrl),
              const SizedBox(height: AppSpacing.md),
              // ── List ─────────────────────────────────────────────────────
              if (list.isEmpty)
                _EmptyState(
                  icon: Icons.bed_rounded,
                  message: 'No admissions match',
                  isDark: isDark,
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _AdmissionCard(
                    admission: list[i],
                    isDark: isDark,
                    showDischarge: list[i].isActive,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    surface: surface,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMISSION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _AdmissionCard extends StatelessWidget {
  const _AdmissionCard({
    required this.admission,
    required this.isDark,
    required this.showDischarge,
    required this.textPrimary,
    required this.textSecondary,
    required this.surface,
  });

  final AdmissionModel admission;
  final bool isDark;
  final bool showDischarge;
  final Color textPrimary;
  final Color textSecondary;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    final a = admission;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderMD,
        border: Border.all(
          color: (a.isActive ? AppColors.secondary : AppColors.lightTextTertiary)
              .withValues(alpha: 0.2),
        ),
        boxShadow: AppDecorations.elevation1(isDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppDecorations.borderSM,
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.patient.fullName,
                          style: AppTextStyles.titleSmall(textPrimary)),
                      Text('MRN: ${a.patient.mrn}',
                          style: AppTextStyles.labelSmall(textSecondary)),
                    ],
                  ),
                ),
                StatusBadge(
                  label: a.isActive ? 'Active' : 'Discharged',
                  type: a.isActive ? StatusType.success : StatusType.neutral,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(
              icon: Icons.calendar_today_rounded,
              label: 'Admission',
              value: _formatDate(a.admissionDate),
              textSecondary: textSecondary,
              textPrimary: textPrimary,
            ),
            const SizedBox(height: AppSpacing.xs),
            _InfoRow(
              icon: Icons.bed_rounded,
              label: 'Ward & Bed',
              value: a.wardAndBed,
              textSecondary: textSecondary,
              textPrimary: textPrimary,
            ),
            const SizedBox(height: AppSpacing.xs),
            _InfoRow(
              icon: Icons.local_hospital_rounded,
              label: 'Type',
              value: a.displayAdmissionType,
              textSecondary: textSecondary,
              textPrimary: textPrimary,
            ),
            const SizedBox(height: AppSpacing.xs),
            _InfoRow(
              icon: Icons.medical_services_rounded,
              label: 'Attending',
              value:
                  a.attendingDoctorId != null ? 'Assigned Doctor' : '—',
              textSecondary: textSecondary,
              textPrimary: textPrimary,
            ),
            if (showDischarge && a.isActive) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Get.to(
                    () => DischargePatientView(
                      admissionId: a.id,
                      patientName: a.patient.fullName,
                      bedNumber: a.bed.bedNumber,
                    ),
                    transition: Transition.cupertino,
                  ),
                  icon: const Icon(Icons.logout_rounded,
                      size: 16, color: AppColors.error),
                  label: Text('Discharge',
                      style: AppTextStyles.labelMedium(AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.5)),
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    shape: RoundedRectangleBorder(
                        borderRadius: AppDecorations.borderSM),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textSecondary,
    required this.textPrimary,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color textSecondary;
  final Color textPrimary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Text('$label: ', style: AppTextStyles.labelSmall(textSecondary)),
        Expanded(
          child: Text(value,
              style: AppTextStyles.labelSmall(textPrimary),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WARDS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _WardsTab extends GetView<InpatientController> {
  const _WardsTab({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<InpatientController>(
      builder: (ctrl) {
        final wards = ctrl.activeWards;
        final textPrimary =
            isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              // ── Header row with Add Ward button ───────────────────────────
              Row(
                children: [
                  Text('Wards Overview',
                      style: AppTextStyles.titleSmall(textPrimary)),
                  const Spacer(),
                  _AddWardButton(),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Manage hospital wards & view occupancy',
                style: AppTextStyles.bodySmall(
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              if (wards.isEmpty)
                _EmptyState(
                  icon: Icons.holiday_village_rounded,
                  message: 'No active wards',
                  isDark: isDark,
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: wards.length,
                  itemBuilder: (_, i) =>
                      _WardCard(ward: wards[i], isDark: isDark),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _WardCard extends GetView<InpatientController> {
  const _WardCard({required this.ward, required this.isDark});
  final WardModel ward;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final rate = ward.occupancyRate / 100;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderMD,
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15), width: 1),
        boxShadow: AppDecorations.elevation1(isDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppDecorations.borderSM,
                  ),
                  child: const Icon(Icons.holiday_village_rounded,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ward.name.trim(),
                          style: AppTextStyles.titleSmall(textPrimary)),
                      Text(
                        'CODE: ${ward.code} | TYPE: ${ward.displayType.toUpperCase()}',
                        style: AppTextStyles.labelSmall(textSecondary),
                      ),
                    ],
                  ),
                ),
                StatusBadge(label: 'Active', type: StatusType.success),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                    child: _WardStat(
                        label: 'Beds',
                        value: '${ward.capacity}',
                        color: textPrimary,
                        isDark: isDark)),
                Expanded(
                    child: _WardStat(
                        label: 'Occupied',
                        value: '${ward.occupiedBeds}',
                        color: AppColors.error,
                        isDark: isDark)),
                Expanded(
                    child: _WardStat(
                        label: 'Available',
                        value: '${ward.availableBeds}',
                        color: AppColors.secondary,
                        isDark: isDark)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text('Occupancy Rate',
                    style: AppTextStyles.labelSmall(textSecondary)),
                const Spacer(),
                Text('${ward.occupancyRate.toStringAsFixed(0)}%',
                    style: AppTextStyles.labelSmall(AppColors.secondary)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: AppDecorations.borderFull,
              child: LinearProgressIndicator(
                value: rate.clamp(0.0, 1.0),
                backgroundColor: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // ── Action Buttons: Deactivate (left) | Edit (right) ─────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _confirmDeactivate(context, ward, isDark),
                    icon: const Icon(Icons.power_settings_new_rounded,
                        size: 14, color: AppColors.error),
                    label: Text('Deactivate',
                        style: AppTextStyles.labelSmall(AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm),
                      shape: RoundedRectangleBorder(
                          borderRadius: AppDecorations.borderSM),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Get.to(
                      () => WardFormView(ward: ward),
                      transition: Transition.cupertino,
                    ),
                    icon: const Icon(Icons.edit_rounded,
                        size: 14, color: AppColors.primary),
                    label: Text('Edit',
                        style: AppTextStyles.labelSmall(AppColors.primary)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm),
                      shape: RoundedRectangleBorder(
                          borderRadius: AppDecorations.borderSM),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeactivate(
      BuildContext context, WardModel ward, bool isDark) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
            borderRadius: AppDecorations.borderLG),
        title: Text('Deactivate Ward',
            style: AppTextStyles.titleSmall(textPrimary)),
        content: Text(
          'Are you sure you want to deactivate "${ward.name.trim()}"? This will remove it from active wards.',
          style: AppTextStyles.bodySmall(textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel',
                style: AppTextStyles.labelMedium(textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deactivateWard(ward.id);
            },
            child: Text('Deactivate',
                style: AppTextStyles.labelMedium(AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD WARD BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _AddWardButton extends StatelessWidget {
  const _AddWardButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppDecorations.borderMD,
      ),
      child: TextButton.icon(
        onPressed: () => Get.to(
          () => const WardFormView(),
          transition: Transition.cupertino,
        ),
        icon: const Icon(Icons.add_rounded,
            color: AppColors.lightSurface, size: AppSpacing.iconSM),
        label: Text(
          'Add Ward',
          style: AppTextStyles.labelMedium(AppColors.lightSurface),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _WardStat extends StatelessWidget {
  const _WardStat({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  final String label;
  final String value;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurfaceVariant;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm, horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppDecorations.borderSM,
      ),
      child: Column(
        children: [
          Text(value,
              style: AppTextStyles.titleSmall(color)
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.labelSmall(color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BEDS GRID TAB
// ─────────────────────────────────────────────────────────────────────────────

class _BedsGridTab extends GetView<InpatientController> {
  const _BedsGridTab({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<InpatientController>(
      builder: (ctrl) {
        final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
        final textPrimary =
            isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        final textSecondary =
            isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Ward',
                          style: AppTextStyles.labelSmall(textSecondary)
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        _buildWardDropdown(
                            ctrl, surface, textPrimary, textSecondary, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Filter',
                          style: AppTextStyles.labelSmall(textSecondary)
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        _buildStatusDropdown(
                            ctrl, surface, textPrimary, textSecondary, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    height: 46, // Matches dropdown height
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: AppDecorations.borderMD,
                      boxShadow: AppDecorations.elevation1(isDark),
                    ),
                    child: TextButton.icon(
                      onPressed: () => Get.toNamed('/inpatient/add-bed'),
                      icon: const Icon(Icons.add_rounded,
                          color: AppColors.lightSurface,
                          size: AppSpacing.iconSM),
                      label: Text(
                        'Add Bed',
                        style: AppTextStyles.labelSmall(AppColors.lightSurface)
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (ctrl.selectedWardModel != null)
                _WardInfoBanner(
                    ward: ctrl.selectedWardModel!,
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary),
              const SizedBox(height: AppSpacing.md),
              if (ctrl.selectedWardId.isEmpty)
                _EmptyState(
                  icon: Icons.bed_rounded,
                  message: 'No active wards available',
                  isDark: isDark,
                )
              else if (ctrl.filteredBeds.isEmpty)
                _EmptyState(
                  icon: Icons.bed_rounded,
                  message: 'No beds match the filter',
                  isDark: isDark,
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth > 600;
                    final crossAxisCount = isTablet ? 3 : 1;
                    final double aspectRatio = isTablet ? 0.85 : 1.4;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                        childAspectRatio: aspectRatio,
                      ),
                      itemCount: ctrl.filteredBeds.length,
                      itemBuilder: (_, i) =>
                          _BedCard(bed: ctrl.filteredBeds[i], isDark: isDark),
                    );
                  },
                ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWardDropdown(InpatientController ctrl, Color surface,
      Color textPrimary, Color textSecondary, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderMD,
        boxShadow: AppDecorations.elevation1(isDark),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: ctrl.selectedWardId.isEmpty ? null : ctrl.selectedWardId,
          hint: Text('Select Ward',
              style: AppTextStyles.bodySmall(textSecondary)),
          isExpanded: true,
          dropdownColor: surface,
          style: AppTextStyles.bodySmall(textPrimary),
          icon: Icon(Icons.expand_more_rounded,
              color: textSecondary, size: 18),
          items: ctrl.activeWards
              .map((w) => DropdownMenuItem(
                    value: w.id,
                    child: Text('${w.name.trim()} (${w.code})',
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) ctrl.setSelectedWard(v);
          },
        ),
      ),
    );
  }

  Widget _buildStatusDropdown(InpatientController ctrl, Color surface,
      Color textPrimary, Color textSecondary, bool isDark) {
    const statuses = [
      ('all', 'All Beds'),
      ('available', 'Available'),
      ('occupied', 'Occupied'),
      ('maintenance', 'Maintenance'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderMD,
        boxShadow: AppDecorations.elevation1(isDark),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: ctrl.selectedBedStatus,
          isExpanded: true,
          dropdownColor: surface,
          style: AppTextStyles.bodySmall(textPrimary),
          icon: Icon(Icons.expand_more_rounded,
              color: textSecondary, size: 18),
          items: statuses
              .map((s) =>
                  DropdownMenuItem(value: s.$1, child: Text(s.$2)))
              .toList(),
          onChanged: (v) {
            if (v != null) ctrl.setSelectedBedStatus(v);
          },
        ),
      ),
    );
  }
}

class _WardInfoBanner extends StatelessWidget {
  const _WardInfoBanner({
    required this.ward,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
  });

  final WardModel ward;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderMD,
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ward Type',
                    style: AppTextStyles.labelSmall(textSecondary)),
                Text(ward.displayType,
                    style: AppTextStyles.titleSmall(textPrimary)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Capacity',
                    style: AppTextStyles.labelSmall(textSecondary)),
                Text('${ward.capacity} Beds',
                    style: AppTextStyles.titleSmall(textPrimary)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Occupancy',
                    style: AppTextStyles.labelSmall(textSecondary)),
                Text(
                    '${ward.occupiedBeds} Beds (${ward.occupancyRate.toStringAsFixed(0)}%)',
                    style: AppTextStyles.titleSmall(AppColors.primary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status', style: AppTextStyles.labelSmall(textSecondary)),
              StatusBadge(
                label: ward.isActive ? 'Accepting' : 'Inactive',
                type:
                    ward.isActive ? StatusType.success : StatusType.neutral,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BedCard extends StatelessWidget {
  const _BedCard({required this.bed, required this.isDark});
  final BedModel bed;
  final bool isDark;

  Color get _statusColor {
    switch (bed.status) {
      case 'available':
        return AppColors.secondary;
      case 'occupied':
        return AppColors.error;
      case 'maintenance':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  StatusType get _statusType {
    switch (bed.status) {
      case 'available':
        return StatusType.success;
      case 'occupied':
        return StatusType.error;
      case 'maintenance':
        return StatusType.warning;
      default:
        return StatusType.info;
    }
  }

  String get _statusLabel {
    switch (bed.status) {
      case 'available':
        return 'AVAILABLE';
      case 'occupied':
        return 'OCCUPIED';
      case 'maintenance':
        return 'MAINTENANCE';
      default:
        return bed.status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final ctrl = Get.find<InpatientController>();
    final activeAdmission = ctrl.admissions.firstWhereOrNull(
      (a) => a.bedId == bed.id && a.isActive,
    );

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppDecorations.borderMD,
        border: Border.all(
            color: _statusColor.withValues(alpha: 0.3), width: 1),
        boxShadow: AppDecorations.elevation1(isDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Row (Bed icon & number + Status badge) ───────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: AppDecorations.borderSM,
                  ),
                  child: Icon(Icons.bed_rounded,
                      color: _statusColor, size: 16),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    bed.bedNumber,
                    style: AppTextStyles.titleSmall(textPrimary)
                        .copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusBadge(
                  label: _statusLabel,
                  type: _statusType,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Bed Type Row ─────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('BED TYPE', style: AppTextStyles.labelSmall(textSecondary)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    borderRadius: AppDecorations.borderXS,
                  ),
                  child: Text(
                    bed.displayType,
                    style: AppTextStyles.labelSmall(textPrimary)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Middle Section (Occupant box OR status messages) ─────────────
            Expanded(
              child: bed.status == 'occupied'
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.08),
                        borderRadius: AppDecorations.borderSM,
                        border: Border.all(
                            color: AppColors.secondary.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded,
                                  color: AppColors.secondary, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'CURRENT OCCUPANT',
                                style: AppTextStyles.labelSmall(AppColors.secondary)
                                    .copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activeAdmission?.patient.fullName ?? 'Unknown Patient',
                            style: AppTextStyles.bodyMedium(textPrimary)
                                .copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'MRN: ${activeAdmission?.patient.mrn ?? 'N/A'}',
                            style: AppTextStyles.labelSmall(textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(
                          bed.isAvailable
                              ? Icons.check_circle_outline_rounded
                              : Icons.info_outline_rounded,
                          size: 14,
                          color: _statusColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            bed.statusMessage,
                            style: AppTextStyles.bodySmall(textSecondary),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Action Buttons ───────────────────────────────────────────────
            if (bed.status == 'available')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => ctrl.updateBedStatus(bed.id, 'maintenance'),
                  icon: const Icon(Icons.build_outlined, color: AppColors.warning, size: 14),
                  label: Text(
                    'Maintain',
                    style: AppTextStyles.labelSmall(AppColors.warning)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.warning.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    shape: RoundedRectangleBorder(
                        borderRadius: AppDecorations.borderSM),
                  ),
                ),
              )
            else if (bed.status == 'maintenance')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => ctrl.updateBedStatus(bed.id, 'available'),
                  icon: const Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.secondary, size: 14),
                  label: Text(
                    'Available',
                    style: AppTextStyles.labelSmall(AppColors.secondary)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    shape: RoundedRectangleBorder(
                        borderRadius: AppDecorations.borderSM),
                  ),
                ),
              )
            else if (bed.status == 'occupied')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ctrl.updateBedStatus(bed.id, 'available'),
                      icon: const Icon(Icons.check_circle_outline_rounded,
                          color: AppColors.secondary, size: 14),
                      label: Text(
                        'Available',
                        style: AppTextStyles.labelSmall(AppColors.secondary)
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppDecorations.borderSM),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ctrl.updateBedStatus(bed.id, 'maintenance'),
                      icon: const Icon(Icons.build_outlined, color: AppColors.warning, size: 14),
                      label: Text(
                        'Maintain',
                        style: AppTextStyles.labelSmall(AppColors.warning)
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.warning.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppDecorations.borderSM),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMISSIONS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _AdmissionsTab extends GetView<InpatientController> {
  const _AdmissionsTab({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<InpatientController>(
      builder: (ctrl) {
        final list = ctrl.filteredAdmissions;
        final textPrimary =
            isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        final textSecondary =
            isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
        final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              Text('All Admissions',
                  style: AppTextStyles.titleSmall(textPrimary)),
              const SizedBox(height: AppSpacing.md),
              _AdmissionSearchBar(isDark: isDark, ctrl: ctrl),
              const SizedBox(height: AppSpacing.md),
              if (list.isEmpty)
                _EmptyState(
                  icon: Icons.people_rounded,
                  message: 'No admissions found',
                  isDark: isDark,
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _AdmissionCard(
                    admission: list[i],
                    isDark: isDark,
                    showDischarge: list[i].isActive,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    surface: surface,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMISSION SEARCH BAR (shared by Overview + Admissions tabs)
// ─────────────────────────────────────────────────────────────────────────────

class _AdmissionSearchBar extends StatelessWidget {
  const _AdmissionSearchBar({required this.isDark, required this.ctrl});
  final bool isDark;
  final InpatientController ctrl;

  static const _filterOptions = [
    ('active', 'Active Admissions'),
    ('discharged', 'Discharged Patients'),
    ('all', 'All Records'),
  ];

  String get _currentLabel {
    return _filterOptions
        .firstWhere((o) => o.$1 == ctrl.admissionFilter,
            orElse: () => ('active', 'Active Admissions'))
        .$2;
  }

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: AppDecorations.borderMD,
              border: Border.all(
                  color: textSecondary.withValues(alpha: 0.15)),
              boxShadow: AppDecorations.elevation1(isDark),
            ),
            child: TextField(
              onChanged: ctrl.setAdmissionSearch,
              style: AppTextStyles.bodySmall(textPrimary),
              decoration: InputDecoration(
                hintText: 'Search patient by name or MRN...',
                hintStyle: AppTextStyles.bodySmall(textSecondary),
                prefixIcon: Icon(Icons.search_rounded,
                    color: textSecondary, size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: AppSpacing.md),
                isDense: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        PopupMenuButton<String>(
          onSelected: ctrl.setAdmissionFilter,
          color: surface,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: AppDecorations.borderMD,
            side: BorderSide(
                color: textSecondary.withValues(alpha: 0.12)),
          ),
          offset: const Offset(0, 48),
          itemBuilder: (_) => _filterOptions
              .map((opt) => PopupMenuItem<String>(
                    value: opt.$1,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            opt.$2,
                            style: AppTextStyles.bodySmall(
                              ctrl.admissionFilter == opt.$1
                                  ? AppColors.primary
                                  : textPrimary,
                            ),
                          ),
                        ),
                        if (ctrl.admissionFilter == opt.$1)
                          const Icon(Icons.check_rounded,
                              color: AppColors.primary, size: 16),
                      ],
                    ),
                  ))
              .toList(),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: AppDecorations.borderMD,
              border: Border.all(
                  color: textSecondary.withValues(alpha: 0.15)),
              boxShadow: AppDecorations.elevation1(isDark),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_currentLabel,
                    style: AppTextStyles.labelSmall(textPrimary)),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: textSecondary, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED: Empty State, Skeleton, Error
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon,
      required this.message,
      required this.isDark});
  final IconData icon;
  final String message;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Center(
        child: Column(
          children: [
            Icon(icon,
                size: 48, color: textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                style: AppTextStyles.bodyMedium(textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState(
      {required this.message,
      required this.onRetry,
      required this.isDark});
  final String message;
  final VoidCallback onRetry;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                style: AppTextStyles.bodyMedium(textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.lightSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class _InpatientSkeleton extends StatelessWidget {
  const _InpatientSkeleton({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final shimmer = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 2.4,
            ),
            itemCount: 6,
            itemBuilder: (context, index) => Container(
              decoration: BoxDecoration(
                  color: shimmer, borderRadius: AppDecorations.borderMD),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...List.generate(
            3,
            (_) => Container(
              height: 120,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                  color: shimmer, borderRadius: AppDecorations.borderMD),
            ),
          ),
        ],
      ),
    );
  }
}