import 'package:flutter_test/flutter_test.dart';
import 'package:ather/domain/services/summaries.dart';

import '../support/instants.dart';
import 'fixtures.dart';

/// The homework verdict and its silence rule (audit P3-05).
///
/// A homework score is advisory, never evidence. Its one present-tense
/// warning -- «تحتاج مذاكرة أكثر» -- may only be issued while the homework is
/// still the newest word on the lesson: a homework logged **before the
/// lesson's first exam** has been outvoted by that exam and stays silent,
/// whatever its percentage says. Every case below goes through
/// [Summaries.lesson] against a real snapshot, so the derivation of
/// `latestHomeworkAt` / `firstExamAt` is tested alongside the rule that
/// consumes them.
void main() {
  final DateTime now = DateTime(2026, 6, 1);

  Future<LessonSummary> summaryWith({
    List<(DateTime, int)> homework = const <(DateTime, int)>[],
    List<(DateTime, int)> exams = const <(DateTime, int)>[],
  }) async {
    final snapshot = await buildSnapshot((repo) async {
      final chapter = await repo.createChapter(
        subjectId: 1,
        name: 'الباب الأول',
        at: kSeedInstant,
      );
      final lesson = await repo.createLesson(
        chapterId: chapter,
        name: 'درس',
        at: kSeedInstant,
      );
      for (final (at, pct) in homework) {
        await repo.recordHomework(
          lessonId: lesson,
          score: pct,
          maxScore: 100,
          at: at,
        );
      }
      for (final (at, pct) in exams) {
        await recordPercentage(repo, lesson, pct, at);
      }
    });
    final lesson = snapshot.lessons.single;
    return Summaries.lesson(snapshot, lesson, now);
  }

  group('homeworkSuggestsMoreStudy', () {
    test('a homework older than the first exam is silent', () async {
      final summary = await summaryWith(
        homework: <(DateTime, int)>[(DateTime(2026, 1, 1), 30)],
        exams: <(DateTime, int)>[(DateTime(2026, 2, 1), 80)],
      );

      expect(summary.latestHomeworkPercentage, 30);
      expect(summary.firstExamAt, DateTime(2026, 2, 1));
      expect(summary.homeworkSuggestsMoreStudy, isFalse);
    });

    test('a homework logged after the first exam still speaks', () async {
      final summary = await summaryWith(
        homework: <(DateTime, int)>[(DateTime(2026, 3, 1), 30)],
        exams: <(DateTime, int)>[(DateTime(2026, 2, 1), 45)],
      );

      expect(summary.homeworkSuggestsMoreStudy, isTrue);
    });

    test('with no exams at all the homework always speaks', () async {
      final summary = await summaryWith(
        homework: <(DateTime, int)>[(DateTime(2026, 1, 1), 30)],
      );

      expect(summary.firstExamAt, isNull);
      expect(summary.homeworkSuggestsMoreStudy, isTrue);
    });

    test('logged on the same instant as the first exam is not "before"',
        () async {
      final instant = DateTime(2026, 2, 1, 12);
      final summary = await summaryWith(
        homework: <(DateTime, int)>[(instant, 30)],
        exams: <(DateTime, int)>[(instant, 45)],
      );

      expect(summary.homeworkSuggestsMoreStudy, isTrue);
    });

    test('a ready homework never warns, old or new', () async {
      // Exactly at the readiness threshold: still "ready", even outvoted.
      final old = await summaryWith(
        homework: <(DateTime, int)>[(DateTime(2026, 1, 1), 60)],
        exams: <(DateTime, int)>[(DateTime(2026, 1, 15), 90)],
      );
      expect(old.homeworkSuggestsMoreStudy, isFalse);

      final fresh = await summaryWith(
        homework: <(DateTime, int)>[(DateTime(2026, 3, 1), 70)],
      );
      expect(fresh.homeworkSuggestsMoreStudy, isFalse);
    });

    test('no homework says nothing', () async {
      final summary = await summaryWith(
        exams: <(DateTime, int)>[(DateTime(2026, 2, 1), 80)],
      );

      expect(summary.latestHomeworkPercentage, isNull);
      expect(summary.latestHomeworkAt, isNull);
      expect(summary.homeworkSuggestsMoreStudy, isFalse);
    });
  });

  group('timestamp derivation', () {
    test('firstExamAt survives out-of-order recording', () async {
      final summary = await summaryWith(
        homework: const <(DateTime, int)>[],
        exams: <(DateTime, int)>[
          (DateTime(2026, 3, 1), 60),
          (DateTime(2026, 1, 1), 50),
        ],
      );

      expect(summary.examCount, 2);
      expect(summary.firstExamAt, DateTime(2026, 1, 1));
    });

    test('latestHomeworkAt belongs to the entry the percentage came from',
        () async {
      final summary = await summaryWith(
        homework: <(DateTime, int)>[
          (DateTime(2026, 1, 1), 20),
          (DateTime(2026, 4, 1), 90),
        ],
      );

      // The percentage shown is the newest entry's, so its date must be too.
      expect(summary.latestHomeworkPercentage, 90);
      expect(summary.latestHomeworkAt, DateTime(2026, 4, 1));
    });

    test('an unexamined lesson with no homework carries both as null', () async {
      final summary = await summaryWith(homework: const <(DateTime, int)>[]);

      expect(summary.latestHomeworkAt, isNull);
      expect(summary.firstExamAt, isNull);
      expect(summary.homeworkSuggestsMoreStudy, isFalse);
    });
  });
}
