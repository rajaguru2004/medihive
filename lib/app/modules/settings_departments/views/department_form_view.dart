import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/keys/settings_departments_keys.dart';
import '../../../data/models/staff_user.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../controllers/department_form_controller.dart';

/// One department: what it is called, its code, and who heads it.
class DepartmentFormView extends GetView<DepartmentFormController> {
  const DepartmentFormView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root of the build, or the `lazyPut` never happens and the
    // edit form opens empty.
    final form = controller;

    return Scaffold(
      key: SettingsDepartmentsKeys.form,
      appBar: DetailHeader(
        title: form.isEdit ? 'Edit department' : 'Add department',
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
                            final error = form.rxError.value;
                            if (error == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: NoticeBanner(
                                key: SettingsDepartmentsKeys.errors,
                                message: error,
                                icon: Icons.error_outline_rounded,
                                tint: AppColors.error,
                              ),
                            );
                          }),
                          _what(form),
                          const SizedBox(height: BentoSpace.section),
                          _who(form),
                        ],
                      ),
                    ),
                  ),
                ),
                _bottom(context, form),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _what(DepartmentFormController form) => FormCard(
    title: 'What it is',
    children: [
      BentoInput(
        fieldKey: SettingsDepartmentsKeys.name,
        label: 'Name',
        controller: form.name,
        required: true,
        validator: form.validateName,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        hint: 'What a rota, a ward and a staff record call this unit',
      ),
      BentoInput(
        fieldKey: SettingsDepartmentsKeys.code,
        label: 'Code',
        controller: form.code,
        textInputAction: TextInputAction.next,
        hint:
            'What a room sign or a rota says where the full name will '
            'not fit',
        inputFormatters: [
          // Upper-cased as typed: a code is an identifier, and `card`
          // beside `CARD` is two departments to anything that groups by it.
          TextInputFormatter.withFunction(
            (_, next) => next.copyWith(text: next.text.toUpperCase()),
          ),
        ],
      ),
      BentoInput(
        fieldKey: SettingsDepartmentsKeys.description,
        label: 'Description',
        controller: form.description,
        textCapitalization: TextCapitalization.sentences,
        maxLines: 3,
        hint: 'Optional. What this unit does, for somebody new.',
      ),
    ],
  );

  Widget _who(DepartmentFormController form) => FormCard(
    title: 'Who runs it',
    children: [
      Obx(
        () => AsyncPicker<StaffUser>(
          fieldKey: SettingsDepartmentsKeys.head,
          label: 'Head of department',
          valueLabel: form.rxHeadName.value,
          placeholder: 'Nobody named',
          hint: 'Optional. Escalations and rota questions go here.',
          searchHint: 'Name or role',
          emptyMessage: 'Nobody in the directory matches that',
          onSearch: (query) async => [
            // A way back out of a choice. Without it a head named by
            // accident can only be replaced, never removed.
            const PickerOption<StaffUser>(
              value: StaffUser.empty,
              label: 'Nobody',
              sublabel: 'Leave the department without a named head',
            ),
            for (final person in await form.staff(query))
              PickerOption<StaffUser>(
                value: person,
                label: person.displayName,
                sublabel: Formatters.label(person.role),
              ),
          ],
          onSelected: (person) =>
              person.isEmpty ? form.clearHead() : form.setHead(person),
        ),
      ),
      // Outside the `Obx`, not inside it. Whether this is an edit is fixed
      // for the screen's lifetime, and an `Obx` whose builder returns
      // before reading an observable **throws** rather than rendering
      // nothing — so on a new department the early return took the whole
      // form down with it.
      if (form.isEdit)
        Obx(
          () => BentoSwitchRow(
            switchKey: SettingsDepartmentsKeys.active,
            label: 'Active',
            // Retired rather than removed: the department is on every
            // staff record and every ward that names it, and taking it
            // out of the list is usually what somebody means by
            // "delete".
            sublabel:
                'Off stops it being offered on new records. '
                'Everything that already names it keeps it.',
            value: form.rxActive.value,
            onChanged: form.setActive,
          ),
        ),
    ],
  );

  Widget _bottom(BuildContext context, DepartmentFormController form) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(
          BentoSpace.page,
          0,
          BentoSpace.page,
          BentoSpace.page,
        ),
        child: MaxWidthBody(
          maxWidth: 560,
          child: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Absent, not disabled: an account that cannot write settings
                // gets a form it can read and no way to send it.
                if (form.canWrite && form.isEdit) ...[
                  SecondaryBar(
                    key: SettingsDepartmentsKeys.delete,
                    label: 'Remove this department',
                    icon: Icons.delete_outline_rounded,
                    destructive: true,
                    onPressed: form.rxDeleting.value
                        ? null
                        : () => _confirmDelete(context, form),
                  ),
                  const SizedBox(height: BentoSpace.action),
                ],
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FieldErrorSummary(
                    count: form.rxSubmitted.value ? form.invalidFieldCount : 0,
                  ),
                ),
                if (form.canWrite)
                  PrimaryBar(
                    key: SettingsDepartmentsKeys.save,
                    label: form.isEdit ? 'Save changes' : 'Add department',
                    busy: form.rxSubmitting.value,
                    onPressed: form.save,
                  ),
              ],
            ),
          ),
        ),
      );

  /// Names what becomes true, not what is being deleted.
  ///
  /// The fear at this dialog is "does this delete my staff". It does not — the
  /// server unassigns them and leaves every account alone — and the confirm is
  /// the only place anybody will read that.
  Future<void> _confirmDelete(
    BuildContext context,
    DepartmentFormController form,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Remove ${form.editing?.name ?? 'this department'}?',
      message: form.deleteConsequence,
      confirmLabel: 'Remove',
      destructive: true,
      confirmKey: SettingsDepartmentsKeys.deleteConfirm,
      cancelKey: SettingsDepartmentsKeys.deleteCancel,
    );
    if (confirmed) await form.delete();
  }
}
