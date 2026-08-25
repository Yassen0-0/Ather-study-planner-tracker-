import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/core/l10n/formatting.dart';
import 'package:ather/core/l10n/generated/app_localizations.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/domain/entities/subject.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:ather/presentation/providers/backup_providers.dart';
import 'package:ather/presentation/providers/task_providers.dart';
import 'package:ather/presentation/review_center/review_center_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/established_install.dart';
import '../support/fake_auth.dart';
import '../support/fake_backup.dart';

final DateTime kNow = DateTime(2026, 6, 1);

/// The four seeded subjects, without a database.
///
/// Two lessons are waiting -- the review centre of audit P3-08: a header that
/// counts them, chips that narrow them to one subject, and one target per row
/// (06-design #10). "تركيب الخلية" proved 40 days ago (10 overdue) and
/// "قوانين نيوتن" proved 35 days ago (5 overdue). Most overdue sorts first,
/// which the order assertions below lean on.
StudySnapshot twoSubjectsWaiting() {
  DateTime reviewedAt(int daysAgo) =>
      kNow.subtract(Duration(days: daysAgo));

  return StudySnapshot(
    subjects: const <Subject>[
      Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
      Subject.seeded(id: 2, code: SubjectCode.physics, sortOrder: 1),
      Subject.seeded(id: 3, code: SubjectCode.chemistry, sortOrder: 2),
      Subject.seeded(id: 4, code: SubjectCode.english, sortOrder: 3),
    ],
    chapters: <Chapter>[
      Chapter(
        id: 1,
        subjectId: 1,
        name: 'الباب الأول',
        createdAt: reviewedAt(40),
      ),
      Chapter(
        id: 2,
        subjectId: 2,
        name: 'الباب الثاني',
        createdAt: reviewedAt(35),
      ),
    ],
    lessons: <Lesson>[
      Lesson(
        id: 1,
        chapterId: 1,
        name: 'تركيب الخلية',
        createdAt: reviewedAt(40),
        lastReviewedAt: reviewedAt(40),
      ),
      Lesson(
        id: 2,
        chapterId: 2,
        name: 'قوانين نيوتن',
        createdAt: reviewedAt(35),
        lastReviewedAt: reviewedAt(35),
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
        createdAt: reviewedAt(40),
      ),
      ExamEntry(
        id: 2,
        lessonId: 2,
        isReviewExam: false,
        totalPossiblePoints: 100,
        correctPoints: 60,
        percentage: 60,
        createdAt: reviewedAt(35),
      ),
    ],
    homework: const <HomeworkEntry>[],
  );
}

Future<void> bootReviewTab(WidgetTester tester, StudySnapshot snapshot) async {
  // Tall enough that both rows mount without scrolling: the list inflates only
  // what layout asks for, so a finder against the second row needs the room.
  tester.view.physicalSize = const Size(390 * 3, 1200 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  // Established install: without the recorded uid the gate reads this seeded
  // record as a legacy hand-over and sheets over the tab bar.
  SharedPreferences.setMockInitialValues(establishedInstallPrefs());
  final preferences = await SharedPreferences.getInstance();
  // Keyed so a second boot in the same test inflates a fresh scope: reusing
  // the element keeps the old container's provider states alive, and the new
  // snapshot stream override never reaches screens built from them.
  final ar = await L.delegate.load(const Locale('ar'));

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
        backupRepositoryProvider.overrideWithValue(
          FakeBackupRepository.failing(),
        ),
        sharedPreferencesProvider.overrideWithValue(preferences),
        snapshotProvider.overrideWith((ref) => Stream.value(snapshot)),
        tasksProvider.overrideWith(
          (ref) => Stream<List<DailyTask>>.value(const <DailyTask>[]),
        ),
        // The production clock ticks every minute to keep "days overdue"
        // honest; here time is pinned to a single emission so no timer
        // outlives the test.
        clockProvider.overrideWithValue(MutableClock(kNow)),
        nowProvider.overrideWith((ref) => Stream<DateTime>.value(kNow)),
      ],
      child: const AtherApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text(ar.navReview));
  await tester.pumpAndSettle();
}

/// Every finder is scoped to the review screen: the shell keeps every tab
/// branch mounted under an opacity switch, so the dashboard's subject rows are
/// in the tree even while this screen is the one showing.
Finder onReviewScreen(Finder finder) =>
    find.descendant(of: find.byType(ReviewCenterScreen), matching: finder);

