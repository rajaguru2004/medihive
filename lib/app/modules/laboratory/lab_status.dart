import 'package:flutter/material.dart';

import '../../data/utils/formatters.dart';
import '../../theme/theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the laboratory's own vocabulary
///
/// `CaseStatus` resolves clinical states, and a lab order's status is not one:
/// it is where a tube has got to. Routed through the acuity ramp the words
/// land wrong — `pending` reads as "awaiting a clinician's sign-off", and
/// `in_progress` and `sample_collected` are not spelled the way that table
/// spells them, so both resolve to the grey fallback and the whole worklist
/// becomes one colour.
///
/// So the six statuses, the three priorities and the four result flags are
/// mapped here, once, and every laboratory screen reads them from here. Each
/// carries **colour and rank and word**, never colour alone.
///
/// Two rules this file exists to hold:
///
///   * **No red.** Nothing about a workflow state is a deteriorating patient.
///     A rejected sample is amber — an administrative problem, the same way a
///     missed appointment is. The only red in this module is a critical
///     result, and it says the word "Critical" beside it.
///   * **STAT is `acuityUrgent`, not critical.** It is the top of the lab's
///     own queue, and painting it red would put a red row on a ward board for
///     a patient nobody is worried about.
/// ─────────────────────────────────────────────────────────────────────────────
abstract final class LabOrderStatus {
  static const String pending = 'pending';
  static const String sampleCollected = 'sample_collected';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  static const String rejected = 'rejected';

  /// Every status the API's `@IsIn` accepts, in workflow order — which is also
  /// the order a filter sheet should offer them in.
  static const List<String> all = [
    pending,
    sampleCollected,
    inProgress,
    completed,
    cancelled,
    rejected,
  ];

  static String _key(String? status) => (status ?? '').trim().toLowerCase();

  static Color colorOf(String? status) => switch (_key(status)) {
        pending => AppColors.acuityRoutine,
        sampleCollected => AppColors.acuityStandard,
        inProgress => AppColors.acuityReview,
        completed => AppColors.acuityStable,
        cancelled => AppColors.acuityDischarged,
        // Amber. A sample that could not be run is a job to redo, not a
        // patient in trouble.
        rejected => AppColors.warning,
        _ => AppColors.acuityRoutine,
      };

  /// `sample_collected` → `Sample collected`. Never the stored spelling: an
  /// underscore on a pill has leaked a database convention onto a ward screen.
  static String labelOf(String? status) => switch (_key(status)) {
        pending => 'Pending',
        sampleCollected => 'Sample collected',
        inProgress => 'In progress',
        completed => 'Completed',
        cancelled => 'Cancelled',
        rejected => 'Rejected',
        _ => Formatters.label(status),
      };

  static IconData iconOf(String? status) => switch (_key(status)) {
        pending => Icons.schedule_rounded,
        sampleCollected => Icons.science_outlined,
        inProgress => Icons.biotech_outlined,
        completed => Icons.check_circle_rounded,
        cancelled => Icons.block_rounded,
        rejected => Icons.report_problem_outlined,
        _ => Icons.circle_outlined,
      };

  /// Whether the order is still moving. A closed order offers no actions.
  static bool isOpen(String? status) => switch (_key(status)) {
        completed || cancelled || rejected => false,
        _ => true,
      };
}

/// `routine`, `urgent`, `stat` — how fast the lab is being asked to work.
abstract final class LabPriority {
  static const String routine = 'routine';
  static const String urgent = 'urgent';
  static const String stat = 'stat';

  /// Most urgent first, which is the order a picker should offer them in.
  static const List<String> all = [stat, urgent, routine];

  static String _key(String? priority) => (priority ?? '').trim().toLowerCase();

  /// Lowest number first. Derived from the stored word rather than from the
  /// colour: `stat` and `urgent` share a colour deliberately — a reader across
  /// a corridor should not have to tell two ambers apart — and a rank read off
  /// the colour would tie them and hand the order back to arrival time, which
  /// is the sort this exists to replace.
  static int rankOf(String? priority) => switch (_key(priority)) {
        stat => 0,
        urgent => 1,
        routine => 2,
        _ => 3,
      };

  static Color colorOf(String? priority) => switch (_key(priority)) {
        // Amber, not red. Red on a board means a patient is deteriorating, and
        // a STAT potassium is a lab queue position.
        stat || urgent => AppColors.acuityUrgent,
        routine => AppColors.acuityRoutine,
        _ => AppColors.acuityRoutine,
      };

  /// Upper-cased for `stat`, because that is the word on the request form and
  /// the word a bench technician says out loud.
  static String labelOf(String? priority) => switch (_key(priority)) {
        stat => 'STAT',
        urgent => 'Urgent',
        routine => 'Routine',
        _ => Formatters.label(priority),
      };

  static bool isStat(String? priority) => _key(priority) == stat;
}

/// `H`, `L`, `N`, `A` — what the bench recorded about a value.
abstract final class LabResultFlag {
  static const String high = 'H';
  static const String low = 'L';
  static const String normal = 'N';
  static const String abnormal = 'A';

  static const List<String> all = [normal, high, low, abnormal];

  static String _key(String? flag) => (flag ?? '').trim().toUpperCase();

  /// The word, never the letter.
  ///
  /// `H` beside a number is a letter a reader has to decode, and `L` is one
  /// somebody eventually reads as a unit. The stored value stays a letter
  /// because the DTO's `@IsIn` says so; what a person sees is a word.
  static String labelOf(String? flag) => switch (_key(flag)) {
        high => 'High',
        low => 'Low',
        normal => 'Normal',
        abnormal => 'Abnormal',
        _ => '',
      };

  static Color colorOf(String? flag) => switch (_key(flag)) {
        normal => AppColors.acuityStable,
        high || low || abnormal => AppColors.acuityUrgent,
        _ => AppColors.acuityRoutine,
      };

  static bool isNormal(String? flag) => _key(flag) == normal;
}
