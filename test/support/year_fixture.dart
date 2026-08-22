import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_backup.dart';
import 'package:ather/domain/entities/subject.dart';

/// A full school year of study, as one [StudyBackup].
///
/// Built for the P2-07 load test (`test/data/snapshot_load_test.dart`): the
/// maximal student the audit's P1 finding is about — 4 subjects x 15 chapters
/// x 10 lessons = **600 lessons**, **3000 exams** (5 per lesson) each carrying
/// **two realistic question groups**, plus one homework entry per lesson.
/// Roughly 21,000 rows land in SQLite through `DriftStudyRepository.restore`,
/// never through raw SQL, so the fixture exercises exactly the write path a
/// real record arrives by.
///
/// Every lesson shares one exam history so the mastery arithmetic stays
/// hand-checkable at any scale (see [kFixtureOverallMastery]), while review
/// clocks are staggered so the dashboard's overdue/upcoming loops do real work.
const int kFixtureSubjects = 4;
const int kFixtureChaptersPerSubject = 15;
const int kFixtureLessonsPerChapter = 10;
const int kFixtureExamsPerLesson = 5;

int get kFixtureChapterCount =>
    kFixtureSubjects * kFixtureChaptersPerSubject;
int get kFixtureLessonCount =>
    kFixtureChapterCount * kFixtureLessonsPerChapter;
int get kFixtureExamCount => kFixtureLessonCount * kFixtureExamsPerLesson;

/// The fixed "today" every fixture date is anchored to. A constant, never
/// `DateTime.now()`: the expected dashboard figures below are only true for
/// this instant, and a test whose truth moves with the wall clock cannot be
/// trusted on a slow CI runner that starts it a second later.
final DateTime kFixtureNow = DateTime(2026, 8, 20);

/// First day of the school year the fixture spans.
final DateTime _termStart = DateTime(2025, 9, 1);

/// Exam percentages for one lesson, oldest first.
///
/// The newest exam (90) carries `kRecentWeight` 0.7; the other four average
/// 65 and carry the remaining `kHistoryWeight` 0.3.
const List<double> _examPercentagesOldestFirst = <double>[50, 60, 70, 80, 90];

/// The hand-computed figure the whole curriculum must produce.
///
/// Worked through once, here, so the load test can assert it:
///
/// ```text
/// lessonMastery  = 90 * 0.7 + ((50+60+70+80)/4) * 0.3 = 63 + 19.5 = 82.5
/// chapterMastery = mean of 10 identical lessons        = 82.5
/// subjectMastery = mean of 15 identical chapters       = 82.5
/// overallMastery = mean of the 4 identical subjects    = 82.5
/// ```
///
/// Uniformity is the point: one number, derivable on paper, checked at full
/// volume — if any layer of the pipeline (restore, snapshot mapping,
/// `Summaries.dashboard`) drops or duplicates rows at scale, 82.5 stops being
/// 82.5. Compare with `closeTo`, not `moreOrLessEquals(0)`: the 0.7/0.3
/// weights are not exact binary fractions, so floating-point noise puts the
/// result a few ulps off the literal.
const double kFixtureOverallMastery = 82.5;

/// Dashboard figures the fixture must produce at [kFixtureNow], also worked
/// out by hand once:
///
/// - Review clocks stagger round-robin over lessons: 10 days ago, 26 days
///   ago, 45 days ago. Against the 30-day cycle that is 200 fresh lessons,
///   200 due within a week (`upcomingReviews`, remaining 4 <= 7) and 200
///   overdue.
/// - Every lesson is examined at 82.5 >= the 70 threshold, so
///   `lessonsRemaining` is 0.
/// - No chapter was ever closed ("أتقنت الباب"), so `masteredChapters` is 0.
const int kFixtureOverdueCount = 200;
const int kFixtureUpcomingReviews = 200;

/// Calendar-safe subtraction/addition of whole days -- the same discipline as
/// `daysBefore` in `instants.dart`. Egypt shifts its clocks, so elapsed-time
/// arithmetic must never stand in for calendar arithmetic.
DateTime _minusDays(DateTime from, int count) =>
    DateTime(from.year, from.month, from.day - count);
DateTime _plusDays(DateTime base, int count) =>
    DateTime(base.year, base.month, base.day + count);

