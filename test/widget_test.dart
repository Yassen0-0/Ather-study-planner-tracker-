import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/core/l10n/formatting.dart';
import 'package:ather/core/l10n/generated/app_localizations.dart';
import 'package:ather/core/widgets/ather_scaffold.dart';
import 'package:ather/core/widgets/list_entrance.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/domain/entities/subject.dart';
import 'package:ather/presentation/common/settings_button.dart';
import 'package:ather/presentation/dashboard/dashboard_screen.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ather/presentation/providers/auth_providers.dart';

import 'support/fake_auth.dart';

final DateTime kNow = DateTime(2026, 6, 1);

/// The four seeded subjects, without a database.
///
/// These tests exercise the presentation layer, so drift is deliberately kept
/// out: it contributes stream-query machinery whose timers outlive the test
/// binding, and its behaviour is already covered by the tests in
/// `test/data/drift_study_repository_test.dart`.
StudySnapshot snapshotWith({
  List<Chapter> chapters = const <Chapter>[],
  List<Lesson> lessons = const <Lesson>[],
  List<ExamEntry> exams = const <ExamEntry>[],
  List<HomeworkEntry> homework = const <HomeworkEntry>[],
}) {
  return StudySnapshot(
    subjects: const <Subject>[
      Subject(id: 1, code: SubjectCode.biology, sortOrder: 0),
      Subject(id: 2, code: SubjectCode.physics, sortOrder: 1),
      Subject(id: 3, code: SubjectCode.chemistry, sortOrder: 2),
      Subject(id: 4, code: SubjectCode.english, sortOrder: 3),
    ],
    chapters: chapters,
    lessons: lessons,
    exams: exams,
    homework: homework,
  );
}

Future<Widget> bootApp({StudySnapshot? snapshot}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final preferences = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      // Signed in from the start: these tests are about the study screens,
      // and the auth gate is covered on its own in test/widget/auth_test.dart.
      authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
      sharedPreferencesProvider.overrideWithValue(preferences),
      snapshotProvider.overrideWith(
        (ref) => Stream<StudySnapshot>.value(snapshot ?? snapshotWith()),
      ),
      // The production clock ticks every minute to keep "days overdue" honest;
      // in a widget test that periodic timer outlives the tree and trips
      // "A Timer is still pending", so time is pinned to a single emission.
      clockProvider.overrideWithValue(MutableClock(kNow)),
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(kNow)),
    ],
    child: const AtherApp(),
  );
}

/// An overdue lesson: proven 40 days ago, past the 30-day cycle.
StudySnapshot overdueSnapshot() {
  final reviewedAt = kNow.subtract(const Duration(days: 40));
  return snapshotWith(
    chapters: <Chapter>[
      Chapter(id: 1, subjectId: 1, name: 'الباب الأول', createdAt: reviewedAt),
    ],
    lessons: <Lesson>[
      Lesson(
        id: 1,
        chapterId: 1,
        name: 'تركيب الخلية',
        createdAt: reviewedAt,
        lastReviewedAt: reviewedAt,
      ),
    ],
    exams: <ExamEntry>[
      ExamEntry(
        id: 1,
        lessonId: 1,
        isReviewExam: false,
        totalPossiblePoints: 100,
        correctPoints: 85,
        percentage: 85,
        createdAt: reviewedAt,
      ),
    ],
  );
}

/// One lesson, proven today at 74%. Nothing has decayed, so 74 is what every
/// level of the tree reports -- lesson, chapter, subject and the dashboard.
StudySnapshot freshExamSnapshot() {
  return snapshotWith(
    chapters: <Chapter>[
      Chapter(id: 1, subjectId: 1, name: 'الباب الأول', createdAt: kNow),
    ],
    lessons: <Lesson>[
      Lesson(
        id: 1,
        chapterId: 1,
        name: 'تركيب الخلية',
        createdAt: kNow,
        lastReviewedAt: kNow,
      ),
    ],
    exams: <ExamEntry>[
      ExamEntry(
        id: 1,
        lessonId: 1,
        isReviewExam: false,
        totalPossiblePoints: 100,
        correctPoints: 74,
        percentage: 74,
        createdAt: kNow,
      ),
    ],
  );
}

