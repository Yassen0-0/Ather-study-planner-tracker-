import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../haptics/app_haptics.dart';
import '../l10n/formatting.dart';
import '../l10n/generated/app_localizations.dart';
import '../motion/springs.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'pressable.dart';
import 'reduced_motion.dart';

/// The date navigation at the top of the tasks screen: a short row of day
/// pills, centred on the day the list belongs to.
///
/// ## It replaced a seven-day strip that did not fit a phone
///
/// The strip before it showed the whole week at once. As a picker each of its
/// seven cells was a [Pressable] carrying the app's [kMinTarget] floor, so the
/// row demanded `7 x 48 = 336` however narrow the window was — it fitted only
/// from 368 up. A 360 phone, the commonest Android width there is, clipped it
/// by 8, and `layout_matrix_test.dart` had to exclude the tasks tab below 400
/// to stay green. Seven 48px targets cannot be laid in 288 and no arrangement
/// of them exists, so the fix could not be a spacing change: it had to be
/// fewer cells.
///
/// **So the count is measured, never assumed.** [_visibleDays] lays out the
/// selected day, then adds neighbours outward in pairs for as long as they
/// actually fit the width it was given. Three on a 320 phone, five on a tablet.
/// Nothing is ever scaled down to make it fit — a date the student cannot read
/// is worse than a date that is not on screen, and the one directly either side
/// of today is what a task list is actually navigated by.
///
/// ## Pairs, so the selected pill stays in the middle
///
/// Neighbours are added two at a time, one each side. An odd count is what puts
/// the selected day in the centre of a centred row, and the centre is where the
/// eye returns after every tap.
///
/// ## Today is a fixed landmark
///
/// Today's cell reads `اليوم` whether it is selected or not. The other cells
/// change every time the student moves a day; this one does not, so it is the
/// thing they navigate against. When it is off screen entirely the green edge
/// marker says which side it is on and goes back in one tap.
///
/// ## The drag is physical (SP-08)
///
/// A horizontal pull translates the row paint-only by a third of a cell per
/// cell of travel, rubber-banded square-law past the first cell. Release
/// commits by Kowalski rule — distance or velocity — and either outcome
/// returns on the settle spring carrying the finger's own velocity. The
/// constants and their reasoning sit on [DayPicker] itself; reduce-motion
/// skips the preview entirely and commits instantly.
class DayPicker extends StatefulWidget {
  const DayPicker({
    super.key,
    required this.today,
    required this.selectedDay,
    required this.completeDays,
    required this.onSelect,
  });

  /// The current date, from the injectable clock rather than `DateTime.now()`.
  final DateTime today;

  /// The day the screen is showing.
  final DateTime selectedDay;

  /// Dates (at day precision) on which the student finished everything they
  /// set themselves. Marked with a dot, not a fill: see [_Cell].
  final Set<DateTime> completeDays;

  final ValueChanged<DateTime> onSelect;

  /// The most days the row will ever show, however wide the window is.
  ///
  /// A week's worth. Past that the row stops being a navigation control and
  /// starts being the calendar this replaced.
  static const int maxCells = 7;

  /// ---- SP-08 drag physics (animation/06_motion_specs.md) ----
  ///
  /// The drag has two halves: a *visual* one, how far the row visibly
  /// translates while the finger travels, and a *decision* one, what makes a
  /// release commit to the adjacent day. They are deliberately decoupled —
  /// the student calibrates their swipe against finger travel, not against a
  /// squished preview of it, so both thresholds read raw gesture distance
  /// while only the preview is rubber-banded.

  /// How much of the finger's travel the row shows, inside the first cell.
  ///
  /// `dx = dragFraction × cellWidth` per cell of travel: a third of the way,
  /// which reads as weight without lag. Past that first cell the square-law
  /// rubber-band takes over and each further cell buys progressively less.
  static const double dragResistance = 0.35;

  /// Kowalski rule, distance half: raw finger travel in logical pixels past
  /// which a release commits to the adjacent day.
  static const double commitDistance = 45;

  /// Kowalski rule, velocity half, quoted in px/ms as specced. A release
  /// faster than this commits even from a short flick; [commitVelocityPxPerS]
  /// is the same number in the px/s Flutter hands us.
  static const double commitVelocity = 0.11;

  static const double commitVelocityPxPerS = commitVelocity * 1000;

  /// Shortest gesture that has a velocity at all.
  ///
  /// A down-move-up delivered inside one display frame has no dt: any velocity
  /// over a zero-length interval is tracker extrapolation noise, not a fling.
  /// Such gestures decide on distance alone.
  static const int minGestureMs = 16;

