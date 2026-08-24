import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ather/core/l10n/generated/app_localizations.dart';
import 'package:ather/core/theme/app_theme.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/data/repositories/drift_study_repository.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/subject/subject_screen.dart';

import '../support/instants.dart';

/// وضع ليلة الامتحان, end to end from the subject screen's button.
///
/// The harness overrides the two plain providers the screen chain reads
/// (`snapshotValueProvider`, `nowValueProvider`) with a snapshot built through
/// a real (in-memory) database -- the button, the sheet, the tiering and the
/// push into the wizard route are all production widgets.
void main() {
  final DateTime now = DateTime(2026, 6, 1);

  DateTime daysAgo(int n) => DateTime(now.year, now.month, now.day - n, 15);

  Future<StudySnapshot> buildSnapshot(
    Future<void> Function(DriftStudyRepository repo) setup,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = DriftStudyRepository(db);
    try {
      await setup(repo);
      return await repo.readSnapshot();
    } finally {
      await db.close();
    }
  }

  /// A subject holding one row of each tier:
  /// «لم يُثبت» never examined · «ضعيف» weak (40%) · «متأخر» proven, overdue.
  /// Returns the snapshot and the weak lesson's id -- the row the navigation
  /// test taps.
  Future<(StudySnapshot, int)> mixedSnapshot() async {
    var weakLessonId = 0;
    final snapshot = await buildSnapshot((repo) async {
      final chapter = await repo.createChapter(
        subjectId: 1,
        name: 'الباب الأول',
        at: kSeedInstant,
      );
      await repo.createLesson(
        chapterId: chapter,
        name: 'لم يُثبت',
        at: kSeedInstant,
      );
      weakLessonId = await repo.createLesson(
        chapterId: chapter,
        name: 'ضعيف',
        at: kSeedInstant,
      );
      final l103 = await repo.createLesson(
        chapterId: chapter,
        name: 'متأخر',
        at: kSeedInstant,
      );
      await repo.recordExam(
        lessonId: weakLessonId,
        groups: <DraftQuestionGroup>[
          const DraftQuestionGroup(
            pointsPerQuestion: 1,
            questionCount: 100,
            correctCount: 40,
          ),
        ],
        isReviewExam: false,
        at: daysAgo(2),
      );
      await repo.recordExam(
        lessonId: l103,
        groups: <DraftQuestionGroup>[
          const DraftQuestionGroup(
            pointsPerQuestion: 1,
            questionCount: 100,
            correctCount: 85,
          ),
        ],
        isReviewExam: false,
        at: daysAgo(35),
      );
    });
    return (snapshot, weakLessonId);
  }

  Widget harness(StudySnapshot snapshot, {GoRouter? router}) {
    final testRouter =
        router ??
        GoRouter(
          initialLocation: Routes.subjectPath(1),
          routes: <RouteBase>[
            GoRoute(
              path: Routes.subjectPathTemplate,
              builder: (context, state) => SubjectScreen(
                subjectId: int.parse(state.pathParameters['id']!),
              ),
            ),
          ],
        );
    return ProviderScope(
      overrides: [
        snapshotValueProvider.overrideWithValue(snapshot),
        nowValueProvider.overrideWithValue(now),
      ],
      child: MaterialApp.router(
        theme: AppTheme.dark,
        locale: const Locale('ar'),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        routerConfig: testRouter,
      ),
    );
  }

  testWidgets('the three tiers render in order under their headers',
      (tester) async {
    final (snapshot, _) = await mixedSnapshot();
    await tester.pumpWidget(harness(snapshot));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ليلة الامتحان'));
    await tester.pumpAndSettle();

    // All three section headers are up...
    expect(find.text('غير مُثبت — بلا امتحان'), findsOneWidget);
    expect(find.text('الأضعف إتقانًا'), findsOneWidget);
    expect(find.text('الأقرب سقوطًا'), findsOneWidget);

    // ...and the rows sit in tier order. `widgetList` yields matches in
    // document order, so the row titles must come out ① then ② then ③.
    final rowOrder = tester
        .widgetList<Text>(
          find.textContaining(RegExp(r'^لم يُثبت$|^ضعيف$|^متأخر$')),
        )
        .map((t) => t.data)
        .toList();
    expect(rowOrder, <String>['لم يُثبت', 'ضعيف', 'متأخر']);

    // Trailing evidence per tier: «لا امتحان», the score, the overdue line.
    expect(find.text('لا امتحان'), findsOneWidget);
    expect(find.textContaining('40%'), findsOneWidget);
    expect(find.textContaining('متأخّر'), findsWidgets);
  });

  testWidgets('an empty tier shows no header at all', (tester) async {
    final snapshot = await buildSnapshot((repo) async {
      final chapter = await repo.createChapter(
        subjectId: 1,
        name: 'الباب الأول',
        at: kSeedInstant,
      );
      final id = await repo.createLesson(
        chapterId: chapter,
        name: 'وحيد',
        at: kSeedInstant,
      );
      await repo.recordExam(
        lessonId: id,
        groups: <DraftQuestionGroup>[
          const DraftQuestionGroup(
            pointsPerQuestion: 1,
            questionCount: 100,
            correctCount: 90,
          ),
        ],
        isReviewExam: false,
        at: daysAgo(3),
      );
    });

    await tester.pumpWidget(harness(snapshot));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ليلة الامتحان'));
    await tester.pumpAndSettle();

    // Only tier 3 can speak here: nothing unexamined, nothing weak.
    expect(find.text('الأقرب سقوطًا'), findsOneWidget);
    expect(find.text('غير مُثبت — بلا امتحان'), findsNothing);
    expect(find.text('الأضعف إتقانًا'), findsNothing);
  });

  testWidgets('a subject with no lessons gets no button to press',
      (tester) async {
    final snapshot = await buildSnapshot((_) async {});

    await tester.pumpWidget(harness(snapshot));
    await tester.pumpAndSettle();

    expect(find.text('ليلة الامتحان'), findsNothing);
  });

  testWidgets('a row opens the wizard directly, marked from=list',
      (tester) async {
    final router = GoRouter(
      initialLocation: Routes.subjectPath(1),
      routes: <RouteBase>[
        GoRoute(
          path: Routes.subjectPathTemplate,
          builder: (context, state) =>
              SubjectScreen(subjectId: int.parse(state.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/lesson/:id/exam',
          builder: (context, state) => Scaffold(
            body: Text(
              'WIZARD ${state.uri.queryParameters['from']} '
              '${state.pathParameters['id']}',
            ),
          ),
        ),
      ],
    );

    final (snapshot, weakLessonId) = await mixedSnapshot();
    await tester.pumpWidget(harness(snapshot, router: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ليلة الامتحان'));
    await tester.pumpAndSettle();

    // The weak lesson's row -- one tier-2 tap proves the wiring; every row
    // shares it.
    await tester.tap(find.text('ضعيف'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('WIZARD list $weakLessonId'),
      findsOneWidget,
      reason: 'fromLesson:false lands as from=list on the wizard route',
    );
    // And the sheet itself is gone.
    expect(find.text('الأضعف إتقانًا'), findsNothing);
  });
}

/// Route strings local to this harness -- the production `Routes.subject(id)`
/// builds a location, not a pattern, and a pattern is what a GoRoute needs.
abstract final class Routes {
  static String subjectPath(int id) => '/subject/$id';
  static const String subjectPathTemplate = '/subject/:id';
}
