import 'dart:async';

import 'package:flutter/material.dart';

import '../core/window_class.dart';
import 'app_async_widgets.dart';
import 'app_bento.dart';
import 'app_bento_forms.dart';
import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_surfaces.dart';
import 'app_text_styles.dart';
import 'app_theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the list layer of the kit
///
/// Every module in this app is a list, a record, and a form. This file is the
/// list half: the search field, the paged list, the rows, and the sheets that
/// filter and sort them.
/// ─────────────────────────────────────────────────────────────────────────────

/// A search field that waits for the typing to stop.
///
/// The backend's search is a regex scan with no index behind it, so a request
/// per keystroke is both slow and pointless — the answer to "ac" is thrown away
/// before it arrives. The delay is long enough to skip the middle of a word and
/// short enough not to feel like lag.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search',
    this.initial,
    this.fieldKey,
    this.autofocus = false,
    this.debounce = const Duration(milliseconds: 350),
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final String? initial;
  final Key? fieldKey;
  final bool autofocus;
  final Duration debounce;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onChanged(value));
    setState(() {}); // the clear button appears and disappears
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // `Material`, not a bare `Container`. A `TextField` asserts on a missing
    // Material ancestor and the assertion is Flutter's **red screen**, not a
    // degraded field — so a board that dropped this straight into a sliver
    // rather than inside a `BentoCard` rendered as a crash. The kit's contract
    // is that a component can go anywhere; carrying its own material is what
    // makes that true. `type: transparency` so it paints nothing of its own:
    // the decoration below is still the only thing drawing this pill.
    return Material(
      type: MaterialType.transparency,
      child: Container(
        // A **minimum**, not a height. A fixed 46 is 46 at every text scale, and
        // the field's own content needs more than that as soon as the reader
        // turns their font size up — the glyphs are then clipped mid-letter,
        // which looks like a broken font rather than a layout that ran out of
        // room.
        constraints: const BoxConstraints(minHeight: 46),
        decoration: BoxDecoration(
          color: wellColor(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: hairlineColor(context)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              Icons.search_rounded,
              size: 19,
              color: tertiaryLabelColor(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: widget.fieldKey,
                controller: _controller,
                autofocus: widget.autofocus,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                // Submitting jumps the debounce: somebody who pressed the key
                // has finished typing and should not wait out a timer.
                onSubmitted: (value) {
                  _timer?.cancel();
                  widget.onChanged(value);
                },
                style: isDark
                    ? AppTextStyles.darkBody()
                    : AppTextStyles.lightBody(),
                decoration: InputDecoration(
                  isDense: true,
                  // Both of these come from the app's `InputDecorationTheme`,
                  // and both are wrong inside a pill that already draws itself:
                  // `filled` paints a second, smaller box within this one, and
                  // the theme's 14-point vertical padding makes the field taller
                  // than the pill — so the text is clipped by the very box that
                  // should not be there. Turned off explicitly rather than left
                  // to inheritance.
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: widget.hint,
                  hintStyle:
                      (isDark
                              ? AppTextStyles.darkBody()
                              : AppTextStyles.lightBody())
                          .copyWith(color: tertiaryLabelColor(context)),
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                onPressed: _clear,
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Clear',
                color: secondaryLabelColor(context),
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

/// What a paged list is doing, for [InfiniteList].
enum ListPhase {
  /// Nothing fetched yet. Shows skeletons shaped like the rows to come.
  firstLoad,

  /// Rows on screen, possibly more to come.
  ready,

  /// The first fetch failed. Shows a retry, never an empty list — the two look
  /// identical to a user and only one is worth waiting through.
  error,

  /// The server refused: this account may not read this module.
  ///
  /// Its own phase because it is neither of the two above. A retry cannot fix
  /// it, so it must not offer one; and an empty list would say "there is
  /// nobody waiting" about a board this user simply cannot see.
  forbidden,
}

/// A paged list: skeletons, rows, an end, and the three states that are not
/// rows.
///
/// Returns slivers rather than a widget so a screen can put a header above it
/// inside one scroll view, which is what keeps the search field scrolling away
/// with the content instead of pinning a bar nobody asked for.
class InfiniteList extends StatelessWidget {
  const InfiniteList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.phase,
    this.hasMore = false,
    this.loadingMore = false,
    this.onLoadMore,
    this.error,
    this.onRetry,
    this.empty,
    this.skeletonRows = 6,
    this.separator,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final ListPhase phase;

  final bool hasMore;
  final bool loadingMore;

  /// Called when the list is three rows from the end. Idempotent: it fires
  /// again on every build near the boundary, so the controller guards it.
  final VoidCallback? onLoadMore;

  final String? error;
  final VoidCallback? onRetry;

  /// Shown when the fetch succeeded and there is nothing to show. Never the
  /// same thing as [error].
  final Widget? empty;

  final int skeletonRows;
  final Widget? separator;

  @override
  Widget build(BuildContext context) {
    // Each of these returns a sliver, because that is what a caller puts in a
    // `slivers:` list. `BentoSection` is already one — wrapping it in a
    // `SliverToBoxAdapter` puts a sliver inside a box and asserts at layout.
    if (phase == ListPhase.firstLoad) {
      return BentoSection(child: BentoSkeleton(rows: skeletonRows));
    }

    if (phase == ListPhase.error) {
      return BentoSection(
        child: ErrorRetryBanner(
          message: error ?? 'Something went wrong.',
          onRetry: onRetry,
        ),
      );
    }

    // No retry, and no red. Nothing is broken: this account was not granted
    // this module, and the only useful next step is a person, not a button.
    if (phase == ListPhase.forbidden) {
      return BentoSection(
        child: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Not available to your role',
          message: error ?? 'Ask an administrator if you need access to this.',
        ),
      );
    }

    if (itemCount == 0) {
      return BentoSection(
        child:
            empty ??
            const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'Nothing here yet',
            ),
      );
    }

    return SliverList.builder(
      // One extra slot for the footer: the load-more spinner, or the end rule.
      itemCount: itemCount + 1,
      itemBuilder: (context, index) {
        if (index == itemCount) {
          return _Footer(hasMore: hasMore, loading: loadingMore);
        }

        // Three rows from the end, not at it: fetching when the last row is
        // built means the user watches a spinner they could have been scrolling
        // past.
        if (hasMore && !loadingMore && index >= itemCount - 3) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => onLoadMore?.call(),
          );
        }

        final row = itemBuilder(context, index);
        if (separator == null || index == 0) return row;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [separator!, ?row],
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.hasMore, required this.loading});

  final bool hasMore;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (hasMore) return const SizedBox(height: 20);

    // The end of a finite list, said quietly. Without it a list that happens to
    // fill the screen exactly looks like one that failed to load its next page.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          'End of list',
          style: AppFonts.text(
            fontSize: 12,
            color: tertiaryLabelColor(context),
          ),
        ),
      ),
    );
  }
}

