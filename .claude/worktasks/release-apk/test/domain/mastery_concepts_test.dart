import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/instants.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/data/repositories/drift_study_repository.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/services/summaries.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/summary_providers.dart';

/// The three named states the student is ever shown — «أثبت», «متفوق», «باب
/// مُغلق» — and the one rule behind them: a present-tense claim dies when its
/// evidence does.
///
/// Before this policy lived in the domain, the same word «متقن» meant "has an
/// exam, fresh, ≥ 90" on the dashboard's stat row, "masteredAt != null" on the
/// chapter counter, and "has an exam, ≥ 70" on the share card — two of them
/// contradictory on one screen at the same second (audit ك1). These tests pin
/// the single definitions the screens now read.
void main() {
  final DateTime now = DateTime(2026, 6, 1);
  final DateTime t0 = DateTime(2025, 1, 1);

  LessonSummary lesson(
    double mastery, {
    required int examCount,
    bool needsReview = false,
  }) => LessonSummary(
    lesson: Lesson(id: 1, chapterId: 1, name: 'درس', createdAt: t0),
    mastery: mastery,
    examCount: examCount,
    needsReview: needsReview,
    daysOverdue: needsReview ? 5 : 0,
    daysUntilDue: null,
    latestHomeworkPercentage: null,
  );

  group('the lesson states', () {
    test('«أثبت» needs exam evidence — unmeasured is not failed or proven', () {
      // A constructed 100% with no exam behind it cannot exist through
      // Summaries.lesson, which is exactly why it is worth constructing here:
      // counting on the percentage alone would read untouched lessons as
      // proven ones.
      final untouched = lesson(100, examCount: 0);
      expect(untouched.isProven, isFalse);
      expect(untouched.isExcellent, isFalse);
    });

    test('the proof threshold is inclusive at 70', () {
      expect(lesson(69.9, examCount: 1).isProven, isFalse);
      expect(lesson(70, examCount: 1).isProven, isTrue);
    });

    test('«متفوق» is proven at the excellent band, not merely above 70', () {
      final strong = lesson(89.9, examCount: 2);
      expect(strong.isProven, isTrue);
      expect(strong.isExcellent, isFalse);

      final excellent = lesson(90, examCount: 2);
      expect(excellent.isProven, isTrue);
      expect(excellent.isExcellent, isTrue);
    });

    test('a stale score proves nothing — freshness is part of both states', () {
      // 95% earned forty days ago has decayed; the review clock says so.
      final stale = lesson(95, examCount: 3, needsReview: true);
      expect(stale.isProven, isFalse);
      expect(stale.isExcellent, isFalse);
    });
  });

  group('«باب مُغلق» — the closure decision', () {
    late AppDatabase db;
    late DriftStudyRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = DriftStudyRepository(db);
    });
    tearDown(() async => db.close());

    Future<void> proveEverything(int chapterId, List<int> lessonIds) async {
      for (final id in lessonIds) {
        await repo.recordExam(
          lessonId: id,
          groups: const <DraftQuestionGroup>[
            DraftQuestionGroup(
              pointsPerQuestion: 1,
              questionCount: 100,
              correctCount: 80,
            ),
          ],
          isReviewExam: false,
          at: now.subtract(const Duration(days: 1)),
        );
      }
    }

    test(
      'a closure counts while its evidence stands, breaks when it does not, '
      'and keeps its date either way',
      () async {
        final chapterId = await repo.createChapter(
          subjectId: 1,
          name: 'الباب الأول',
          at: kSeedInstant,
        );
        final a = await repo.createLesson(
          chapterId: chapterId,
          name: 'أ',
          at: kSeedInstant,
        );
        final b = await repo.createLesson(
          chapterId: chapterId,
          name: 'ب',
          at: kSeedInstant,
        );
        await proveEverything(chapterId, <int>[a, b]);
        await repo.markChapterMastered(chapterId: chapterId, at: now);

        var snapshot = await repo.readSnapshot();
        var dashboard = Summaries.dashboard(snapshot, now);
        var summary = Summaries.chapter(
          snapshot,
          snapshot.chapterById(chapterId)!,
          now,
        );
        expect(dashboard.masteredChapters, 1);
        expect(summary.isCurrentlyClosed, isTrue);
        expect(summary.chapter.masteredAt, now);

        // A new lesson arrives without an exam. The closure was real once but
        // its evidence no longer stands: every-lesson-examined fails, so the
        // counter drops the chapter and the badge condition goes false — while
        // the dated event itself survives untouched.
        await repo.createLesson(
          chapterId: chapterId,
          name: 'جديد',
          at: now.add(const Duration(days: 1)),
        );

        snapshot = await repo.readSnapshot();
        dashboard = Summaries.dashboard(snapshot, now);
        summary = Summaries.chapter(
          snapshot,
          snapshot.chapterById(chapterId)!,
          now,
        );

        expect(
          dashboard.masteredChapters,
          0,
          reason: '«أتقنت X من Y باب» counts closures whose evidence stands',
        );
        expect(summary.isCurrentlyClosed, isFalse);
        expect(summary.isMastered, isTrue);
        expect(summary.chapter.masteredAt, now);
      },
    );

    test('a broken closure leaves the subject row too', () async {
      final chapterId = await repo.createChapter(
        subjectId: 1,
        name: 'الباب الأول',
        at: kSeedInstant,
      );
      final a = await repo.createLesson(
        chapterId: chapterId,
        name: 'أ',
        at: kSeedInstant,
      );
      await proveEverything(chapterId, <int>[a]);
      await repo.markChapterMastered(chapterId: chapterId, at: now);

      var snapshot = await repo.readSnapshot();
      var subject = Summaries.subject(snapshot, snapshot.subjectById(1)!, now);
      expect(subject.masteredChapterCount, 1);

      await repo.createLesson(
        chapterId: chapterId,
        name: 'جديد',
        at: now.add(const Duration(days: 1)),
      );
      snapshot = await repo.readSnapshot();
      subject = Summaries.subject(snapshot, snapshot.subjectById(1)!, now);
      expect(subject.masteredChapterCount, 0);
    });
  });

  test('homeStatsProvider counts through the domain, not its own arithmetic',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = DriftStudyRepository(db);
    addTearDown(db.close);

    final chapterId = await repo.createChapter(
      subjectId: 1,
      name: 'الباب الأول',
      at: kSeedInstant,
    );
    Future<int> addLesson(String name) => repo.createLesson(
      chapterId: chapterId,
      name: name,
      at: kSeedInstant,
    );
    Future<void> exam(int lessonId, int correct, DateTime at) =>
        repo.recordExam(
          lessonId: lessonId,
          groups: <DraftQuestionGroup>[
            DraftQuestionGroup(
              pointsPerQuestion: 1,
              questionCount: 100,
              correctCount: correct,
            ),
          ],
          isReviewExam: false,
          at: at,
        );

    final excellent = await addLesson('متفق');
    await addLesson('بلا امتحان');
    final stale = await addLesson('قديم');
    await exam(excellent, 92, now);
    await exam(stale, 90, now.subtract(const Duration(days: 40)));

    final snapshot = await repo.readSnapshot();
    final container = ProviderContainer(
      overrides: [
        snapshotValueProvider.overrideWithValue(snapshot),
        nowValueProvider.overrideWithValue(now),
      ],
    );
    addTearDown(container.dispose);

    final stats = container.read(homeStatsProvider);
    expect(stats.totalLessons, 3);
    // Only the never-examined lesson counts as remaining.
    expect(stats.remaining, 1);
    // The stale 90 crossed the 30-day line.
    expect(stats.overdue, 1);
    // Fresh and ≥ 90: exactly one. The old compound condition here counted
    // this same number, but as private arithmetic the share card could not
    // reuse and nothing could test against «متفوق» elsewhere.
    expect(stats.excellent, 1);
  });
}
