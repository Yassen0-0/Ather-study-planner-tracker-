import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'icon_motion.dart';
import 'pressable.dart';

/// The seven-day strip at the top of the dashboard and the tasks screen.
///
/// The widget has **no opinion about what a filled circle means** — [activeDays]
/// is whatever the caller says it is. On the dashboard that is "an exam was
/// recorded", the only thing that proves anything; on the tasks screen it is
/// "every task the student set themselves that day is done". One widget, because
/// the shape is the same and two copies would drift.
class WeekStrip extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l = L.of(context);
    final start = weekStart(today);
    final todayDate = DateTime(today.year, today.month, today.day);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        for (var i = 0; i < _weekdayOrder.length; i++)
          _Day(
            letter: _letter(l, _weekdayOrder[i]),
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
    return onTap == null ? day : Pressable(onTap: onTap, child: day);
  }

  Widget _column(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Today is marked twice -- a darker letter and a dot above it -- so it
        // is still findable when the strip is read at a glance in bright light.
        SizedBox(
          height: 4,
          child: isToday
              ? Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.textPrimary,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 3),
        Text(
          letter,
          style: context.text.dayLabel.copyWith(
            color: isToday || selected
                ? context.colors.textPrimary
                : context.colors.weekLabel,
          ),
        ),
        const SizedBox(height: 9),
        // Selection adds no new shape — it darkens the ring the empty circle
        // already has. A complete day is already a filled disc and needs no
        // second marker; today keeps its dot above the letter, so the two
        // signals never land on the same pixel.
        //
        // The fill closes inward from the rim and the tick lands after it. It
        // is not a level rising, which is the thing that would read as a day
        // half-proved.
        CompletionDisc(
          done: done,
          size: AppSizes.weekCircle,
          fill: context.colors.actionPrimary,
          ring: selected
              ? context.colors.textPrimary
              : context.colors.dashedBorder,
          ringWidth: 1.6,
          tickSize: 16,
          tickColor: context.colors.onPrimary,
        ),
      ],
    );
  }
}
