import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'list_entrance.dart';
import 'reduced_motion.dart';

/// A list whose rows enter and leave instead of appearing and vanishing.
///
/// Why the row outlives its data: the collapse has to be *rendered*, so the
/// widget must stay in the tree for 200ms after the record is gone. That is
/// what [AnimatedList] does, and why this uses it rather than a bare
/// `AnimatedSize`.
///
/// It is driven by the data, not by a delete button: nothing in this app
/// deletes a row from inside the list -- a student opens the chapter, deletes
/// it there and pops back. The removal therefore arrives as a shorter list on
/// the next build, and this widget is what turns that into a row collapsing and
/// the rows below settling into the gap.
///
/// **This is the one place in Ather where height animates.** PROJECT.md §3.20.
/// Everything else moves transform and opacity only.
class CollapsingList<T> extends StatefulWidget {
  const CollapsingList({
    super.key,
    required this.items,
    required this.idOf,
    required this.itemBuilder,
    this.gap = AppSpacing.listGap,
  });

  final List<T> items;

  /// Stable identity, so a rename is not read as a delete plus an insert.
  final Object Function(T item) idOf;

  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Sits *inside* the collapse, so a leaving row takes its gap with it --
  /// otherwise a 10px ghost is left behind and the rows below stop short of
  /// where they belong.
  final double gap;

  @override
  State<CollapsingList<T>> createState() => _CollapsingListState<T>();
}

class _CollapsingListState<T> extends State<CollapsingList<T>> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late List<T> _rows = List<T>.of(widget.items);

  /// After the first build every insert is news, so it enters on its own rather
  /// than as slot `i` of a staggered arrival.
  bool _settled = false;

  @override
  void didUpdateWidget(CollapsingList<T> old) {
    super.didUpdateWidget(old);
    _settled = true;

    final incoming = widget.items;
    final listState = _listKey.currentState;

    // No mounted list to animate against -- adopt the new data and let the
    // next build construct one. Mutating `_rows` without telling AnimatedList
    // is what desyncs its internal item count from ours.
    if (listState == null) {
      _rows = List<T>.of(incoming);
      return;
    }

    final incomingIds = incoming.map(widget.idOf).toSet();
    final duration = prefersReducedMotion(context)
        ? Duration.zero
        : AppMotion.exit;

    // Removals first, back to front, so the indices stay valid as we go.
    for (var i = _rows.length - 1; i >= 0; i--) {
      if (incomingIds.contains(widget.idOf(_rows[i]))) continue;
      final leaving = _rows.removeAt(i);
      listState.removeItem(
        i,
        (context, animation) => _LeavingRow(
          animation: animation,
          gap: widget.gap,
          child: widget.itemBuilder(context, leaving),
        ),
        duration: duration,
      );
    }

    // Then insertions, front to back, at the position the data gives them.
    // Zero duration: the row's own ListEntrance is what animates it in, so the
    // list does not also animate the slot opening underneath it.
    final present = _rows.map(widget.idOf).toSet();
    for (var i = 0; i < incoming.length; i++) {
      if (present.contains(widget.idOf(incoming[i]))) continue;
      _rows.insert(i, incoming[i]);
      listState.insertItem(i, duration: Duration.zero);
    }

    // `_rows` and `incoming` now hold the same identities. Adopt `incoming`
    // wholesale so rows whose *contents* changed -- a rename, a new percentage
    // -- carry the new data without animating anything.
    assert(
      _rows.length == incoming.length,
      'CollapsingList diff left ${_rows.length} rows for ${incoming.length} '
      'items; idOf is probably not stable',
    );
    _rows = List<T>.of(incoming);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      // One child of the screen's own ListView; it must not scroll itself.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      initialItemCount: _rows.length,
      itemBuilder: (context, i, animation) {
        if (i >= _rows.length) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(bottom: widget.gap),
          child: ListEntrance(
            index: _settled ? 0 : i,
            // The list already has a stable identity for every row -- it is
            // what the insert/remove diff above is built on -- so scrolling a
            // chapter's lessons past cannot replay their arrival.
            id: widget.idOf(_rows[i]),
            child: widget.itemBuilder(context, _rows[i]),
          ),
        );
      },
    );
  }
}

class _LeavingRow extends StatelessWidget {
  const _LeavingRow({
    required this.animation,
    required this.gap,
    required this.child,
  });

  final Animation<double> animation;
  final double gap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.standard,
    );

    // Collapse and fade on the same clock.
    return SizeTransition(
      sizeFactor: curved,
      // Top-anchored: the row shrinks into its own top edge, so the rows below
      // rise to meet it instead of the whole block sliding.
      alignment: const Alignment(0, -1),
      child: FadeTransition(
        opacity: curved,
        child: Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: child,
        ),
      ),
    );
  }
}
