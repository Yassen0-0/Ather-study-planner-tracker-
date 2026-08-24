import 'package:flutter_test/flutter_test.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/domain/entities/subject.dart';
import 'package:ather/domain/services/review_cycle_service.dart';

/// A Monday. The Thursday four days later -- where the pile-up below lands --
/// is `anchor + 3`.
final DateTime kAnchor = DateTime(2026, 6, 1);

Lesson proven(int id, int daysAgo) => Lesson(
  id: id,
  chapterId: 1,
  name: 'درس $id',
  createdAt: DateTime(2026, 1, 1),
  lastReviewedAt: kAnchor.subtract(Duration(days: daysAgo)),
);

StudySnapshot snapshotWith(List<Lesson> lessons) => StudySnapshot(
  subjects: const <Subject>[
    Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
  ],
  chapters: <Chapter>[
    Chapter(id: 1, subjectId: 1, name: 'الباب الأول', createdAt: kAnchor),
  ],
  lessons: lessons,
  exams: const <ExamEntry>[],
  homework: const <HomeworkEntry>[],
);

void main() {
  group('upcomingDueDistribution', () {
    test('four lessons pile up on the same Thursday, the stragglers sorted out',
        () {
      expect(kAnchor.add(const Duration(days: 3)).weekday, DateTime.thursday,
          reason: 'the scenario is named for the day the collision lands on');

      final snapshot = snapshotWith(<Lesson>[
        // The Thursday four: each proven 27 days ago, so all four turn due
        // together three calendar days from now.
        for (var i = 1; i <= 4; i++) proven(i, 27),
        // One the day after -- present, but in its own column.
        proven(5, 26),
        // Overdue: no "until due" left, so it never plots. It is already a
        // red row in the list underneath.
        proven(6, 40),
        // Never examined: nothing can fall due that was never proven.
        Lesson(
          id: 7,
          chapterId: 1,
          name: 'درس 7',
          createdAt: kAnchor,
        ),
        // Due in 25 days: real, and deliberately out of frame.
        proven(8, 5),
      ]);

      expect(
        ReviewCycleService.upcomingDueDistribution(snapshot, kAnchor),
        <int, int>{3: 4, 4: 1},
      );
    });

    test('day 14 is the edge of the frame -- in, while day 15 stays out', () {
      final snapshot = snapshotWith(<Lesson>[
        proven(1, 16), // 30 - 16 = 14: the last column.
        proven(2, 15), // 30 - 15 = 15: past it, invisible here.
      ]);

      expect(
        ReviewCycleService.upcomingDueDistribution(snapshot, kAnchor),
        <int, int>{14: 1},
      );
    });

    test('nothing upcoming means an empty map -- the chart has nothing to say',
        () {
      final snapshot = snapshotWith(<Lesson>[
        proven(1, 40), // overdue
        proven(2, 3), // due in 27 days, beyond the window
      ]);

      expect(
        ReviewCycleService.upcomingDueDistribution(snapshot, kAnchor),
        isEmpty,
      );
    });
  });
}
