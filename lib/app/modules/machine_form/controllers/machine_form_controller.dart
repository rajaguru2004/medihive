import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_log.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/drafts/admin_drafts.dart';
import '../../../data/models/json.dart';
import '../../../data/models/machine_integration.dart';
import '../../../data/repositories/integrations_repository.dart';
import '../../../data/services/access_service.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';

/// Registering a device, or editing one that is already wired in.
///
/// One controller for both, because they are one form: the differences are the
/// title, the verb on the button, and the two fields a registered device is not
/// allowed to change.
///
/// **`machineType` and `connectionType` are create-only.** `UpdateMachineDto`
/// declares neither, and the API runs `forbidNonWhitelisted`, so sending either
/// on an edit is a 400 for the whole save. The form shows them as facts on an
/// edit rather than as pickers that would refuse — a control that cannot work
/// is worse than a sentence saying why.
class MachineFormController extends GetxController {
  MachineFormController() : repository = _resolveRepository();

  static MachineFormController get to => Get.find<MachineFormController>();

  /// Registered rather than found, for the same reason the hub does it: this
  /// screen is reachable by deep link, where no other binding has run.
  static IntegrationsRepository _resolveRepository() {
    IntegrationsRepositories.register();
    return IntegrationsRepositories.instance;
  }

  final IntegrationsRepository repository;

  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final manufacturerController = TextEditingController();
  final modelController = TextEditingController();
  final serialController = TextEditingController();
  final departmentController = TextEditingController();
  final hostController = TextEditingController();
  final portController = TextEditingController();

  final machineType = RxnString();
  final connectionType = RxnString();
  final isActive = true.obs;

  final isSubmitting = false.obs;
  final isDeleting = false.obs;
  final errorMessage = RxnString();
  final invalidFields = 0.obs;

  /// Raised by the first refused save.
  ///
  /// The two pickers are the only required controls a `Form` cannot police:
  /// `AsyncPicker` opens a sheet rather than wrapping a `FormField`, so
  /// `validate()` never sees them. Complaining about an untouched choice before
  /// anybody has tried to save is a form that argues with somebody halfway
  /// through filling it in.
  final showChoiceErrors = false.obs;

  /// The device being edited, or null when registering a new one.
  MachineIntegration? editing;

  bool get isEdit => editing != null;

  bool get canDelete =>
      isEdit &&
      Get.isRegistered<AccessService>() &&
      AccessService.to.can(Modules.integrations, AccessVerb.delete);

  /// Whether the chosen transport has an address to configure at all.
  bool get hasAddress => MachineConnection.hasAddress(connectionType.value);

