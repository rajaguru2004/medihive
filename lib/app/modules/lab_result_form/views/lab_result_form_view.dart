import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/keys/laboratory_keys.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../../laboratory/lab_status.dart';
import '../controllers/lab_result_form_controller.dart';

/// Entering one result.
class LabResultFormView extends GetView<LabResultFormController> {
  const LabResultFormView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root: a `GetView` that never touches `controller` never
    // builds it, and the reference ranges are never fetched.
    final form = controller;

    return Scaffold(
      key: LaboratoryKeys.resultFormScreen,
      appBar: DetailHeader(
        title: form.testName.isEmpty ? 'Enter result' : form.testName,
        subtitle: form.orderNumber.isEmpty
            ? 'Laboratory result'
            : 'Order ${form.orderNumber}',
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
                      child: Obx(
                        () => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (form.errorMessage.value != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: BentoSpace.action,
                                ),
                                child: NoticeBanner(
                                  message: form.errorMessage.value!,
                                  icon: Icons.error_outline_rounded,
                                  tint: AppColors.error,
                                ),
                              ),
                            FormCard(
                              title: 'Reading',
                              children: [
                                _valueField(form),
                                BentoInput(
                                  fieldKey: LaboratoryKeys.resultUnit,
                                  label: 'Unit',
                                  controller: form.unitController,
                                  hint: form.catalogueUnit.isEmpty
                                      ? 'What the analyser reports in'
                                      : 'The catalogue says '
                                          '${form.catalogueUnit}',
                                ),
                                _reference(context, form),
                              ],
                            ),
                            const SizedBox(height: BentoSpace.section),
                            FormCard(
                              title: 'Flag',
                              children: [
                                const SizedBox(height: 10),
                                BentoSegmented<String>(
                                  options: LabResultFlag.all,
                                  selected: form.flag.value,
                                  // Words, never the stored letter. `H` beside
                                  // a number is a letter somebody has to
                                  // decode, and `L` is one that eventually
                                  // reads as a unit.
                                  labelOf: LabResultFlag.labelOf,
                                  keyOf: LaboratoryKeys.resultFlag,
                                  onSelected: form.setFlag,
                                ),
                                const SizedBox(height: 6),
                                BentoSwitchRow(
                                  switchKey: LaboratoryKeys.resultAbnormal,
                                  label: 'Outside the reference range',
                                  sublabel: 'Marks the result abnormal on the '
                                      'report.',
                                  value: form.isAbnormal.value,
                                  onChanged: form.setAbnormal,
                                ),
                                BentoSwitchRow(
                                  switchKey: LaboratoryKeys.resultCritical,
                                  label: 'Critical',
                                  sublabel: 'Somebody has to be telephoned. '
                                      'Turning this on marks it abnormal too.',
                                  value: form.isCritical.value,
                                  onChanged: form.setCritical,
                                ),
                              ],
                            ),
                            const SizedBox(height: BentoSpace.section),
                            FormCard(
                              title: 'Notes',
                              children: [
                                BentoInput(
                                  fieldKey: LaboratoryKeys.resultComment,
                                  label: 'Comment',
                                  controller: form.commentController,
                                  maxLines: 3,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  hint: 'Goes on the report beside the value',
                                ),
                              ],
                            ),
                          ],
                        ),
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
                      () => PrimaryBar(
                        key: LaboratoryKeys.resultSubmit,
                        label: 'Save result',
                        icon: Icons.save_outlined,
                        busy: form.isSubmitting.value,
                        onPressed: form.submit,
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

  /// The value input, shaped by what the catalogue says this test answers
  /// with.
  Widget _valueField(LabResultFormController form) {
    if (form.isQualitative) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            BentoSegmented<String>(
              options: LabResultFormController.qualitativeAnswers,
              selected: LabResultFormController.qualitativeAnswers.firstWhere(
                (answer) =>
                    answer.toLowerCase() ==
                    form.valueController.text.trim().toLowerCase(),
                orElse: () => LabResultFormController.qualitativeAnswers.last,
              ),
              labelOf: (answer) => answer,
              keyOf: (answer) =>
                  LaboratoryKeys.resultFlag(answer.toLowerCase()),
              onSelected: form.chooseAnswer,
            ),
            const SizedBox(height: 10),
            BentoInput(
              fieldKey: LaboratoryKeys.resultValue,
              label: 'Result',
              controller: form.valueController,
              validator: form.validateValue,
              required: true,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      );
    }

    return BentoInput(
      fieldKey: LaboratoryKeys.resultValue,
      label: 'Result',
      controller: form.valueController,
      validator: form.validateValue,
      required: true,
      autofocus: true,
      keyboardType: form.isNumeric
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      maxLines: form.isNumeric ? 1 : 2,
      textCapitalization:
          form.isNumeric ? TextCapitalization.none : TextCapitalization.sentences,
      inputFormatters: form.isNumeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-<>]'))]
          : null,
      hint: form.isNumeric
          ? 'The number the analyser reported'
          : 'What came back — a word, a titre, a description',
    );
  }

  /// The reference range, beside the field rather than a screen away.
  ///
  /// The person typing 7.2 is the person who has to know whether 7.2 is
  /// normal, and a range they have to leave the form to look up is a range
  /// they stop looking up.
  Widget _reference(BuildContext context, LabResultFormController form) {
    final ranges = form.referenceRanges;
    if (ranges.isEmpty) return const SizedBox.shrink();

    return Padding(
      key: LaboratoryKeys.resultReference,
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: InsetSurface(
        radius: BentoRadius.control,
        padding: const EdgeInsets.all(12),
        color: wellColor(context),
        bordered: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Reference',
              style: AppTextStyles.overline(Theme.of(context).brightness),
            ),
            const SizedBox(height: 5),
            for (final range in ranges)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    if (range.label.isNotEmpty) ...[
                      Text(
                        Formatters.label(range.label),
                        style: AppFonts.text(
                          fontSize: 12.5,
                          color: secondaryLabelColor(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        [
                          range.display,
                          if (form.catalogueUnit.isNotEmpty) form.catalogueUnit,
                        ].join(' '),
                        // Never shortened. A reference range with its end cut
                        // off is worse than none: "3.5 – 5…" reads as 5, and a
                        // potassium of 5.6 then looks fine.
                        style: numeralStyle(context, size: 13),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
