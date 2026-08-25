import 'dart:async';

import 'package:ather/core/clock/clock.dart';
import 'package:ather/core/l10n/generated/app_localizations.dart';
import 'package:ather/data/notifications/review_notification_service.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/mastery.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/domain/services/review_cycle_service.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:ather/presentation/providers/notification_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth.dart';
import '../support/fake_notifications.dart';

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
/// exams or mastery, and the cap test needs several hundred lessons, which is a
/// lot of SQLite for a decision that never touches it.
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

      // Soonest first, so the cap keeps what matters next.
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

  group('stateful wording', () {
    String declining(String lesson) => 'danger:$lesson';
    String weak(String lesson) => 'weak:$lesson';

    ExamEntry exam({
      required int id,
      required double percentage,
      required DateTime at,
    }) {
      return ExamEntry(
        id: id,
        lessonId: 7,
        isReviewExam: false,
        totalPossiblePoints: 100,
        correctPoints: percentage.round(),
        percentage: percentage,
        createdAt: at,
      );
    }

    /// A single-lesson snapshot carrying exam history -- the history is what
    /// the stateful wording hangs the lesson's state on.
    StudySnapshot snapshotWithExams({
      required Lesson lesson,
      required List<ExamEntry> exams,
    }) {
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
        lessons: [lesson],
        exams: exams,
        homework: const [],
      );
    }

    List<ScheduledReminder> planStateful(
      StudySnapshot snapshot, {
      String Function(String lesson)? buildDecliningBody,
      String Function(String lesson)? buildWeakBody,
    }) {
      return ReviewNotificationService.planReminders(
        snapshot: snapshot,
        now: kAnchor,
        enabled: true,
        buildBody: (lesson, chapter) => 'due:$lesson/$chapter',
        buildEarlyBody: (lesson, chapter) => 'early:$lesson/$chapter',
        buildDecliningBody: buildDecliningBody,
        buildWeakBody: buildWeakBody,
      );
    }

    test('a lesson whose last exam scored below the one before it gets the '
        'danger line on its due reminder', () {
      final snapshot = snapshotWithExams(
        lesson: lessonWith(id: 7, lastReviewedAt: DateTime(2026, 5, 20)),
        exams: [
          exam(id: 1, percentage: 80, at: DateTime(2026, 4, 20)),
          exam(id: 2, percentage: 60, at: DateTime(2026, 5, 20)),
        ],
      );

      final reminders = planStateful(
        snapshot,
        buildDecliningBody: declining,
        buildWeakBody: weak,
      );

      expect(reminders.where((r) => r.isEarly).single.body, 'early:درس/باب');
      expect(reminders.where((r) => !r.isEarly).single.body, 'danger:درس');
    });

    test('a freshly examined but weak lesson gets the weak line', () {
      // One exam at 40%: no trend to decline on, mastery under the flag
      // threshold. Only the weak callback is passed, which doubles as proof
      // the two are independent.
      final snapshot = snapshotWithExams(
        lesson: lessonWith(id: 7, lastReviewedAt: kAnchor),
        exams: [exam(id: 1, percentage: 40, at: kAnchor)],
      );

      final reminders = planStateful(snapshot, buildWeakBody: weak);

      expect(reminders.singleWhere((r) => !r.isEarly).body, 'weak:درس');
    });

    test('a healthy lesson keeps the plain sentence', () {
      final snapshot = snapshotWithExams(
        lesson: lessonWith(id: 7, lastReviewedAt: kAnchor),
        exams: [exam(id: 1, percentage: 85, at: kAnchor)],
      );

      final reminders = planStateful(
        snapshot,
        buildDecliningBody: declining,
        buildWeakBody: weak,
      );

      final due = reminders.singleWhere((r) => !r.isEarly);
      expect(due.body, 'due:درس/باب');
      expect(due.body, isNot('danger:درس'));
      expect(due.body, isNot('weak:درس'));
    });

    test('a lesson that is weak and declining at once gets the danger line -- '
        'declining wins', () {
      // 55% then 30%: declining, and mastery sits at 37.5 -- below the
      // threshold too, so the precedence is what is actually under test.
      final snapshot = snapshotWithExams(
        lesson: lessonWith(id: 7, lastReviewedAt: DateTime(2026, 5, 25)),
        exams: [
          exam(id: 1, percentage: 55, at: DateTime(2026, 4, 25)),
          exam(id: 2, percentage: 30, at: DateTime(2026, 5, 25)),
        ],
      );

      final reminders = planStateful(
        snapshot,
        buildDecliningBody: declining,
        buildWeakBody: weak,
      );

      expect(reminders.singleWhere((r) => !r.isEarly).body, 'danger:درس');
    });

    test('a lesson with a review clock but no recorded exam is not called '
        'weak', () {
      // Mastery of an unexamined lesson computes to 0; without the guard a
      // clock without evidence would read as weakness. The Review Center's
      // reason logic carries the same guard.
      final snapshot = snapshotOf([lessonWith(id: 7, lastReviewedAt: kAnchor)]);

      final reminders = planStateful(snapshot, buildWeakBody: weak);

      expect(reminders.singleWhere((r) => !r.isEarly).body, 'due:درس/باب');
    });

    test('a dropped score that flips the wording moves the fingerprint, so '
        'the rebuild cannot be deduped away', () {
      // Ids, moments, title and enabled flag identical throughout; the only
      // thing that moved is what the due-day body says. This is the case that
      // would silently strand yesterday's sentence on the device if bodies
      // were left out of the fingerprint.
      StudySnapshot snapshotWith({required double newest}) => snapshotWithExams(
        lesson: lessonWith(id: 7, lastReviewedAt: DateTime(2026, 5, 20)),
        exams:
            newest == 90
                ? [exam(id: 1, percentage: 90, at: DateTime(2026, 5, 20))]
                : [
                  exam(id: 1, percentage: 95, at: DateTime(2026, 4, 20)),
                  exam(id: 2, percentage: 60, at: DateTime(2026, 5, 20)),
                ],
      );

      String fingerprintOfPlan(StudySnapshot snapshot) =>
          ReviewNotificationService.fingerprintOf(
            reminders: planStateful(
              snapshot,
              buildDecliningBody: declining,
              buildWeakBody: weak,
            ),
            enabled: true,
            title: 'title',
          );

      expect(
        fingerprintOfPlan(snapshotWith(newest: 90)),
        isNot(fingerprintOfPlan(snapshotWith(newest: 60))),
      );
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

  group('alarm cap', () {
    /// [count] lessons spread across the last 25 days, so every one of them is
    /// still inside its cycle and still holds both of its reminders.
    ///
    /// The spread is 25 rather than 30 deliberately: a lesson examined 27 or
    /// more days ago has already passed its early warning and would contribute
    /// one alarm instead of two, which would make the arithmetic below depend
    /// on the skip rule rather than on the cap.
    List<Lesson> manyLessons(int count) {
      return <Lesson>[
        for (var i = 0; i < count; i++)
          lessonWith(
            id: i + 1,
            lastReviewedAt: kAnchor.subtract(Duration(days: i % 25)),
          ),
      ];
    }

    test('never registers more than the cap', () {
      final snapshot = snapshotOf(manyLessons(500));

      expect(
        plan(snapshot, kAnchor).length,
        ReviewNotificationService.kMaxScheduledAlarms,
      );
    });

    test('the alarms it keeps are the soonest ones', () {
      final snapshot = snapshotOf(manyLessons(500));

      final kept = plan(snapshot, kAnchor);
      final cutoff = kept.last.at;

      // Everything kept is ordered soonest first...
      for (var i = 1; i < kept.length; i++) {
        expect(
          kept[i].at.isBefore(kept[i - 1].at),
          isFalse,
          reason: 'reminders must be ordered soonest first',
        );
      }

      // ...and nothing that was dropped falls due before something that was
      // kept.
      final keptIds = kept.map((r) => r.id).toSet();
      final dropped = <DateTime>[
        for (final lesson in snapshot.lessons) ...<DateTime>[
          if (ReviewCycleService.earlyReminderAt(lesson)!.isAfter(kAnchor) &&
              !keptIds.contains(lesson.id * 2 + 1))
            ReviewCycleService.earlyReminderAt(lesson)!,
          if (ReviewCycleService.dueAt(lesson)!.isAfter(kAnchor) &&
              !keptIds.contains(lesson.id * 2))
            ReviewCycleService.dueAt(lesson)!,
        ],
      ];

      expect(dropped, isNotEmpty, reason: 'the cap should have dropped some');
      for (final at in dropped) {
        expect(
          at.isBefore(cutoff),
          isFalse,
          reason: 'a dropped alarm fell due before one that was kept',
        );
      }
    });

    test('stays well under the platform ceiling', () {
      // Android drops registrations past roughly 500 without reporting it.
      expect(ReviewNotificationService.kMaxScheduledAlarms, lessThan(500));
    });

    test('a student under the cap keeps every reminder', () {
      // 20 lessons, all far enough out to still hold their early warning.
      expect(plan(snapshotOf(manyLessons(20)), kAnchor), hasLength(40));
    });

    test('the cycle length the cap is reasoned about has not moved', () {
      expect(kReviewCycleDays, 30);
      expect(ReviewCycleService.kEarlyReminderDays, 3);
    });
  });

  group('cold-start race', () {
    /// The scheduler mounted the way the app mounts it, against a snapshot
    /// stream that has **not** emitted yet -- the exact state of a cold start
    /// for the few seconds drift needs to answer its first query.
    Future<FakeNotificationService> pumpScheduler(
      WidgetTester tester,
      StreamController<StudySnapshot> snapshots,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final auth = FakeAuthRepository.signedIn();
      addTearDown(auth.dispose);
      final notifications = FakeNotificationService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationServiceProvider.overrideWithValue(notifications),
            snapshotProvider.overrideWith((ref) => snapshots.stream),
            clockProvider.overrideWithValue(MutableClock(kAnchor)),
            sharedPreferencesProvider.overrideWithValue(preferences),
            authRepositoryProvider.overrideWithValue(auth),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: const ReviewScheduler(child: SizedBox.shrink()),
          ),
        ),
      );
      // Second frame so the post-frame callback that opens the first sync has
      // run up to its first await.
      await tester.pump();
      return notifications;
    }

    testWidgets('the loading fallback never empties the schedule; the first '
        'pass waits for the real record and plans from it', (tester) async {
      final snapshots = StreamController<StudySnapshot>();
      addTearDown(snapshots.close);

      final notifications = await pumpScheduler(tester, snapshots);

      // The cold-start sync is now pending on data that has not arrived. It
      // used to run straight away against `StudySnapshot.empty()` instead:
      // that pass cancelled every alarm on the device and recorded the
      // emptiness as applied, so each launch held zero alarms until the first
      // real pass, and a reminder falling due inside the gap was lost.
      expect(
        notifications.rescheduleEnabled,
        isEmpty,
        reason: 'no pass may run while the snapshot is still loading',
      );
      // Still nothing even past the debounce: waiting for data is not the
      // same as waiting out a debounce over an empty answer.
      await tester.pump(const Duration(seconds: 6));
      expect(notifications.rescheduleEnabled, isEmpty);

      // The record arrives; the pending pass resumes and plans from it.
      snapshots.add(snapshotOf([lessonWith(id: 7, lastReviewedAt: kAnchor)]));
      await tester.pump(const Duration(seconds: 6));

      expect(
        notifications.rescheduleEnabled,
        isNotEmpty,
        reason: 'the sync owed to the arrived data must actually happen',
      );
      // Every pass that did run saw real lessons -- never the fallback.
      expect(notifications.rescheduleEnabled, everyElement(isTrue));
      expect(
        notifications.plannedReminders.map((r) => r.lessonId),
        everyElement(7),
      );
      expect(notifications.cancelAllCount, 0);
    });
  });
}
