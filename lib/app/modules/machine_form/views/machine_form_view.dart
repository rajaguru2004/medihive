import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/keys/integrations_keys.dart';
import '../../../data/repositories/integrations_repository.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../../integrations/device_status.dart';
import '../controllers/machine_form_controller.dart';

/// One device: what it is, how the site talks to it, and where it stands.
class MachineFormView extends GetView<MachineFormController> {
  const MachineFormView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root of `build`, or the lazyPut controller is never built and
    // an edit opens on an empty form.
    final form = controller;

    return Scaffold(
      key: IntegrationsKeys.machineForm,
      appBar: DetailHeader(
        title: form.isEdit ? 'Edit device' : 'Register a device',
        subtitle: 'Instrument link',
      ),
      body: BentoGround(
        child: SafeArea(
          child: Form(
            key: form.formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(BentoSpace.page),
                    child: MaxWidthBody(
                      maxWidth: 560,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Obx(() {
                            final message = form.errorMessage.value;
                            if (message == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: BentoSpace.action,
                              ),
                              child: NoticeBanner(
                                key: IntegrationsKeys.machineFormError,
                                message: message,
                                icon: Icons.error_outline_rounded,
                                tint: AppColors.error,
                              ),
                            );
                          }),
                          _identity(form),
                          const SizedBox(height: BentoSpace.section),
                          _link(form),
                          const SizedBox(height: BentoSpace.section),
                          _service(form),
                          if (form.canDelete) ...[
                            const SizedBox(height: BentoSpace.section),
                            _remove(context, form),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BentoSpace.page,
                    0,
                    BentoSpace.page,
                    BentoSpace.page,
                  ),
                  child: MaxWidthBody(
                    maxWidth: 560,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Obx(
                          () => form.invalidFields.value == 0
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: FieldErrorSummary(
                                    count: form.invalidFields.value,
                                  ),
                                ),
                        ),
                        Obx(
                          () => PrimaryBar(
                            key: IntegrationsKeys.machineSave,
                            label: form.isEdit
                                ? 'Save changes'
                                : 'Register device',
                            busy: form.isSubmitting.value,
                            onPressed: () => _save(form),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── What it is ────────────────────────────────────────────────────────────

  Widget _identity(MachineFormController form) => FormCard(
        title: 'What it is',
        children: [
          BentoInput(
            fieldKey: IntegrationsKeys.machineName,
            label: 'Name',
            controller: form.nameController,
            validator: form.validateName,
            required: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            hint: 'What the bench calls it — Sysmex XN-1000',
          ),
          BentoInput(
            fieldKey: IntegrationsKeys.machineManufacturer,
            label: 'Manufacturer',
            controller: form.manufacturerController,
            textCapitalization: TextCapitalization.words,
          ),
          BentoInput(
            fieldKey: IntegrationsKeys.machineModel,
            label: 'Model',
            controller: form.modelController,
          ),
          BentoInput(
            fieldKey: IntegrationsKeys.machineSerial,
            label: 'Serial number',
            controller: form.serialController,
            hint: 'What is on the plate, for the engineer who asks',
          ),
          BentoInput(
            fieldKey: IntegrationsKeys.machineDepartment,
            label: 'Department',
            controller: form.departmentController,
            hint: 'Where it stands — laboratory, radiology, ICU',
          ),
        ],
      );

  // ── How the site talks to it ──────────────────────────────────────────────

  Widget _link(MachineFormController form) {
    // On an edit the pair is shown and not offered. `UpdateMachineDto` declares
    // neither, so a picker here would compose a request the server refuses
    // whole — and the person would have changed a name in the same save.
    if (form.isEdit) {
      return Obx(
        () => FormCard(
          key: IntegrationsKeys.machineFixed,
          title: 'How the site talks to it',
          children: [
            FactRow(
              label: 'Kind',
              value: DeviceKind.labelOf(form.machineType.value),
            ),
            FactRow(
              label: 'Link',
              value: connectionLabel(form.connectionType.value),
            ),
            const NoticeBanner(
              message: 'A device keeps the kind and the link it was registered '
                  'with. To change either, remove it and register it again.',
            ),
            ..._addressFields(form),
          ],
        ),
      );
    }

    return Obx(
      () => FormCard(
        title: 'How the site talks to it',
        children: [
          AsyncPicker<String>(
            fieldKey: IntegrationsKeys.machineType,
            label: 'Kind',
            required: true,
            valueLabel: form.machineType.value == null
                ? null
                : DeviceKind.labelOf(form.machineType.value),
            placeholder: 'Analyser, imaging, vitals',
            error: form.typeError,
            options: [
              for (final type in MachineType.all)
                PickerOption<String>(
                  value: type,
                  label: DeviceKind.labelOf(type),
                ),
            ],
            onSelected: (value) => form.machineType.value = value,
          ),
          AsyncPicker<String>(
            fieldKey: IntegrationsKeys.machineConnection,
            label: 'Link',
            required: true,
            valueLabel: form.connectionType.value == null
                ? null
                : connectionLabel(form.connectionType.value),
            placeholder: 'HL7, ASTM, REST, file, serial',
            hint: 'How results reach this site. It cannot be changed later.',
            error: form.connectionError,
            options: [
              for (final type in MachineConnection.all)
                PickerOption<String>(
                  value: type,
                  label: connectionLabel(type),
                ),
            ],
            onSelected: (value) => form.connectionType.value = value,
          ),
          ..._addressFields(form),
        ],
      ),
    );
  }

  /// The address, for the transports that have one.
  ///
  /// Absent for a serial cable or a dropped file: an empty host on those reads
  /// as a setting somebody forgot rather than as one that does not apply.
  List<Widget> _addressFields(MachineFormController form) {
    if (!form.hasAddress) return const [];
    return [
      BentoInput(
        fieldKey: IntegrationsKeys.machineHost,
        label: 'Host or address',
        controller: form.hostController,
        validator: form.validateHost,
        keyboardType: TextInputType.url,
        hint: '192.168.1.50, or the name the network knows it by',
      ),
      BentoInput(
        fieldKey: IntegrationsKeys.machinePort,
        label: 'Port',
        controller: form.portController,
        validator: form.validatePort,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    ];
  }

  // ── In service ────────────────────────────────────────────────────────────

  Widget _service(MachineFormController form) {
    if (!form.isEdit) {
      // A new device is registered `disconnected` and switched on. Saying so
      // beats a switch that sets a state the server overwrites anyway.
      return const FormCard(
        title: 'In service',
        children: [
          NoticeBanner(
            message: 'A device is in service from the moment it is registered. '
                'It reads as not connected until it first calls in.',
          ),
        ],
      );
    }

    final device = form.editing!;
    return FormCard(
      title: 'In service',
      children: [
        Obx(
          () => BentoSwitchRow(
            switchKey: IntegrationsKeys.machineActive,
            label: 'In service',
            sublabel: 'Off reads as switched off rather than as a fault, and '
                'stops it being offered as the source of an import.',
            value: form.isActive.value,
            onChanged: (value) => form.isActive.value = value,
          ),
        ),
        FactRow(
          label: 'Link now',
          value: DeviceLink.of(device).label,
          dense: true,
        ),
        FactRow(
          label: 'Last heard from',
          value: Formatters.elapsed(
            device.lastConnectedAt ?? device.lastResultReceivedAt,
          ),
          dense: true,
        ),
      ],
    );
  }

  // ── Removing it ───────────────────────────────────────────────────────────

  Widget _remove(BuildContext context, MachineFormController form) => Obx(
        () => SecondaryBar(
          key: IntegrationsKeys.machineDelete,
          label: 'Remove this device',
          icon: Icons.delete_outline_rounded,
          destructive: true,
          onPressed:
              form.isDeleting.value ? null : () => _confirmRemove(context, form),
        ),
      );

  Future<void> _confirmRemove(
    BuildContext context,
    MachineFormController form,
  ) async {
    final name = form.editing?.displayName ?? 'this device';
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Remove $name?',
      message: form.deleteMessage,
      confirmLabel: 'Remove',
      destructive: true,
      confirmKey: IntegrationsKeys.machineDeleteConfirm,
    );
    if (!confirmed) return;

    if (await form.remove()) {
      Get.back<void>();
      showBentoToast('$name removed.');
    }
  }

  Future<void> _save(MachineFormController form) async {
    final name = form.nameController.text.trim();
    if (!await form.save()) return;
    Get.back<void>();
    showBentoToast(form.isEdit ? '$name saved.' : '$name registered.');
  }
}
