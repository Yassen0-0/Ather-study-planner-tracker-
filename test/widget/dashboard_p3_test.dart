import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/core/l10n/generated/app_localizations.dart';
import 'package:ather/core/widgets/ather_icons.dart';
import 'package:ather/core/widgets/ather_sheet.dart';
import 'package:ather/core/widgets/buttons.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_backup.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/domain/entities/subject.dart';
import 'package:ather/domain/repositories/study_repository.dart';
import 'package:ather/presentation/common/subject_mark.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:ather/presentation/providers/backup_providers.dart';
import 'package:ather/presentation/providers/task_providers.dart';
import 'package:ather/presentation/subject/subject_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth.dart';
import '../support/fake_backup.dart';

final DateTime kNow = DateTime(2026, 6, 1);

/// Numbers reach the screen wrapped in Unicode isolates; a finder must look
/// for what the student actually reads. Escapes, not literals -- pasted raw,
/// they silently reorder this source file in an editor.
String iso(Object value) => '\u2066$value\u2069';

/// Written by the dashboard on every open. Seeding it stands in for "the app
/// was last opened on this day".
const String kLastOpenDayKey = 'last_open_day';

/// Satisfies the one write the dashboard's "+" makes; everything else stays
/// unreachable because [snapshotProvider] itself is overridden. `noSuchMethod`
/// keeps the fake to exactly the members in use, as `_EventsOnlyStudyRepository`
/// does in backup_flush_test.
class _AddOnlyStudyRepository implements StudyRepository {
  int createdSubjects = 0;

  @override
  Future<int> createSubject({required String name}) async {
    createdSubjects++;
    return 42;
  }

  @override
  Stream<StudySnapshot> watchSnapshot() =>
      Stream<StudySnapshot>.value(const StudySnapshot.empty());

  @override
  Future<StudySnapshot> readSnapshot() async => const StudySnapshot.empty();

