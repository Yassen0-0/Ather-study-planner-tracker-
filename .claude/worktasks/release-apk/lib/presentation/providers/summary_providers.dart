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
/// unrelated numbers. The third figure is «متفوق»: lessons whose proof is both
/// strong (≥ 90) and fresh. It is derived by [LessonSummary.isExcellent] in the
/// domain; this row only counts it.
final class HomeStats {
  const HomeStats({
    required this.totalLessons,
    required this.remaining,
    required this.overdue,
    required this.excellent,
  });

  final int totalLessons;
  final int remaining;
  final int overdue;
  final int excellent;

  double fraction(int value) => totalLessons == 0 ? 0 : value / totalLessons;
}

final homeStatsProvider = Provider<HomeStats>((ref) {
  final dashboard = ref.watch(dashboardProvider);

  var total = 0;
  var examined = 0;
  var overdue = 0;
  var excellent = 0;

  for (final subject in dashboard.subjects) {
    for (final chapter in subject.chapters) {
      for (final lesson in chapter.lessons) {
        total++;
        if (lesson.hasExam) examined++;
        if (lesson.needsReview) overdue++;
        if (lesson.isExcellent) excellent++;
      }
    }
  }

  return HomeStats(
    totalLessons: total,
    remaining: total - examined,
    overdue: overdue,
    excellent: excellent,
  );
});

final dashboardProvider = Provider<DashboardSummary>((ref) {
  return Summaries.dashboard(
    ref.watch(snapshotValueProvider),
    ref.watch(nowValueProvider),
  );
});

// Verified statically (audit P2-07): nothing keeps `dashboardProvider` alive
// across tabs anymore. Its only listeners are `homeStatsProvider` above --
// itself watched only by the dashboard screen -- the dashboard screen, and the
// analytics screen. Each lives inside one tab branch of `AppShell`, where
// `BranchCrossFade` wraps hidden branches in `TickerMode(enabled: false)`;
// flutter_riverpod 3.4.2 pauses a ConsumerWidget's `ref.watch` subscriptions
// under TickerMode (`consumer.dart`, `_updateTickerMode`), the element goes
// inactive, and `onCancel` stops the upstream snapshot subscription -- so the
// whole chain above stops recomputing for writes made from another tab. The
// shell's own badge watches `reviewQueueProvider` (an O(lessons) pass over the
// snapshot), not this provider -- that was audit finding P1, fixed by P1-03.
//
// What remains true: the *state* stays cached while the tab is hidden (these
// are keepAlive providers by default in 3.x), and switching back replays
// anything missed. Only the compute moves out of the hidden tabs' way.

final subjectSummaryProvider = Provider.autoDispose.family<SubjectSummary?, int>((
  ref,
  subjectId,
) {
  final snapshot = ref.watch(snapshotValueProvider);
  final subject = snapshot.subjectById(subjectId);
  if (subject == null) return null;
  return Summaries.subject(snapshot, subject, ref.watch(nowValueProvider));
});

final chapterSummaryProvider = Provider.autoDispose.family<ChapterSummary?, int>((
  ref,
  chapterId,
) {
  final snapshot = ref.watch(snapshotValueProvider);
  final chapter = snapshot.chapterById(chapterId);
  if (chapter == null) return null;
  return Summaries.chapter(snapshot, chapter, ref.watch(nowValueProvider));
});

final lessonSummaryProvider = Provider.autoDispose.family<LessonSummary?, int>((
  ref,
  lessonId,
) {
  final snapshot = ref.watch(snapshotValueProvider);
  final lesson = snapshot.lessonById(lessonId);
  if (lesson == null) return null;
  return Summaries.lesson(snapshot, lesson, ref.watch(nowValueProvider));
});

// The three families above are `.autoDispose` on purpose (audit P2-03, ج2-أ).
// In riverpod 3.4.2 the manual provider API defaults to keepAlive
// (`isAutoDispose = false`), and there is no family eviction: every
// lesson/chapter/subject id a student ever opened kept its element and cached
// summary until process death -- unbounded memory accumulation, dragging any
// chained lookups with it. autoDispose disposes an element when its last
// listener goes away, which is exactly a screen closing.
//
// The accepted trade: memoization is lost between visits, so reopening a
// screen recomputes its O(lesson/chapter/subject) summary. That is cheap next
// to what the screen does anyway, and correctness is untouched -- every call
// site consumes these through `ref.watch` during build (and the wizard's one
// `ref.read` in `_save` runs while its own build still holds a watch open), so
// elements stay alive for as long as their screen is on the stack.
