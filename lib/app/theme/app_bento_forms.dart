import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_clock.dart';
import '../core/window_class.dart';
import 'app_async_widgets.dart';
import 'app_bento.dart';
import 'app_bento_data.dart';
import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_surfaces.dart';
import 'app_text_styles.dart';
import 'app_theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the form layer of the kit
///
/// Entering a document on a phone is the hardest thing this app asks anyone to
/// do, and it is what makes the difference between a CRM people update and one
/// they update later. Everything here exists to take keystrokes out of it:
/// pickers that search rather than scroll, dates with the three answers people
/// actually give, amounts that already know the currency.
/// ─────────────────────────────────────────────────────────────────────────────

/// Confirms something that cannot be undone.
///
/// The one dialog in this app. Everything else is a sheet or an inline state —
/// a dialog stops the world, and almost nothing deserves to.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.destructive = false,
    this.confirmKey,
    this.cancelKey,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final Key? confirmKey;
  final Key? cancelKey;

  /// Returns true only if the user confirmed. A dismissed dialog is a no.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
    Key? confirmKey,
    Key? cancelKey,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        confirmKey: confirmKey,
        cancelKey: cancelKey,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = destructive ? semanticInk(context, AppColors.error) : null;

    return AlertDialog(
      backgroundColor: surfaceColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      title: Text(
        title,
        style: isDark ? AppTextStyles.darkTitle3() : AppTextStyles.lightTitle3(),
      ),
      content: Text(
        message,
        style: (isDark ? AppTextStyles.darkBody() : AppTextStyles.lightBody())
            .copyWith(color: secondaryLabelColor(context)),
      ),
      actions: [
        TextButton(
          key: cancelKey,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            cancelLabel,
            style: AppFonts.text(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: secondaryLabelColor(context),
            ),
          ),
        ),
        TextButton(
          key: confirmKey,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: AppFonts.text(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: tint ?? brandInkColor(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// One option a picker can offer.
class PickerOption<T> {
  const PickerOption({
    required this.value,
    required this.label,
    this.sublabel,
    this.color,
  });

  final T value;
  final String label;
  final String? sublabel;

  /// A dot beside the option — the status ramp, so a picker and the rows it
  /// produces agree on what each state looks like.
  final Color? color;
}

/// A field whose value is chosen from a list, searched as you type.
///
/// A dropdown is fine for six payment modes and unusable for four thousand
/// customers, and this app has both behind the same control. The sheet searches
/// the server when a search callback is given and filters in memory when it is
/// not, so a caller states where the options come from and nothing else.
class AsyncPicker<T> extends StatelessWidget {
  const AsyncPicker({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.onSelected,
    this.options,
    this.onSearch,
    this.hint,
    this.error,
    this.required = false,
    this.enabled = true,
    this.placeholder = 'Select',
    this.onCreateNew,
    this.createNewLabel,
    this.fieldKey,
    this.emptyMessage = 'Nothing found',
    this.searchHint,
  });

  final String label;

  /// What the chosen value reads as. Null shows [placeholder].
  final String? valueLabel;

  final ValueChanged<T> onSelected;

  /// A fixed set, filtered in memory. For a lookup small enough to hold.
  final List<PickerOption<T>>? options;

  /// Searches the server. For a collection too big to hold.
  final Future<List<PickerOption<T>>> Function(String query)? onSearch;

  final String? hint;
  final String? error;
  final bool required;
  final bool enabled;
  final String placeholder;

  /// Offers "add a new one" from inside the picker.
  ///
  /// The alternative is abandoning a half-typed admission to go and register
  /// the patient it is for, which is where a phone clinical app loses people.
  final VoidCallback? onCreateNew;
  final String? createNewLabel;

  final Key? fieldKey;

  /// Overrides the sheet's search hint.
  ///
  /// The default composes it from the label, which reads well for a noun
  /// ("Search customers") and badly for anything else — a label of "Find the
  /// site" becomes "Search find the site".
  final String? searchHint;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return BentoPicker(
      label: label,
      value: valueLabel,
      placeholder: placeholder,
      hint: hint,
      error: error,
      required: required,
      enabled: enabled,
      fieldKey: fieldKey,
      icon: Icons.unfold_more_rounded,
      onTap: enabled ? () => _open(context) : () {},
    );
  }

  /// Opens the picker sheet on its own and answers with what was chosen.
  ///
  /// For the places a value is picked without a field sitting there waiting for
  /// it — a library button beside a free-text input, a step inside a dialog.
  static Future<V?> choose<V>(
    BuildContext context, {
    required String title,
    List<PickerOption<V>>? options,
    Future<List<PickerOption<V>>> Function(String query)? onSearch,
    String emptyMessage = 'Nothing found',
    VoidCallback? onCreateNew,
    String createNewLabel = 'Add new',
  }) =>
      showModalBottomSheet<V>(
        context: context,
        isScrollControlled: true,
        backgroundColor: surfaceColor(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BentoRadius.sheet),
          ),
        ),
        builder: (context) => _PickerSheet<V>(
          title: title,
          options: options,
          onSearch: onSearch,
          emptyMessage: emptyMessage,
          onCreateNew: onCreateNew,
          createNewLabel: createNewLabel,
        ),
      );

  Future<void> _open(BuildContext context) async {
    final selected = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BentoRadius.sheet),
        ),
      ),
      builder: (context) => _PickerSheet<T>(
        title: label,
        options: options,
        onSearch: onSearch,
        emptyMessage: emptyMessage,
        onCreateNew: onCreateNew,
        createNewLabel: createNewLabel ?? 'Add new',
        searchHint: searchHint,
      ),
    );
    if (selected != null) onSelected(selected);
  }
}

