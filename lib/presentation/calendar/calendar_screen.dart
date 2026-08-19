import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_scaffold.dart';
import '../../core/widgets/day_header.dart';
import '../../domain/entities/exam_entry.dart';
import '../common/settings_button.dart';
import '../providers/app_providers.dart';
import 'scheduled_exam_form.dart';
import 'widgets/exam_detail_card.dart';
import 'widgets/exam_history_card.dart';

/// The exam calendar screen.
///
/// Shows scheduled upcoming exams and past exam history in a calendar view.
/// Students can see which exams are approaching and plan their review cycles
/// accordingly. This screen connects exam scheduling with mastery tracking,
/// making the 30-day decay mechanic actionable for exam preparation.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = DateTime(now.year, now.month, now.day);
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final snapshot = ref.watch(snapshotValueProvider);
    final now = ref.watch(nowValueProvider);

    // Group scheduled exams by date for markers
    final scheduledExamsByDate = <DateTime, int>{};
    for (final exam in snapshot.scheduledExams) {
      final day = DateTime(exam.date.year, exam.date.month, exam.date.day);
      scheduledExamsByDate[day] = (scheduledExamsByDate[day] ?? 0) + 1;
    }

    // Group past exams by date for markers
    final examsByDate = <DateTime, int>{};
    for (final exam in snapshot.exams) {
      final day = DateTime(
        exam.createdAt.year,
        exam.createdAt.month,
        exam.createdAt.day,
      );
      examsByDate[day] = (examsByDate[day] ?? 0) + 1;
    }

    // Find scheduled exams for the selected day
    final selectedDayScheduledExams = _selectedDay == null
        ? <dynamic>[]
        : snapshot.scheduledExams.where((exam) {
            final examDay = DateTime(
              exam.date.year,
              exam.date.month,
              exam.date.day,
            );
            final selected = DateTime(
              _selectedDay!.year,
              _selectedDay!.month,
              _selectedDay!.day,
            );
            return examDay == selected;
          }).toList();

    // Find past exams for the selected day
    final selectedDayPastExams = _selectedDay == null
        ? <ExamEntry>[]
        : snapshot.exams.where((exam) {
            final examDay = DateTime(
              exam.createdAt.year,
              exam.createdAt.month,
              exam.createdAt.day,
            );
            final selected = DateTime(
              _selectedDay!.year,
              _selectedDay!.month,
              _selectedDay!.day,
            );
            return examDay == selected;
          }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showScheduledExamForm(context),
        backgroundColor: context.colors.accent,
        child: Icon(Icons.add, color: context.colors.onAccent),
      ),
      body: AtherScreen(
        header: DayHeader(
          title: l.calendarTitle,
          actions: const <Widget>[SettingsButton()],
        ),
        children: <Widget>[
          TableCalendar(
          firstDay: DateTime.utc(now.year - 2, 1, 1),
          lastDay: DateTime.utc(now.year + 2, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: CalendarFormat.month,
          startingDayOfWeek: StartingDayOfWeek.saturday,
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: AppTypography.style(
              size: 16,
              weight: AppTypography.semiBold,
              color: context.colors.textPrimary,
            ),
            leftChevronIcon: Icon(
              Icons.chevron_left,
              color: context.colors.textPrimary,
            ),
            rightChevronIcon: Icon(
              Icons.chevron_right,
              color: context.colors.textPrimary,
            ),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: context.text.secondary.copyWith(fontSize: 14),
            weekendStyle: context.text.secondary.copyWith(fontSize: 14),
          ),
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            todayDecoration: BoxDecoration(
              color: context.colors.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: context.colors.accent,
              shape: BoxShape.circle,
            ),
            markerDecoration: BoxDecoration(
              color: context.colors.accent,
              shape: BoxShape.circle,
            ),
            markersMaxCount: 1,
            defaultTextStyle: AppTypography.style(
              size: 15,
              weight: AppTypography.medium,
              color: context.colors.textPrimary,
            ),
            weekendTextStyle: AppTypography.style(
              size: 15,
              weight: AppTypography.medium,
              color: context.colors.textPrimary,
            ),
            todayTextStyle: AppTypography.style(
              size: 15,
              weight: AppTypography.semiBold,
              color: context.colors.accent,
            ),
            selectedTextStyle: AppTypography.style(
              size: 15,
              weight: AppTypography.semiBold,
              color: Colors.white,
            ),
          ),
          eventLoader: (day) {
            final normalizedDay = DateTime(day.year, day.month, day.day);
            final count = (scheduledExamsByDate[normalizedDay] ?? 0) +
                (examsByDate[normalizedDay] ?? 0);
            return List.filled(count, 'event');
          },
          onDaySelected: (selectedDay, focusedDay) {
            if (!isSameDay(_selectedDay, selectedDay)) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            }
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
        ),

        // Show scheduled exams for the selected day
        if (selectedDayScheduledExams.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxxl),
          ...selectedDayScheduledExams.map((exam) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ExamDetailCard(exam: exam),
          )),
        ],

        // Show past exams for the selected day
        if (selectedDayPastExams.isNotEmpty) ...[
          if (selectedDayScheduledExams.isEmpty)
            const SizedBox(height: AppSpacing.xxxl),
          ...selectedDayPastExams.map((exam) {
            final lesson = snapshot.lessons
                .where((l) => l.id == exam.lessonId)
                .firstOrNull;
            // Skip if lesson was deleted
            if (lesson == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ExamHistoryCard(
                exam: exam,
                snapshot: snapshot,
              ),
            );
          }),
        ],
        ],
      ),
    );
  }
}
