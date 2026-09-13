import 'package:flutter/material.dart';

import '../core/window_class.dart';
import 'app_bento.dart';
import 'app_bento_adaptive.dart';
import 'app_bento_data.dart';
import 'app_surfaces.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the lookup-list layer of the kit
///
/// Some of this app's screens are not records with a lifecycle — they are
/// settings with rows. Payment modes, tax rates, platform pages, a master-data
/// library: a short list, an inline sheet to add or edit one, and no detail
/// screen at all, because there is nothing to say about a tax rate that does
/// not fit on its row.
///
/// Building each of those as a full module would be five files of near-identical
/// code per entity. This is the shape they share.
/// ─────────────────────────────────────────────────────────────────────────────

/// A list of lookup rows with one primary action.
///
/// Deliberately not [ListDetailScaffold]: there is no detail to put in a second
/// pane, and a wide window is better spent on a wider row than on an empty half.
class SimpleCrudScaffold extends StatelessWidget {
  const SimpleCrudScaffold({
    super.key,
    required this.screenKey,
    required this.itemCount,
    required this.itemBuilder,
    required this.phase,
    this.onSearch,
    this.searchHint = 'Search',
    this.searchKey,
    this.error,
    this.onRetry,
    this.onRefresh,
    this.empty,
    this.addLabel,
    this.onAdd,
    this.addKey,
    this.separator,
    this.onFilter,
    this.filterCount = 0,
    this.filterKey,
    this.onSort,
    this.sortKey,
    this.title,
    this.subtitle,
  });

  /// The screen's own heading, for one of these reached by a push rather than
  /// by a shell tab.
  ///
  /// Null for a tab, where the shell already draws the title and there is
  /// nothing to go back to. Payment modes is the one that needs it: it used to
  /// be a tab, and moving it behind a row on the Payments screen left it with
  /// no header at all — the first row rendered under the status bar, against
  /// the clock, with no way back but the system gesture.
  final String? title;
  final String? subtitle;

  final Key screenKey;
  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final ListPhase phase;

  /// Omitted for a list short enough to read at a glance. A search field over
  /// six payment modes is furniture.
  final ValueChanged<String>? onSearch;
  final String searchHint;
  final Key? searchKey;

  final String? error;
  final VoidCallback? onRetry;
  final Future<void> Function()? onRefresh;
  final Widget? empty;

  /// Null when this account may not add one — absent, not disabled.
  final String? addLabel;
  final VoidCallback? onAdd;
  final Key? addKey;

  final Widget? separator;

  /// Sorting and filtering, for a lookup list where the server honours them.
  ///
  /// Optional because most do not: `taxes` goes through the shared CRUD
  /// handler and supports both, while `library/:lib/list` discards `sortBy`
  /// and `filters` outright — a control there would be furniture that changes
  /// the request and not the answer.
  final VoidCallback? onFilter;
  final int filterCount;
  final Key? filterKey;
  final VoidCallback? onSort;
  final Key? sortKey;

  @override
  Widget build(BuildContext context) {
    final window = WindowClass.of(context);

    return Scaffold(
      key: screenKey,
      backgroundColor: Colors.transparent,
      appBar: title == null
          ? null
          : DetailHeader(title: title!, subtitle: subtitle),
      body: MaxWidthBody(
        child: BentoScreen(
          onRefresh: onRefresh,
          // Pushed, under a DetailHeader, with no tab bar anywhere beneath it
          // — the same as every other screen in this app.
          bottomClearance: false,
          slivers: [
            if (onSearch != null || onFilter != null || onSort != null)
              BentoSection(
                top: 4,
                bottom: BentoSpace.action,
                child: ListControls(
                  searchKey: searchKey,
                  searchHint: searchHint,
                  onSearch: onSearch ?? (_) {},
                  onFilter: onFilter,
                  filterCount: filterCount,
                  filterKey: filterKey,
                  onSort: onSort,
                  sortKey: sortKey,
                ),
              ),
            InfiniteList(
              phase: phase,
              itemCount: itemCount,
              itemBuilder: itemBuilder,
              error: error,
              onRetry: onRetry,
              empty: empty,
              separator: separator ?? const Hairline(indent: BentoSpace.listPad),
              skeletonRows: 4,
            ),
          ],
        ),
      ),
      bottomNavigationBar: onAdd == null || addLabel == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                // The shell's own layout already ends above the floating tab
                // bar; this needs the bar's margin, not its whole clearance.
                //
                // A pushed one has no tab bar under it at all — `title` is what
                // says so — so it takes plain page padding and stops floating
                // above a gap that nothing occupies.
                padding: EdgeInsets.fromLTRB(
                  BentoSpace.page,
                  BentoSpace.action,
                  BentoSpace.page,
                  window.navMode.isBottomBar && title == null
                      ? kFloatingTabBarMargin
                      : BentoSpace.page,
                ),
                child: PrimaryBar(
                  key: addKey,
                  label: addLabel!,
                  icon: Icons.add_rounded,
                  onPressed: onAdd,
                ),
              ),
            ),
    );
  }
}

/// One lookup row: what it is called, what it means, and the two flags a
/// lookup carries.
class LookupRow extends StatelessWidget {
  const LookupRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.isDefault = false,
    this.enabled = true,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final String? subtitle;

  /// The number this row is about — a tax rate, a term's days.
  final String? value;

  /// Marked rather than sorted-to-top in the row itself: a reader scanning for
  /// "which one is the default" should find a word, not have to infer position.
  final bool isDefault;

  /// A disabled lookup is shown, dimmed, rather than hidden: it is still on
  /// every document that used it, and hiding it makes those documents reference
  /// something nobody can find.
  final bool enabled;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: BentoRow(
        title: title,
        subtitle: subtitle,
        onTap: onTap,
        onLongPress: onLongPress,
        showChevron: onTap != null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null) ...[
              Text(
                value!,
                style: numeralStyle(context, size: 17),
              ),
              const SizedBox(width: 8),
            ],
            if (isDefault)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: StatusPill(
                  status: 'default',
                  label: 'Default',
                  compact: true,
                ),
              ),
            if (!enabled)
              const StatusPill(
                status: 'void',
                label: 'Off',
                compact: true,
              ),
          ],
        ),
      ),
    );
  }
}
