import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/core/l10n/generated/app_localizations.dart';
import 'package:ather/core/theme/app_theme.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/data/repositories/drift_study_repository.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/presentation/lesson/lesson_screen.dart';
import 'package:ather/presentation/providers/app_providers.dart';

import '../support/instants.dart';

void main() {
  final DateTime now = DateTime(2026, 6, 1);

  /// Numbers reach the screen wrapped in Unicode isolates; a finder must look
  /// for what the student actually reads. Escapes, not literals -- pasted raw,
  /// they silently reorder this source file in an editor.
  String iso(Object value) => '\u2066$value\u2069';

  late AppDatabase db;
  late DriftStudyRepository repo;
  late int lessonId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftStudyRepository(db);
    final chapterId = await repo.createChapter(
      subjectId: 1,
      name: 'الباب الأول',
      at: kSeedInstant,
    );
    lessonId = await repo.createLesson(
      chapterId: chapterId,
      name: 'الدايركت كيرنت',
      at: kSeedInstant,
    );
  });

  /// Tears the tree down **inside** the test body, then lets the fake clock
  /// run past the zero-duration timers drift schedules when a watched stream
  /// cancels. Same arrangement as `chapter_badge_test`, for the same reason.
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
    child: MaterialApp(
      theme: AppTheme.dark,
      locale: const Locale('ar'),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: LessonScreen(lessonId: lessonId),
    ),
  );

  Future<void> tickAllSteps() => repo.updateChecklist(
    lessonId: lessonId,
    checklist: const LessonChecklist(
      watchedLesson: true,
      readNotes: true,
      didHomework: true,
      didExam: true,
      reviewedNotes: true,
    ),
  );

  Future<void> recordExamAt(int percentage, DateTime at) => repo.recordExam(
    lessonId: lessonId,
    groups: <DraftQuestionGroup>[
      DraftQuestionGroup(
        pointsPerQuestion: 1,
        questionCount: 100,
        correctCount: percentage,
      ),
    ],
    isReviewExam: false,
    at: at,
  );

  testWidgets('a partial checklist keeps counting', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text(iso('0 / 5')), findsOneWidget);
    final ar = await L.delegate.load(const Locale('ar'));
    expect(find.text(ar.checklistAllDone), findsNothing);

    await closeTree(tester);
  });

  testWidgets('five of five with no exam says the sentence, not the count', (
    tester,
  ) async {
    await tickAllSteps();
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final ar = await L.delegate.load(const Locale('ar'));
    expect(find.text(ar.checklistAllDone), findsOneWidget);
    expect(find.text(iso('5 / 5')), findsNothing);

    await closeTree(tester);
  });

  testWidgets('with an exam behind it, 5/5 stays a count', (tester) async {
    await recordExamAt(80, now.subtract(const Duration(days: 1)));
    // recordExam stamps the didExam step itself; the other four are the
    // student's own ticks.
    await tickAllSteps();
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text(iso('5 / 5')), findsOneWidget);
    final ar = await L.delegate.load(const Locale('ar'));
    expect(find.text(ar.checklistAllDone), findsNothing);

    await closeTree(tester);
  });
}
