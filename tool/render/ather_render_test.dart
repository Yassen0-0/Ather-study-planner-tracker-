// This file lives outside `test/` so `flutter test` skips it, which also puts
// it outside the analyzer's idea of test code -- hence the ignore.
// ignore_for_file: invalid_use_of_visible_for_testing_member
@Tags(<String>['render'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/core/widgets/ather_scaffold.dart';
import 'package:ather/core/widgets/buttons.dart';
import 'package:ather/domain/entities/subject.dart';
import 'package:ather/presentation/common/settings_button.dart';
import 'package:ather/presentation/dashboard/dashboard_screen.dart';
import 'package:ather/presentation/tasks/tasks_screen.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/task_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ather/presentation/providers/backup_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';

import '../../test/support/fake_backup.dart';
import '../../test/support/fake_auth.dart';

/// Renders every screen to a PNG so the design can be eyeballed without a
/// device.
///
/// Deliberately **outside `test/`**, so `flutter test` does not run it: these
/// are visual references, not assertions, and golden bytes differ across
/// machines and Flutter versions. Regenerate on demand with:
///
/// ```
/// flutter test tool/render/ather_render_test.dart --update-goldens
/// ```
///
/// The PNGs land in `tool/render/render/` and are git-ignored.
final DateTime kNow = DateTime(2026, 8, 3);

Future<void> loadFont() async {
  final bytes = await File('assets/fonts/ReadexPro.ttf').readAsBytes();
  final loader = FontLoader('ReadexPro')
    ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  await loader.load();
}

StudySnapshot seeded() {
  DateTime ago(int days) => kNow.subtract(Duration(days: days));

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
        name: 'الباب الأول — الخلية',
        createdAt: ago(70),
        masteredAt: ago(9),
      ),
      Chapter(id: 2, subjectId: 1, name: 'الباب الثاني — الوراثة', createdAt: ago(60)),
      Chapter(id: 3, subjectId: 2, name: 'الباب الأول — الحركة', createdAt: ago(60)),
      Chapter(id: 4, subjectId: 4, name: 'الوحدة الأولى — Grammar', createdAt: ago(40)),
    ],
    lessons: <Lesson>[
      Lesson(id: 1, chapterId: 1, name: 'تركيب الخلية', createdAt: ago(70), lastReviewedAt: ago(9)),
      Lesson(id: 2, chapterId: 1, name: 'الغشاء البلازمي', createdAt: ago(70), lastReviewedAt: ago(10)),
      Lesson(id: 3, chapterId: 2, name: 'قوانين مندل', createdAt: ago(60), lastReviewedAt: ago(24)),
      Lesson(id: 4, chapterId: 3, name: 'قوانين نيوتن للحركة', createdAt: ago(60), lastReviewedAt: ago(46)),
      Lesson(id: 5, chapterId: 3, name: 'الشغل والطاقة', createdAt: ago(60)),
      Lesson(id: 6, chapterId: 4, name: 'Present Perfect Tense', createdAt: ago(40), lastReviewedAt: ago(5)),
    ],
    exams: <ExamEntry>[
      ExamEntry(id: 1, lessonId: 1, isReviewExam: false, totalPossiblePoints: 100, correctPoints: 82, percentage: 82, createdAt: ago(63)),
      ExamEntry(id: 2, lessonId: 1, isReviewExam: false, totalPossiblePoints: 100, correctPoints: 90, percentage: 90, createdAt: ago(9)),
      ExamEntry(id: 3, lessonId: 2, isReviewExam: false, totalPossiblePoints: 100, correctPoints: 91, percentage: 91, createdAt: ago(10)),
      ExamEntry(id: 4, lessonId: 3, isReviewExam: false, totalPossiblePoints: 100, correctPoints: 80, percentage: 80, createdAt: ago(63)),
      ExamEntry(id: 5, lessonId: 3, isReviewExam: false, totalPossiblePoints: 100, correctPoints: 75, percentage: 75, createdAt: ago(24)),
      ExamEntry(id: 6, lessonId: 4, isReviewExam: false, totalPossiblePoints: 100, correctPoints: 58, percentage: 58, createdAt: ago(46)),
      ExamEntry(id: 7, lessonId: 6, isReviewExam: false, totalPossiblePoints: 100, correctPoints: 42, percentage: 42, createdAt: ago(5)),
    ],
    homework: <HomeworkEntry>[
      HomeworkEntry(id: 1, lessonId: 1, score: 9, maxScore: 10, createdAt: ago(12)),
      HomeworkEntry(id: 2, lessonId: 3, score: 4, maxScore: 10, createdAt: ago(25)),
    ],
  );
}

/// A day's worth of tasks, half of them done, so the screen renders with real
/// content rather than as an empty state.
List<DailyTask> seededTasks() {
  final today = dayOf(kNow);
  final yesterday = today.subtract(const Duration(days: 1));
  return <DailyTask>[
    DailyTask(id: 1, day: today, title: 'أذاكر الباب الثاني — الوراثة', done: true, sortOrder: 0, createdAt: kNow),
    DailyTask(id: 2, day: today, title: 'أحل امتحان على قوانين مندل', done: false, sortOrder: 1, createdAt: kNow),
    DailyTask(id: 3, day: today, title: 'أراجع ملخص الغشاء البلازمي', done: false, sortOrder: 2, createdAt: kNow),
    // A fully finished day, so one circle in the strip is filled.
    DailyTask(id: 4, day: yesterday, title: 'واجب الفيزياء', done: true, sortOrder: 0, createdAt: kNow),
  ];
}

