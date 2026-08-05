import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/summaries.dart';
import 'app_providers.dart';

/// Screen-shaped views over the snapshot.
///
/// Every screen reads a summary rather than calling the calculators itself, so
/// a lesson's mastery is computed once per snapshot instead of once per widget
/// rebuild, and no two screens can derive the same number differently.

/// The three figures in the dashboard's stat row.
///
/// All three share the same denominator — every lesson the student has created
/// — so the row reads as one picture of the same set rather than three
/// unrelated numbers. "متقن" deliberately excludes overdue lessons: a lesson
/// that scored 95% two months ago is not currently mastered.
final class HomeStats {
  const HomeStats({
    required this.totalLessons,
    required this.remaining,
    required this.overdue,
    required this.mastered,
  });

  final int totalLessons;
  final int remaining;
  final int overdue;
  final int mastered;

  double fraction(int value) => totalLessons == 0 ? 0 : value / totalLessons;
}

final homeStatsProvider = Provider<HomeStats>((ref) {
  final dashboard = ref.watch(dashboardProvider);

  var total = 0;
  var examined = 0;
  var overdue = 0;
  var mastered = 0;

  for (final subject in dashboard.subjects) {
    for (final chapter in subject.chapters) {
      for (final lesson in chapter.lessons) {
        total++;
        if (lesson.hasExam) examined++;
        if (lesson.needsReview) overdue++;
        if (lesson.hasExam && !lesson.needsReview && lesson.mastery >= 90) {
          mastered++;
        }
      }
    }
  }

  return HomeStats(
    totalLessons: total,
    remaining: total - examined,
    overdue: overdue,
    mastered: mastered,
  );
});

final dashboardProvider = Provider<DashboardSummary>((ref) {
  return Summaries.dashboard(
    ref.watch(snapshotValueProvider),
    ref.watch(nowValueProvider),
  );
});

final subjectSummaryProvider = Provider.family<SubjectSummary?, int>((
  ref,
  subjectId,
) {
  final snapshot = ref.watch(snapshotValueProvider);
  final subject = snapshot.subjectById(subjectId);
  if (subject == null) return null;
  return Summaries.subject(snapshot, subject, ref.watch(nowValueProvider));
});

final chapterSummaryProvider = Provider.family<ChapterSummary?, int>((
  ref,
  chapterId,
) {
  final snapshot = ref.watch(snapshotValueProvider);
  final chapter = snapshot.chapterById(chapterId);
  if (chapter == null) return null;
  return Summaries.chapter(snapshot, chapter, ref.watch(nowValueProvider));
});

final lessonSummaryProvider = Provider.family<LessonSummary?, int>((
  ref,
  lessonId,
) {
  final snapshot = ref.watch(snapshotValueProvider);
  final lesson = snapshot.lessonById(lessonId);
  if (lesson == null) return null;
  return Summaries.lesson(snapshot, lesson, ref.watch(nowValueProvider));
});

/// The chapter a lesson belongs to -- needed by the lesson screen's breadcrumb
/// and by the exam wizard when it reports which chapter was affected.
final chapterOfLessonProvider = Provider.family<ChapterSummary?, int>((
  ref,
  lessonId,
) {
  final snapshot = ref.watch(snapshotValueProvider);
  final lesson = snapshot.lessonById(lessonId);
  if (lesson == null) return null;
  return ref.watch(chapterSummaryProvider(lesson.chapterId));
});