  /// Test handle for the paint-only drag transform (see [_DayPickerState]).
  static const Key dragOffsetKey = Key('day-picker-drag-transform');

  static const double _cellPadding = AppSpacing.md;

  static const double _gap = AppSpacing.xxs;

  static String _name(L l, int weekday) => switch (weekday) {
    DateTime.saturday => l.weekdaySaturday,
    DateTime.sunday => l.weekdaySunday,
    DateTime.monday => l.weekdayMonday,
    DateTime.tuesday => l.weekdayTuesday,
    DateTime.wednesday => l.weekdayWednesday,
    DateTime.thursday => l.weekdayThursday,
    _ => l.weekdayFriday,
  };

  /// What one cell says.
  ///
  /// Today is always [L.todayLabel]. Every other day is its short name and the
  /// day of the month, and the number goes through [iso] like every other number
  /// in the app — Western digits in both locales (PROJECT.md §3.16), wrapped in
  /// the isolate pair so the bidi algorithm cannot pull it out of the Arabic
  /// beside it.
  static String label(L l, DateTime date, DateTime today) => date == today
      ? l.todayLabel
      : '${_name(l, date.weekday)} ${iso(date.day)}';

  @override
  State<DayPicker> createState() => _DayPickerState();
}

class _DayPickerState extends State<DayPicker>
    with SingleTickerProviderStateMixin {
  /// Live horizontal drag, in logical *start-to-end* pixels: positive is a drag
  /// toward the end of the row, whichever physical direction that is.
  ///
  /// The one thing this widget inherited wholesale from the strip it replaced.
  /// Direction is accumulated logically and multiplied by a single `sign`
  /// exactly once, at the point it becomes a decision — the design prototype
  /// flipped it per direction at three separate call sites and broke under LTR.
  double _drag = 0;

  /// The row's visual translation, in logical pixels, on its own ticker.
  ///
  /// The kit's own [SpringController]. The one thing that once justified a
  /// private unbounded controller here — SP-08 seeds the release spring *with
  /// the finger's velocity* — is now [SpringController.springWithVelocity],
  /// so the picker runs on the register like everyone else: same settle
  /// spring, grabs interrupt via [SpringController.jump], reduce-motion jumps
  /// home, and the finger genuinely carries through.
  late final SpringController _offset = SpringController(vsync: this);

  /// When this gesture began, on the frame clock.
  ///
  /// Not a [Stopwatch]: wall-clock time does not advance under the test
  /// framework's fake clock, and the frame clock is exactly the clock both
  /// real gestures and pumped tests share. A gesture that never spanned a
  /// frame has no dt and therefore no trustworthy velocity.
  Duration? _dragStartedAt;

  /// Which side of the commit band the last update sat on — `-1`, `0`, `+1`.
  ///
  /// The threshold haptic fires on *crossing*, once per entry into a side of
  /// the band. Holding past the line must not re-trigger; only leaving and
  /// crossing again may.
  int _crossed = 0;

  /// Cached per build from the same measurement the layout uses.
  double _sign = 1;
  double _cellExtent = 0;

  void _pick(DateTime date) {
    AppHaptics.select();
    widget.onSelect(date);
  }

  void _step(int days) => _pick(widget.selectedDay.add(Duration(days: days)));

  /// SP-08 forward map: raw logical drag → visible translation, both in px.
  ///
  /// Inside the first cell of travel the row tracks [DayPicker.dragResistance]
  /// linearly. Past it, square-law rubber-band: each further unit of visible
  /// displacement costs the *square* in finger travel, so resistance grows the
  /// further the student pulls. Written forward that is a square root; the
  /// square is its inverse, [_rawFor] — which is where the spec's
  /// `sign(x)·x²` lives verbatim. Continuous at the boundary by construction:
  /// both branches return exactly `dragResistance × cellWidth` at one cell.
  static double _translateFor(double raw, double cellWidth) {
    final u = raw / cellWidth;
    if (u.abs() <= 1) return raw * DayPicker.dragResistance;
    final cap = cellWidth * DayPicker.dragResistance;
    final s = math.sqrt(1 + (u.abs() - 1));
    return cap * s * (u.isNegative ? -1.0 : 1.0);
  }

  /// Inverse of [_translateFor]: how much raw drag a parked translation stands
  /// for, so grabbing a row mid-spring folds its leftover motion back into
  /// gesture space instead of snapping it under the finger.
  static double _rawFor(double translate, double cellWidth) {
    final cap = cellWidth * DayPicker.dragResistance;
    final s = translate.abs() / cap;
    if (s <= 1) return translate / DayPicker.dragResistance;
    return cellWidth * s * s * (translate.isNegative ? -1.0 : 1.0);
  }

  /// Which side of the commit band [raw] sits on: `-1`, `0`, or `+1`.
  static int _band(double raw) =>
      raw > DayPicker.commitDistance
      ? 1
      : raw < -DayPicker.commitDistance
      ? -1
      : 0;

  void _onDragStart(DragStartDetails d) {
    // Interruptible by grab, as springs promise: stop the return mid-flight
    // and re-enter gesture space from wherever the row actually is. `jump` to
    // the current value is the kit's stop-in-place.
    _offset.jump(_offset.value);
    _drag = _rawFor(_offset.value, _cellExtent);
    _crossed = _band(_drag);
    _dragStartedAt = SchedulerBinding.instance.currentSystemFrameTimeStamp;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _drag += d.delta.dx * _sign;

    final band = _band(_drag);
    if (band != 0 && band != _crossed) AppHaptics.light();
    _crossed = band;

    // Reduce-motion keeps the row put: no preview to follow. The release
    // below still commits, instantly, on the very same thresholds.
    if (prefersReducedMotion(context)) return;
    _offset.jump(_translateFor(_drag, _cellExtent));
  }

  void _onDragEnd(DragEndDetails d) {
    final startedAt = _dragStartedAt;
    _dragStartedAt = null;
    final dt = startedAt == null
        ? Duration.zero
        : SchedulerBinding.instance.currentSystemFrameTimeStamp - startedAt;

    // Kowalski rule. Velocity comes from the platform tracker already in px/s,
    // mirrored into logical direction; it counts only when the gesture lasted
    // long enough to have one ([DayPicker.minGestureMs]).
    final v = dt.inMilliseconds >= DayPicker.minGestureMs
        ? d.velocity.pixelsPerSecond.dx * _sign
        : 0.0;

    // A drag toward the end of the row pulls the *earlier* day into view,
    // exactly as swiping a photo leftwards brings the next one in.
    if (_drag > DayPicker.commitDistance || v > DayPicker.commitVelocityPxPerS) {
      _step(-1);
    } else if (_drag < -DayPicker.commitDistance ||
        v < -DayPicker.commitVelocityPxPerS) {
      _step(1);
    }
    _drag = 0;
    _crossed = 0;

    if (prefersReducedMotion(context)) {
      // Nothing ever moved; nothing needs to move back.
      _offset.jump(0);
      return;
    }
    // Both outcomes — commit and spring-back — go home on the settle spring,
    // seeded with whatever the finger was doing at the moment of release.
    _offset.springWithVelocity(0, velocity: v);
  }

  void _onDragCancel() {
    _dragStartedAt = null;
    _drag = 0;
    _crossed = 0;
    if (prefersReducedMotion(context)) {
      _offset.jump(0);
    } else {
      // A cancellation carries no momentum of its own: home from wherever the
      // row stands, from rest — identical to a release with no velocity.
      _offset.springWithVelocity(0, velocity: 0);
    }
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  /// The width a cell holding [text] will actually occupy.
  ///
  /// Floored at [kMinTarget], and [_Cell] applies the same floor to the box it
  /// builds. The two have to agree exactly: a measurement that says 48 against
  /// a cell that lays out at 41 is how a row that "fits" overflows by seven
  /// pixels per short label.
  double _cellWidth(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    return (painter.width + DayPicker._cellPadding * 2).clamp(
      kMinTarget,
      double.infinity,
    );
  }

  /// The days that fit in [width], the selected day in the middle.
  ///
  /// Greedy and symmetric: the selected day is placed, then one day either side
  /// is measured as a *pair* and kept only if the pair fits whole. Half a pair
  /// would put the selected pill off centre, which is the one thing the layout
  /// promises.
  ///
  /// A pair costs two cells and two gaps, because `n` cells carry `n - 1` gaps
  /// between them and each pair takes the count up by two. The layout below
  /// must therefore separate cells rather than pad them: padding every interior
  /// cell on both sides bills three gaps for a five-cell row's two, and the
  /// arithmetic here would be under by exactly the difference.
  List<DateTime> _visibleDays(double width, TextStyle style, TextScaler scaler) {
    final l = L.of(context);
    final selected = widget.selectedDay;

    double used = _cellWidth(
      DayPicker.label(l, selected, widget.today),
      style,
      scaler,
    );
    var days = <DateTime>[selected];

    for (var step = 1; days.length + 2 <= DayPicker.maxCells; step++) {
      final before = selected.subtract(Duration(days: step));
      final after = selected.add(Duration(days: step));
      final pair =
          _cellWidth(DayPicker.label(l, before, widget.today), style, scaler) +
          _cellWidth(DayPicker.label(l, after, widget.today), style, scaler) +
          DayPicker._gap * 2;

      if (used + pair > width) break;
      used += pair;
      days = <DateTime>[before, ...days, after];
    }

    return days;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final style = context.text.dayLabel;

    // The student's own text size, handed to the measurement rather than
    // assumed away. A picker measured at 1.0 and rendered at 1.3 is a picker
    // that overflows for exactly the students who most need it not to.
    final scaler = MediaQuery.textScalerOf(context);

    // The one place physical direction is computed.
    final sign = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final days = _visibleDays(constraints.maxWidth, style, scaler);

        // The drag physics normalise against the selected cell's own width,
        // measured by exactly the arithmetic the layout uses, so the preview
        // can never disagree with what is on screen.
        _sign = sign;
        _cellExtent = _cellWidth(
          DayPicker.label(l, widget.selectedDay, widget.today),
          style,
          scaler,
        );

        // Which side today is on, asked as a date comparison rather than
        // derived from the direction of travel. Those are opposite edges, and
        // reasoning about a mirror is what put this arrow backwards once
        // already: dates grow toward the end of the row, so a today that is
        // earlier than everything on screen lies toward the start.
        final DayEdge? home = widget.today.isBefore(days.first)
            ? DayEdge.start
            : widget.today.isAfter(days.last)
            ? DayEdge.end
            : null;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Explicitly a horizontal recogniser, so a drag that is mostly
          // vertical goes to the screen's scroll view instead of being eaten
          // here, and a long press still reaches the task list below.
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onHorizontalDragCancel: _onDragCancel,
          dragStartBehavior: DragStartBehavior.down,
          child: AnimatedBuilder(
            animation: _offset.view,
            // The row is built once and cached: the controller repaints it
            // through Transform.translate alone — paint-only by construction,
            // zero relayout per frame of drag or spring.
            child: SizedBox(
              height: AppSizes.dayPicker,
              child: Stack(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    // `n - 1` gaps for `n` cells, which is what _visibleDays
                    // budgeted. `spacing` puts them between the children and
                    // never outside the first or last, so the row still centres
                    // on its content rather than on its own padding.
                    spacing: DayPicker._gap,
                    children: <Widget>[
                      for (final date in days)
                        _Cell(
                          // Keyed by the date, not by position. The window
                          // recentres on every tap, so position identity would
                          // animate the fill across cells that are not the ones
                          // that changed.
                          key: ValueKey<DateTime>(date),
                          label: DayPicker.label(l, date, widget.today),
                          semanticLabel: dateLabel(date),
                          selected: date == widget.selectedDay,
                          complete: widget.completeDays.contains(date),
                          onTap: () => _pick(date),
                        ),
                    ],
                  ),
                  if (home != null)
                    _ReturnEdge(
                      key: returnGlowKey,
                      edge: home,
                      onTap: () => _pick(widget.today),
                    ),
                ],
              ),
            ),
            builder: (context, row) => Transform.translate(
              key: DayPicker.dragOffsetKey,
              offset: Offset(_offset.value * sign, 0),
              child: row,
            ),
          ),
        );
      },
    );
  }
}

