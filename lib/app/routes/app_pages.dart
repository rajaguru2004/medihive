import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';

import '../modules/login/bindings/login_binding.dart';
import '../modules/login/views/login_view.dart';
import '../modules/placeholders/views/placeholder_view.dart';
import '../modules/queue/bindings/queue_binding.dart';
import '../modules/queue/views/queue_view.dart';
import '../modules/add_to_queue/bindings/add_to_queue_binding.dart';
import '../modules/add_to_queue/views/add_to_queue_view.dart';
import '../modules/appointments/bindings/appointments_binding.dart';
import '../modules/appointments/views/appointments_view.dart';
import '../modules/inpatient/bindings/inpatient_binding.dart';
import '../modules/inpatient/views/inpatient_view.dart';
import '../modules/admit_patient/bindings/admit_patient_binding.dart';
import '../modules/admit_patient/views/admit_patient_view.dart';

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
      page: () => const PlaceholderView(
        title: 'Pre-Triage',
        icon: Icons.assignment_ind_rounded,
      ),
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
      name: _Paths.INPATIENT_DISCHARGE,
      page: () => const PlaceholderView(
        title: 'Discharge Patient',
        icon: Icons.logout_rounded,
      ),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.INPATIENT_ADD_BED,
      page: () => const PlaceholderView(
        title: 'Add Bed',
        icon: Icons.add_to_photos_rounded,
      ),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: _Paths.INPATIENT_ADMIT,
      page: () => const AdmitPatientView(),
      binding: AdmitPatientBinding(),
      transition: Transition.cupertino,
    ),
  ];
}
