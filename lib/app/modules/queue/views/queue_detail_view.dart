// lib/app/modules/queue/views/queue_detail_view.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:medihive/app/theme/theme.dart';
import '../models/queue_model.dart';

class QueueDetailView extends StatelessWidget {
  const QueueDetailView({super.key, required this.item});

  final QueueModel item;

  Color get _priorityColor {
    switch (item.priority.toLowerCase()) {
      case 'urgent':
        return AppColors.error;
      case 'normal':
        return AppColors.info;
      case 'low':
        return AppColors.secondary;
      default:
        return AppColors.darkTextTertiary;
    }
  }

  Color get _statusColor {
    switch (item.status.toLowerCase()) {
      case 'waiting':
        return AppColors.warning;
      case 'called':
        return AppColors.primary;
      case 'in_service':
        return AppColors.secondary;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.info;
    }
  }

  String get _statusLabel {
    switch (item.status.toLowerCase()) {
      case 'waiting':
        return 'Waiting';
      case 'called':
        return 'Called';
      case 'in_service':
        return 'In Service';
      case 'completed':
        return 'Completed';
      default:
        return item.status;
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final divider = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row ──────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Queue Entry',
                    style: AppTextStyles.titleMedium(textPrimary).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _PillBadge(
                    label: _capitalize(item.priority),
                    color: _priorityColor,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _PillBadge(
                    label: _statusLabel,
                    color: _statusColor,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.lightSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: textPrimary,
                        size: AppSpacing.iconSM,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Token Row ──────────────────────────────────────────────────
              Row(
                children: [
                  Text(
                    '# Token: ',
                    style: AppTextStyles.bodyMedium(textSecondary),
                  ),
                  Text(
                    item.queueNumber,
                    style: AppTextStyles.numeric(
                      AppColors.secondary,
                      fontSize: 14,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Divider(color: divider, height: 1),
              const SizedBox(height: AppSpacing.lg),

              // ── PATIENT SECTION ─────────────────────────────────────────────
              _SectionHeader(title: 'PATIENT', textColor: textSecondary),
              const SizedBox(height: AppSpacing.sm),
              _DetailRow(
                icon: Icons.person_outline_rounded,
                label: 'Name',
                value: item.patient.fullName,
                isDark: isDark,
              ),
              const SizedBox(height: AppSpacing.md),
              _DetailRow(
                icon: Icons.tag_rounded,
                label: 'MRN',
                value: item.patient.mrn,
                isDark: isDark,
              ),
              const SizedBox(height: AppSpacing.md),
              _DetailRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: item.patient.phonePrimary ?? 'Not Provided',
                isDark: isDark,
              ),
              const SizedBox(height: AppSpacing.md),
              _DetailRow(
                icon: Icons.person_outline_rounded,
                label: 'Gender',
                value: _capitalize(item.patient.gender),
                isDark: isDark,
              ),
              const SizedBox(height: AppSpacing.xl),
              Divider(color: divider, height: 1),
              const SizedBox(height: AppSpacing.lg),

              // ── SERVICE SECTION ─────────────────────────────────────────────
              _SectionHeader(title: 'SERVICE', textColor: textSecondary),
              const SizedBox(height: AppSpacing.sm),
              _DetailRow(
                icon: Icons.local_hospital_outlined,
                label: 'Service Area',
                value: item.serviceArea.toUpperCase(),
                isDark: isDark,
              ),
              const SizedBox(height: AppSpacing.md),
              _DetailRow(
                icon: Icons.access_time_rounded,
                label: 'Wait Time',
                value: item.formattedWaitTime,
                isDark: isDark,
              ),
              const SizedBox(height: AppSpacing.xl),
              Divider(color: divider, height: 1),
              const SizedBox(height: AppSpacing.lg),

              // ── TIMELINE SECTION ────────────────────────────────────────────
              _SectionHeader(title: 'TIMELINE', textColor: textSecondary),
              const SizedBox(height: AppSpacing.lg),
              _TimelineItem(
                label: 'Joined Queue',
                timestamp: _formatDate(item.joinedQueueAt),
                isDone: true,
                isDark: isDark,
              ),
              _TimelineItem(
                label: 'Called',
                timestamp: _formatDate(item.calledAt),
                isDone: item.calledAt != null,
                isDark: isDark,
              ),
              _TimelineItem(
                label: 'Service Started',
                timestamp: _formatDate(item.serviceStartedAt),
                isDone: item.serviceStartedAt != null,
                isDark: isDark,
              ),
              _TimelineItem(
                label: 'Completed',
                timestamp: _formatDate(item.serviceCompletedAt),
                isDone: item.serviceCompletedAt != null,
                isLast: true,
                isDark: isDark,
              ),
              const SizedBox(height: AppSpacing.lg),
              Divider(color: divider, height: 1),
              const SizedBox(height: AppSpacing.lg),

              // ── RECORD SECTION ──────────────────────────────────────────────
              _SectionHeader(title: 'RECORD', textColor: textSecondary),
              const SizedBox(height: AppSpacing.sm),
              _DetailRow(
                icon: Icons.calendar_month_outlined,
                label: 'Created',
                value: _formatDate(item.createdAt),
                isDark: isDark,
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.massive),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 3, backgroundColor: color),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTextStyles.labelSmall(color)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.textColor});

  final String title;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.labelSmall(textColor).copyWith(
        letterSpacing: 1.2,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: AppSpacing.iconSM,
          color: textSecondary,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelSmall(textSecondary),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                value,
                style: AppTextStyles.bodyMedium(textPrimary).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.label,
    required this.timestamp,
    required this.isDone,
    this.isLast = false,
    required this.isDark,
  });

  final String label;
  final String timestamp;
  final bool isDone;
  final bool isLast;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final divider = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Indicator column
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.secondary
                      : (isDark ? AppColors.darkBackground : AppColors.lightBackground),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDone ? Colors.transparent : textSecondary,
                    width: 2,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDone ? AppColors.secondary : divider,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),

          // Content column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyMedium(textPrimary).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (timestamp.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      timestamp,
                      style: AppTextStyles.bodySmall(textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
