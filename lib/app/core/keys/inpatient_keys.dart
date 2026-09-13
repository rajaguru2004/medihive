import 'package:flutter/widgets.dart';

/// Widget keys for the inpatient estate: the overview, wards, the bed map and
/// admissions.
///
/// One file for four screens because they are four views of one thing — a
/// ward's beds — and a key that names a bed must mean the same bed on all of
/// them.
abstract final class InpatientKeys {
  // ── Overview ──────────────────────────────────────────────────────────────
  static const overview = Key('inpatient_overview_screen');
  static const capacity = Key('inpatient_capacity');
  static const overviewError = Key('inpatient_overview_error');

  // ── Wards ─────────────────────────────────────────────────────────────────
  static const wards = Key('inpatient_wards_screen');
  static const wardsList = Key('inpatient_wards_list');
  static const addWard = Key('inpatient_add_ward_button');
  static const wardsEmpty = Key('inpatient_wards_empty');
  static Key ward(String id) => Key('inpatient_ward_$id');

  // ── Beds ──────────────────────────────────────────────────────────────────
  static const beds = Key('inpatient_beds_screen');
  static const bedGrid = Key('inpatient_bed_grid');
  static const bedLegend = Key('inpatient_bed_legend');
  static const addBed = Key('inpatient_add_bed_button');
  static const bedsEmpty = Key('inpatient_beds_empty');
  static Key bed(String id) => Key('inpatient_bed_$id');

  /// One per `BedState`, keyed by its enum name. The counts on the bed map are
  /// also its filters, so this names a control rather than a statistic.
  static Key bedStateFilter(String state) => Key('inpatient_bed_filter_$state');

  // ── Admissions ────────────────────────────────────────────────────────────
  static const admissions = Key('inpatient_admissions_screen');
  static const admissionsList = Key('inpatient_admissions_list');
  static const admissionsFilters = Key('inpatient_admissions_filters');
  static const admissionsEmpty = Key('inpatient_admissions_empty');
  static Key admission(String id) => Key('inpatient_admission_$id');

  // ── Ward form ─────────────────────────────────────────────────────────────
  static const wardForm = Key('inpatient_ward_form_screen');
  static const wardNameField = Key('inpatient_ward_name');
  static const wardTypePicker = Key('inpatient_ward_type');
  static const wardCapacityField = Key('inpatient_ward_capacity');
  static const wardSave = Key('inpatient_ward_save');

  // ── Bed form ──────────────────────────────────────────────────────────────
  static const bedForm = Key('inpatient_bed_form_screen');
  static const bedNumberField = Key('inpatient_bed_number');
  static const bedWardPicker = Key('inpatient_bed_ward');
  static const bedTypePicker = Key('inpatient_bed_type');
  static const bedSave = Key('inpatient_bed_save');
}
