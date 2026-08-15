import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../l10n/formatting.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'icon_motion.dart';
import 'pressable.dart';
import 'reduced_motion.dart';

/// The seven-day strip at the top of the dashboard and the tasks screen.
///
/// The widget has **no opinion about what a filled circle means** — [activeDays]
/// is whatever the caller says it is. On the dashboard that is "an exam was
/// recorded", the only thing that proves anything; on the tasks screen it is
/// "every task the student set themselves that day is done". One widget, because
/// the shape is the same and two copies would drift.
///
/// ## It is flat content, not a control surface
///
/// The strip used to sit in a floating glass capsule. It does not any more: it
/// is a row of cells directly in the page's padding, with no background, no
/// border and no blur. The glass exception is spent on the tab bar and nowhere
/// else (PROJECT.md §3.19), and a header component does not need to be lifted
/// off a page it is already the top of.
///
/// ## Today is marked by an underline
///
/// Not a filled pill. A filled cell is what "this day is done" means three rows
/// down in the same component, and using the same fill for "this day is now"
/// made the two unreadable together. Today gets a dot above the letter, the
/// letter in the foreground colour, and a 1.5px rule under it — three quiet
/// marks instead of one loud one, none of which collide with the disc's states.
///
/// ## Weeks either side
///
/// The strip holds three weeks — previous, current, next — and drags
/// horizontally between them. Past that, [WeekStrip] refuses to let the student
/// get lost: whenever a week other than today's is on screen, a green edge glow
/// appears on **the side they would have to drag toward** to come back, and
/// tapping it returns in one move. Green, not the accent: it is wayfinding, not
/// brand.
class WeekStrip extends StatefulWidget {
  const WeekStrip({
    super.key,
    required this.today,
    required this.activeDays,
    this.selectedDay,
    this.onSelect,
  });

  /// The current date, from the injectable clock rather than `DateTime.now()`.
  final DateTime today;

  /// Dates (at day precision) that count as complete.
  final Set<DateTime> activeDays;

  /// The day the screen is currently showing, if it shows one day at a time.
  ///
  /// Null on the dashboard, which shows the week as a summary rather than as a
  /// picker — so its strip keeps exactly two states and renders unchanged.
  final DateTime? selectedDay;

  /// Null makes the strip inert: no press response, no selection.
  final ValueChanged<DateTime>? onSelect;

  /// The week runs Saturday-first, the Egyptian school week.
  static const List<int> _weekdayOrder = <int>[
    DateTime.saturday,
    DateTime.sunday,
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  ];

  static String _letter(L l, int weekday) => switch (weekday) {
    DateTime.saturday => l.weekdaySaturday,
    DateTime.sunday => l.weekdaySunday,
    DateTime.monday => l.weekdayMonday,
    DateTime.tuesday => l.weekdayTuesday,
    DateTime.wednesday => l.weekdayWednesday,
    DateTime.thursday => l.weekdayThursday,
    _ => l.weekdayFriday,
  };

  /// The Saturday that opened the week [today] falls in.
  static DateTime weekStart(DateTime today) {
    final date = DateTime(today.year, today.month, today.day);
    final offset = (date.weekday - DateTime.saturday + 7) % 7;
    return date.subtract(Duration(days: offset));
  }

  @override
  State<WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<WeekStrip> with TickerProviderStateMixin {
  /// Whole weeks away from today's. Negative is the past.
  int _week = 0;

  /// Live drag, in logical pixels of *start-to-end* travel: positive is a drag
  /// toward the end of the week strip, whichever physical direction that is.
  double _drag = 0;

  /// How far past a cell edge a release has to land before it commits.
  static const double _threshold = 45;

  /// Drives the leftover drag back to zero. The curve is applied in the
  /// listener rather than through a [CurvedAnimation], because the value being
  /// eased is a pixel offset this state owns, not an animation anyone else
  /// listens to.
  late final AnimationController _snap;

  /// The drag value the current snap animation started from.
  double _snapFrom = 0;

  /// Runs **only while the glow is on screen.** An always-running repeat is
  /// what made the hidden glow pulse a fully transparent shape forever, and a
  /// ticker nobody can see is a frame budget nobody gets back.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    // Built here rather than lazily at the field: a `late final` controller that
    // is never touched during the widget's life is still touched by dispose(),
    // which would construct one against a ticker provider that is on its way
    // out. A strip the student never drags is exactly that case.
    _snap = AnimationController(vsync: this, duration: AppMotion.weekSnap)
      ..addListener(() {
        final t = AppMotion.weekSnapCurve.transform(_snap.value);
        setState(() => _drag = _snapFrom * (1 - t));
      });
    _pulse = AnimationController(
      vsync: this,
      duration: AppMotion.weekGlowPulse,
    );
  }