void main() {
  testWidgets('boots in Arabic RTL and switches to English LTR', (tester) async {
    // Tall enough to hold all four subject rows without scrolling; the default
    // 800x600 test surface cuts the list off after the first one.
    tester.view.physicalSize = const Size(390 * 3, 1000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await bootApp());
    await tester.pumpAndSettle();

    // Arabic is the default, and the tree must actually be laid out RTL --
    // asserting only on strings would miss a non-mirroring layout bug.
    expect(find.text('أحياء'), findsWidgets);
    expect(
      Directionality.of(tester.element(find.text('أحياء').first)),
      TextDirection.rtl,
    );
    expect(find.text('فيزياء'), findsWidgets);
    expect(find.text('كيمياء'), findsWidgets);
    expect(find.text('إنجليزي'), findsWidgets);

    // Settings is reached from the cog in the header. The "المزيد" tab that
    // used to carry it is gone -- its slot is the tasks screen now -- and the
    // cog is scoped to the dashboard because every root screen has one.
    await tester.tap(
      find.descendant(
        of: find.byType(DashboardScreen),
        matching: find.byType(SettingsButton),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    // Settings is pushed over the shell; return to the dashboard to confirm the
    // language propagated through the whole tree, not just the settings page.
    // The header uses the design's own circular chevron, not Material's.
    await tester.tap(find.byType(BackChevron));
    await tester.pumpAndSettle();

    expect(find.text('Biology'), findsWidgets);
    expect(
      Directionality.of(tester.element(find.text('Biology').first)),
      TextDirection.ltr,
      reason: 'switching to English must flip layout direction, not just text',
    );
  });

  testWidgets('a fresh install shows "—", never a red 0%', (tester) async {
    await tester.pumpWidget(await bootApp());
    await tester.pumpAndSettle();

    // The central product rule of the redesign: unproven is not weak. A student
    // who just installed the app must not be shown four failing subjects.
    expect(find.text('—'), findsWidgets);
    expect(find.text('0%'), findsNothing);
    expect(find.text('لسه مبدأتش'), findsWidgets);
  });

  testWidgets('an overdue lesson is called out on the dashboard',
      (tester) async {
    await tester.pumpWidget(await bootApp(snapshot: overdueSnapshot()));
    await tester.pumpAndSettle();

    expect(
      find.text('فات ميعاد مراجعة درس'),
      findsOneWidget,
      reason: 'decay must be visible without opening the Review tab',
    );
    // The tab-bar badge carries the count.
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('the review centre offers the exam directly', (tester) async {
    await tester.pumpWidget(await bootApp(snapshot: overdueSnapshot()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('مراجعة'));
    await tester.pumpAndSettle();

    expect(find.text('تركيب الخلية'), findsOneWidget);
    expect(
      find.text('امتحن'),
      findsWidgets,
      reason: 'there is one thing to do about an overdue lesson, so the row '
          'offers it rather than routing through a detail screen',
    );
  });

  testWidgets('an empty review queue is a result, not a task', (tester) async {
    await tester.pumpWidget(await bootApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('مراجعة'));
    await tester.pumpAndSettle();

    expect(find.text('مفيش حاجة محتاجة مراجعة'), findsOneWidget);
    expect(find.text('كل دروسك في وقتها. استمر.'), findsOneWidget);
  });

  testWidgets('renders without overflow on a small phone viewport',
      (tester) async {
    // A narrow, short window is where fixed-height rows break.
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await bootApp(snapshot: overdueSnapshot()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion lands on the final state in one frame', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 1000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: await bootApp(snapshot: freshExamSnapshot()),
      ),
    );

    // Deliberately pump() and not pumpAndSettle(): the point of reduced motion
    // is that there is nothing left to settle. An animation that is merely
    // faster still fails this.
    await tester.pump();

    // Every staggered row goes through RiseIn, so it must be in the tree --
    // otherwise the assertion below passes by finding nothing to check.
    expect(find.byType(RiseIn), findsWidgets);

    // ...and under reduced motion RiseIn returns its child untouched, so it
    // must contribute no opacity or transform layer of its own. Scoped to
    // RiseIn's own subtree deliberately: the route transition and the tab
    // cross-fade sit above it and legitimately keep their (zero-duration)
    // fades.
    expect(
      find.descendant(
        of: find.byType(RiseIn),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
      // Not asserted on Transform: Pressable puts one inside every row, so a
      // Transform under RiseIn proves nothing either way. The fade is the
      // layer RiseIn itself contributes, and its absence is the contract.
      reason: 'a staggered entrance must not run under reduced motion',
    );

    // And the number is already its final value, not mid-count.
    expect(find.text('${kLri}74%$kPdi'), findsWidgets);
  });

  test('ARB keys resolve in both locales', () async {
    final ar = await L.delegate.load(const Locale('ar'));
    final en = await L.delegate.load(const Locale('en'));

    expect(ar.appName, 'Ather');
    expect(en.appName, 'Ather');
    expect(ar.dashboardTitle, 'النهارده');
    expect(ar.masterChapter, 'أتقنت الباب');
    expect(en.examErrorCorrectExceeds, isNotEmpty);
  });

  test('Arabic plurals follow the real rules, not "1 دروس"', () async {
    final ar = await L.delegate.load(const Locale('ar'));

    expect(ar.lessonCount(1), 'درس واحد');
    expect(ar.lessonCount(2), 'درسين');
    expect(ar.lessonCount(5), '5 دروس');
    expect(ar.lessonCount(11), '11 درس');
    expect(ar.chapterCount(1), 'باب واحد');
    expect(ar.chapterCount(2), 'بابين');
    expect(ar.chapterCount(3), '3 أبواب');
  });
}
