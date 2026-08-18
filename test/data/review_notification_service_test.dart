import 'package:ather/data/notifications/review_notification_service.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/domain/services/review_cycle_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixed reference point. Every date below is relative to this.
final DateTime kAnchor = DateTime(2026, 6, 1);

/// The reminder hour, spelled out once so the expectations below read as times
/// rather than as arithmetic.
const int kHour = ReviewCycleService.kReminderHour;

Lesson lessonWith({
  required int id,
  required DateTime? lastReviewedAt,
  int chapterId = 1,
  String name = 'درس',
}) {
  return Lesson(
    id: id,
    chapterId: chapterId,
    name: name,
    createdAt: DateTime(2026, 1, 1),
    lastReviewedAt: lastReviewedAt,
  );
}

/// A snapshot of lessons under one chapter.
///
/// Built directly rather than through the database fixture: nothing here reads
/// exams or mastery, so the database fixture would only add setup to read past.
StudySnapshot snapshotOf(List<Lesson> lessons) {
  return StudySnapshot(
    subjects: const [],
    chapters: [
      Chapter(
        id: 1,
        subjectId: 1,
        name: 'باب',
        createdAt: DateTime(2026, 1, 1),
      ),
    ],
    lessons: lessons,
    exams: const [],
    homework: const [],
  );
}

List<ScheduledReminder> plan(
  StudySnapshot snapshot,
  DateTime now, {
  bool enabled = true,
}) {
  return ReviewNotificationService.planReminders(
    snapshot: snapshot,
    now: now,
    enabled: enabled,
    buildBody: (lesson, chapter) => 'due:$lesson/$chapter',
    buildEarlyBody: (lesson, chapter) => 'early:$lesson/$chapter',
  );
}

