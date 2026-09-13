import 'package:flutter/material.dart';

import '../core/window_class.dart';
import 'app_bento.dart';
import 'app_fonts.dart';
import 'app_surfaces.dart';
import 'app_theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the adaptive layer of the kit
///
/// Everything here answers the same question: what changes when the window is
/// wider than a phone. The answer is never "the same thing, stretched" — a
/// phone layout on a tablet is the failure mode, not the fallback.
/// ─────────────────────────────────────────────────────────────────────────────

/// One destination in the shell's navigation.
///
/// Deliberately a plain value: the shell builds these from the server's menu,
/// so nothing about them is known at compile time.
class ShellNavItem {
  const ShellNavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.children = const [],
  });

  /// The page key — `QUEUE`, `INPATIENT`. Stable across renames.
  final String id;

  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// Nested destinations, shown indented in an extended rail and inside the
  /// parent's row in the More sheet. Payment Modes sits under Payments.
  final List<ShellNavItem> children;

  bool get hasChildren => children.isNotEmpty;

  /// This item and everything under it, in display order.
  Iterable<ShellNavItem> get flattened sync* {
    yield this;
    for (final child in children) {
      yield* child.flattened;
    }
  }
}

/// The vertical navigation a window wider than a phone gets.
///
/// Narrow (icons only) at medium width, extended (icons, labels and the
/// company's own identity) from expanded upward. A bottom bar is never shipped
/// here: it would put the app's primary navigation as far from the pointer as
/// the window allows, and on a mounted screen, below the reach of a short
/// person standing at it.
class ShellRail extends StatelessWidget {
  const ShellRail({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
    this.extended = false,
    this.header,
    this.itemKey,
  });

  final List<ShellNavItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final bool extended;

  /// The company mark and name, shown above the destinations in an extended
  /// rail — where there is room for the workspace to say whose it is.
  final Widget? header;

  /// Widget key per destination id, so a flow can drive the rail by name.
  final Key Function(String id)? itemKey;

  static const double narrowWidth = 84;
  static const double extendedWidth = 248;

  @override
  Widget build(BuildContext context) {
    final window = WindowClass.of(context);

    return Container(
      width: extended ? extendedWidth : narrowWidth,
      decoration: BoxDecoration(
        color: surfaceColor(context),
        border: Border(right: BorderSide(color: hairlineColor(context))),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(extended ? 16 : 8, 16, 16, 8),
                child: header,
              ),
              Hairline(indent: extended ? 16 : 8),
            ],
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  for (final item in items)
                    _RailGroup(
                      item: item,
                      selectedId: selectedId,
                      onSelected: onSelected,
                      extended: extended,
                      minTarget: window.minTarget,
                      itemKey: itemKey,
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

class _RailGroup extends StatelessWidget {
  const _RailGroup({
    required this.item,
    required this.selectedId,
    required this.onSelected,
    required this.extended,
    required this.minTarget,
    this.itemKey,
  });

  final ShellNavItem item;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final bool extended;
  final double minTarget;
  final Key Function(String id)? itemKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RailItem(
          key: itemKey?.call(item.id),
          item: item,
          selected: selectedId == item.id,
          onTap: () => onSelected(item.id),
          extended: extended,
          minTarget: minTarget,
        ),
        // Children are shown inline rather than behind a disclosure: there are
        // never more than a couple, and a rail that hides half its destinations
        // behind a tap is a rail that costs more than the bar it replaced.
        for (final child in item.children)
          _RailItem(
            key: itemKey?.call(child.id),
            item: child,
            selected: selectedId == child.id,
            onTap: () => onSelected(child.id),
            extended: extended,
            minTarget: minTarget,
            indented: true,
          ),
      ],
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    required this.extended,
    required this.minTarget,
    this.indented = false,
  });

  final ShellNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool extended;
  final double minTarget;
  final bool indented;