/// Which edge of the row today lies past.
enum DayEdge { start, end }

/// Identifies the "come back to today" marker, for tests: it is a bare
/// coloured edge with no text and no icon, so there is nothing else to find it
/// by. The `glow` in the name is historical -- the gradient it identified was
/// replaced by a solid 2px edge (§3.10), and renaming the key would break the
/// tests that find it.
const Key returnGlowKey = Key('day-picker-return-glow');

/// One day.
///
/// The whole 48px cell is the target, so there is no [Pressable.minTarget] here
/// and no hit box larger than the artwork. That is the difference that let the
/// count become adaptive: a floor applied per cell to a fixed seven of them is
/// what made the old strip demand 336px it did not always have.
class _Cell extends StatelessWidget {
  const _Cell({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.complete,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final bool selected;
  final bool complete;
  final VoidCallback onTap;

  /// The dot that says every task set for this day is done.
  ///
  /// A dot rather than the filled disc the strip used, and the reason is the
  /// same one that kept today off a filled cell there: the pill behind it is
  /// already a fill, and two fills in one cell are two claims the eye has to
  /// separate. 4px is enough to be seen and too small to be read as a second
  /// selection.
  static const double _dot = 4;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = prefersReducedMotion(context);
    final duration = reduced ? Duration.zero : AppMotion.micro;

    return Pressable(
      onTap: onTap,
      // The label alone reads as "اليوم" or "ثلاثاء 14"; the full date is what
      // a student actually needs to hear before picking a day.
      semanticLabel: semanticLabel,
      child: ConstrainedBox(
        // The square a finger has to find, in both axes: the height is the row's
        // own, and the floor on the width is what stops a short label like
        // "اليوم" from drawing a 41px target. `_cellWidth` applies the same
        // floor when it measures — if these two ever disagree the row silently
        // overflows by the difference, once per short label.
        constraints: const BoxConstraints(
          minWidth: kMinTarget,
          minHeight: AppSizes.dayPicker,
          maxHeight: AppSizes.dayPicker,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedContainer(
              duration: duration,
              curve: AppMotion.standard,
              padding: const EdgeInsets.symmetric(
                horizontal: DayPicker._cellPadding,
                vertical: AppSpacing.textGap,
              ),
              decoration: BoxDecoration(
                // The selected day is the app's one accent, filled. Everything
                // else is the page: no tint, no border, no card.
                color: selected ? c.accent : const Color(0x00000000),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: AnimatedDefaultTextStyle(
                duration: duration,
                curve: AppMotion.standard,
                style: context.text.dayLabel.copyWith(
                  color: selected ? c.onAccent : c.weekLabel,
                ),
                child: Text(label, maxLines: 1, softWrap: false),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            SizedBox(
              height: _dot,
              child: complete
                  ? Container(
                      width: _dot,
                      height: _dot,
                      // Always the accent: the dot sits *below* the pill, on
                      // the page rather than on the fill, so the selected cell
                      // needs no separate colour for it.
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// The "today is not on screen" cue: a solid 2px edge in `right` on the side
/// today actually lies past, tappable to jump straight back.
///
/// An edge, not a fade. §3.10 bans gradients outright and sanctions exactly
/// one exception (the tab bar's glass, §3.19); a direction sign does not need
/// one, because the hard edge *is* the signpost -- it says "off this way"
/// without borrowing decoration to say it.
///
/// Green rather than the accent on purpose. The accent means *selected* in the
/// row directly beside it — a blue edge here would read as an eighth day to
/// turn on. This is a direction sign, and it borrows the one colour the student
/// already reads as "this way is right".
///
/// It appears only while today is off screen. When today is one of the cells
/// there is nothing to signpost, and a marker for something already visible is
/// a marker that has to be ignored.
class _ReturnEdge extends StatelessWidget {
  const _ReturnEdge({super.key, required this.edge, required this.onTap});

  final DayEdge edge;
  final VoidCallback onTap;

  /// The tap target: [kMinTarget], like every other control -- it was 18,
  /// which is a strip a thumb has to aim for. The visible mark inside it is
  /// still only [_edge], so nothing on screen changes. The trade: the outer
  /// part of the cell at that edge -- the visible day nearest to today --
  /// now returns to today rather than picking that day. Both move toward
  /// today, and the rest of that cell still picks it.
  static const double _width = kMinTarget;

  /// The approved replacement for the gradient this cue used to draw: §3.10
  /// bans gradients and sanctions one exception (the tab bar's glass), so the
  /// signpost is the hard edge itself. A drawn line weight, like the icons'
  /// 1.9-2.2 strokes -- artwork geometry, not a spacing-ladder value.
  static const double _edge = 2;

  @override
  Widget build(BuildContext context) {
    final green = context.colors.right;
    final atStart = edge == DayEdge.start;

    return PositionedDirectional(
      top: 0,
      bottom: 0,
      start: atStart ? 0 : null,
      end: atStart ? null : 0,
      width: _width,
      // The line carries no text, so without a label a screen reader finds
      // an unnamed tap target at the row's edge.
      child: Semantics(
        button: true,
        label: L.of(context).dayPickerBackToToday,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Align(
            alignment: atStart
                ? AlignmentDirectional.centerStart
                : AlignmentDirectional.centerEnd,
            child: Container(width: _edge, color: green),
          ),
        ),
      ),
    );
  }
}