/// Question groups consistent with a percentage over a 20-point paper.
///
/// Real Thanaweya papers mix point values ("٥ أسئلة بدرجتين، ١٠ بدرجة"),
/// which is what the two groups model: 5 questions x 2 points + 10 questions
/// x 1 point = 20 possible. Each row's correct counts are integers that earn
/// exactly [percentage] of those 20 points, because a fixture whose groups
/// contradicted their denormalised percentage would be rehearsing corruption
/// the wizard can never write.
(List<ExamQuestionGroup>, int totalPossible, int correct) _groupsFor(
  int examId,
  int groupIdBase,
  double percentage,
) {
  final int earned = (percentage / 100 * 20).round();
  // Split into (correctA on 2-point questions <= 5) and (correctB on 1-point
  // questions <= 10) such that 2*A + B == earned. All five percentages split
  // cleanly: 50->A3,B4 | 60->A2,B8 | 70->A2,B10 | 80->A3,B10 | 90->A4,B10.
  final Map<double, (int, int)> splits = <double, (int, int)>{
    50: (3, 4),
    60: (2, 8),
    70: (2, 10),
    80: (3, 10),
    90: (4, 10),
  };
  final (int a, int b) = splits[percentage]!;
  assert(2 * a + b == earned);
  return (
    <ExamQuestionGroup>[
      ExamQuestionGroup(
        id: groupIdBase,
        examId: examId,
        pointsPerQuestion: 2,
        questionCount: 5,
        correctCount: a,
      ),
      ExamQuestionGroup(
        id: groupIdBase + 1,
        examId: examId,
        pointsPerQuestion: 1,
        questionCount: 10,
        correctCount: b,
      ),
    ],
    20,
    earned,
  );
}

/// Builds the backup. Deterministic: same input, byte-identical record.
StudyBackup buildYearBackup() {
  var groupId = 1;
  var homeworkId = 1;

  final lessons = <Lesson>[];
  final exams = <ExamEntry>[];
  final homework = <HomeworkEntry>[];
  final chapters = <Chapter>[];

  var globalLesson = 0;
  for (var subject = 0; subject < kFixtureSubjects; subject++) {
    for (var chapter = 0; chapter < kFixtureChaptersPerSubject; chapter++) {
      final chapterId =
          subject * kFixtureChaptersPerSubject + chapter + 1;
      chapters.add(
        Chapter(
          id: chapterId,
          subjectId: subject + 1,
          name: 'مادة ${subject + 1} — باب ${chapter + 1}',
          // Ascending with id, so the snapshot sort is already in insertion
          // order and a tie-break never has to rescue the fixture.
          createdAt: _plusDays(_termStart, chapterId),
        ),
      );

      for (var lesson = 0; lesson < kFixtureLessonsPerChapter; lesson++) {
        final lessonId = (chapterId - 1) * kFixtureLessonsPerChapter + lesson + 1;
        globalLesson++;

        // Round-robin review clocks: fresh / due-this-week / overdue.
        final reviewedAt = switch (globalLesson % 3) {
          0 => _minusDays(kFixtureNow, 10),
          1 => _minusDays(kFixtureNow, 26),
          _ => _minusDays(kFixtureNow, 45),
        };

        lessons.add(
          Lesson(
            id: lessonId,
            chapterId: chapterId,
            name: 'باب $chapterId — درس ${lesson + 1}',
            // Ascending with id across the whole curriculum, and always
            // before every review stamp below -- a lesson must exist before
            // it was proven, even though nothing in the pipeline checks it.
            createdAt: _plusDays(_termStart, globalLesson),
            lastReviewedAt: reviewedAt,
            checklist: LessonChecklist(
              watchedLesson: true,
              readNotes: true,
              didExam: true,
            ),
          ),
        );

        for (var exam = 0; exam < kFixtureExamsPerLesson; exam++) {
          // Index 0 is the oldest paper; the last one (percentage 90) is the
          // newest and carries the lesson's review stamp as its date. Only the
          // first-ever exam on a lesson is not a review exam.
          final ageInExams = kFixtureExamsPerLesson - 1 - exam;
          final percentage = _examPercentagesOldestFirst[exam];
          final examId = (lessonId - 1) * kFixtureExamsPerLesson + exam + 1;
          final (groups, possible, correct) = _groupsFor(
            examId,
            groupId,
            percentage,
          );
          groupId += groups.length;
          exams.add(
            ExamEntry(
              id: examId,
              lessonId: lessonId,
              isReviewExam: exam > 0,
              totalPossiblePoints: possible,
              correctPoints: correct,
              percentage: percentage,
              createdAt: _minusDays(reviewedAt, 35 * ageInExams),
              groups: groups,
            ),
          );
        }

        homework.add(
          HomeworkEntry(
            id: homeworkId++,
            lessonId: lessonId,
            score: 8,
            maxScore: 10,
            createdAt: _minusDays(reviewedAt, 1),
          ),
        );
      }
    }
  }

  return StudyBackup(
    subjects: <Subject>[
      Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
      Subject.seeded(id: 2, code: SubjectCode.physics, sortOrder: 1),
      Subject.seeded(id: 3, code: SubjectCode.chemistry, sortOrder: 2),
      Subject.seeded(id: 4, code: SubjectCode.english, sortOrder: 3),
    ],
    chapters: chapters,
    lessons: lessons,
    exams: exams,
    homework: homework,
    tasks: const <DailyTask>[],
  );
}
