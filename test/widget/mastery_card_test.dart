import 'dart:io';
import 'dart:ui' as ui;

import 'package:ather/core/branding/ather_brand.dart';
import 'package:ather/core/l10n/formatting.dart';
import 'package:ather/core/theme/app_colors.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/subject.dart';
import 'package:ather/domain/services/summaries.dart';
import 'package:ather/presentation/share/mastery_card.dart';
import 'package:ather/presentation/share/widget_raster.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shareable progress card.
///
/// Two things matter about an image built to be posted: that it renders at all
/// away from the screen, and that it does not carry the student's identity out
/// with it.
void main() {
  final DateTime t0 = DateTime.fromMillisecondsSinceEpoch(1754300000000);

  late ui.FlutterView view;

  setUp(() {
    view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
  });

  LessonSummary lesson(
    int id,
    double mastery, {
    required int examCount,
    bool needsReview = false,
  }) =>
      LessonSummary(
        lesson: Lesson(
          id: id,
          chapterId: 1,
          name: 'تركيب الخلية',
          createdAt: t0,
          checklist: const LessonChecklist(
            watchedLesson: false,
            readNotes: false,
            didHomework: false,
            didExam: false,
            reviewedNotes: false,
          ),
        ),
        mastery: mastery,
        examCount: examCount,
        needsReview: needsReview,
        daysOverdue: needsReview ? 5 : 0,
        daysUntilDue: null,
        latestHomeworkPercentage: null,
      );

  DashboardSummary dashboardWith(List<LessonSummary> lessons) {
    final chapter = ChapterSummary(
      chapter: Chapter(
        id: 1,
        subjectId: 1,
        name: 'الباب الأول — الخلية',
        createdAt: t0,
      ),
      mastery: 60,
      lessons: lessons,
      needsReview: false,
      canMaster: false,
      averageExamScore: 60,
    );
    final subject = SubjectSummary(
      subject: const Subject.seeded(
        id: 1,
        code: SubjectCode.biology,
        sortOrder: 0,
      ),
      mastery: 60,
      chapters: <ChapterSummary>[chapter],
      needsReview: false,
      averageExamScore: 60,
      mostRecentChapterId: 1,
      mostRecentLessonId: 1,
    );
    return DashboardSummary(
      subjects: <SubjectSummary>[subject],
      overallMastery: 60,
      masteredChapters: 0,
      totalChapters: 1,
      lessonsRemaining: 1,
      upcomingReviews: 0,
      overdueCount: 0,
      weakestSubject: subject,
      strongestSubject: subject,
    );
  }

  Widget framed({
    required AppColors colors,
    required AtherBrandPalette brand,
    required TextDirection direction,
    List<MasteryCardRow> rows = const <MasteryCardRow>[
      MasteryCardRow(label: 'أحياء', mastery: 82, hasData: true),
      MasteryCardRow(label: 'فيزياء', mastery: 41, hasData: true),
    ],
  }) => Directionality(
    textDirection: direction,
    child: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.noScaling),
      child: DefaultTextStyle(
        style: TextStyle(fontFamily: 'ReadexPro', color: colors.textPrimary),
        child: RepaintBoundary(
          child: MasteryCard(
            title: 'إتقاني في أثر',
            overallLabel: 'الإتقان العام',
            overall: 74,
            lessonsAboveLabel: 'درسان فوق حد الإتقان',
            rows: rows,
            colors: colors,
            brand: brand,
          ),
        ),
      ),
    ),
  );

  Future<ui.Image> render(
    WidgetTester tester, {
    required AppColors colors,
    required AtherBrandPalette brand,
    TextDirection direction = TextDirection.rtl,
  }) async {
    // `runAsync` because `toImage` waits on the engine, and inside a widget
    // test the fake clock never delivers that reply.
    final images = await tester.runAsync(
      () => rasterizeBlocks(
        widget: framed(colors: colors, brand: brand, direction: direction),
        width: MasteryCard.width,
        pixelRatio: 2,
        view: view,
      ),
    );
    return images!.single;
  }

  Future<Set<int>> pixelsOf(WidgetTester tester, ui.Image image) async {
    final data = await tester.runAsync(() => image.toByteData());
    return data!.buffer.asUint32List().toSet();
  }

  group('counting what the card claims', () {
    test('only lessons with an exam behind them are counted', () {
      // A lesson with no exam has a mastery of 0. Counting on the percentage
      // alone would report untouched lessons as failed rather than unmeasured,
      // which is the one thing this app exists not to do.
      final dashboard = dashboardWith(<LessonSummary>[
        lesson(1, 90, examCount: 2),
        lesson(2, 70, examCount: 1),
        lesson(3, 69.9, examCount: 1),
        lesson(4, 0, examCount: 0),
      ]);

      expect(lessonsAboveThreshold(dashboard), 2);
    });

    test('the threshold is inclusive, and is the chapter threshold', () {
      expect(
        lessonsAboveThreshold(dashboardWith(<LessonSummary>[
          lesson(1, 70, examCount: 1),
        ])),
        1,
      );
      expect(
        lessonsAboveThreshold(dashboardWith(<LessonSummary>[
          lesson(1, 69, examCount: 1),
        ])),
        0,
      );
    });

    test('a stale high score is not shared as proven', () {
      // 85% earned forty days ago has decayed -- the dashboard calls it
      // overdue. The card used to count it anyway, so the picture that leaves
      // the phone claimed a lesson the app itself had turned red.
      expect(
        lessonsAboveThreshold(dashboardWith(<LessonSummary>[
          lesson(1, 85, examCount: 2),
          lesson(2, 85, examCount: 2, needsReview: true),
        ])),
        1,
      );
    });

    test('a student with nothing recorded is counted as zero, not as an error',
        () {
      expect(lessonsAboveThreshold(dashboardWith(<LessonSummary>[])), 0);
    });
  });

  group('rendering away from the screen', () {
    testWidgets('produces one image at the card width', (tester) async {
      final image = await render(
        tester,
        colors: AppColors.light,
        brand: AtherBrandPalette.light.withoutPlate,
      );

      expect(image.width, MasteryCard.width * 2);
      expect(image.height, greaterThan(0));
      expect(
        (await pixelsOf(tester, image)).length,
        greaterThan(1),
        reason: 'the card came back a flat fill -- nothing was painted',
      );
      image.dispose();
    });

    testWidgets('light and dark are actually different cards', (tester) async {
      // The card is handed its palette rather than reading an ambient theme,
      // which is exactly the sort of wiring that silently ends up hardcoded.
      final light = await render(
        tester,
        colors: AppColors.light,
        brand: AtherBrandPalette.light.withoutPlate,
      );
      final dark = await render(
        tester,
        colors: AppColors.dark,
        brand: AtherBrandPalette.dark.withoutPlate,
      );

      expect(
        await pixelsOf(tester, light),
        isNot(await pixelsOf(tester, dark)),
      );
      light.dispose();
      dark.dispose();
    });

    testWidgets('renders right-to-left and left-to-right', (tester) async {
      for (final direction in TextDirection.values) {
        final image = await render(
          tester,
          colors: AppColors.light,
          brand: AtherBrandPalette.light.withoutPlate,
          direction: direction,
        );
        expect(image.width, MasteryCard.width * 2);
        expect((await pixelsOf(tester, image)).length, greaterThan(1));
        image.dispose();
      }
    });
  });

  group('the unmeasured is not failed', () {
    testWidgets('an untouched subject is a grey dash, never red 0%',
        (tester) async {
      // The card is the app's one image built to be posted, so it least of
      // all may fail a subject the student never took an exam in: no exam
      // under any lesson means "—", in the same no-data grey every screen
      // uses (P3-12 / audit ح13).
      await tester.pumpWidget(
        framed(
          colors: AppColors.light,
          brand: AtherBrandPalette.light.withoutPlate,
          direction: TextDirection.rtl,
          rows: const <MasteryCardRow>[
            MasteryCardRow(label: 'أحياء', mastery: 82, hasData: true),
            MasteryCardRow(label: 'فيزياء', mastery: 0, hasData: false),
          ],
        ),
      );

      final drawn = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toSet();

      expect(drawn, contains('—'));
      // The dash is not "0%" wearing a disguise: the bare zero-percent string
      // must not be on the card at all. Measured rows keep their numbers.
      expect(drawn, isNot(contains(percent(0))));
      expect(drawn, contains(percent(82)));

      final dashStyle = tester.widget<Text>(find.text('—')).style;
      expect(dashStyle?.color, AppColors.light.textNoData);
    });

    testWidgets('a measured row keeps its live colour', (tester) async {
      // hasData rides per row; passing it must not flatten the verdicts the
      // palette already makes for rows that do have exams behind them.
      await tester.pumpWidget(
        framed(
          colors: AppColors.light,
          brand: AtherBrandPalette.light.withoutPlate,
          direction: TextDirection.rtl,
        ),
      );

      final weak = tester.widget<Text>(find.text(percent(41))).style;
      expect(weak?.color, AppColors.light.wrong);
    });
  });

  group('what the card does not say', () {
    testWidgets('carries no name, no email and no uid', (tester) async {
      // Structural, not cosmetic: every string the card draws is one it was
      // handed. If a future edit reads the profile from a provider, this test
      // is what notices -- the rendered text would stop matching the arguments.
      await tester.pumpWidget(
        framed(
          colors: AppColors.light,
          brand: AtherBrandPalette.light.withoutPlate,
          direction: TextDirection.rtl,
        ),
      );

      final drawn = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toSet();

      // The percentages go through `percent()` rather than being written as
      // literals: that helper wraps them in bidi isolate marks, and a test
      // asserting the bare digits would be asserting the wrong string.
      expect(drawn, <String>{
        'إتقاني في أثر',
        'الإتقان العام',
        'درسان فوق حد الإتقان',
        'أحياء',
        'فيزياء',
        percent(74),
        percent(82),
        percent(41),
      });
    });
  });

  group('the chapter certificate', () {
    testWidgets('draws what it was handed, and nothing else', (tester) async {
      // Same structural rule as the progress card: chapter name and numbers
      // are content, identity is not. If a future edit reaches for a provider,
      // the drawn set stops matching the arguments and this notices.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.noScaling),
            child: DefaultTextStyle(
              style: const TextStyle(fontFamily: 'ReadexPro'),
              child: RepaintBoundary(
                child: ChapterCertificateCard(
                  chapterName: 'الباب الأول — الخلية',
                  closureLabel: 'أُغلِق ${dateLabel(t0)}',
                  examsLabel: '5 امتحانات',
                  masteryLabel: 'الإتقان',
                  mastery: 82,
                  hasData: true,
                  needsReview: false,
                  colors: AppColors.light,
                  brand: AtherBrandPalette.light.withoutPlate,
                ),
              ),
            ),
          ),
        ),
      );

      final drawn = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toSet();

      expect(drawn, <String>{
        'الباب الأول — الخلية',
        'أُغلِق ${dateLabel(t0)}',
        '5 امتحانات',
        'الإتقان',
        percent(82),
      });
    });

    testWidgets('captureAndShare hands the share sheet one stable filename',
        (tester) async {
      // Every dart:io await below sits in `runAsync`: real filesystem calls
      // never deliver inside the test's fake async.
      final tempDir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('ather_test'),
      ))!;
      addTearDown(() => tempDir.delete(recursive: true));

      const providerChannel = MethodChannel('plugins.flutter.io/path_provider');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        providerChannel,
        (call) async =>
            call.method == 'getTemporaryDirectory' ? tempDir.path : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(providerChannel, null),
      );

      // share_plus 10 routes `shareXFiles` through this channel; the file has
      // a real path, so what arrives here is exactly what captureAndShare wrote.
      final shared = <String>[];
      const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        shareChannel,
        (call) async {
          if (call.method == 'shareFiles') {
            final paths =
                (call.arguments as Map<Object?, Object?>)['paths']! as List<Object?>;
            shared.addAll(paths.whereType<String>());
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(shareChannel, null),
      );

      Future<void> share() => tester.runAsync(
            () => captureAndShare(
              widget: framed(
                colors: AppColors.light,
                brand: AtherBrandPalette.light.withoutPlate,
                direction: TextDirection.rtl,
              ),
              width: MasteryCard.width,
              fileNameBase: 'ather_progress',
              pixelRatio: 2,
              view: view,
            ),
          );

      await share();

      expect(shared, hasLength(1));
      expect(File(shared.single).uri.pathSegments.last, 'ather_progress.png');

      final bytes = (await tester.runAsync(
        () => File(shared.single).readAsBytes(),
      ))!;
      expect(bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4e, 0x47],
          reason: 'the file is a PNG, not a half-written buffer');

      // Sharing twice reuses the name rather than collecting files -- which is
      // why the name must be fixed, never derived from names or dates.
      shared.clear();
      await share();
      expect(File(shared.single).uri.pathSegments.last, 'ather_progress.png');
    });
  });
}