/// The search field inside whichever picker sheet is open.
///
/// One constant rather than a key per picker: only one picker sheet can be
/// open at a time, and without it a long option list is undrivable — the
/// option a flow wants is below the fold, which in a sliver means it is not
/// built at all and no finder can reach it.
const Key kPickerSearchKey = Key('picker.search');

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.emptyMessage,
    required this.createNewLabel,
    this.options,
    this.onSearch,
    this.onCreateNew,
    this.searchHint,
  });

  final String title;
  final String? searchHint;
  final List<PickerOption<T>>? options;
  final Future<List<PickerOption<T>>> Function(String query)? onSearch;
  final String emptyMessage;
  final VoidCallback? onCreateNew;
  final String createNewLabel;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  late List<PickerOption<T>> _results = widget.options ?? const [];
  bool _loading = false;
  String? _error;
  String _query = '';

  /// Guards against an older search landing after a newer one and replacing a
  /// good result with a stale one.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.onSearch != null) _search('');
  }

  Future<void> _search(String query) async {
    _query = query;
    if (widget.onSearch == null) {
      setState(() {
        final needle = query.trim().toLowerCase();
        _results = (widget.options ?? const [])
            .where((o) =>
                needle.isEmpty ||
                o.label.toLowerCase().contains(needle) ||
                (o.sublabel ?? '').toLowerCase().contains(needle))
            .toList();
      });
      return;
    }

    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.onSearch!(query);
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = 'Could not search. Check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;

    return SheetShell(
      title: widget.title,
      child: ConstrainedBox(
        // A ceiling, not a height, and the distinction is the difference
        // between a picker that works and one that does not. A `SizedBox` of
        // the same fraction is a *demand*: a lookup with three options
        // reserved two thirds of the screen to show three rows in, and a sheet
        // opened with the keyboard up asked for more room than the sheet had —
        // which the enclosing `Column` answered by squeezing the results out
        // rather than the search field. As a ceiling it is tall enough for a
        // useful number of results, short enough to leave the screen behind it
        // visible — which is what keeps the choice in the context that
        // prompted it — and no taller than the results themselves.
        constraints: BoxConstraints(maxHeight: height * 0.62),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BentoSpace.listPad,
                0,
                BentoSpace.listPad,
                10,
              ),
              child: SearchField(
                fieldKey: kPickerSearchKey,
                hint: widget.searchHint ??
                    'Search ${widget.title.toLowerCase()}',
                onChanged: _search,
                autofocus: false,
              ),
            ),
            if (widget.onCreateNew != null)
              SheetRow(
                icon: Icons.add_rounded,
                label: widget.createNewLabel,
                tint: brandInkColor(context),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onCreateNew!();
                },
              ),
            Flexible(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading && _results.isEmpty) {
      // A definite height rather than a `Center` filling whatever is left: the
      // sheet is sized by its content now, and a spinner that claims the whole
      // ceiling makes the sheet collapse to a third of itself the moment the
      // first results land. Roughly two rows, so the settle is a nudge.
      return const SizedBox(
        height: 96,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(BentoSpace.listPad),
        child: ErrorRetryBanner(
          message: _error!,
          onRetry: () => _search(_query),
        ),
      );
    }

    if (_results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: widget.emptyMessage,
        message: _query.trim().isEmpty
            ? null
            : 'Nothing matches "${_query.trim()}".',
        compact: true,
      );
    }

    return ListView.builder(
      // Shrink-wrapped so a short result set makes a short sheet. It costs
      // nothing on a long one: the viewport still stops building rows once it
      // has filled the ceiling above, so a thousand customers lay out the same
      // dozen either way.
      shrinkWrap: true,
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final option = _results[index];
        return SheetRow(
          icon: option.color == null
              ? Icons.chevron_right_rounded
              : Icons.circle,
          tint: option.color == null
              ? null
              : semanticInk(context, option.color!),
          label: option.label,
          sublabel: option.sublabel,
          onTap: () => Navigator.of(context).pop(option.value),
        );
      },
    );
  }
}

