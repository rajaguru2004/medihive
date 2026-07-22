import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../modules/add_to_queue/bindings/add_to_queue_binding.dart';
import '../modules/add_to_queue/views/add_to_queue_view.dart';
import '../modules/admit_patient/bindings/admit_patient_binding.dart';
import '../modules/admit_patient/views/admit_patient_view.dart';
import '../modules/appointments/bindings/appointments_binding.dart';
import '../modules/appointments/views/appointments_view.dart';
import '../modules/discharge_patient/bindings/discharge_patient_binding.dart';
import '../modules/discharge_patient/views/discharge_patient_view.dart';
import '../modules/edit_screening/bindings/edit_screening_binding.dart';
import '../modules/edit_screening/views/edit_screening_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/inpatient/bindings/inpatient_binding.dart';
import '../modules/inpatient/views/inpatient_view.dart';
import '../modules/inpatient_add_bed/bindings/inpatient_add_bed_binding.dart';
import '../modules/inpatient_add_bed/views/inpatient_add_bed_view.dart';
import '../modules/inpatient_add_ward/bindings/inpatient_add_ward_binding.dart';
import '../modules/inpatient_add_ward/views/inpatient_add_ward_view.dart';
import '../modules/inpatient_admissions/bindings/inpatient_admissions_binding.dart';
import '../modules/inpatient_admissions/views/inpatient_admissions_view.dart';
import '../modules/inpatient_beds_grid/bindings/inpatient_beds_grid_binding.dart';
import '../modules/inpatient_beds_grid/views/inpatient_beds_grid_view.dart';
import '../modules/inpatient_overview/bindings/inpatient_overview_binding.dart';
import '../modules/inpatient_overview/views/inpatient_overview_view.dart';
import '../modules/inpatient_wards/bindings/inpatient_wards_binding.dart';
import '../modules/inpatient_wards/views/inpatient_wards_view.dart';
import '../modules/login/bindings/login_binding.dart';
import '../modules/login/views/login_view.dart';
import '../modules/new_screening_step1/bindings/new_screening_step1_binding.dart';
import '../modules/new_screening_step1/views/new_screening_step1_view.dart';
import '../modules/new_screening_step2/bindings/new_screening_step2_binding.dart';
import '../modules/new_screening_step2/views/new_screening_step2_view.dart';
import '../modules/placeholders/views/placeholder_view.dart';
import '../modules/pre_triage/bindings/pre_triage_binding.dart';
import '../modules/pre_triage/views/pre_triage_view.dart';
import '../modules/pre_triage_details/bindings/pre_triage_details_binding.dart';
import '../modules/pre_triage_details/views/pre_triage_details_view.dart';
import '../modules/queue/bindings/queue_binding.dart';
import '../modules/queue/views/queue_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.LOGIN;

  static final routes = [
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.LOGIN,
      page: () => const LoginView(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: _Paths.CONSULTATIONS,
      page: () => const PlaceholderView(
        title: 'Consultations',
        icon: Icons.medical_services_outlined,
      ),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.PATIENTS,
      page: () =>
          const PlaceholderView(title: 'Patients', icon: Icons.people_rounded),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.PHARMACY,
      page: () => const PlaceholderView(
        title: 'Pharmacy',
        icon: Icons.local_pharmacy_rounded,
      ),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.LABORATORY,
      page: () => const PlaceholderView(
        title: 'Laboratory',
        icon: Icons.science_rounded,
      ),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.RADIOLOGY,
      page: () => const PlaceholderView(
        title: 'Radiology',
        icon: Icons.settings_accessibility_rounded,
      ),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.PRE_TRIAGE,
      page: () => const PreTriageView(),
      binding: PreTriageBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.NEW_SCREENING_STEP1,
      page: () => const NewScreeningStep1View(),
      binding: NewScreeningStep1Binding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.NEW_SCREENING_STEP2,
      page: () => const NewScreeningStep2View(),
      binding: NewScreeningStep2Binding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.EDIT_SCREENING,
      page: () => const EditScreeningView(),
      binding: EditScreeningBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.PRE_TRIAGE_DETAILS,
      page: () => const PreTriageDetailsView(),
      binding: PreTriageDetailsBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.BILLING,
      page: () => const PlaceholderView(
        title: 'Billing & Revenue',
        icon: Icons.currency_rupee_rounded,
      ),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.USERS_STAFF,
      page: () => const PlaceholderView(
        title: 'Users & Staff',
        icon: Icons.badge_rounded,
      ),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.INTEGRATIONS,
      page: () => const PlaceholderView(
        title: 'Integrations',
        icon: Icons.integration_instructions_rounded,
      ),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.QUEUE,
      page: () => const QueueView(isEmbedded: false),
      binding: QueueBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.ADD_TO_QUEUE,
      page: () => const AddToQueueView(),
      binding: AddToQueueBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.APPOINTMENTS,
      page: () => const AppointmentsView(isEmbedded: false),
      binding: AppointmentsBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.INPATIENT,
      page: () => const InpatientView(isEmbedded: false),
      binding: InpatientBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.INPATIENT_ADD_BED,
      page: () => const InpatientAddBedView(),
      binding: InpatientAddBedBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.INPATIENT_ADMIT,
      page: () => const AdmitPatientView(),
      binding: AdmitPatientBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.DISCHARGE_PATIENT,
      page: () => const DischargePatientView(),
      binding: DischargePatientBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.INPATIENT_OVERVIEW,
      page: () => const InpatientOverviewView(),
      binding: InpatientOverviewBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.INPATIENT_BEDS_GRID,
      page: () => const InpatientBedsGridView(),
      binding: InpatientBedsGridBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.INPATIENT_ADD_WARD,
      page: () => const InpatientAddWardView(),
      binding: InpatientAddWardBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.INPATIENT_ADMISSIONS,
      page: () => const InpatientAdmissionsView(),
      binding: InpatientAdmissionsBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.INPATIENT_WARDS,
      page: () => const InpatientWardsView(),
      binding: InpatientWardsBinding(),
      transition: Transition.cupertino,
    ),
  ];
}
