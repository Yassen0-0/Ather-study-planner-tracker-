import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/lesson.dart';
import '../../domain/services/review_cycle_service.dart';
import 'app_providers.dart';

/// The single lesson the app thinks the student should sit next.
final class NextTarget {
  const NextTarget({
    required this.lesson,
    required this.subjectId,
    required this.chapterId,
    required this.isOverdue,
    required this.hasExam,
    required this.daysOverdue,
  });

  final Lesson lesson;
  final int subjectId;
  final int chapterId;
  final bool isOverdue;
  final bool hasExam;
  final int daysOverdue;
}

/// What the dashboard's "اللي بعده" card points at: the most overdue lesson,
/// else the first lesson with no exam at all.
///
/// Null when neither exists — which is the honest answer, and why the card
/// disappears instead of inventing a task.
final nextTargetProvider = Provider<NextTarget?>((ref) {
  final snapshot = ref.watch(snapshotValueProvider);
  final now = ref.watch(nowValueProvider);

  NextTarget? build(Lesson lesson) {
    final chapter = snapshot.chapterById(lesson.chapterId);
    if (chapter == null) return null;
    return NextTarget(
      lesson: lesson,
      chapterId: chapter.id,
      subjectId: chapter.subjectId,
      isOverdue: ReviewCycleService.needsReview(lesson, now),
      hasExam: snapshot.examsFor(lesson.id).isNotEmpty,
      daysOverdue: ReviewCycleService.daysOverdue(lesson, now),
    );
  }

  // Walk chapters rather than the flat lesson list so the order the student
  // built their curriculum in is the order the app offers it back.
  final ordered = <Lesson>[
    for (final subject in snapshot.activeSubjects)
      for (final chapter in snapshot.chaptersIn(subject.id))
        ...snapshot.lessonsIn(chapter.id),
  ];
  if (ordered.isEmpty) return null;

  Lesson? mostOverdue;
  var worst = -1;
  for (final lesson in ordered) {
    final days = ReviewCycleService.daysOverdue(lesson, now);
    if (ReviewCycleService.needsReview(lesson, now) && days > worst) {
      worst = days;
      mostOverdue = lesson;
    }
  }
  if (mostOverdue != null) return build(mostOverdue);

  for (final lesson in ordered) {
    if (snapshot.examsFor(lesson.id).isEmpty) return build(lesson);
  }

  return null;
});

/// Where the tab bar's black "+" lands.
///
/// The same target as the dashboard card, but falling back to the first lesson
/// once everything has been examined and nothing is overdue. The "+" is the
/// shortest path from "I just sat a paper" to "it is recorded", so it must
/// never be a dead end while any lesson exists.
final quickExamTargetProvider = Provider<NextTarget?>((ref) {
  final next = ref.watch(nextTargetProvider);
  if (next != null) return next;

  final snapshot = ref.watch(snapshotValueProvider);
  final now = ref.watch(nowValueProvider);
  for (final subject in snapshot.activeSubjects) {
    for (final chapter in snapshot.chaptersIn(subject.id)) {
      for (final lesson in snapshot.lessonsIn(chapter.id)) {
        return NextTarget(
          lesson: lesson,
          chapterId: chapter.id,
          subjectId: subject.id,
          isOverdue: ReviewCycleService.needsReview(lesson, now),
          hasExam: snapshot.examsFor(lesson.id).isNotEmpty,
          daysOverdue: ReviewCycleService.daysOverdue(lesson, now),
        );
      }
    }
  }
  return null;
});