/// An amount, in the site's own convention.
///
/// Never formats money itself — the symbol and the separators are supplied by
/// the caller, which reads them from settings. A field that assumes a dot for
/// decimals is a field that reads 1.234,56 as one and a bit.
class MoneyInput extends StatelessWidget {
  const MoneyInput({
    super.key,
    required this.label,
    required this.controller,
    this.symbol = '',
    this.decimalSeparator = '.',
    this.hint,
    this.error,
    this.required = false,
    this.enabled = true,
    this.max,
    this.onChanged,
    this.fieldKey,
    this.focusNode,
  });

  final String label;
  final TextEditingController controller;

  /// The site's currency symbol, shown inside the field.
  final String symbol;

  final String decimalSeparator;
  final String? hint;
  final String? error;
  final bool required;
  final bool enabled;

  /// The largest value this field accepts, shown as a hint. Used where the
  /// server enforces a ceiling — a payment cannot exceed what is owed.
  final double? max;

  final ValueChanged<String>? onChanged;
  final Key? fieldKey;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return BentoInput(
      label: label,
      controller: controller,
      fieldKey: fieldKey,
      focusNode: focusNode,
      hint: hint,
      error: error,
      required: required,
      enabled: enabled,
      placeholder: '0',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        // Both separators accepted on the way in: the keyboard offers whichever
        // the device's locale prefers, and refusing the other one is how a
        // German phone cannot enter cents.
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        _SingleDecimalFormatter(decimalSeparator),
      ],
      prefixIcon: null,
      onChanged: onChanged,
      suffix: symbol.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                symbol,
                style: AppFonts.numeric(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: secondaryLabelColor(context),
                ),
              ),
            ),
    );
  }
}

/// Keeps a money field to one decimal separator.
class _SingleDecimalFormatter extends TextInputFormatter {
  const _SingleDecimalFormatter(this.separator);

  final String separator;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final separators = RegExp(r'[.,]').allMatches(text).length;
    if (separators <= 1) return newValue;
    return oldValue;
  }
}

