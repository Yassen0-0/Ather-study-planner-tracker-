import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/core/l10n/generated/app_localizations.dart';
import 'package:ather/core/theme/app_theme.dart';
import 'package:ather/core/widgets/ather_icons.dart';
import 'package:ather/core/widgets/buttons.dart';
import 'package:ather/core/widgets/celebration_overlay.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/data/repositories/drift_study_repository.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/presentation/chapter/chapter_screen.dart';
import 'package:ather/presentation/providers/app_providers.dart';

import '../support/instants.dart';

/// The chapter screen's mastery line, against a real database.
///
/// «أتقنته في {date}» in green is a *present-tense* claim, so it is only drawn
/// while the closure's evidence still stands. Once it breaks -- a lesson added
/// after the closure without an exam -- the date survives but drops to a
/// neutral «أُغلِق {date}»: an event that happened, not a quality the chapter
/// still has (audit ك2أ).
void main() {
  final DateTime now = DateTime(2026, 6, 1);

  late AppDatabase db;
  late DriftStudyRepository repo;
  late int chapterId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftStudyRepository(db);
    chapterId = await repo.createChapter(
      subjectId: 1,
      name: 'الباب الأول',
      at: kSeedInstant,
    );
  });

  /// Tears the tree down **inside** the test body, then lets the fake clock
  /// run past the zero-duration timers drift schedules when a watched stream
  /// cancels. Same arrangement as `tasks_test`, for the same reason.
  Future<void> closeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  Widget harness() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(MutableClock(now)),
      // The production clock re-emits every minute; that periodic timer
      // outlives the test binding.
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(now)),
    ],
    // Routed, not `home:`: closing a chapter pushes the chapter report the
    // moment its celebration is dismissed, and that push needs a GoRouter in
    // context -- production always has one, so the harness must too.
    child: MaterialApp.router(
      theme: AppTheme.dark,
      locale: const Locale('ar'),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => ChapterScreen(chapterId: chapterId),
          ),
          GoRoute(
            path: '/chapter/:id/report',
            builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
          ),
        ],
      ),
    ),
  );

  Future<void> addProvenLesson(String name) async {
    final id = await repo.createLesson(
      chapterId: chapterId,
      name: name,
      at: kSeedInstant,
    );
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

  testWidgets('a standing closure wears its date in green', (tester) async {
    await addProvenLesson('أ');
    await addProvenLesson('ب');
    await repo.markChapterMastered(chapterId: chapterId, at: now);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.textContaining('أتقنته في'), findsOneWidget);
    expect(find.byType(CheckDisc), findsOneWidget);
    expect(find.textContaining('أُغلِق'), findsNothing);

    await closeTree(tester);
  });

  testWidgets('when the evidence breaks, the date turns neutral and loses '
      'the tick', (tester) async {
    await addProvenLesson('أ');
    await addProvenLesson('ب');
    await repo.markChapterMastered(chapterId: chapterId, at: now);
    // Created after the closure, never examined: the chapter can no longer
    // claim every lesson examined today.
    await repo.createLesson(
      chapterId: chapterId,
      name: 'جديد',
      at: now.add(const Duration(days: 1)),
    );

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.textContaining('أُغلِق'), findsOneWidget);
    expect(find.textContaining('أتقنته في'), findsNothing);
    expect(find.byType(CheckDisc), findsNothing);
    // The event still happened: its report stays reachable from the gate.
    expect(find.text('تقرير الباب'), findsOneWidget);

    await closeTree(tester);
  });

  testWidgets('a never-closed chapter claims neither line', (tester) async {
    await addProvenLesson('أ');
    await addProvenLesson('ب');

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.textContaining('أتقنته في'), findsNothing);
    expect(find.textContaining('أُغلِق'), findsNothing);

    await closeTree(tester);
  });

  testWidgets('two rapid taps on an earned gate celebrate once', (tester)
      async {
    // The mastery write is one event per tap: closure, celebration, report.
    // A second tap landing inside the write's await used to stack a second
    // celebration over the same closure (audit C2). Both taps are dispatched
    // before the first frame rebuilds, so this is precisely the race the
    // busy flag closes -- the second tap meets a button that no longer takes
    // taps, and the handler refuses it anyway.
    await addProvenLesson('أ');
    await addProvenLesson('ب');

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Earned and not yet closed: the gate is the green «أتقنت الباب».
    final gate = find.byType(PrimaryButton);
    expect(gate, findsOneWidget);

    await tester.tap(gate);
    await tester.tap(gate);
    // The celebration is a dialog that waits for a tap on it -- it never
    // dismisses itself, so pumpAndSettle here would hang forever. Pump a
    // bounded amount of frame time instead, enough for the closure write and
    // the celebration's pop-in to land.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      find.byType(CelebrationOverlay, skipOffstage: false),
      findsOneWidget,
      reason: 'two taps stacked inside one write celebrate exactly once',
    );
    // The chapter really did close underneath -- exactly once.
    final row = await (db.select(
      db.chapters,
    )..where((t) => t.id.equals(chapterId))).getSingleOrNull();
    expect(row?.masteredAt, isNotNull);

    // Dismiss the celebration the way its own tap handler would, then let the
    // report navigation it schedules land -- bounded pumps, since pumpAndSettle
    // would hang while any dialog route is up.
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pop();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await closeTree(tester);
  });
}