  @override
  Future<List<StudyEvent>> readEvents() async => const <StudyEvent>[];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

/// The four seeded subjects, without a database.
StudySnapshot snapshotWith({
  List<Chapter> chapters = const <Chapter>[],
  List<Lesson> lessons = const <Lesson>[],
}) {
  return StudySnapshot(
    subjects: const <Subject>[
      Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
      Subject.seeded(id: 2, code: SubjectCode.physics, sortOrder: 1),
      Subject.seeded(id: 3, code: SubjectCode.chemistry, sortOrder: 2),
      Subject.seeded(id: 4, code: SubjectCode.english, sortOrder: 3),
    ],
    chapters: chapters,
    lessons: lessons,
    exams: const <ExamEntry>[],
    homework: const <HomeworkEntry>[],
  );
}

void main() {
  /// Eight days away as of [kNow]: last opened 2026-05-24, back 2026-06-01.
  ///
  /// Lesson 1 was proved 33 days ago and crossed its due date three days into
  /// the absence. Lesson 2 was proved 45 days ago -- already red when the
  /// student left, so it belongs to no comeback count. It is also the more
  /// overdue of the two, which is the one "التالي" points at.
  (StudySnapshot, Map<String, Object>) awayEightDays() => (
    snapshotWith(
      chapters: <Chapter>[
        Chapter(
          id: 1,
          subjectId: 1,
          name: 'الباب الأول',
          createdAt: DateTime(2026, 4, 20),
        ),
      ],
      lessons: <Lesson>[
        Lesson(
          id: 1,
          chapterId: 1,
          name: 'تركيب الخلية',
          createdAt: DateTime(2026, 4, 29),
          lastReviewedAt: DateTime(2026, 4, 29),
        ),
        Lesson(
          id: 2,
          chapterId: 1,
          name: 'التنفس الخلوي',
          createdAt: DateTime(2026, 4, 17),
          lastReviewedAt: DateTime(2026, 4, 17),
        ),
      ],
    ),
    <String, Object>{
      kLastOpenDayKey: DateTime(2026, 5, 24).toIso8601String(),
    },
  );

  Future<void> boot(
    WidgetTester tester,
    StudySnapshot snapshot,
    Map<String, Object> preferences, {
    _AddOnlyStudyRepository? repository,
  }) async {
    // Tall enough that every dashboard section -- the comeback line, the four
    // subject rows and the "التالي" card -- actually mounts: the screen's
    // ListView inflates only what layout asks for, so a finder against
    // below-the-fold content needs the room first.
    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(preferences);
    final stored = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository.signedIn(),
          ),
          backupRepositoryProvider.overrideWithValue(
            FakeBackupRepository.failing(),
          ),
          sharedPreferencesProvider.overrideWithValue(stored),
          studyRepositoryProvider.overrideWithValue(
            repository ?? _AddOnlyStudyRepository(),
          ),
          snapshotProvider.overrideWith((ref) => Stream.value(snapshot)),
          tasksProvider.overrideWith(
            (ref) => Stream<List<DailyTask>>.value(const <DailyTask>[]),
          ),
          clockProvider.overrideWithValue(MutableClock(kNow)),
          nowProvider.overrideWith((ref) => Stream<DateTime>.value(kNow)),
        ],
        child: const AtherApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a return after eight days says so, with the right count', (
    tester,
  ) async {
    final (snapshot, preferences) = awayEightDays();
    await boot(tester, snapshot, preferences);

    // Built from the same localisation the screen reads, so the assertion
    // holds against the copy whatever it says.
    final ar = await L.delegate.load(const Locale('ar'));
    expect(
      find.text(ar.comebackLine(iso('8'), iso('1'))),
      findsOneWidget,
      reason: 'one lesson crossed its due date inside the absence window; '
          'the lesson that was already red before leaving is not part of it',
    );

    // The key moves to today even though the line was shown, so reopening
    // later cannot show the same gap twice.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kLastOpenDayKey), kNow.toIso8601String());
  });

  testWidgets('opening again after one day stays silent', (tester) async {
    final (snapshot, _) = awayEightDays();
    await boot(tester, snapshot, <String, Object>{
      kLastOpenDayKey: DateTime(2026, 5, 31).toIso8601String(),
    });

    // A one-day gap is an ordinary evening, not an absence. If a bug ever
    // showed it anyway, its count could only be zero -- assert exactly that
    // string's absence rather than scanning for any text.
    final ar = await L.delegate.load(const Locale('ar'));
    expect(
      find.text(ar.comebackLine(iso('1'), iso('0'))),
      findsNothing,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kLastOpenDayKey), kNow.toIso8601String());
  });

  testWidgets('a subject row starts at its title, with no leading mark', (
    tester,
  ) async {
    final (snapshot, preferences) = awayEightDays();
    await boot(tester, snapshot, preferences);

    // The per-subject icons beside each row were removed outright on the
    // owner's instruction ("الأيقونات اللي بجانب المواد تتشال خالص",
    // 2026-08-23). `SubjectMark` itself survives for the settings screens,
    // so the class existing proves nothing -- this asserts its absence on
    // the one surface it was asked to leave.
    expect(
      find.byType(SubjectMark),
      findsNothing,
      reason: 'the owner asked for the marks beside the subjects to go '
          'entirely; a reintroduced mark here is a reverted decision',
    );
    expect(find.text('أحياء'), findsOneWidget);
  });

  testWidgets('the next card names the subject and chapter of its lesson', (
    tester,
  ) async {
    final (snapshot, preferences) = awayEightDays();
    await boot(tester, snapshot, preferences);

    // "التالي" points at the most overdue lesson, which here is lesson 2 --
    // and a bare name like this exists in more than one subject, so the card
    // must say where it lives before asking for an exam.
    expect(find.text('التنفس الخلوي'), findsOneWidget);
    expect(find.text('أحياء · الباب الأول'), findsOneWidget);
  });

  testWidgets('adding a subject lands you inside the new subject', (
    tester,
  ) async {
    final (snapshot, preferences) = awayEightDays();
    final repository = _AddOnlyStudyRepository();
    await boot(tester, snapshot, preferences, repository: repository);

    // The "+" beside the subjects heading. Found by glyph rather than a
    // test-only key: asserting on the glyph is asserting on what the student
    // actually sees.
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is AtherIcon && widget.glyph == AtherGlyph.plus,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'تاريخ');
    await tester.tap(
      find.descendant(
        of: find.byType(AtherSheetBody),
        matching: find.byType(PrimaryButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.createdSubjects, 1);
    expect(
      find.byType(SubjectScreen),
      findsOneWidget,
      reason: 'the id createSubject returns is the route into the new '
          'subject -- an eager student must not be left on the dashboard',
    );
  });
}
