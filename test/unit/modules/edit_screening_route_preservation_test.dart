import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:medihive/app/data/models/pre_triage_model.dart';
import 'package:medihive/app/data/services/pre_triage_service.dart';
import 'package:medihive/app/modules/edit_screening/controllers/edit_screening_controller.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — editing a screening must not erase where the patient was sent
///
/// The routing picker offers display labels — 'OPD', 'Pediatrics' — and the
/// stored value is frequently none of them: the pre-triage API and the backend
/// seeds write `adult_triage`, `mch_triage`, `psychiatric_triage`. When the
/// chips could not render the stored value the form fell back to "Decide
/// later", and because the update path sends `'routedTo': routedTo`
/// unconditionally — unlike create, which is null-aware — correcting a
/// temperature transmitted a real null and the column was cleared. The
/// screening then carried `status: 'routed'` with no destination: the only
/// record of where a nurse had sent that patient, gone, with nothing on screen
/// to say so.
///
/// That is a data-integrity bug, not a display bug, so what is asserted here is
/// the **payload** — the `routedTo` the service was actually handed — rather
/// than anything the screen shows. Three cases, because the fix has to hold at
/// both ends:
///
///   * a value the chips cannot show survives an edit that never touched
///     routing (the regression itself);
///   * choosing a real destination overrides that carried value, so the
///     preservation is not a value that can never be changed;
///   * choosing "Decide later" against a value the chips *can* show still
///     sends null, because deliberate clearing is a decision and must keep
///     working. A blanket null-aware send would have silently broken it.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  tearDown(Get.reset);

  /// A controller loaded with [stored] as the screening's routing value.
  ///
  /// The record is handed over the way the route hands it over — `Get.arguments`
  /// — because `onInit` reading that argument is the step that decides whether
  /// the stored value can be rendered, and that decision is what is under test.
  EditScreeningController loadedWith(String? stored) {
    Get.routing.args = PreTriageModel(
      id: 'screening-1',
      screeningId: 'SCR-0001',
      firstName: 'Amina',
      lastName: 'Yusuf',
      age: 34,
      gender: 'Female',
      chiefComplaint: 'Abdominal pain for two days',
      temperature: 38.4,
      pulse: 96,
      bpSystolic: 128,
      bpDiastolic: 82,
      route: stored,
      status: 'routed',
      createdAt: DateTime(2026, 3, 4, 9, 15),
    );
    final controller = EditScreeningController();
    controller.onInit();
    return controller;
  }

  /// The form the screen builds, reduced to the fields `save()` validates.
  ///
  /// `save()` opens with `formKey.currentState?.validate()`, and a form key
  /// attached to nothing validates to null — the save would return before
  /// reaching the service and every assertion below would pass on a call that
  /// never happened. So a real tree, with the controller's own validators, is
  /// what makes the absence of a payload distinguishable from a wrong one.
  Future<void> pumpForm(
    WidgetTester tester,
    EditScreeningController controller,
  ) async {
    Widget field(
      TextEditingController text,
      String? Function(String?) validator,
    ) =>
        TextFormField(controller: text, validator: validator);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: controller.formKey,
            child: ListView(
              children: [
                field(controller.firstNameController,
                    controller.validateFirstName),
                field(controller.complaintController,
                    controller.validateComplaint),
                field(controller.temperatureController,
                    controller.validateTemperature),
                field(controller.pulseController, controller.validatePulse),
                field(controller.systolicController,
                    controller.validateSystolic),
                field(controller.diastolicController,
                    controller.validateDiastolic),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Takes the tree down before the controller's text controllers go, so the
  /// disposal order here is the screen's and not an artefact of the test.
  Future<void> close(
    WidgetTester tester,
    EditScreeningController controller,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.onClose();
  }

  testWidgets(
    'a stored routing the chips cannot show survives an unrelated edit',
    (tester) async {
      final service = _RecordingPreTriageService();
      Get.put<PreTriageService>(service);
      final controller = loadedWith('adult_triage');
      await pumpForm(tester, controller);

      // Nothing in the picker was touched; the chips never offered
      // `adult_triage` in the first place, so `route.value` is null here and a
      // null is exactly what the broken build sent on.
      expect(controller.route.value, isNull);

      controller.temperatureController.text = '37.2';
      await controller.save();

      expect(service.calls, hasLength(1));
      expect(service.calls.single.routedTo, 'adult_triage');
      // The correction itself still went, so this is not a save that was
      // quietly abandoned.
      expect(service.calls.single.temperature, 37.2);

      await close(tester, controller);
    },
  );

  testWidgets(
    'choosing a destination overrides the value the chips could not show',
    (tester) async {
      final service = _RecordingPreTriageService();
      Get.put<PreTriageService>(service);
      final controller = loadedWith('adult_triage');
      await pumpForm(tester, controller);

      controller.route.value = 'Emergency';
      await controller.save();

      // Carrying the old value must not outrank the nurse in front of the
      // screen — a preserved routing that cannot be redirected is its own bug.
      expect(service.calls.single.routedTo, 'Emergency');

      await close(tester, controller);
    },
  );

  testWidgets(
    '"Decide later" against a renderable routing still clears it',
    (tester) async {
      final service = _RecordingPreTriageService();
      Get.put<PreTriageService>(service);
      final controller = loadedWith('OPD');
      await pumpForm(tester, controller);

      // The chips can show 'OPD', so the form was telling the truth about
      // where this patient went, and un-choosing it is a decision rather than
      // a gap the screen failed to represent.
      expect(controller.route.value, 'OPD');

      controller.route.value = null;
      await controller.save();

      expect(service.calls.single.routedTo, isNull);

      await close(tester, controller);
    },
  );
}

/// The arguments one `updateScreening` was given.
class _Update {
  const _Update({required this.routedTo, required this.temperature});

  final String? routedTo;
  final double? temperature;
}

/// A service that answers the way the backend does on a successful write and
/// keeps what it was asked to send.
///
/// `envelopeOk` reads `success: true` off a map body, which is the shape the
/// pre-triage routes return; a response the controller treated as a failure
/// would leave `errorMessage` set and prove nothing about the payload.
class _RecordingPreTriageService extends PreTriageService {
  final List<_Update> calls = [];

  @override
  Future<Response> updateScreening(
    String id, {
    required String firstName,
    String? lastName,
    int? age,
    String? gender,
    String? phone,
    required String chiefComplaint,
    String? briefHistory,
    double? temperature,
    int? pulse,
    int? bpSystolic,
    int? bpDiastolic,
    String? routedTo,
    String? status,
  }) async {
    calls.add(_Update(routedTo: routedTo, temperature: temperature));
    return Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: '/pre-triage/$id'),
      statusCode: 200,
      data: const {'success': true, 'data': <String, dynamic>{}},
    );
  }
}