  @override
  Widget build(BuildContext context) {
    final tint = brandInkColor(context);
    final idle = indented ? tertiaryLabelColor(context) : secondaryLabelColor(context);
    final icon = Icon(
      selected ? item.activeIcon : item.icon,
      size: indented ? 20 : 22,
      color: selected ? tint : idle,
    );

    final label = Text(
      item.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppFonts.text(
        fontSize: extended ? 14 : 10,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? tint : idle,
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Padding(
        padding: EdgeInsets.fromLTRB(extended ? 10 : 6, 2, 10, 2),
        child: Material(
          color: selected ? brandTonalColor(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minTarget),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    extended ? (indented ? 28 : 12) : 4,
                    8,
                    12,
                    8,
                  ),
                  child: extended
                      ? Row(
                          children: [
                            icon,
                            const SizedBox(width: 12),
                            Expanded(child: label),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [icon, const SizedBox(height: 4), label],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An `IndexedStack` that builds a child the first time it is shown.
///
/// The shell hosts eleven destinations. A plain `IndexedStack` builds all of
/// them on the first frame, so every list controller fetches its first page
/// before the user has chosen a tab — eleven requests to show one screen.
///
/// Once built, a child stays built: switching tabs keeps scroll position and
/// does not refetch, which is the reason the stack was chosen over a
/// `PageView` in the first place.
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.placeholder = const SizedBox.shrink(),
  });

  final int index;
  final List<Widget> children;

  /// Stands in for a child that has never been shown.
  final Widget placeholder;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late final Set<int> _built = {widget.index};

  @override
  void didUpdateWidget(LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _built.add(widget.index);
    // The destination list itself can change — a permission refresh removes a
    // tab — so an index that no longer exists must not be remembered.
    _built.removeWhere((i) => i >= widget.children.length);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return widget.placeholder;
    final index = widget.index.clamp(0, widget.children.length - 1);
    _built.add(index);

    return IndexedStack(
      index: index,
      sizing: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _built.contains(i) ? widget.children[i] : widget.placeholder,
      ],
    );
  }
}

/// A list beside the record it opens, once there is room for both.
///
/// Below [WindowClass.expanded] the detail is a pushed screen and this renders
/// the list alone; at expanded and above the two sit side by side and choosing
/// a row replaces the pane rather than navigating. The same list widget and the
/// same detail widget serve both, so a module is not written twice.
class ListDetailScaffold extends StatelessWidget {
  const ListDetailScaffold({
    super.key,
    required this.list,
    required this.detailBuilder,
    this.selectedId,
    this.placeholder,
    this.listPaneKey,
    this.detailPaneKey,
  });

  final Widget list;

  /// Builds the pane for a chosen record. Never called on a narrow window.
  final Widget Function(BuildContext context, String id) detailBuilder;

  final String? selectedId;

  /// What fills the detail pane before anything is chosen. An empty half-screen
  /// with nothing in it reads as a rendering failure.
  final Widget? placeholder;

  final Key? listPaneKey;
  final Key? detailPaneKey;

  @override
  Widget build(BuildContext context) {
    final window = WindowClass.of(context);
    if (!window.isTwoPane) return KeyedSubtree(key: listPaneKey, child: list);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: window.listPaneWidth,
          child: KeyedSubtree(key: listPaneKey, child: list),
        ),
        VerticalDivider(width: 1, thickness: 1, color: hairlineColor(context)),
        Expanded(
          child: KeyedSubtree(
            key: detailPaneKey,
            child: selectedId == null
                ? (placeholder ??
                    const EmptyState(
                      icon: Icons.touch_app_outlined,
                      title: 'Nothing selected',
                      message: 'Choose a record on the left to see it here.',
                    ))
                : detailBuilder(context, selectedId!),
          ),
        ),
      ],
    );
  }
}

/// A form with its summary beside it on a wide window, and beneath it on a
/// narrow one.
///
/// The summary of an admission — its bed and its ward — is what the person
/// filling the form
/// is watching change. On a phone it follows the line items; on a tablet it
/// stays in view while they type.
class SupportingPaneScaffold extends StatelessWidget {
  const SupportingPaneScaffold({
    super.key,
    required this.primary,
    required this.supporting,
    this.supportingWidth = 320,
  });

  final Widget primary;
  final Widget supporting;
  final double supportingWidth;

  @override
  Widget build(BuildContext context) {
    final window = WindowClass.of(context);
    if (!window.isTwoPane) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [primary, supporting],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: primary),
        const SizedBox(width: BentoSpace.section),
        SizedBox(width: supportingWidth, child: supporting),
      ],
    );
  }
}

/// Lays fields out in one column on a phone and two on a wide window.
///
/// Pairs are kept together on the same row, so a related pair — a date and its
/// due date, a quantity and its unit — never splits across the fold.
class TwoColumn extends StatelessWidget {
  const TwoColumn({
    super.key,
    required this.children,
    this.spacing = BentoSpace.action,
    this.runSpacing = BentoSpace.action,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    final columns = WindowClass.of(context).formColumns;
    if (columns == 1 || children.length < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: runSpacing),
            children[i],
          ],
        ],
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final left = children[i];
      final right = i + 1 < children.length ? children[i + 1] : null;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            SizedBox(width: spacing),
            // An odd last field keeps its column rather than stretching to the
            // full width, so the grid stays a grid.
            Expanded(child: right ?? const SizedBox.shrink()),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: runSpacing),
          rows[i],
        ],
      ],
    );
  }
}