  @override
  void dispose() {
    _snap.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _syncPulse() {
    final wanted = _week != 0 && !prefersReducedMotion(context);
    if (wanted && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!wanted && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  void _settle({required int week}) {
    _snapFrom = _drag;
    setState(() => _week = week);
    _snap
      ..value = 0
      ..forward();
    _syncPulse();
  }

  void _onDragUpdate(DragUpdateDetails details, double sign) {
    _snap.stop();
    setState(() => _drag += details.delta.dx * sign);
  }

  void _onDragEnd(double width) {
    // A drag toward the end of the strip pulls the *earlier* week into view,
    // exactly as swiping a photo leftwards brings the next one in.
    if (_drag > _threshold) {
      _drag -= width;
      _settle(week: _week - 1);
    } else if (_drag < -_threshold) {
      _drag += width;
      _settle(week: _week + 1);
    } else {
      _settle(week: _week);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final todayDate = DateTime(
      widget.today.year,
      widget.today.month,
      widget.today.day,
    );
    final anchor = WeekStrip.weekStart(widget.today);

    // The one place physical direction is computed. Everything below is
    // expressed as start/end travel and multiplied through this exactly once.
    final sign = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // A week either side, but only while the strip is actually moving. At
        // rest the neighbours are not merely invisible -- they are not in the
        // tree at all, so nothing off screen answers a hit test, a semantics
        // walk or a `find.text` looking for "the Saturday cell".
        final moving = _drag != 0;

        Widget week(int offset) => SizedBox(
          width: width,
          child: _Week(
            start: anchor.add(Duration(days: offset * 7)),
            todayDate: todayDate,
            activeDays: widget.activeDays,
            selectedDay: widget.selectedDay,
            onSelect: widget.onSelect,
            letter: (weekday) => WeekStrip._letter(l, weekday),
          ),
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Explicitly a horizontal recogniser, so a drag that is mostly
          // vertical goes to the scroll view instead of being eaten here.
          onHorizontalDragUpdate: (d) => _onDragUpdate(d, sign),
          onHorizontalDragEnd: (_) => _onDragEnd(width),
          onHorizontalDragCancel: () => _settle(week: _week),
          dragStartBehavior: DragStartBehavior.down,
          child: ClipRect(
            child: SizedBox(
              height: AppSizes.weekStrip,
              child: Stack(
                children: <Widget>[
                  if (!moving)
                    week(_week)
                  else
                    Transform.translate(
                      // The current week is the middle of the three, so the
                      // resting position is one week's travel to the start.
                      // `sign` converts the logical drag to physical pixels and
                      // is the only place direction is applied.
                      offset: Offset(-width + _drag * sign, 0),
                      child: OverflowBox(
                        // maxWidth has to be told explicitly: the parent's
                        // constraint is one week wide, and the Row would
                        // otherwise be squeezed into it.
                        maxWidth: width * 3,
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          children: <Widget>[
                            week(_week - 1),
                            week(_week),
                            week(_week + 1),
                          ],
                        ),
                      ),
                    ),
                  if (_week != 0)
                    _ReturnGlow(
                      key: returnGlowKey,
                      // Past weeks sit toward the start of the travel, so the
                      // way home is the start edge; future weeks, the end.
                      atStart: _week < 0,
                      pulse: _pulse,
                      onTap: () {
                        _drag = 0;
                        _settle(week: 0);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Seven cells. Stateless, and built once per week in the buffer — a week is
/// cheap enough that rebuilding three of them mid-drag costs less than the
/// bookkeeping to avoid it.
class _Week extends StatelessWidget {
  const _Week({
    required this.start,
    required this.todayDate,
    required this.activeDays,
    required this.selectedDay,
    required this.onSelect,
    required this.letter,
  });

  final DateTime start;
  final DateTime todayDate;
  final Set<DateTime> activeDays;
  final DateTime? selectedDay;
  final ValueChanged<DateTime>? onSelect;
  final String Function(int weekday) letter;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        for (var i = 0; i < WeekStrip._weekdayOrder.length; i++)
          _Day(
            letter: letter(WeekStrip._weekdayOrder[i]),
            date: start.add(Duration(days: i)),
            isToday: start.add(Duration(days: i)) == todayDate,
            done: activeDays.contains(start.add(Duration(days: i))),
            selected: selectedDay == start.add(Duration(days: i)),
            onTap: onSelect == null
                ? null
                : () => onSelect!(start.add(Duration(days: i))),
          ),
      ],
    );
  }
}

/// Identifies the "come back to today" glow, for tests: it is a gradient with
/// no text and no icon, so there is nothing else to find it by.
const Key returnGlowKey = Key('week-strip-return-glow');

/// The "you are not on this week" cue: a green gradient bleeding in from one
/// edge, pulsing, and tappable to jump straight back.
///
/// Green rather than the accent on purpose. The accent means *active* all over
/// this app — a blue edge here would read as another thing to turn on. This is
/// a direction sign, and it borrows the one colour the student already reads as
/// "this way is right".
class _ReturnGlow extends StatelessWidget {
  const _ReturnGlow({
    super.key,
    required this.atStart,
    required this.pulse,
    required this.onTap,
  });

  final bool atStart;
  final Animation<double> pulse;
  final VoidCallback onTap;

  static const double _width = 34;

  @override
  Widget build(BuildContext context) {
    final green = context.colors.right;

    return PositionedDirectional(
      top: 0,
      bottom: 0,
      start: atStart ? 0 : null,
      end: atStart ? null : 0,
      width: _width,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: FadeTransition(
          // 0.45 -> 1.0 rather than 0 -> 1: a cue that disappears completely
          // every 1.8 seconds is a cue the student has to wait for.
          opacity: pulse.drive(Tween<double>(begin: 0.45, end: 1)),
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
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.letter,
    required this.date,
    required this.isToday,
    required this.done,
    this.selected = false,
    this.onTap,
  });

  final String letter;
  final DateTime date;
  final bool isToday;
  final bool done;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final day = _column(context);
    // No Pressable at all on an inert strip: the dashboard must not gain a
    // press response for a tap that does nothing.
    if (onTap == null) return day;

    return Pressable(
      onTap: onTap,
      // The letter alone reads as "ا" or "T"; the date is what a student
      // actually needs to hear before picking a day.
      semanticLabel: dateLabel(date),
      // The circle is drawn at 34 and the column is narrow. The hit area is not
      // obliged to be.
      minTarget: kMinTarget,
      child: day,
    );
  }

  Widget _column(BuildContext context) {
    final c = context.colors;
    final marked = isToday || selected;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Today is marked three times -- a dot, a darker letter and a rule
        // under it -- so it is still findable when the strip is read at a
        // glance in bright light, and none of the three is a filled shape that
        // could be confused with a completed day.
        SizedBox(
          height: 4,
          child: isToday
              ? Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.textPrimary,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.only(bottom: 3),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: marked ? c.textPrimary : const Color(0x00000000),
                width: 1.5,
              ),
            ),
          ),
          child: Text(
            letter,
            style: context.text.dayLabel.copyWith(
              color: marked ? c.textPrimary : c.weekLabel,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.textGap),
        // Done is the accent fill -- the same blue every progress bar fills
        // with, because a completed day is progress and not a verdict. Green
        // here would claim the day was *correct*.
        //
        // It floods inward from the rim rather than landing on one frame, and
        // the tick follows it. What would read as a day half-proved is a fill
        // that *rises*; this one never shows a level.
        CompletionDisc(
          done: done,
          size: AppSizes.weekCircle,
          fill: c.accent,
          // Today-not-done gets the accent as an outline: the shape the day is
          // heading for, not yet filled.
          ring: isToday
              ? c.accent
              : selected
              ? c.textPrimary
              : c.checkboxBorder,
          ringWidth: isToday ? 1.6 : 1.5,
          tickSize: 16,
          tickColor: c.onAccent,
        ),
      ],
    );
  }
}