/// A date, with the answers people actually give.
///
/// Most dates entered into a CRM are today, a week out, or thirty days out.
/// Offering those first turns the commonest case into one tap and leaves the
/// calendar for the rest.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.format,
    this.hint,
    this.error,
    this.required = false,
    this.enabled = true,
    this.quickPicks = true,
    this.firstDate,
    this.lastDate,
    this.fieldKey,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  /// Formats a date in the site's own pattern. See `Formatters.date`.
  final String Function(DateTime) format;

  final String? hint;
  final String? error;
  final bool required;
  final bool enabled;
  final bool quickPicks;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return BentoPicker(
      label: label,
      value: value == null ? null : format(value!),
      placeholder: 'Choose a date',
      hint: hint,
      error: error,
      required: required,
      enabled: enabled,
      fieldKey: fieldKey,
      icon: Icons.calendar_today_rounded,
      onTap: enabled ? () => _open(context) : () {},
    );
  }

  Future<void> _open(BuildContext context) async {
    if (!quickPicks) {
      await _openCalendar(context);
      return;
    }

    final today = AppClock.now();
    final choice = await showModalBottomSheet<DateTime?>(
      context: context,
      backgroundColor: surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BentoRadius.sheet),
        ),
      ),
      builder: (context) => SheetShell(
        title: label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetRow(
              icon: Icons.today_rounded,
              label: 'Today',
              sublabel: format(today),
              onTap: () => Navigator.of(context).pop(_dateOnly(today)),
            ),
            SheetRow(
              icon: Icons.next_week_outlined,
              label: 'In a week',
              sublabel: format(today.add(const Duration(days: 7))),
              onTap: () => Navigator.of(context)
                  .pop(_dateOnly(today.add(const Duration(days: 7)))),
            ),
            SheetRow(
              icon: Icons.event_repeat_rounded,
              label: 'In 30 days',
              sublabel: format(today.add(const Duration(days: 30))),
              onTap: () => Navigator.of(context)
                  .pop(_dateOnly(today.add(const Duration(days: 30)))),
            ),
            const Hairline(indent: BentoSpace.listPad),
            SheetRow(
              icon: Icons.calendar_month_rounded,
              label: 'Pick a date',
              // Sentinel: the calendar opens after this sheet closes, because
              // a dialog raised from inside a sheet is dismissed with it.
              onTap: () => Navigator.of(context).pop(_calendarSentinel),
            ),
            if (value != null && !required)
              SheetRow(
                icon: Icons.clear_rounded,
                label: 'Clear',
                onTap: () => Navigator.of(context).pop(_clearSentinel),
              ),
          ],
        ),
      ),
    );

    if (choice == null) return;
    if (choice == _clearSentinel) {
      onChanged(null);
      return;
    }
    if (choice == _calendarSentinel) {
      if (context.mounted) await _openCalendar(context);
      return;
    }
    onChanged(choice);
  }

  Future<void> _openCalendar(BuildContext context) async {
    final now = AppClock.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: firstDate ?? DateTime(now.year - 5),
      lastDate: lastDate ?? DateTime(now.year + 5),
    );
    if (picked != null) onChanged(_dateOnly(picked));
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static final DateTime _calendarSentinel = DateTime.utc(1970, 1, 1);
  static final DateTime _clearSentinel = DateTime.utc(1970, 1, 2);
}

