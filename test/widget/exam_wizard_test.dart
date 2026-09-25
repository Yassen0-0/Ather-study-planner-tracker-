import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/instants.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/core/l10n/generated/app_localizations.dart';
import 'package:ather/core/theme/app_theme.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/data/exam_draft_store.dart';
import 'package:ather/data/repositories/drift_study_repository.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/mastery.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/domain/repositories/study_repository.dart';
import 'package:ather/domain/services/mastery_calculator.dart';
import 'package:ather/domain/services/review_cycle_service.dart';
import 'package:ather/domain/services/summaries.dart';
import 'package:ather/core/widgets/animated_percentage.dart';
import 'package:ather/core/widgets/mastery_bar.dart';
import 'package:ather/presentation/exam_entry/exam_entry_screen.dart';
import 'package:ather/presentation/providers/app_providers.dart';

/// Numbers are rendered wrapped in Unicode isolates so they read correctly
/// inside Arabic sentences; a finder has to look for the same thing the user
/// sees, isolates and all.
String iso(String value) => '\u2066$value\u2069';

/// Exercises the rules the exam wizard and the "أتقنت الباب" button enforce,
/// against a real database rather than a mocked one.
void main() {
  late AppDatabase db;
  late DriftStudyRepository repo;
  // Set by the widget tests, which drain drift's timers themselves by closing
  // inside the test body -- the binding checks for pending timers before
  // tearDown runs.
  var dbClosedByTest = false;
  final now = DateTime(2026, 6, 1);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftStudyRepository(db);
    dbClosedByTest = false;
  });

  tearDown(() async {
    if (!dbClosedByTest) await db.close();
  });

  group('exam arithmetic as the wizard computes it', () {
    test('mixed point groups produce the right percentage', () {
      // "5 أسئلة بدرجة واحدة، 3 أسئلة بدرجتين", 4 and 2 correct.
      const groups = <ExamQuestionGroup>[
        ExamQuestionGroup(
          id: 1,
          examId: 1,
          pointsPerQuestion: 1,
          questionCount: 5,
          correctCount: 4,
        ),
        ExamQuestionGroup(
          id: 2,
          examId: 1,
          pointsPerQuestion: 2,
          questionCount: 3,
          correctCount: 2,
        ),
      ];

      // possible 5*1 + 3*2 = 11; earned 4*1 + 2*2 = 8
      expect(ExamEntry.percentageOf(groups), closeTo(72.7272, 0.001));
    });

    test('an all-correct exam is exactly 100%', () {
      const groups = <ExamQuestionGroup>[
        ExamQuestionGroup(
          id: 1,
          examId: 1,
          pointsPerQuestion: 3,
          questionCount: 7,
          correctCount: 7,
        ),
      ];
      expect(ExamEntry.percentageOf(groups), 100);
    });

    test('an all-wrong exam is 0%, not NaN', () {
      const groups = <ExamQuestionGroup>[
        ExamQuestionGroup(
          id: 1,
          examId: 1,
          pointsPerQuestion: 2,
          questionCount: 4,
          correctCount: 0,
        ),
      ];
      expect(ExamEntry.percentageOf(groups), 0);
      expect(ExamEntry.percentageOf(groups).isNaN, isFalse);
    });

    test('higher-value questions weigh more than low-value ones', () {
      // Same number of questions right, but on the heavier group.
      const heavyRight = <ExamQuestionGroup>[
        ExamQuestionGroup(
          id: 1,
          examId: 1,
          pointsPerQuestion: 1,
          questionCount: 5,
          correctCount: 0,
        ),
        ExamQuestionGroup(
          id: 2,
          examId: 1,
          pointsPerQuestion: 5,
          questionCount: 5,
          correctCount: 5,
        ),
      ];
      const lightRight = <ExamQuestionGroup>[
        ExamQuestionGroup(
          id: 1,
          examId: 1,
          pointsPerQuestion: 1,
          questionCount: 5,
          correctCount: 5,
        ),
        ExamQuestionGroup(
          id: 2,
          examId: 1,
          pointsPerQuestion: 5,
          questionCount: 5,
          correctCount: 0,
        ),
      ];

      expect(
        ExamEntry.percentageOf(heavyRight),
        greaterThan(ExamEntry.percentageOf(lightRight)),
      );
    });
  });

  group('review exam flow end to end', () {
    test('an overdue lesson clears once a review exam is recorded', () async {
      final chapterId = await repo.createChapter(
        subjectId: 1,
        name: 'الباب الأول',
        at: kSeedInstant,
      );
      final lessonId = await repo.createLesson(
        chapterId: chapterId,
        name: 'درس',
        at: kSeedInstant,
      );

      // Proven 40 days ago -> decayed.
      await repo.recordExam(
        lessonId: lessonId,
        groups: const <DraftQuestionGroup>[
          DraftQuestionGroup(
            pointsPerQuestion: 1,
            questionCount: 100,
            correctCount: 85,
          ),
        ],
        isReviewExam: false,
        at: now.subtract(const Duration(days: 40)),
      );

      var snapshot = await repo.readSnapshot();
      expect(
        ReviewCycleService.needsReview(snapshot.lessons.single, now),
        isTrue,
      );
      expect(
        ReviewCycleService.chapterNeedsReview(snapshot, chapterId, now),
        isTrue,
        reason: 'one decayed lesson reddens the whole chapter',
      );

      // The student sits the review exam.
      await repo.recordExam(
        lessonId: lessonId,
        groups: const <DraftQuestionGroup>[
          DraftQuestionGroup(
            pointsPerQuestion: 1,
            questionCount: 100,
            correctCount: 95,
          ),
        ],
        isReviewExam: true,
        at: now,
      );

      snapshot = await repo.readSnapshot();
      expect(
        ReviewCycleService.needsReview(snapshot.lessons.single, now),
        isFalse,
        reason: 'a review exam is the only thing that clears decay',
      );
      expect(
        ReviewCycleService.chapterNeedsReview(snapshot, chapterId, now),
        isFalse,
      );

      // Mastery recomputes with the review exam as "last": 95*0.7 + 85*0.3.
      expect(
        MasteryCalculator.lessonMastery(snapshot.examsFor(lessonId)),
        closeTo(92, 1e-9),
      );
      expect(snapshot.examsFor(lessonId).first.isReviewExam, isTrue);
    });
  });

  group('chapter completion guard', () {
    test('blocks, then celebrates once every lesson clears 70%', () async {
      final chapterId = await repo.createChapter(
        subjectId: 1,
        name: 'باب',
        at: kSeedInstant,
      );
      final a = await repo.createLesson(
        chapterId: chapterId,
        name: 'أ',
        at: kSeedInstant,
      );
      final b = await repo.createLesson(
        chapterId: chapterId,
        name: 'ب',
        at: kSeedInstant,
      );

      // Nothing examined yet.
      var snapshot = await repo.readSnapshot();
      expect(ReviewCycleService.canMasterChapter(snapshot, chapterId), isFalse);
      expect(
        ReviewCycleService.chapterBlockers(snapshot, chapterId),
        hasLength(2),
      );

      // One strong lesson; the other still unexamined.
      await repo.recordExam(
        lessonId: a,
        groups: const <DraftQuestionGroup>[
          DraftQuestionGroup(
            pointsPerQuestion: 1,
            questionCount: 100,
            correctCount: 90,
          ),
        ],
        isReviewExam: false,
        at: now,
      );
      snapshot = await repo.readSnapshot();
      expect(
        ReviewCycleService.canMasterChapter(snapshot, chapterId),
        isFalse,
        reason: 'an unexamined lesson blocks regardless of the others',
      );

      // Second lesson examined but weak -> chapter average 55, still short.
      await repo.recordExam(
        lessonId: b,
        groups: const <DraftQuestionGroup>[
          DraftQuestionGroup(
            pointsPerQuestion: 1,
            questionCount: 100,
            correctCount: 20,
          ),
        ],
        isReviewExam: false,
        at: now,
      );
      snapshot = await repo.readSnapshot();
      expect(ReviewCycleService.canMasterChapter(snapshot, chapterId), isFalse);

      final blockers = ReviewCycleService.chapterBlockers(snapshot, chapterId);
      expect(blockers, hasLength(1));
      expect(blockers.single.lesson.name, 'ب');

      // Retake lifts it: 80*0.7 + 20*0.3 = 62 -> chapter (90+62)/2 = 76.
      await repo.recordExam(
        lessonId: b,
        groups: const <DraftQuestionGroup>[
          DraftQuestionGroup(
            pointsPerQuestion: 1,
            questionCount: 100,
            correctCount: 80,
          ),
        ],
        isReviewExam: false,
        at: now.add(const Duration(days: 1)),
      );
      snapshot = await repo.readSnapshot();

      expect(
        MasteryCalculator.chapterMasteryOf(snapshot, chapterId),
        closeTo(76, 1e-9),
      );
      expect(ReviewCycleService.canMasterChapter(snapshot, chapterId), isTrue);

      // The gate is the *chapter average*, so a chapter can qualify at 76%
      // while one lesson still sits at 62%. `chapterBlockers` keeps listing
      // that lesson -- it answers "what is weakest here", and is only ever
      // rendered when the gate fails, so the two never contradict on screen.
      final remaining = ReviewCycleService.chapterBlockers(snapshot, chapterId);
      expect(remaining, hasLength(1));
      expect(remaining.single.mastery, closeTo(62, 1e-9));
    });

    test('mastering restarts the review clock on every lesson', () async {
      final chapterId = await repo.createChapter(
        subjectId: 1,
        name: 'باب',
        at: kSeedInstant,
      );
      for (var i = 0; i < 3; i++) {
        final id = await repo.createLesson(
          chapterId: chapterId,
          name: 'د$i',
          at: kSeedInstant,
        );
        await repo.recordExam(
          lessonId: id,
          groups: const <DraftQuestionGroup>[
            DraftQuestionGroup(
              pointsPerQuestion: 1,
              questionCount: 100,
              correctCount: 88,
            ),
          ],
          isReviewExam: false,
          at: now.subtract(const Duration(days: 20)),
        );
      }

      await repo.markChapterMastered(chapterId: chapterId, at: now);
      final snapshot = await repo.readSnapshot();

      expect(snapshot.chapterById(chapterId)!.isMastered, isTrue);
      for (final lesson in snapshot.lessons) {
        expect(lesson.lastReviewedAt, now);
        expect(ReviewCycleService.daysUntilDue(lesson, now), 30);
      }
    });
  });

  group('summaries stay consistent with the calculators', () {
    test(
      'a chapter summary reports the same numbers as the raw services',
      () async {
        final chapterId = await repo.createChapter(
          subjectId: 2,
          name: 'باب',
          at: kSeedInstant,
        );
        final a = await repo.createLesson(
          chapterId: chapterId,
          name: 'أ',
          at: kSeedInstant,
        );
        await repo.createLesson(
          chapterId: chapterId,
          name: 'ب',
          at: kSeedInstant,
        );
        await repo.recordExam(
          lessonId: a,
          groups: const <DraftQuestionGroup>[
            DraftQuestionGroup(
              pointsPerQuestion: 1,
              questionCount: 100,
              correctCount: 60,
            ),
          ],
          isReviewExam: false,
          at: now,
        );

        final snapshot = await repo.readSnapshot();
        final summary = Summaries.chapter(
          snapshot,
          snapshot.chapterById(chapterId)!,
          now,
        );

        expect(
          summary.mastery,
          closeTo(
            MasteryCalculator.chapterMasteryOf(snapshot, chapterId),
            1e-9,
          ),
        );
        expect(summary.lessonCount, 2);
        expect(summary.examinedLessonCount, 1);
        expect(summary.canMaster, isFalse);
        expect(summary.weakestLesson!.lesson.name, 'ب');
      },
    );

    test(
      'the dashboard counts remaining lessons and mastered chapters',
      () async {
        final chapterId = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        final strong = await repo.createLesson(
          chapterId: chapterId,
          name: 'قوي',
          at: kSeedInstant,
        );
        await repo.createLesson(
          chapterId: chapterId,
          name: 'بدون',
          at: kSeedInstant,
        );
        await repo.recordExam(
          lessonId: strong,
          groups: const <DraftQuestionGroup>[
            DraftQuestionGroup(
              pointsPerQuestion: 1,
              questionCount: 100,
              correctCount: 92,
            ),
          ],
          isReviewExam: false,
          at: now,
        );

        final snapshot = await repo.readSnapshot();
        final dashboard = Summaries.dashboard(snapshot, now);

        expect(dashboard.totalChapters, 1);
        expect(dashboard.masteredChapters, 0);
        // Only the unexamined lesson still counts as remaining.
        expect(dashboard.lessonsRemaining, 1);
        expect(dashboard.strongestSubject!.subject.id, 1);
        expect(dashboard.overdueCount, 0);
      },
    );
  });

  // C1: "what do I need next time?" is asked before the save, so the paper on
  // screen is part of the history the NEXT paper will stand on. The mean must
  // count it; before this fix a first paper always read an empty history and
  // was told 100% no matter what it had just scored.
  group('score needed after this paper', () {
    ExamEntry recorded(double percentage) => ExamEntry(
      id: 1,
      lessonId: 7,
      isReviewExam: false,
      totalPossiblePoints: 10,
      correctPoints: 0,
      percentage: percentage,
      createdAt: now,
    );

    test('a first paper at 50% asks 79, not 100', () {
      // Mean of {50} = 50: (70 - 0.3*50)/0.7 = 78.57 -> 79.
      expect(
        scoreNeededAfterPaper(existing: const <ExamEntry>[], paperPercentage: 50),
        79,
      );
    });

    test('a recorded 90 and this paper at 20 average to 55 -> 77', () {
      // Mean of {90, 20} = 55: (70 - 0.3*55)/0.7 = 76.43 -> 77. Reading the
      // recorded 90 alone would have promised 62 -- too low to cross.
      expect(
        scoreNeededAfterPaper(
          existing: <ExamEntry>[recorded(90)],
          paperPercentage: 20,
        ),
        77,
      );
      expect(
        77 * kRecentWeight + 55 * kHistoryWeight,
        greaterThanOrEqualTo(kChapterMasteryThreshold),
      );
    });

    test('equals the calculator fed the mean of every paper', () {
      final existing = <ExamEntry>[recorded(30), recorded(45)];
      expect(
        scoreNeededAfterPaper(existing: existing, paperPercentage: 60),
        MasteryCalculator.scoreNeededToCross(meanOfExisting: 45),
      );
    });
  });

  // P3-04: the wizard is the one screen holding data that exists nowhere
  // else yet. These exercise the two guards around it: the draft that
  // survives process death, and the back press arriving while a save is in
  // flight.
  group('wizard draft and back guard', () {
    const lessonId = 7;
    const draftKey = 'exam_draft_$lessonId';

    /// Pumps a minimal host with the wizard pushed on top of it.
    ///
    /// The host page exists so the wizard has somewhere to pop back to when a
    /// save completes; [repository] lets a test park the write in flight.
    Future<void> pumpWizard(
      WidgetTester tester,
      SharedPreferences preferences, {
      StudyRepository? repository,
    }) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
          ),
          GoRoute(
            path: '/wizard',
            builder: (_, _) => const ExamEntryScreen(
              lessonId: lessonId,
              openedFromLesson: true,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            databaseProvider.overrideWithValue(db),
            clockProvider.overrideWithValue(MutableClock(now)),
            nowProvider.overrideWith((ref) => Stream<DateTime>.value(now)),
            studyRepositoryProvider.overrideWithValue(
              repository ?? DriftStudyRepository(db),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            locale: const Locale('ar'),
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      router.push('/wizard');
      await tester.pumpAndSettle();
    }

    /// Drives the wizard to step 3 with the paper described (5 × 2 marks).
    Future<void> fillToStep3(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).first, '5');
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '5');
      await tester.enterText(fields.at(1), '2');
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
    }

    Future<void> fillToStep4(WidgetTester tester) async {
      // Step 1: five questions.
      await tester.enterText(find.byType(TextField).first, '5');
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      // Step 2: five questions worth two marks each -- sums match.
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), '5');
      await tester.enterText(fields.at(1), '2');
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      // Step 3: three of them right -> 6 of 10 points -> 60%. One pump so
      // the button re-arms from the typed text before the tap lands.
      await tester.enterText(find.byType(TextField).first, '3');
      await tester.pump();
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      // Two legitimate bearers of the number on step 4: the big counted-up
      // result and the "after" side of the before→after card.
      expect(find.text(iso('60%')), findsExactly(2));

      // Drafts are written on a trailing debounce (PF2); move past it so the
      // store's pending write has landed in prefs.
      await tester.pump(kExamDraftWriteDelay);
    }

    testWidgets(
      'a draft that lost part of a group is discarded, not half-applied',
      (tester) async {
        // A truncation that keeps the JSON parseable: the second group entry
        // is one field short. Restoring the surviving half would show a paper
        // the student cannot complete -- the numbers they typed are gone.
        SharedPreferences.setMockInitialValues(<String, Object>{
          draftKey: jsonEncode(<String, Object?>{
            'total': '20',
            'groups': <Object?>[
              <String>['5', '2', '3'],
              <String>['6', '2'],
            ],
          }),
        });
        final preferences = await SharedPreferences.getInstance();

        await pumpWizard(tester, preferences);

        // The whole draft went: an empty wizard is honest about what survived.
        expect(find.text('20'), findsNothing);
        expect(find.text('5'), findsNothing);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, isEmpty);

        dbClosedByTest = true;
        await db.close();
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'a typed count that exceeds the group still explains itself (N9 parity)',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final preferences = await SharedPreferences.getInstance();

        await pumpWizard(tester, preferences);
        await fillToStep3(tester);

        // Nine right of five asked: the blank gate passes -- a number WAS
        // typed -- and the exceeds banner says what is wrong instead of the
        // button going quietly inert.
        await tester.enterText(find.byType(TextField).first, '9');
        await tester.tap(find.text('التالي'));
        await tester.pumpAndSettle();
        expect(
          find.text('عدد الإجابات الصحيحة لا يتجاوز عدد الأسئلة'),
          findsOneWidget,
        );

        dbClosedByTest = true;
        await db.close();
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'pausing the app flushes the draft without waiting for the debounce',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final preferences = await SharedPreferences.getInstance();

        await pumpWizard(tester, preferences);
        await tester.enterText(find.byType(TextField).first, '5');
        await tester.pump();

        // Not one debounce window has passed -- the trailing write is still
        // pending. Pausing is a loss boundary, so the store must flush now.
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();

        expect(preferences.getString(draftKey), isNotNull);
        final decoded =
            jsonDecode(preferences.getString(draftKey)!)
                as Map<dynamic, dynamic>;
        expect(decoded['total'], '5');

        dbClosedByTest = true;
        await db.close();
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'tearing the wizard down flushes its pending draft',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final preferences = await SharedPreferences.getInstance();

        await pumpWizard(tester, preferences);
        await tester.enterText(find.byType(TextField).first, '7');
        await tester.pump();

        // Dispose with the debounce still armed; only a blink of fake time
        // passes afterwards -- far less than kExamDraftWriteDelay.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 10));

        expect(preferences.getString(draftKey), isNotNull);

        dbClosedByTest = true;
        await db.close();
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'a killed process leaves the paper intact for the next open',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final preferences = await SharedPreferences.getInstance();

        // Session one: describe the paper.
        await pumpWizard(tester, preferences);
        await fillToStep4(tester);

        // Every keystroke landed in prefs under this lesson's key.
        final String raw = preferences.getString(draftKey)!;
        final Object? decoded = jsonDecode(raw);
        expect(decoded, isA<Map<dynamic, dynamic>>());
        expect(
          (decoded! as Map<dynamic, dynamic>)['groups'],
          isNotEmpty,
        );

        // Process death: tear everything down and reopen cold.
        await tester.pumpWidget(const SizedBox());
        await pumpWizard(tester, preferences);

        // The numbers are simply still there -- silently, on step 1.
        expect(find.text('5'), findsOneWidget);
        await tester.tap(find.text('التالي'));
        await tester.pumpAndSettle();
        expect(find.text('5'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        await tester.tap(find.text('التالي'));
        await tester.pumpAndSettle();
        expect(find.text('3'), findsOneWidget);

        dbClosedByTest = true;
        await db.close();
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'a blank correct count cannot silently record an all-wrong paper',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final preferences = await SharedPreferences.getInstance();

        await pumpWizard(tester, preferences);
        await fillToStep3(tester);

        // Step 3 arrives with the correct-count field still blank. Tapping
        // Next must go nowhere: a blank used to parse as 0 and an unfinished
        // form saved itself as a paper answered entirely wrong.
        expect(find.byType(TextField), findsOneWidget);
        await tester.tap(find.text('التالي'));
        await tester.pumpAndSettle();
        expect(find.byType(ExamEntryScreen), findsOneWidget);
        expect(find.text(iso('0%')), findsNothing);

        // Entering the count re-arms Next, and the flow completes normally:
        // 3 of 5 right at two points each -> 60%. One pump lets the button
        // rebuild from the typed text before the tap.
        await tester.enterText(find.byType(TextField).first, '3');
        await tester.pump();
        await tester.tap(find.text('التالي'));
        await tester.pumpAndSettle();
        expect(find.text(iso('60%')), findsExactly(2));

        dbClosedByTest = true;
        await db.close();
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'step 4: the bar and the number land on one beat (SP-04أ)',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final preferences = await SharedPreferences.getInstance();

        await pumpWizard(tester, preferences);

        // Steps 1–3 have no entrance of their own to wait out.
        await tester.enterText(find.byType(TextField).first, '5');
        await tester.tap(find.text('التالي'));
        await tester.pumpAndSettle();
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), '5');
        await tester.enterText(fields.at(1), '2');
        await tester.tap(find.text('التالي'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, '3');
        // One pump so the gated Next re-arms from the typed count.
        await tester.pump();

        double step4BarFill() => tester
            .widget<FractionallySizedBox>(
              find.descendant(
                of: find.byType(MasteryBar),
                matching: find.byType(FractionallySizedBox),
              ),
            )
            .widthFactor!;

        // Arrive at step 4 and hold time manually -- a pumpAndSettle here
        // would skip straight past the moment under test.
        await tester.tap(find.text('التالي'));
        await tester.pump(const Duration(milliseconds: 50));

        // Inside the lead-in: the bar is empty and the count has not even
        // mounted. Before this fix the bar stood pre-filled from frame one.
        expect(step4BarFill(), 0.0);
        expect(find.byType(CountUpFromZero), findsNothing);

        // t≈300ms: both mid-flight. The big number is still counting, so only
        // the "after" side of the before→after card carries 60%.
        await tester.pump(const Duration(milliseconds: 250));
        final fill = step4BarFill();
        expect(fill, greaterThan(0));
        expect(fill, lessThan(0.6), reason: 'the fill must still be travelling');
        expect(find.text(iso('60%')), findsExactly(1));

        await tester.pumpAndSettle();
        expect(find.text(iso('60%')), findsExactly(2));
        expect(step4BarFill(), closeTo(0.6, 0.001));

        dbClosedByTest = true;
        await db.close();
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'step 4 on a first paper asks what the next one needs from THIS history',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final preferences = await SharedPreferences.getInstance();

        await pumpWizard(tester, preferences);
        // The lesson has no recorded exams; this paper scores 60%.
        await fillToStep4(tester);
        await tester.pumpAndSettle();

        // Mean of {60} = 60: (70 - 0.3*60)/0.7 = 74.29 -> 75. The old call
        // site averaged the empty record set to 0 and always said 100%.
        expect(find.textContaining(iso('75%')), findsOneWidget);
        expect(find.textContaining(iso('100%')), findsNothing);

        dbClosedByTest = true;
        await db.close();
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'system back during the save does not flip the step or lose the draft',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final preferences = await SharedPreferences.getInstance();

        final gate = Completer<int>();
        await pumpWizard(
          tester,
          preferences,
          repository: _HangingExamRepository(repo, gate),
        );
        await fillToStep4(tester);

        await tester.tap(find.text('احفظ النتيجة'));
        await tester.pump(); // _saving flips on; the write is parked.

        // The system back gesture arrives mid-write.
        final NavigatorState navigator = tester.state(
          find.byType(Navigator).first,
        );
        await navigator.maybePop();
        await tester.pump();

        // Nothing moved: still on step 4, write unfinished, draft intact.
        expect(find.byType(ExamEntryScreen), findsOneWidget);
        expect(preferences.getString(draftKey), isNotNull);

        gate.complete(1);
        await tester.pumpAndSettle();

        // The write lands, the wizard pops home, and the draft's job is done.
        expect(find.byType(ExamEntryScreen), findsNothing);
        expect(preferences.getString(draftKey), isNull);

        // Let the saved-toast retire itself; its timer outlives the test.
        await tester.pump(const Duration(seconds: 3));

        dbClosedByTest = true;
        await db.close();
        await tester.pump(const Duration(seconds: 1));
      },
    );
  });
}

/// A repository whose `recordExam` parks until a test releases it -- the
/// widget-side stand-in for "the write is in flight". Everything else is
/// forwarded to the real repository; anything unexpected fails loudly.
class _HangingExamRepository implements StudyRepository {
  _HangingExamRepository(this._inner, this._gate);

  final StudyRepository _inner;
  final Completer<int> _gate;

  @override
  Future<int> recordExam({
    required int lessonId,
    required List<DraftQuestionGroup> groups,
    required bool isReviewExam,
    required DateTime at,
  }) =>
      _gate.future;

  @override
  Stream<StudySnapshot> watchSnapshot() => _inner.watchSnapshot();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
