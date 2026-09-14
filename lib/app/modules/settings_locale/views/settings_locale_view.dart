import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/keys/settings_locale_keys.dart';
import '../../../data/utils/formatters.dart';
import '../../../theme/theme.dart';
import '../controllers/settings_locale_controller.dart';

/// Money, dates, the clock and the clinic day.
///
/// Every format control here carries a line under it showing what it produces,
/// drawn from the **pending** value through the same formatters the rest of the
/// app uses. A separator is not a thing anybody has an opinion about in the
/// abstract; `₹1,234,567.50` is.
class SettingsLocaleView extends GetView<SettingsLocaleController> {
  const SettingsLocaleView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read at the root of the build, or the `lazyPut` never happens.
    final c = controller;

    return Scaffold(
      key: SettingsLocaleKeys.screen,
      appBar: const DetailHeader(title: 'Locale and money'),
      body: BentoGround(
        child: SafeArea(
          child: Obx(() {
            if (c.hasNoAccess) {
              return const Center(
                child: EmptyState(
                  key: SettingsLocaleKeys.noAccess,
                  icon: Icons.lock_outline_rounded,
                  title: 'Not yours to change',
                  message: 'An administrator can give your account permission '
                      'to change how this site writes money and dates.',
                ),
              );
            }

            return Form(
              key: c.formKey,
              child: BentoScreen(
                ground: false,
                bottomClearance: false,
                slivers: [
                  if (c.hasLoadError)
                    BentoSection(
                      top: BentoSpace.section,
                      child: ErrorRetryBanner(
                        message: c.rxLoadError.value!,
                        onRetry: c.save,
                      ),
                    ),
                  BentoSection(top: BentoSpace.section, child: _money(c)),
                  BentoSection(child: _dates(c)),
                  BentoSection(child: _place(c)),
                  BentoSection(child: _clinicDay(c)),
                ],
              ),
            );
          }),
        ),
      ),
      bottomNavigationBar: Obx(() {
        // Absent, not disabled, for an account that may read settings and not
        // write them.
        if (!c.canWrite) return const SizedBox.shrink();

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BentoSpace.page,
              BentoSpace.action,
              BentoSpace.page,
              BentoSpace.page,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FieldErrorSummary(
                    key: SettingsLocaleKeys.errors,
                    count: c.rxSubmitted.value ? c.invalidFieldCount : 0,
                  ),
                ),
                PrimaryBar(
                  key: SettingsLocaleKeys.save,
                  label: 'Save',
                  busy: c.rxLoading.value,
                  enabled: c.canSave,
                  onPressed: c.save,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ── Money ───────────────────────────────────────────────────────────────

  Widget _money(SettingsLocaleController c) => FormCard(
        title: 'Money',
        children: [
          AsyncPicker<String>(
            fieldKey: SettingsLocaleKeys.currency,
            label: 'Currency',
            valueLabel: '${c.rxCurrency.value} · '
                '${SettingsLocaleController.currencies[c.rxCurrency.value] ?? ''}',
            hint: 'Every figure with a currency on it in this app follows this.',
            options: [
              for (final entry
                  in SettingsLocaleController.currencies.entries)
                PickerOption<String>(
                  value: entry.key,
                  label: entry.key,
                  sublabel: entry.value,
                ),
            ],
            onSelected: c.selectCurrency,
          ),
          BentoInput(
            fieldKey: SettingsLocaleKeys.currencySymbol,
            label: 'Symbol',
            controller: c.currencySymbol,
            required: true,
            validator: c.validateSymbol,
            maxLength: 5,
            textInputAction: TextInputAction.next,
            hint: 'What goes on a price. Changing the currency sets this, and '
                'a site that writes “Rs” can overwrite it.',
          ),
          BentoField(
            label: 'Where the symbol goes',
            child: BentoSegmented<String>(
              options: const ['before', 'after'],
              selected: c.rxCurrencyPosition.value,
              labelOf: (value) =>
                  value == 'before' ? 'Before · ₹100' : 'After · 100₹',
              keyOf: (value) =>
                  SettingsLocaleKeys.option('position', value),
              onSelected: c.selectPosition,
            ),
          ),
          BentoField(
            label: 'Decimal mark',
            child: BentoSegmented<String>(
              options: SettingsLocaleController.decimalSeparators,
              selected: c.rxDecimalSeparator.value,
              labelOf: (value) => value == '.' ? 'Full stop  .' : 'Comma  ,',
              keyOf: (value) => SettingsLocaleKeys.option(
                'decimal',
                value == '.' ? 'dot' : 'comma',
              ),
              onSelected: c.selectDecimalSeparator,
            ),
          ),
          BentoField(
            label: 'Grouping mark',
            child: BentoSegmented<String>(
              options: SettingsLocaleController.thousandSeparators,
              selected: c.rxThousandSeparator.value,
              labelOf: SettingsLocaleController.thousandSeparatorLabel,
              keyOf: (value) => SettingsLocaleKeys.option(
                'thousand',
                switch (value) {
                  ',' => 'comma',
                  '.' => 'dot',
                  _ => 'space',
                },
              ),
              onSelected: c.selectThousandSeparator,
            ),
          ),
          BentoField(
            label: 'Decimal places',
            child: BentoSegmented<int>(
              options: SettingsLocaleController.centPrecisions,
              selected: c.rxCentPrecision.value,
              labelOf: SettingsLocaleController.centPrecisionLabel,
              keyOf: (value) =>
                  SettingsLocaleKeys.option('precision', '$value'),
              onSelected: c.selectCentPrecision,
            ),
          ),
          _Example(
            exampleKey: SettingsLocaleKeys.moneyExample,
            label: 'A bill will read',
            value: c.moneyExample,
          ),
        ],
      );

  // ── Dates and the clock ─────────────────────────────────────────────────

  Widget _dates(SettingsLocaleController c) => FormCard(
        title: 'Dates and the clock',
        children: [
          AsyncPicker<String>(
            fieldKey: SettingsLocaleKeys.dateFormat,
            label: 'Date format',
            valueLabel: c.rxDateFormat.value,
            options: [
              for (final format in SettingsLocaleController.dateFormats)
                PickerOption<String>(
                  value: format,
                  label: format,
                  // The pattern means nothing to most people; the date it
                  // produces means everything.
                  sublabel: Formatters.date(
                    SettingsLocaleController.sampleMoment,
                    pattern: format,
                  ),
                ),
            ],
            onSelected: c.selectDateFormat,
          ),
          _Example(
            exampleKey: SettingsLocaleKeys.dateExample,
            label: 'Today would read',
            value: c.dateExample,
          ),
          BentoSwitchRow(
            switchKey: SettingsLocaleKeys.clock24,
            label: '24-hour clock',
            // The reason the default is on, stated. RULES §0 is about being
            // read under load, and a drug chart in 12-hour without a meridiem
            // is how a dose gets given twice.
            sublabel: 'Off writes 4:40 PM. A drug chart in 12-hour with no '
                'meridiem is how a dose gets given twice.',
            value: c.rx24Hour.value,
            onChanged: c.select24Hour,
          ),
          _Example(
            exampleKey: SettingsLocaleKeys.timeExample,
            label: 'A time will read',
            value: c.timeExample,
          ),
          BentoField(
            label: 'Calendar',
            hint: 'What a date picker counts in.',
            child: BentoSegmented<String>(
              options: SettingsLocaleController.calendars,
              selected: c.rxCalendar.value,
              labelOf: Formatters.label,
              keyOf: (value) =>
                  SettingsLocaleKeys.option('calendar', value),
              onSelected: c.selectCalendar,
            ),
          ),
        ],
      );

  // ── Place ───────────────────────────────────────────────────────────────

  Widget _place(SettingsLocaleController c) => FormCard(
        title: 'Place',
        children: [
          AsyncPicker<String>(
            fieldKey: SettingsLocaleKeys.language,
            label: 'Language',
            valueLabel: SettingsLocaleController.languageLabel(
              c.rxLanguage.value,
            ),
            options: [
              for (final code in c.languageOptions)
                PickerOption<String>(
                  value: code,
                  label: SettingsLocaleController.languageLabel(code),
                  sublabel: code,
                ),
            ],
            onSelected: c.selectLanguage,
          ),
          AsyncPicker<String>(
            fieldKey: SettingsLocaleKeys.timezone,
            label: 'Timezone',
            valueLabel: c.rxTimezone.value,
            hint: 'How a timestamp is read on the ward. A board an hour out is '
                'a board that flags the wrong waits.',
            options: [
              for (final zone in c.timezoneOptions)
                PickerOption<String>(value: zone, label: zone),
            ],
            onSelected: c.selectTimezone,
          ),
        ],
      );

  // ── The clinic day ──────────────────────────────────────────────────────

  Widget _clinicDay(SettingsLocaleController c) => FormCard(
        title: 'The clinic day',
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: BentoInput(
                  fieldKey: SettingsLocaleKeys.workingHoursStart,
                  label: 'Opens',
                  controller: c.workingHoursStart,
                  required: true,
                  validator: c.validateClock,
                  keyboardType: TextInputType.datetime,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                    LengthLimitingTextInputFormatter(5),
                  ],
                  placeholder: '08:00',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BentoInput(
                  fieldKey: SettingsLocaleKeys.workingHoursEnd,
                  label: 'Closes',
                  controller: c.workingHoursEnd,
                  required: true,
                  validator: c.validateClock,
                  keyboardType: TextInputType.datetime,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                    LengthLimitingTextInputFormatter(5),
                  ],
                  placeholder: '17:00',
                ),
              ),
            ],
          ),
          QuantityField(
            fieldKey: SettingsLocaleKeys.appointmentDuration,
            label: 'Default slot (minutes)',
            controller: c.appointmentDuration,
            min: 5,
            required: true,
            error: c.rxSubmitted.value
                ? c.validateDuration(c.rxDuration.value)
                : null,
          ),
          const _Hint(
            text: 'The length a new appointment takes unless somebody changes '
                'it. The clinic grid is drawn from these three.',
          ),
        ],
      );
}

/// A line showing what the control above it produces.
///
/// Tabular figures, because the point is comparing one setting against another
/// and a proportional `7` is narrower than a `0` in every bundled face.
class _Example extends StatelessWidget {
  const _Example({
    required this.exampleKey,
    required this.label,
    required this.value,
  });

  final Key exampleKey;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: InsetSurface(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: isDark
                    ? AppTextStyles.darkFootnote()
                    : AppTextStyles.lightFootnote(),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                value,
                key: exampleKey,
                maxLines: 1,
                // Never ellipsised away to nothing: the whole figure is the
                // message, and `₹1,23…` says less than no example at all.
                overflow: TextOverflow.visible,
                softWrap: false,
                style: numeralStyle(context, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A line of explanation under a field the kit's own hint cannot carry.
class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Text(
          text,
          style: Theme.of(context).brightness == Brightness.dark
              ? AppTextStyles.darkFootnote()
              : AppTextStyles.lightFootnote(),
        ),
      );
}