/// A record in a list: a screening, an admission, an appointment.
///
/// Number and client on the left, amount and status on the right — the four
/// things somebody scanning a list of money is actually looking for, in the
/// order they look for them.
class DocumentRow extends StatelessWidget {
  const DocumentRow({
    super.key,
    required this.number,
    required this.title,
    required this.amount,
    this.subtitle,
    this.status,
    this.statusColor,
    this.secondaryStatus,
    this.secondaryStatusColor,
    this.onTap,
    this.onLongPress,
    this.dimmed = false,
    this.selected = false,
  });

  /// The document's own number, shown above the client's name.
  final String number;

  /// Usually the client.
  final String title;

  /// Already formatted in the site's own convention. This widget never
  /// formats money itself — see `SettingsService.money`.
  final String amount;

  final String? subtitle;
  final String? status;
  final Color? statusColor;

  /// A second pill, for a document that carries two states at once — an
  /// screening is both "urgent" and "awaiting review".
  final String? secondaryStatus;
  final Color? secondaryStatusColor;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Greys the row. For a record that is no longer live — a discharged
  /// admission, a cancelled appointment.
  final bool dimmed;

  /// Marks the row a two-pane layout is currently showing on the right.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final window = WindowClass.of(context);

    return Material(
      color: selected ? brandTonalColor(context) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Opacity(
          opacity: dimmed ? 0.55 : 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: window.rowHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BentoSpace.listPad,
                vertical: 12,
              ),
              // Two aligned lines and a full-width third, not two columns of
              // unequal height standing side by side.
              //
              // This used to be one tall left column against one tall right
              // column, split three fifths to two. Nothing lined up: the amount
              // is 17-point and the number above the name is 13, so the right
              // column's first line was taller than the left's and every line
              // after it sat at its own height — a row of five values at four
              // different altitudes. And `Expanded` is *tight*, so the name
              // kept exactly 60% whether the pills used their 40% or a quarter
              // of it; the slack became a hole in the middle of the row while
              // the name ellipsed a character in.
              //
              // Paired instead, so each line answers the one beside it:
              //
              //   2026000054-00                              S$10,000
              //   Acme Manufacturing            Partially Invoiced
              //   E2E-2026…-convert · due 29 Aug 2026
              //
              // The reference line spans the whole width because nothing sits
              // opposite it, which is also the line most likely to be long.
              child: LayoutBuilder(
                builder: (context, row) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Which document, and how much. On a shared baseline: two
                    // sizes of numeral hung from the same line read as one
                    // fact, and centred they read as two.
                    Row(
                      spacing: 12,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            number,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.numeric(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: secondaryLabelColor(context),
                            ),
                          ),
                        ),
                        // Bounded: a non-flex child in a `Row` is laid out with
                        // unbounded width, and a seven-figure total would push
                        // the number off its own row.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: row.maxWidth * 0.55,
                          ),
                          child: Text(
                            amount,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.money(
                              Theme.of(context).brightness,
                              size: 17,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Who it is for, and what state it is in.
                    Row(
                      spacing: 12,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: isDark
                                ? AppTextStyles.darkCallout()
                                : AppTextStyles.lightCallout(),
                          ),
                        ),
                        if (status != null)
                          // Capped rather than given a fixed share: a document
                          // can carry two pills at once — a screening is both
                          // sent and part paid — and unbounded they would size
                          // to both and push the row off screen. Past the cap
                          // they wrap instead of taking the name's room.
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: row.maxWidth * 0.52,
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                StatusPill(
                                  status: status!,
                                  color: statusColor,
                                  label: status,
                                  compact: true,
                                ),
                                if (secondaryStatus != null)
                                  StatusPill(
                                    status: secondaryStatus!,
                                    color: secondaryStatusColor,
                                    label: secondaryStatus,
                                    compact: true,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.text(
                          fontSize: 12,
                          color: tertiaryLabelColor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A person in a list: a patient, a clinician, a staff member.
class PersonRow extends StatelessWidget {
  const PersonRow({
    super.key,
    required this.name,
    this.subtitle,
    this.detail,
    this.photoUrl,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  final String name;
  final String? subtitle;

  /// A third line, or a value on the right — a country, a role.
  final String? detail;

  final String? photoUrl;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Marks the row a two-pane layout is currently showing on the right.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final window = WindowClass.of(context);

    return Material(
      color: selected ? brandTonalColor(context) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: window.rowHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BentoSpace.listPad,
              vertical: 10,
            ),
            // Same reasoning as `DocumentRow`: the trailing detail takes what
            // it needs and the name takes the rest. `Expanded` beside a
            // `Flexible` split this 50/50 whatever the detail held, so "India"
            // reserved half the row and the name ellipsed against empty space.
            child: LayoutBuilder(
              builder: (context, row) => Row(
                children: [
                  _Avatar(name: name, photoUrl: photoUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: isDark
                              ? AppTextStyles.darkCallout()
                              : AppTextStyles.lightCallout(),
                        ),
                        if (subtitle != null &&
                            subtitle!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.text(
                              fontSize: 13,
                              color: secondaryLabelColor(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (detail != null && detail!.trim().isNotEmpty) ...[
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: row.maxWidth * 0.4),
                      child: Text(
                        detail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: AppFonts.text(
                          fontSize: 12,
                          color: tertiaryLabelColor(context),
                        ),
                      ),
                    ),
                  ],
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final initials = _initialsOf(name);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: brandTonalColor(context),
        shape: BoxShape.circle,
        image: (photoUrl != null && photoUrl!.isNotEmpty)
            ? DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: (photoUrl != null && photoUrl!.isNotEmpty)
          ? null
          : Text(
              initials,
              style: AppFonts.text(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: brandInkColor(context),
              ),
            ),
    );
  }

  static String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// One action on a row.
class RowAction {
  const RowAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
    this.actionKey,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;

  /// Paints the row in the error colour and sorts it last. Delete only.
  final bool destructive;

  final Key? actionKey;
}

/// One record, read-only, in a sheet.
///
/// What a row opens for somebody who may see a page and not change it. Without
/// it those screens had a dead row: the editor was gated behind UPDATE, so a
/// VIEW-only account tapped a name and nothing at all happened — which reads
/// as a broken list rather than as a permission.
///
/// The same sheet carries an Edit button for the accounts that do have the
/// permission, so nobody has to learn two ways into a record.
class RecordSheet extends StatelessWidget {
  const RecordSheet({
    super.key,
    required this.title,
    required this.facts,
    this.subtitle,
    this.onEdit,
    this.editLabel = 'Edit',
    this.editKey,
    this.closeKey,
  });

  final String title;
  final String? subtitle;

  /// Label and value, in the order the record reads. A blank value is dropped
  /// rather than shown as an empty row — on a schema-driven screen most of a
  /// record's fields are usually unset.
  final List<(String, String)> facts;

  final VoidCallback? onEdit;
  final String editLabel;
  final Key? editKey;
  final Key? closeKey;

  @override
  Widget build(BuildContext context) {
    final filled = [
      for (final (label, value) in facts)
        if (value.trim().isNotEmpty) (label, value),
    ];

    return SheetShell(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (subtitle != null && subtitle!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BentoSpace.listPad,
                0,
                BentoSpace.listPad,
                4,
              ),
              child: Text(
                subtitle!,
                style: AppFonts.text(
                  fontSize: 13,
                  height: 1.35,
                  color: secondaryLabelColor(context),
                ),
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BentoSpace.listPad,
                ),
                child: BentoCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: BentoSpace.listCardPad,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (filled.isEmpty)
                        const FactRow(label: 'Nothing recorded', value: '—')
                      else
                        for (var i = 0; i < filled.length; i++) ...[
                          if (i > 0) const Hairline(indent: BentoSpace.listPad),
                          FactRow(
                            label: filled[i].$1,
                            value: filled[i].$2,
                            stacked: filled[i].$2.length > 28,
                          ),
                        ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BentoSpace.listPad),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: closeKey,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Close',
                      style: AppFonts.text(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: secondaryLabelColor(context),
                      ),
                    ),
                  ),
                ),
                if (onEdit != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: PrimaryBar(
                      key: editKey,
                      label: editLabel,
                      onPressed: onEdit!,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// What a long press on a row opens.
///
/// A sheet rather than a context menu: the actions differ per row by
/// permission, and a menu that silently has three items for one user and six
/// for another is a menu nobody learns.
class RowActionsSheet extends StatelessWidget {
  const RowActionsSheet({
    super.key,
    required this.title,
    required this.actions,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<RowAction> actions;

  @override
  Widget build(BuildContext context) {
    final ordered = [
      ...actions.where((a) => !a.destructive),
      ...actions.where((a) => a.destructive),
    ];

    return SheetShell(
      title: title,
      // Scrollable, because neither the number of actions nor the room
      // available is fixed: the list grows with the user's permissions, and a
      // sheet opened while the keyboard is up has a few hundred points less to
      // work with than one opened without.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final action in ordered)
              SheetRow(
                key: action.actionKey,
                icon: action.icon,
                label: action.label,
                destructive: action.destructive,
                onTap: action.onSelected,
              ),
          ],
        ),
      ),
    );
  }
}

/// One way a list can be ordered.
class SortOption {
  const SortOption({
    required this.field,
    required this.label,
    this.descending = true,
  });

  /// The backend's own field name — `created`, `total`, `number`.
  final String field;

  final String label;

  /// Which direction reads as "most useful first" for this field. Newest for a
  /// date, largest for an amount, A–Z for a name.
  final bool descending;

  /// `desc` or `asc`, as this API's `orderDir` parameter wants it.
  ///
  /// It was `-1` / `1` here, which belongs to a different backend: this one
  /// validates `orderDir` with `@IsIn(['asc','desc'])`, so a number rejected
  /// the whole request rather than the sort.
  String get orderDir => descending ? 'desc' : 'asc';

  SortOption flipped() =>
      SortOption(field: field, label: label, descending: !descending);

  bool matches(SortOption other) =>
      other.field == field && other.descending == descending;
}

/// Picks the order a list is in.
class SortSheet extends StatelessWidget {
  const SortSheet({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.optionKey,
  });

  final List<SortOption> options;
  final SortOption selected;
  final ValueChanged<SortOption> onSelected;
  final Key? Function(SortOption)? optionKey;

  @override
  Widget build(BuildContext context) {
    return SheetShell(
      title: 'Sort by',
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final option in options)
              SheetRow(
                key: optionKey?.call(option),
                icon: option.descending
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                label: option.label,
                selected: option.matches(selected),
                onTap: () => onSelected(option),
              ),
          ],
        ),
      ),
    );
  }
}

/// One filter a list offers: a field, and the values it can take.
class FilterGroup {
  const FilterGroup({
    required this.field,
    required this.label,
    this.options = const [],
    this.labelOf,
    this.colorOf,
    this.range = false,
    this.rangeSymbol = '',
    this.rangeHint,
  });

  /// A group of two number fields rather than a list of options.
  ///
  /// Encoded into the same `field → values` map as everything else, as the
  /// `min:<n>` and `max:<n>` tokens `invoiceController/paginatedList.js`
  /// already parses. The filter model stays one shape, and the sheet is the
  /// only thing that knows a range looks different from a set of chips.
  const FilterGroup.range({
    required String field,
    required String label,
    String symbol = '',
    String? hint,
  }) : this(
         field: field,
         label: label,
         range: true,
         rangeSymbol: symbol,
         rangeHint: hint,
       );

  /// The backend field this filters on.
  final String field;

  final String label;
  final List<String> options;

  final bool range;
  final String rangeSymbol;
  final String? rangeHint;

  /// How to name a value. Null shows the value itself.
  final String Function(String value)? labelOf;

  /// A dot beside the option — the status ramp, so the filter and the rows it
  /// produces agree on what each state looks like.
  final Color Function(String value)? colorOf;

  String nameOf(String value) => labelOf?.call(value) ?? value;
}

/// Two money fields that read and write a [FilterGroup.range] group's tokens.
///
/// Lives on its own because two sheets render filter groups — this one and the
/// record sheet, which adds a ward picker — and a range that encoded
/// itself differently in each would be a filter that worked on one screen.
class FilterRangeRow extends StatefulWidget {
  const FilterRangeRow({
    super.key,
    required this.group,
    required this.values,
    required this.onChanged,
    this.boundKey,
  });

  final FilterGroup group;

  /// The `min:`/`max:` tokens already held for this field.
  final List<String> values;

  final ValueChanged<List<String>> onChanged;
  final Key? Function(String field, String bound)? boundKey;

  @override
  State<FilterRangeRow> createState() => _FilterRangeRowState();
}

class _FilterRangeRowState extends State<FilterRangeRow> {
  late final _min = TextEditingController(text: _valueOf('min'));
  late final _max = TextEditingController(text: _valueOf('max'));

  String _valueOf(String bound) {
    for (final token in widget.values) {
      if (token.startsWith('$bound:')) return token.substring(bound.length + 1);
    }
    return '';
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _emit() {
    // A blank or unparseable bound drops out rather than going up as an empty
    // token: `paginatedList.js` ignores `min:` with nothing after it, and a
    // filter count that includes a field nobody filled in is a badge that
    // lies.
    widget.onChanged([
      for (final entry in {'min': _min, 'max': _max}.entries)
        if (entry.value.text.trim().isNotEmpty &&
            double.tryParse(entry.value.text.trim()) != null)
          '${entry.key}:${entry.value.text.trim()}',
    ]);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      BentoSpace.listPad,
      0,
      BentoSpace.listPad,
      4,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: MoneyInput(
                label: 'From',
                fieldKey: widget.boundKey?.call(widget.group.field, 'min'),
                controller: _min,
                symbol: widget.group.rangeSymbol,
                onChanged: (_) => _emit(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MoneyInput(
                label: 'To',
                fieldKey: widget.boundKey?.call(widget.group.field, 'max'),
                controller: _max,
                symbol: widget.group.rangeSymbol,
                onChanged: (_) => _emit(),
              ),
            ),
          ],
        ),
        // Under both, not under one: a hint hung on the right-hand field
        // makes it taller than its neighbour, and two fields that should
        // read as one control stop lining up.
        if (widget.group.rangeHint != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.group.rangeHint!,
            style: AppFonts.text(
              fontSize: 12,
              height: 1.35,
              color: tertiaryLabelColor(context),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Picks which records a list shows.
///
/// Multi-select per group, because "show me everything that is not settled" is
/// two statuses, and making that two visits to a sheet is how a filter goes
/// unused.
class FilterSheet extends StatefulWidget {
  const FilterSheet({
    super.key,
    required this.groups,
    required this.selected,
    required this.onApply,
    this.optionKey,
    this.applyKey,
    this.resetKey,
    this.rangeKey,
  });

  final List<FilterGroup> groups;

  /// Field to selected values.
  final Map<String, List<String>> selected;

  final ValueChanged<Map<String, List<String>>> onApply;

  final Key? Function(String field, String value)? optionKey;
  final Key? applyKey;
  final Key? resetKey;

  /// Keyed by field and either `min` or `max`.
  final Key? Function(String field, String bound)? rangeKey;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late final Map<String, List<String>> _draft = {
    for (final entry in widget.selected.entries) entry.key: [...entry.value],
  };

  void _toggle(String field, String value) {
    setState(() {
      final values = _draft.putIfAbsent(field, () => []);
      if (values.contains(value)) {
        values.remove(value);
        if (values.isEmpty) _draft.remove(field);
      } else {
        values.add(value);
      }
    });
  }

  int get _count => _draft.values.fold(0, (sum, values) => sum + values.length);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SheetShell(
      title: 'Filter',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The groups scroll; Reset and Apply do not. How many rows this
          // sheet has is a site's status library and a screen's filter
          // table, neither of which is a number this widget knows — and a
          // range filter puts the keyboard up over its own Apply button, at
          // which point a column that only sizes itself has nowhere to put
          // the rows it still owes. `DocumentFilterSheet` has always had this
          // shape; this one was the copy that did not.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final group in widget.groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        BentoSpace.listPad,
                        12,
                        BentoSpace.listPad,
                        6,
                      ),
                      child: Text(
                        group.label,
                        style: AppTextStyles.overline(
                          Theme.of(context).brightness,
                        ),
                      ),
                    ),
                    if (group.range)
                      FilterRangeRow(
                        group: group,
                        values: _draft[group.field] ?? const [],
                        boundKey: widget.rangeKey,
                        onChanged: (tokens) => setState(() {
                          if (tokens.isEmpty) {
                            _draft.remove(group.field);
                          } else {
                            _draft[group.field] = tokens;
                          }
                        }),
                      )
                    else
                      for (final value in group.options)
                        SheetRow(
                          key: widget.optionKey?.call(group.field, value),
                          icon:
                              (_draft[group.field] ?? const []).contains(value)
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          label: group.nameOf(value),
                          tint: group.colorOf == null
                              ? null
                              : semanticInk(context, group.colorOf!(value)),
                          selected: (_draft[group.field] ?? const []).contains(
                            value,
                          ),
                          onTap: () => _toggle(group.field, value),
                        ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BentoSpace.listPad),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: widget.resetKey,
                    onPressed: _count == 0
                        ? null
                        : () => setState(_draft.clear),
                    child: Text(
                      'Reset',
                      style:
                          (isDark
                                  ? AppTextStyles.darkCallout()
                                  : AppTextStyles.lightCallout())
                              .copyWith(color: secondaryLabelColor(context)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: PrimaryBar(
                    key: widget.applyKey,
                    label: _count == 0 ? 'Show all' : 'Apply ($_count)',
                    onPressed: () => widget.onApply(_draft),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// The row of controls above a list: search, filter, sort.
///
/// One widget rather than three, because the three are always used together and
/// the count badge on the filter button only makes sense beside them.
class ListControls extends StatelessWidget {
  const ListControls({
    super.key,
    required this.onSearch,
    this.searchHint = 'Search',
    this.searchKey,
    this.onFilter,
    this.filterCount = 0,
    this.filterKey,
    this.onSort,
    this.sortKey,
  });

  final ValueChanged<String> onSearch;
  final String searchHint;
  final Key? searchKey;

  final VoidCallback? onFilter;

  /// How many filters are on, shown on the button. A filtered list that looks
  /// like an empty one is the single most common "the app lost my data" report.
  final int filterCount;
  final Key? filterKey;

  final VoidCallback? onSort;
  final Key? sortKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SearchField(
            fieldKey: searchKey,
            hint: searchHint,
            onChanged: onSearch,
          ),
        ),
        if (onFilter != null) ...[
          const SizedBox(width: 8),
          _ControlButton(
            buttonKey: filterKey,
            icon: Icons.filter_list_rounded,
            tooltip: 'Filter',
            badge: filterCount,
            onTap: onFilter!,
          ),
        ],
        if (onSort != null) ...[
          const SizedBox(width: 8),
          _ControlButton(
            buttonKey: sortKey,
            icon: Icons.swap_vert_rounded,
            tooltip: 'Sort',
            onTap: onSort!,
          ),
        ],
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge = 0,
    this.buttonKey,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badge;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final active = badge > 0;
    return Semantics(
      button: true,
      label: active ? '$tooltip, $badge active' : tooltip,
      child: Material(
        color: active ? brandTonalColor(context) : wellColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: InkWell(
          key: buttonKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: active ? brandInkColor(context) : hairlineColor(context),
              ),
            ),
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: active
                      ? brandInkColor(context)
                      : secondaryLabelColor(context),
                ),
                if (active)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: brandFillColor(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$badge',
                        style: AppFonts.numeric(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: onBrandFillColor(context),
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

/// The header of a record screen: what it is, what state it is in, what it is
/// worth, and what can be done with it.
///
/// The order is the order somebody opening a patient record reads in — identity,
/// state, amount, actions — and it is the same on every record in the app so
/// the second one is free to learn.
class RecordHeader extends StatelessWidget {
  const RecordHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.amount,
    this.amountLabel,
    this.status,
    this.statusColor,
    this.secondaryStatus,
    this.secondaryStatusColor,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;

  /// Already formatted. See `SettingsService.money`.
  final String? amount;
  final String? amountLabel;

  final String? status;
  final Color? statusColor;
  final String? secondaryStatus;
  final Color? secondaryStatusColor;

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BentoCard(
      hero: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: isDark
                          ? AppTextStyles.darkTitle3()
                          : AppTextStyles.lightTitle3(),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.text(
                          fontSize: 13,
                          color: secondaryLabelColor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusPill(
                      status: status!,
                      color: statusColor,
                      label: status,
                    ),
                    if (secondaryStatus != null) ...[
                      const SizedBox(height: 5),
                      StatusPill(
                        status: secondaryStatus!,
                        color: secondaryStatusColor,
                        label: secondaryStatus,
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
          if (amount != null) ...[
            const SizedBox(height: 16),
            if (amountLabel != null)
              Text(
                amountLabel!,
                style: AppTextStyles.overline(Theme.of(context).brightness),
              ),
            const SizedBox(height: 2),
            Text(
              amount!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.money(
                Theme.of(context).brightness,
                size: 30,
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Equal tracks, not intrinsic widths. The set differs by
            // permission and by document state, so it has to wrap — but
            // wrapping chips sized to their own labels produced a ragged 2+2
            // that lined up on neither axis, on the most-used part of a
            // record. On a track they read as one control group.
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 8.0;
                // Two across on a phone, more as a detail pane widens.
                final columns = (constraints.maxWidth / 168).floor().clamp(
                  2,
                  4,
                );
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final action in actions)
                      SizedBox(width: width, child: action),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// One action in a [RecordHeader].
class RecordAction extends StatelessWidget {
  const RecordAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tint = destructive
        ? semanticInk(context, AppColors.error)
        : brandInkColor(context);

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: destructive
            ? AppColors.error.withValues(alpha: 0.10)
            : brandTonalColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: WindowClass.of(context).minTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 17, color: tint),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.text(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A filter that is currently narrowing a list, and the way to drop it.
///
/// Shown above the list rather than hidden behind the filter button: a list
/// that is quietly showing one ward's rows, with no visible sign of it,
/// is a list somebody will read as "we only have three invoices".
///
/// Tapping it clears the filter — the close icon says so, and the whole chip
/// is the target because a 15 px icon is not one.
class ActiveFilterChip extends StatelessWidget {
  const ActiveFilterChip({
    super.key,
    required this.label,
    required this.onClear,
    this.chipKey,
    this.icon = Icons.person_rounded,
  });

  final String label;
  final VoidCallback onClear;
  final Key? chipKey;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Material(
    color: brandTonalColor(context),
    borderRadius: BorderRadius.circular(BentoRadius.pill),
    child: InkWell(
      key: chipKey,
      onTap: onClear,
      borderRadius: BorderRadius.circular(BentoRadius.pill),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: brandInkColor(context)),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.text(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: brandInkColor(context),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.close_rounded, size: 15, color: brandInkColor(context)),
          ],
        ),
      ),
    ),
  );
}
