import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/core/l10n/generated/app_localizations.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/domain/entities/subject.dart';
import 'package:ather/presentation/analytics/analytics_screen.dart';
import 'package:ather/presentation/dashboard/dashboard_screen.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:ather/presentation/providers/backup_providers.dart';
import 'package:ather/presentation/providers/task_providers.dart';
import 'package:ather/presentation/review_center/review_center_screen.dart';
import 'package:ather/presentation/tasks/tasks_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth.dart';
import '../support/fake_backup.dart';

// T2a cold-start guard. The shell keeps every visited tab alive so scroll
// positions survive switches -- but that must never mean "builds every tab on
// cold start". Boot pays for the dashboard alone; Review, Analytics and Tasks
// join the tree the first time their tab is picked, and stay mounted after.
//
// This is the failing-if-slow check for the boot path expressed as mount
// counts rather than wall-clock: wall time fails CI on a slow runner, a
// wrongly-mounted screen fails it everywhere, deterministically.

final DateTime kNow = DateTime(2026, 6, 1);

StudySnapshot _emptySnapshot() => StudySnapshot(
  subjects: const <Subject>[
    Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
    Subject.seeded(id: 2, code: SubjectCode.physics, sortOrder: 1),
    Subject.seeded(id: 3, code: SubjectCode.chemistry, sortOrder: 2),
    Subject.seeded(id: 4, code: SubjectCode.english, sortOrder: 3),
  ],
  chapters: const <Chapter>[],
  lessons: const <Lesson>[],
  exams: const <ExamEntry>[],
  homework: const <HomeworkEntry>[],
);

Future<Widget> _boot() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final preferences = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
      backupRepositoryProvider.overrideWithValue(
        FakeBackupRepository.failing(),
      ),
      sharedPreferencesProvider.overrideWithValue(preferences),
      snapshotProvider.overrideWith(
        (ref) => Stream<StudySnapshot>.value(_emptySnapshot()),
      ),
      tasksProvider.overrideWith(
        (ref) => Stream<List<DailyTask>>.value(const <DailyTask>[]),
      ),
      clockProvider.overrideWithValue(MutableClock(kNow)),
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(kNow)),
    ],
    child: const AtherApp(),
  );
}

void main() {
  testWidgets('cold start builds the dashboard tab only', (tester) async {
    await tester.pumpWidget(await _boot());
    await tester.pump();
    await tester.pump();

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(ReviewCenterScreen), findsNothing);
    expect(find.byType(AnalyticsScreen), findsNothing);
    expect(find.byType(TasksScreen), findsNothing);
  });

  testWidgets('a tab mounts on first visit and stays mounted after', (
    tester,
  ) async {
    await tester.pumpWidget(await _boot());
    await tester.pump();
    await tester.pump();

    final l = L.of(tester.element(find.byType(DashboardScreen)));

    await tester.tap(find.text(l.navReview));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewCenterScreen), findsOneWidget);

    // Back to Home: Review stays alive (that is the state-preservation deal),
    // and the two never-visited tabs are still not in the tree.
    await tester.tap(find.text(l.navHome));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewCenterScreen), findsOneWidget);
    expect(find.byType(AnalyticsScreen), findsNothing);
    expect(find.byType(TasksScreen), findsNothing);

    // First visit to Analytics mounts it mid-fade; the cross-fade still plays
    // because the outer AnimatedOpacity was already at 0 for this slot.
    await tester.tap(find.text(l.navProgress));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(AnalyticsScreen), findsOneWidget);
  });
}
