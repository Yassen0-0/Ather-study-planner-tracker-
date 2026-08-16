import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../l10n/formatting.dart';
import '../l10n/generated/app_localizations.dart';
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
/// glow says which side it is on and goes back in one tap.
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

  /// Horizontal breathing room inside a pill, each side.
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

class _DayPickerState extends State<DayPicker> {
  /// Live horizontal drag, in logical *start-to-end* pixels: positive is a drag
  /// toward the end of the row, whichever physical direction that is.
  ///
  /// The one thing this widget inherited wholesale from the strip it replaced.
  /// Direction is accumulated logically and multiplied by a single `sign`
  /// exactly once, at the point it becomes a decision — the design prototype
  /// flipped it per direction at three separate call sites and broke under LTR.
  double _drag = 0;

  /// How far a drag has to travel before it commits to the next day.
  static const double _threshold = 45;

  void _step(int days) {
    widget.onSelect(widget.selectedDay.add(Duration(days: days)));
  }

  void _onDragEnd() {
    // A drag toward the end of the row pulls the *earlier* day into view,
    // exactly as swiping a photo leftwards brings the next one in.
    if (_drag > _threshold) {
      _step(-1);
    } else if (_drag < -_threshold) {
      _step(1);
    }
    _drag = 0;
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
          onHorizontalDragUpdate: (d) => _drag += d.delta.dx * sign,
          onHorizontalDragEnd: (_) => _onDragEnd(),
          onHorizontalDragCancel: () => _drag = 0,
          dragStartBehavior: DragStartBehavior.down,
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
                        onTap: () => widget.onSelect(date),
                      ),
                  ],
                ),
                if (home != null)
                  _ReturnGlow(
                    key: returnGlowKey,
                    edge: home,
                    onTap: () => widget.onSelect(widget.today),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Which edge of the row today lies past.
enum DayEdge { start, end }

/// Identifies the "come back to today" glow, for tests: it is a gradient with
/// no text and no icon, so there is nothing else to find it by.
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

/// The "today is not on screen" cue: a green gradient bleeding in from the edge
/// today actually lies past, tappable to jump straight back.
///
/// Green rather than the accent on purpose. The accent means *selected* in the
/// row directly beside it — a blue edge here would read as an eighth day to
/// turn on. This is a direction sign, and it borrows the one colour the student
/// already reads as "this way is right".
///
/// It appears only while today is off screen. When today is one of the cells
/// there is nothing to signpost, and a marker for something already visible is
/// a marker that has to be ignored.
class _ReturnGlow extends StatelessWidget {
  const _ReturnGlow({super.key, required this.edge, required this.onTap});

  final DayEdge edge;
  final VoidCallback onTap;

  /// Narrow enough to sit beside a pill rather than over its text. The strip's
  /// was 34 and overlaid a whole day cell, which took that cell's taps.
  static const double _width = 18;

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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: atStart
                  ? AlignmentDirectional.centerStart
                  : AlignmentDirectional.centerEnd,
              end: atStart
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              colors: <Color>[
                green.withValues(alpha: 0.32),
                green.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
