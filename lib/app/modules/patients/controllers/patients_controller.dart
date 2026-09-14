import 'package:get/get.dart';

import '../../../core/paged_list_controller.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/patient.dart';
import '../../../data/repositories/patient_repository.dart';
import '../../../data/services/access_service.dart';
import '../../../theme/theme.dart';
import '../patient_routes.dart';

/// Which slice of the register is showing.
///
/// The three values the server's `PatientQueryDto` accepts, spelled the way it
/// spells them — `@IsIn(['all','active','inactive'])`, so anything else is a
/// 400 for the whole request rather than an ignored parameter.
enum PatientStatusView { all, active, inactive }

extension PatientStatusViewLabel on PatientStatusView {
  String get label => switch (this) {
        PatientStatusView.all => 'Everyone',
        PatientStatusView.active => 'Active',
        PatientStatusView.inactive => 'Inactive',
      };
}

/// The patient register.
///
/// Paging, search, sort and the five list states come from
/// [PagedListController]; what is left here is this resource's own: the status
/// slice, which row the tablet's second pane is showing, and whether this
/// account may register anybody.
class PatientsController extends PagedListController<Patient> {
  PatientsController()
      : super(
          repository: patientRepository,
          sortOptions: const [
            // Newest first, because the commonest reason to open the register
            // is somebody who was registered a moment ago at the front desk.
            SortOption(field: 'createdAt', label: 'Newest first'),
            SortOption(
              field: 'lastName',
              label: 'Last name A–Z',
              descending: false,
            ),
            SortOption(
              field: 'createdAt',
              label: 'Oldest first',
              descending: false,
            ),
          ],
        );

  static PatientsController get to => Get.find<PatientsController>();

  final status = PatientStatusView.all.obs;

  /// The row the detail pane is showing on a tablet. Null on a phone, where
  /// the hub is a pushed screen and there is no pane to be out of step with.
  final selectedId = RxnString();

  /// Single-choice, not a filter sheet.
  ///
  /// The sheet is multi-select per group, and two statuses would travel as
  /// `status=active,inactive` — which this route rejects outright. Three
  /// mutually exclusive slices are chips anyway: the choice is visible without
  /// opening anything, which is what a list nobody can tell is filtered needs.
  @override
  Map<String, dynamic> get baseParams => {'status': status.value.name};

  /// Whether the Register control exists at all for this account.
  ///
  /// Absent rather than disabled: a greyed-out button on a ward tablet is a
  /// question the person holding it cannot answer.
  bool get canRegister =>
      AccessService.to.can(Modules.patients, AccessVerb.create);

  @override
  String idOf(Patient item) => item.id;

  @override
  String get couldNotLoadMessage => "Couldn't load the patient register.";

  Future<void> showStatus(PatientStatusView next) async {
    if (next == status.value) return;
    status.value = next;
    // Page four of the old slice has nothing to do with the new one.
    await reload();
  }

  /// Opens a patient in the tablet's second pane.
  void select(String id) => selectedId.value = id;

  /// Where a row goes on a phone. Arguments rather than a path parameter — see
  /// [PatientRoutes] for why the hub is not `/patients/:id`.
  Object hubArgumentsFor(Patient patient) => {
        'id': patient.id,
        // The record the list already holds, so the identity band paints on
        // the first frame instead of after a round trip. The hub refetches
        // regardless: a row is a summary and the hub shows the whole record.
        'patient': patient,
      };
}