void main() {
  group('predictive reminder', () {
    test('a lesson examined today gets an early reminder and a due reminder, '
        'both at the reminder hour', () {
      final snapshot = snapshotOf([lessonWith(id: 7, lastReviewedAt: kAnchor)]);

      final reminders = plan(snapshot, kAnchor);

      expect(reminders, hasLength(2));

      final early = reminders.singleWhere((r) => r.isEarly);
      final due = reminders.singleWhere((r) => !r.isEarly);

      // 1 June + 30 days = 1 July; the warning lands three days before it.
      expect(due.at, DateTime(2026, 7, 1, kHour));
      expect(early.at, DateTime(2026, 6, 28, kHour));

      // Soonest first.
      expect(reminders.first, same(early));
    });

    test('the early reminder is exactly kEarlyReminderDays before the due one, '
        'at the same hour', () {
      final lesson = lessonWith(id: 1, lastReviewedAt: kAnchor);
      final due = ReviewCycleService.dueAt(lesson)!;
      final early = ReviewCycleService.earlyReminderAt(lesson)!;

      expect(
        due.difference(early),
        const Duration(days: ReviewCycleService.kEarlyReminderDays),
      );
      expect(early.hour, kHour);
      expect(due.hour, kHour);
    });

    test('the hour of the exam does not move either reminder', () {
      // The whole point of the calendar-day anchoring: an exam at 23:00 and one
      // at 07:00 on the same date produce the same two moments.
      final late = lessonWith(id: 1, lastReviewedAt: DateTime(2026, 6, 1, 23));
      final early = lessonWith(id: 2, lastReviewedAt: DateTime(2026, 6, 1, 7));

      expect(
        ReviewCycleService.earlyReminderAt(late),
        ReviewCycleService.earlyReminderAt(early),
      );
      expect(ReviewCycleService.dueAt(late), ReviewCycleService.dueAt(early));
      expect(
        ReviewCycleService.earlyReminderAt(late),
        DateTime(2026, 6, 28, kHour),
      );
    });

    test('the early reminder is skipped once it is in the past, and the due '
        'one still stands', () {
      // Examined 28 days ago: due in two days, so the warning was owed
      // yesterday.
      final snapshot = snapshotOf([
        lessonWith(
          id: 7,
          lastReviewedAt: kAnchor.subtract(const Duration(days: 28)),
        ),
      ]);

      final reminders = plan(snapshot, kAnchor);

      expect(reminders.where((r) => r.isEarly), isEmpty);
      expect(reminders, hasLength(1));
      expect(reminders.single.isEarly, isFalse);
    });

    test('an overdue lesson gets neither reminder', () {
      final snapshot = snapshotOf([
        lessonWith(
          id: 7,
          lastReviewedAt: kAnchor.subtract(const Duration(days: 40)),
        ),
      ]);

      expect(plan(snapshot, kAnchor), isEmpty);
    });

    test('a never-examined lesson gets neither reminder', () {
      final snapshot = snapshotOf([lessonWith(id: 7, lastReviewedAt: null)]);

      expect(plan(snapshot, kAnchor), isEmpty);
    });

    test('the two reminders of one lesson never share a notification id', () {
      final snapshot = snapshotOf([
        for (var id = 1; id <= 50; id++)
          lessonWith(id: id, lastReviewedAt: kAnchor),
      ]);

      final reminders = plan(snapshot, kAnchor);

      expect(reminders, hasLength(100));
      expect(reminders.map((r) => r.id).toSet(), hasLength(100));
    });

    test('both reminders carry the lesson id, so tapping either opens it', () {
      final snapshot = snapshotOf([lessonWith(id: 7, lastReviewedAt: kAnchor)]);

      expect(plan(snapshot, kAnchor).map((r) => r.lessonId), everyElement(7));
    });

    test('the two reminders say different things, and each names the lesson '
        'and its chapter', () {
      final snapshot = snapshotOf([
        lessonWith(id: 7, lastReviewedAt: kAnchor, name: 'التحليل الكهربي'),
      ]);

      final reminders = plan(snapshot, kAnchor);
      final early = reminders.singleWhere((r) => r.isEarly);
      final due = reminders.singleWhere((r) => !r.isEarly);

      expect(early.body, 'early:التحليل الكهربي/باب');
      expect(due.body, 'due:التحليل الكهربي/باب');
      expect(early.body, isNot(due.body));
    });

    test('nothing is scheduled when reminders are off', () {
      final snapshot = snapshotOf([lessonWith(id: 7, lastReviewedAt: kAnchor)]);

      expect(plan(snapshot, kAnchor, enabled: false), isEmpty);
    });
  });

  group('fingerprint', () {
    ScheduledReminder reminder({
      int id = 1,
      DateTime? at,
      String body = 'body',
    }) {
      return ScheduledReminder(
        id: id,
        lessonId: 1,
        at: at ?? DateTime(2026, 7, 1, kHour),
        body: body,
        isEarly: false,
      );
    }

    String fingerprint(List<ScheduledReminder> reminders) {
      return ReviewNotificationService.fingerprintOf(
        reminders: reminders,
        enabled: true,
        title: 'title',
      );
    }

    test('an identical schedule fingerprints identically', () {
      expect(fingerprint([reminder()]), fingerprint([reminder()]));
    });

    // The dedupe is what would suppress the new reminder: if adding the early
    // moment left the fingerprint unchanged, `reschedule` would take its early
    // return and never register it.
    test('adding the early reminder changes the fingerprint', () {
      final dueOnly = fingerprint([reminder(id: 2)]);
      final both = fingerprint([
        reminder(id: 3, at: DateTime(2026, 6, 28, kHour)),
        reminder(id: 2),
      ]);

      expect(both, isNot(dueOnly));
    });

    test('moving the early reminder changes the fingerprint', () {
      final before = fingerprint([
        reminder(id: 3, at: DateTime(2026, 6, 28, kHour)),
      ]);
      final after = fingerprint([
        reminder(id: 3, at: DateTime(2026, 6, 29, kHour)),
      ]);

      expect(after, isNot(before));
    });

    test('moving the due reminder changes the fingerprint', () {
      final before = fingerprint([reminder(at: DateTime(2026, 7, 1, kHour))]);
      final after = fingerprint([reminder(at: DateTime(2026, 7, 2, kHour))]);

      expect(after, isNot(before));
    });

    test('a lesson renamed into a different body changes the fingerprint', () {
      expect(
        fingerprint([reminder(body: 'after')]),
        isNot(fingerprint([reminder(body: 'before')])),
      );
    });

    test('two passes over the same data fingerprint identically, so an '
        'unchanged schedule is never rebuilt', () {
      // Two lessons examined on the same day fall due at the same instant; the
      // sort tie-breaks on id so the order -- and the fingerprint -- is stable.
      final snapshot = snapshotOf([
        lessonWith(id: 1, lastReviewedAt: kAnchor),
        lessonWith(id: 2, lastReviewedAt: kAnchor),
      ]);

      expect(
        fingerprint(plan(snapshot, kAnchor)),
        fingerprint(plan(snapshot, kAnchor)),
      );
    });
  });
}
