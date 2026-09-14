import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/keys/staff_keys.dart';
import '../../../theme/theme.dart';
import '../controllers/user_form_controller.dart';

/// One staff account: who they are, what they do, and what they may sign.
class UserFormView extends GetView<UserFormController> {
  const UserFormView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root of `build`, or the lazyPut controller is never built
    // and an edit opens on an empty form.
    final form = controller;

    return Scaffold(
      key: StaffKeys.formScreen,
      appBar: DetailHeader(
        title: form.isEdit ? 'Edit account' : 'Add somebody',
        subtitle: 'Users and staff',
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
                                message: message,
                                icon: Icons.error_outline_rounded,
                                tint: AppColors.error,
                              ),
                            );
                          }),
                          _Identity(form: form),
                          const SizedBox(height: BentoSpace.section),
                          _Work(form: form),
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
                    child: Obx(
                      () => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (form.invalidCount.value > 0) ...[
                            FieldErrorSummary(count: form.invalidCount.value),
                            const SizedBox(height: BentoSpace.action),
                          ],
                          PrimaryBar(
                            key: StaffKeys.formSave,
                            label: form.isEdit ? 'Save changes' : 'Create',
                            busy: form.isSubmitting.value,
                            onPressed: form.save,
                          ),
                        ],
                      ),
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
}

class _Identity extends StatelessWidget {
  const _Identity({required this.form});

  final UserFormController form;

  @override
  Widget build(BuildContext context) {
    return FormCard(
      title: 'Who they are',
      children: [
        // Create only, on both routes. `UpdateUserDto` omits `email` and
        // `password`, and `UpdateSettingsUserDto` never declared them — so
        // sending either on the PUT is a 400 rather than an ignored key.
        // Changing an address and changing a credential are different acts
        // with different audit trails, and neither belongs on this form.
        if (!form.isEdit) ...[
          BentoInput(
            fieldKey: StaffKeys.formEmail,
            label: 'Email',
            controller: form.emailController,
            validator: form.validateEmail,
            required: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            hint: 'How they sign in. It cannot be changed here afterwards.',
          ),
          BentoInput(
            fieldKey: StaffKeys.formPassword,
            label: 'First password',
            controller: form.passwordController,
            validator: form.validatePassword,
            required: true,
            obscure: true,
            hint: 'At least 8 characters. There is no invitation email, so '
                'somebody has to hand this over.',
          ),
        ],
        // One field or two, decided by which route the directory could read.
        // `/api/settings/users` stores one `fullName` and splitting it here
        // would rewrite "Dr Amara Okonkwo" as two columns it does not have.
        if (form.usesFullName)
          BentoInput(
            fieldKey: StaffKeys.formFullName,
            label: 'Full name',
            controller: form.fullNameController,
            validator: form.validateFullName,
            required: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          )
        else ...[
          BentoInput(
            fieldKey: StaffKeys.formFirstName,
            label: 'First name',
            controller: form.firstNameController,
            validator: form.validateFirstName,
            required: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          BentoInput(
            fieldKey: StaffKeys.formLastName,
            label: 'Last name',
            controller: form.lastNameController,
            validator: form.validateLastName,
            required: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
        ],
        BentoInput(
          fieldKey: StaffKeys.formPhone,
          label: 'Phone',
          controller: form.phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]')),
          ],
        ),
      ],
    );
  }
}

class _Work extends StatelessWidget {
  const _Work({required this.form});

  final UserFormController form;

  @override
  Widget build(BuildContext context) {
    return FormCard(
      title: 'What they do',
      children: [
        Obx(
          () => AsyncPicker<String>(
            fieldKey: StaffKeys.formRole,
            label: 'Role',
            valueLabel: form.roleLabel,
            placeholder: 'Choose a role',
            required: form.usesFullName && !form.isEdit,
            options: form.roleOptions,
            emptyMessage: 'No roles to choose from',
            hint: 'What they are allowed to do is decided by the role, not by '
                'this app.',
            onSelected: (value) => form.role.value = value,
          ),
        ),
        Obx(
          () => AsyncPicker<String>(
            fieldKey: StaffKeys.formDepartment,
            label: 'Department',
            valueLabel: form.departmentLabel,
            placeholder: 'Choose a department',
            options: form.departmentOptions,
            emptyMessage: 'No departments recorded yet',
            onSelected: (value) => form.departmentId.value = value,
          ),
        ),
        BentoInput(
          fieldKey: StaffKeys.formEmployeeId,
          label: 'Employee id',
          controller: form.employeeIdController,
          hint: 'What payroll and the rota call them',
        ),
        BentoInput(
          fieldKey: StaffKeys.formSpecialization,
          label: 'Specialisation',
          controller: form.specializationController,
          textCapitalization: TextCapitalization.sentences,
          hint: 'Emergency medicine, diagnostic radiology',
        ),
        Obx(
          () => BentoInput(
            fieldKey: StaffKeys.formLicence,
            label: 'Licence number',
            controller: form.licenceController,
            validator: form.validateLicence,
            required: form.isClinicalRole,
            hint: form.isClinicalRole
                // Says why, not only that. A required field with no reason on
                // it reads as bureaucracy and gets filled with "N/A".
                ? 'Results and prescriptions are signed under this number. '
                    'Without it the signature cannot be traced to a person.'
                : 'Only clinical roles need one.',
          ),
        ),
      ],
    );
  }
}