/// A count, with the two buttons that save a keyboard.
class QuantityField extends StatelessWidget {
  const QuantityField({
    super.key,
    required this.label,
    required this.controller,
    this.onChanged,
    this.enabled = true,
    this.required = false,
    this.error,
    this.min = 0,
    this.fieldKey,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool required;
  final String? error;
  final double min;
  final Key? fieldKey;

  void _step(double by) {
    final current = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
    final next = (current + by).clamp(min, double.maxFinite);
    // Whole numbers without a trailing `.0`: a quantity of "3.0" reads as a
    // measurement rather than a count.
    controller.text =
        next == next.roundToDouble() ? next.toInt().toString() : '$next';
    onChanged?.call(controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return BentoInput(
      label: label,
      controller: controller,
      fieldKey: fieldKey,
      enabled: enabled,
      required: required,
      error: error,
      placeholder: '1',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: onChanged,
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            onPressed: enabled ? () => _step(-1) : null,
            tooltip: 'Decrease',
          ),
          _StepButton(
            icon: Icons.add_rounded,
            onPressed: enabled ? () => _step(1) : null,
            tooltip: 'Increase',
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        color: secondaryLabelColor(context),
      );
}

/// A multi-line field that numbers its own lines.
///
/// Terms and conditions are a numbered list every time, and typing "1. " then
/// "2. " by hand on a phone keyboard is the kind of friction that ends with the
/// field left empty.
class NumberedTextInput extends StatefulWidget {
  const NumberedTextInput({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.enabled = true,
    this.minLines = 3,
    this.fieldKey,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool enabled;
  final int minLines;
  final Key? fieldKey;

  @override
  State<NumberedTextInput> createState() => _NumberedTextInputState();
}

class _NumberedTextInputState extends State<NumberedTextInput> {
  late final FocusNode _focus = FocusNode()..addListener(_onFocus);

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  /// Starts the list when the field takes focus empty.
  void _onFocus() {
    if (!_focus.hasFocus) return;
    if (widget.controller.text.isNotEmpty) return;
    widget.controller.text = '1. ';
    widget.controller.selection =
        TextSelection.collapsed(offset: widget.controller.text.length);
  }

  void _onChanged(String value) {
    if (!value.endsWith('\n')) return;
    final lines = value.split('\n');
    final numbered = lines.where((l) => RegExp(r'^\d+\.').hasMatch(l)).length;
    final next = '${numbered + 1}. ';
    widget.controller.text = '$value$next';
    widget.controller.selection =
        TextSelection.collapsed(offset: widget.controller.text.length);
  }

  @override
  Widget build(BuildContext context) {
    return BentoInput(
      label: widget.label,
      controller: widget.controller,
      fieldKey: widget.fieldKey,
      focusNode: _focus,
      hint: widget.hint,
      enabled: widget.enabled,
      maxLines: widget.minLines + 4,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      onChanged: _onChanged,
    );
  }
}

/// A labelled switch, at a real touch target.
class BentoSwitchRow extends StatelessWidget {
  const BentoSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.sublabel,
    this.enabled = true,
    this.switchKey,
  });

  final String label;
  final String? sublabel;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      toggled: value,
      label: label,
      child: InkWell(
        onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: WindowClass.of(context).minTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: isDark
                              ? AppTextStyles.darkCallout()
                              : AppTextStyles.lightCallout(),
                        ),
                        if (sublabel != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            sublabel!,
                            style: AppFonts.text(
                              fontSize: 12,
                              color: tertiaryLabelColor(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Switch(
                    key: switchKey,
                    value: value,
                    onChanged: enabled ? onChanged : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A six-digit one-time code.
///
/// One real field under six drawn cells: six separate fields fight the
/// keyboard's autofill, break paste, and make backspace ambiguous. The cells
/// are decoration over a single value.
class OtpCodeField extends StatelessWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.focusNode,
    this.length = 6,
    this.error,
    this.enabled = true,
    this.fieldKey,
    this.onSubmitted,
    this.expiresIn,
    this.issuedAt,
    this.countdownKey,
    this.onExpired,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final int length;
  final String? error;
  final bool enabled;
  final Key? fieldKey;
  final ValueChanged<String>? onSubmitted;

  /// Counts down to the code's expiry. The server gives five minutes, and a
  /// code that has quietly died looks exactly like a code typed wrong.
  final Duration? expiresIn;

  /// When the code on screen was issued.
  ///
  /// Only ever used to tell one code from the next: a resent code restarts the
  /// clock, and without this the countdown would carry on from wherever the
  /// old one had got to. The remaining time is counted in frames rather than
  /// read from the wall clock, so a screenshot of this field is the same
  /// picture every time it is taken.
  final DateTime? issuedAt;

  final Key? countdownKey;

  /// Fired once, when the countdown reaches zero.
  ///
  /// The screen and whatever holds the code should agree about when it died,
  /// and the only way to guarantee that is for both to read the same clock —
  /// this one.
  final VoidCallback? onExpired;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BentoInput(
          label: 'Verification code',
          fieldKey: fieldKey,
          controller: controller,
          focusNode: focusNode,
          placeholder: '0' * length,
          enabled: enabled,
          error: error,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: length,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(length),
          ],
          prefixIcon: Icons.pin_outlined,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
        if (expiresIn != null) ...[
          const SizedBox(height: 6),
          _Countdown(
            textKey: countdownKey,
            duration: expiresIn!,
            generation: issuedAt,
            onExpired: onExpired,
          ),
        ],
      ],
    );
  }
}

class _Countdown extends StatefulWidget {
  const _Countdown({
    required this.duration,
    this.textKey,
    this.generation,
    this.onExpired,
  });

  final Duration duration;
  final VoidCallback? onExpired;

  /// Goes on the line itself, so a test reads the words rather than the widget
  /// that renders them.
  final Key? textKey;

  /// Changes when a fresh code is issued, which restarts the clock. A resent
  /// code carries the same [duration] as the one it replaces, so the duration
  /// alone cannot tell the two apart.
  final Object? generation;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late Duration _remaining = widget.duration;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_Countdown old) {
    super.didUpdateWidget(old);
    if (old.generation != widget.generation || old.duration != widget.duration) {
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    _remaining = widget.duration;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = _remaining - const Duration(seconds: 1);
        if (_remaining <= Duration.zero) {
          _remaining = Duration.zero;
          _timer?.cancel();
          widget.onExpired?.call();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expired = _remaining <= Duration.zero;
    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;

    return Text(
      key: widget.textKey,
      expired
          ? 'That code has expired. Send a new one.'
          : 'Expires in $minutes:${seconds.toString().padLeft(2, '0')}',
      style: AppFonts.text(
        fontSize: 12,
        color: expired
            ? semanticInk(context, AppColors.error)
            : tertiaryLabelColor(context),
      ),
    );
  }
}