void main() {
  testWidgets('a waiting header counts the queue, and only when there is one', (
    tester,
  ) async {
    final ar = await L.delegate.load(const Locale('ar'));

    await bootReviewTab(tester, twoSubjectsWaiting());
    expect(
      onReviewScreen(find.text(ar.reviewWaitingHeader(iso('2')))),
      findsOneWidget,
      reason: 'twelve red rows organise themselves once they say how many '
          'they are',
    );

    // An empty queue is a result: the success EmptyState takes over and a
    // "0 درس" counter above a celebration would be counting a victory.
    await bootReviewTab(tester, const StudySnapshot.empty());
    expect(
      onReviewScreen(find.text(ar.reviewWaitingHeader(iso('0')))),
      findsNothing,
    );
    expect(onReviewScreen(find.text(ar.reviewEmptyTitle)), findsOneWidget);
  });

  testWidgets('subject chips narrow the queue and let it back out', (
    tester,
  ) async {
    final ar = await L.delegate.load(const Locale('ar'));

    await bootReviewTab(tester, twoSubjectsWaiting());

    // "كل المواد" leads, analytics-style; a subject with nothing waiting gets
    // no chip at all, so picking one can never leave an empty list behind.
    expect(onReviewScreen(find.text(ar.analyticsAllSubjects)), findsOneWidget);
    expect(onReviewScreen(find.text(ar.subjectPhysics)), findsOneWidget);
    expect(onReviewScreen(find.text(ar.subjectChemistry)), findsNothing);

    double topOf(String lessonName) => tester
        .getTopLeft(onReviewScreen(find.text(lessonName)))
        .dy;

    // Both rows, most overdue first.
    expect(topOf('تركيب الخلية'), lessThan(topOf('قوانين نيوتن')));

    await tester.tap(onReviewScreen(find.text(ar.subjectPhysics)));
    await tester.pumpAndSettle();

    expect(onReviewScreen(find.text('قوانين نيوتن')), findsOneWidget);
    expect(
      onReviewScreen(find.text('تركيب الخلية')),
      findsNothing,
      reason: 'the night before a physics exam, biology rows are noise',
    );

    await tester.tap(onReviewScreen(find.text(ar.analyticsAllSubjects)));
    await tester.pumpAndSettle();

    // Back to everything, in the queue's own order -- the filter narrowed the
    // view, it never reordered it.
    expect(topOf('تركيب الخلية'), lessThan(topOf('قوانين نيوتن')));
  });

  testWidgets('the card is the one way into the exam -- no second button', (
    tester,
  ) async {
    final ar = await L.delegate.load(const Locale('ar'));

    await bootReviewTab(tester, twoSubjectsWaiting());

    // One action, one target (06-design #10): the whole card opens the exam
    // wizard, so a row carrying an "امتحن" pill beside it would say the same
    // thing twice.
    expect(onReviewScreen(find.text(ar.actionExam)), findsNothing);

    // Narrowed to physics, the surviving row still routes through the card.
    await tester.tap(onReviewScreen(find.text(ar.subjectPhysics)));
    await tester.pumpAndSettle();
    await tester.tap(onReviewScreen(find.text('قوانين نيوتن')));
    await tester.pumpAndSettle();

    expect(
      find.text(ar.examStep1Title),
      findsOneWidget,
      reason: 'tapping the row is the exam route, not a detour through the '
          'lesson screen',
    );
  });

  testWidgets('a failed read says so instead of congratulating an empty queue',
      (tester) async {
    final ar = await L.delegate.load(const Locale('ar'));

    // Pumped on its own, not through `bootReviewTab`: the backup gate inside
    // `AtherApp` awaits `snapshotProvider.future` outside its try, so an
    // errored read escapes as an unhandled zone error from a file this
    // workstream does not own (C6's fatal half, reported, not fixed here).
    tester.view.physicalSize = const Size(390 * 3, 1200 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          snapshotProvider.overrideWith(
            (ref) => Stream<StudySnapshot>.error(StateError('disk full')),
          ),
          clockProvider.overrideWithValue(MutableClock(kNow)),
          nowProvider.overrideWith((ref) => Stream<DateTime>.value(kNow)),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            L.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const ReviewCenterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(ar.commonSomethingWentWrong), findsOneWidget);
    expect(
      find.text(ar.reviewEmptyTitle),
      findsNothing,
      reason: 'the green "all caught up" state is a claim about a record this '
          'read never saw (N7/C6)',
    );
  });
}