  @override
  void onInit() {
    super.onInit();

    final argument = Get.arguments;
    final passed = argument is Map ? argument['machine'] : argument;
    if (passed is! MachineIntegration) return;

    editing = passed;
    nameController.text = passed.machineName;
    manufacturerController.text = passed.manufacturer ?? '';
    modelController.text = passed.model ?? '';
    serialController.text = passed.serialNumber ?? '';
    departmentController.text = passed.department ?? '';
    machineType.value = passed.machineType;
    connectionType.value = passed.connectionType;
    isActive.value = passed.isActive;

    hostController.text = asString(
      passed.connectionDetails['ipAddress'] ??
          passed.connectionDetails['ip_address'] ??
          passed.connectionDetails['host'],
    );
    portController.text = asString(passed.connectionDetails['port']);
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? validateName(String? value) =>
      (value ?? '').trim().isEmpty ? 'Give the device a name' : null;

  /// Both enums are required by the create DTO, and a null there is a 400 for
  /// the whole request rather than a message about one field.
  bool get hasChoices =>
      isEdit || (machineType.value != null && connectionType.value != null);

  String? get typeError => showChoiceErrors.value && machineType.value == null
      ? 'Say what kind of device this is'
      : null;

  String? get connectionError =>
      showChoiceErrors.value && connectionType.value == null
          ? 'Say how the site talks to it'
          : null;

  String? validatePort(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final port = int.tryParse(text);
    if (port == null) return 'Enter a port number';
    if (port < 1 || port > 65535) return 'A port is between 1 and 65535';
    return null;
  }

  /// A port with nothing to connect to is a setting that looks configured and
  /// is not. Checked here rather than by the server, which stores this column
  /// as free-form JSON and would take it happily.
  String? validateHost(String? value) {
    final host = (value ?? '').trim();
    if (host.isNotEmpty || portController.text.trim().isEmpty) return null;
    return 'A port needs a host or an address to go with it';
  }

  int _invalidCount() {
    var count = 0;
    if (nameController.text.trim().isEmpty) count++;
    if (!isEdit && machineType.value == null) count++;
    if (!isEdit && connectionType.value == null) count++;
    if (hasAddress) {
      if (validatePort(portController.text) != null) count++;
      if (validateHost(hostController.text) != null) count++;
    }
    return count;
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Saves, and answers whether the server took it, so the view raises its
  /// toast only on success.
  Future<bool> save() async {
    if (isSubmitting.value) return false;

    final fieldsValid = formKey.currentState?.validate() ?? false;
    showChoiceErrors.value = true;
    if (!fieldsValid || !hasChoices) {
      invalidFields.value = _invalidCount();
      return false;
    }
    invalidFields.value = 0;

    FocusManager.instance.primaryFocus?.unfocus();
    isSubmitting.value = true;
    errorMessage.value = null;

    try {
      if (isEdit) {
        await repository.update(editing!.id, _updateBody());
      } else {
        await repository.create(_createBody());
      }
      return true;
    } on ApiForbiddenException catch (e) {
      // Gated on the access map and refused anyway: the map was stale.
      errorMessage.value = isEdit
          ? "You don't have permission to change this device."
          : "You don't have permission to register a device.";
      AppLog.info('$runtimeType', 'device write refused: ${e.message}');
      return false;
    } catch (e, stack) {
      AppLog.error('$runtimeType', "couldn't save the device", e, stack);
      errorMessage.value = parseErrorMessage(e, "Couldn't save that device.");
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Removes the device. Answers whether it is gone.
  ///
  /// The confirmation is the view's — a controller that raises a dialog is one
  /// that raises it in a widget test with no navigator under it.
  Future<bool> remove() async {
    final device = editing;
    if (device == null || isDeleting.value) return false;

    isDeleting.value = true;
    errorMessage.value = null;
    try {
      await repository.delete(device.id);
      return true;
    } on ApiForbiddenException catch (e) {
      errorMessage.value = "You don't have permission to remove this device.";
      AppLog.info('$runtimeType', 'device delete refused: ${e.message}');
      return false;
    } catch (e, stack) {
      AppLog.error('$runtimeType', "couldn't remove the device", e, stack);
      errorMessage.value =
          parseErrorMessage(e, "Couldn't remove that device.");
      return false;
    } finally {
      isDeleting.value = false;
    }
  }

  /// What a confirm has to say out loud before a device is removed.
  ///
  /// Names the consequence rather than asking "are you sure": the route runs a
  /// **hard** delete and the queue rows cascade with it, so this is the only
  /// place somebody is told that the results this machine has already sent go
  /// too.
  String get deleteMessage {
    final device = editing;
    if (device == null) return '';
    final waiting = device.queuedResults ?? 0;
    return [
      'Nothing more will arrive from it, and the results it has already sent '
          'are removed with it.',
      if (waiting > 0)
        waiting == 1
            ? 'One result is still waiting in the queue.'
            : '$waiting results are still waiting in the queue.',
      'Registering it again does not bring them back.',
    ].join(' ');
  }

  Map<String, dynamic> _createBody() => MachineDraft(
        machineName: nameController.text,
        machineType: machineType.value,
        connectionType: connectionType.value,
        manufacturer: manufacturerController.text,
        model: modelController.text,
        serialNumber: serialController.text,
        department: departmentController.text,
        connectionDetails: _connectionDetails(),
        // `organizationId` is deliberately not sent. The route resolves it from
        // the bearer token, and a client naming a site it is not signed in to
        // is a client asking to be refused.
      ).toCreateJson();

  Map<String, dynamic> _updateBody() => MachineDraft(
        machineName: nameController.text,
        manufacturer: manufacturerController.text,
        model: modelController.text,
        serialNumber: serialController.text,
        department: departmentController.text,
        connectionDetails: _connectionDetails(),
        isActive: isActive.value,
        // `connectionStatus` is deliberately not sent either. It is what the
        // machine last said about itself; a person typing "connected" into it
        // is a board that reports a link nobody has.
      ).toUpdateJson();

  /// The transport's settings, **merged over whatever is already stored**.
  ///
  /// The column is free-form and a site's integrator may have put a protocol
  /// version, a facility code or a TLS flag in it. This form edits two of its
  /// keys; replacing the map would silently drop the rest, and the symptom
  /// would be an analyser that stops parsing a week after somebody renamed it.
  ///
  /// The host key keeps whichever spelling the record already uses. The backend
  /// example is `ip_address`, so that is what a new device gets.
  Map<String, dynamic> _connectionDetails() {
    final details = <String, dynamic>{...?editing?.connectionDetails};
    if (!hasAddress) return details;

    final hostKey = const ['ipAddress', 'ip_address', 'host']
            .firstWhereOrNull(details.containsKey) ??
        'ip_address';

    final host = hostController.text.trim();
    if (host.isEmpty) {
      details.remove(hostKey);
    } else {
      details[hostKey] = host;
    }

    final port = int.tryParse(portController.text.trim());
    if (port == null) {
      details.remove('port');
    } else {
      details['port'] = port;
    }

    return details;
  }

  @override
  void onClose() {
    nameController.dispose();
    manufacturerController.dispose();
    modelController.dispose();
    serialController.dispose();
    departmentController.dispose();
    hostController.dispose();
    portController.dispose();
    super.onClose();
  }
}