Future<Widget> boot() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final preferences = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
      backupRepositoryProvider.overrideWithValue(FakeBackupRepository.failing()),
      sharedPreferencesProvider.overrideWithValue(preferences),
      snapshotProvider.overrideWith((ref) => Stream<StudySnapshot>.value(seeded())),
      // Overridden for the same reason as the snapshot: this harness has no
      // database, and reaching `taskRepositoryProvider` would construct a real
      // one -- which asks path_provider for a directory that does not exist in
      // a widget test.
      tasksProvider.overrideWith((ref) => Stream<List<DailyTask>>.value(seededTasks())),
      clockProvider.overrideWithValue(MutableClock(kNow)),
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(kNow)),
    ],
    child: const AtherApp(),
  );
}

void main() {
  setUpAll(loadFont);

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('render/$name.png'),
    );
  }

  testWidgets('renders every screen', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await boot());
    await shot(tester, '01-dashboard');

    await tester.tap(find.text('أحياء'));
    await shot(tester, '02-subject');

    await tester.tap(find.text('الباب الثاني — الوراثة'));
    await shot(tester, '03-chapter');

    await tester.tap(find.text('قوانين مندل'));
    await shot(tester, '04-lesson');

    await tester.tap(find.text('سجل نتيجة امتحان'));
    await shot(tester, '05-exam-step1');

    await tester.enterText(find.byType(TextField).first, '8');
    await tester.tap(find.text('التالي'));
    await shot(tester, '06-exam-step2');

    await tester.tap(find.text('رجوع'));
    await tester.pumpAndSettle();
    // Back on step 1, "رجوع" leaves the wizard -- and now that there is typed
    // input to lose, leaving asks first. Answering it is part of the script.
    await tester.tap(find.text('رجوع'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('سيبه'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('مراجعة'));
    await shot(tester, '07-review');

    await tester.tap(find.text('تقدمك'));
    await shot(tester, '08-progress');

    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await shot(tester, '09-progress-scrolled');

    await tester.tap(find.text('مهامك'));
    await shot(tester, '10-tasks');

    // Settings is the cog in the header now, not a tab. Scoped to the visible
    // branch: every root screen carries one and they all stay mounted.
    await tester.tap(
      find.descendant(
        of: find.byType(TasksScreen),
        matching: find.byType(SettingsButton),
      ),
    );
    await shot(tester, '10b-settings');
  });

  testWidgets('renders the exam wizard end to end', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await boot());
    await tester.pumpAndSettle();

    await tester.tap(find.text('أحياء'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الباب الثاني — الوراثة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('قوانين مندل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('سجل نتيجة امتحان'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '8');
    await shot(tester, '11-wizard-step1');

    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '5');
    await tester.enterText(fields.at(1), '2');
    await shot(tester, '12-wizard-step2-mismatch');

    await tester.tap(find.text('التالي'));
    await shot(tester, '13-wizard-error');

    await tester.enterText(find.byType(TextField).at(0), '8');
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '6');
    await shot(tester, '14-wizard-step3');

    await tester.tap(find.text('التالي'));
    await shot(tester, '15-wizard-result');
  });

  testWidgets('renders the not-ready sheet and the chapter report',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await boot());
    await tester.pumpAndSettle();

    await tester.tap(find.text('فيزياء'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الباب الأول — الحركة'));
    await tester.pumpAndSettle();
    await shot(tester, '16-chapter-not-ready');

    await tester.tap(find.text('لسه مش جاهز — اعرف ليه'));
    await shot(tester, '17-not-ready-sheet');

    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackChevron));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackChevron));
    await tester.pumpAndSettle();

    await tester.tap(find.text('أحياء'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الباب الأول — الخلية'));
    await tester.pumpAndSettle();
    await shot(tester, '18-chapter-mastered');

    await tester.tap(find.text('شوف تقرير الباب'));
    await shot(tester, '19-chapter-report');
  });

  testWidgets('renders in English', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await boot());
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DashboardScreen),
        matching: find.byType(SettingsButton),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackChevron));
    await shot(tester, '20-dashboard-en');

    // The screens carrying the motion system's own work, in the mirrored
    // layout. The wizard's before/after row in particular has overflowed here
    // before at wide English metrics -- see PROJECT.md §9.
    //
    // Order matters: go_router builds a branch's navigator lazily, and every
    // branch stays mounted once visited (that is what BranchCrossFade needs).
    // Visiting Review first would leave its rows in the tree and make the
    // lesson-name finders below ambiguous.
    await tester.tap(find.text('Biology'));
    await tester.pumpAndSettle();
    // Chapter and lesson names are the student's own data, so they stay
    // Arabic inside an English shell -- which is exactly the mixed-script case
    // worth rendering.
    await tester.tap(find.text('الباب الثاني — الوراثة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('قوانين مندل'));
    await shot(tester, '22-lesson-en');

    await tester.tap(find.text('Log an exam result'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '8');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '8');
    await tester.enterText(fields.at(1), '2');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '6');
    await tester.tap(find.text('Next'));
    await shot(tester, '23-wizard-result-en');

    // The × now asks before throwing away a fully described paper, so closing
    // the wizard is two taps rather than one.
    await tester.tap(find.byType(CircleHeaderButton));
    await tester.pumpAndSettle();
    await shot(tester, '24-wizard-discard-en');
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review'));
    await shot(tester, '21-review-en');
  });
}
