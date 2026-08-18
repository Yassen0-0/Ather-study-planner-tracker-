import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/l10n/formatting.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/mastery_palette.dart';
import '../../core/widgets/ather_card.dart';
import '../../core/widgets/ather_scaffold.dart';
import '../../core/widgets/mastery_bar.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/ather_toast.dart';
import '../../core/widgets/buttons.dart';
import '../../domain/entities/exam_entry.dart';
import '../../domain/services/pdf_export_service.dart';
import '../../domain/services/summaries.dart';
import '../providers/app_providers.dart';
import '../providers/summary_providers.dart';
import '../share/widget_raster.dart';

/// What the chapter actually looks like now that it is closed.
///
/// The trend line here used to say "you improved" whatever happened. It now
/// tells the truth in three states — up, down, or not enough evidence — because
/// a report that only ever congratulates is not a report.
class ChapterReportScreen extends ConsumerStatefulWidget {
  const ChapterReportScreen({super.key, required this.chapterId});

  final int chapterId;

  @override
  ConsumerState<ChapterReportScreen> createState() =>
      _ChapterReportScreenState();
}

class _ChapterReportScreenState extends ConsumerState<ChapterReportScreen> {
  bool _exporting = false;

  /// Draws the report a second time, away from the screen, and puts it in a PDF.
  ///
  /// Drawn again rather than photographed where it stands, because what stands
  /// on screen is a scrolling list: only the rows inside the viewport are ever
  /// painted, so capturing it would export whichever four lessons the student
  /// happened to be looking at. See [rasterizeBlocks].
  Future<void> _export(
    ChapterSummary summary,
    List<LessonSummary> ranked,
  ) async {
    if (_exporting) return;

    final l = L.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    final direction = Directionality.of(context);
    final theme = Theme.of(context);
    final view = View.of(context);

    setState(() => _exporting = true);
    try {
      // One image per block -- the summary card, then one per lesson row --
      // because the PDF breaks pages between blocks and never through one.
      final images = await rasterizeBlocks(
        widget: _PrintableReport(
          l: l,
          theme: theme,
          direction: direction,
          summary: summary,
          exams: _examsOf(summary),
          ranked: ranked,
        ),
        // A4 minus its margins, at the width the app itself uses for a card.
        // The PDF scales each block onto the page, so this decides how the
        // text wraps, not how large it ends up.
        width: 520,
        // Roughly 200 dpi once scaled onto A4: sharp on a phone and sharp
        // enough from a home printer, without a file too large to send.
        pixelRatio: 2.5,
        view: view,
      );

      final blocks = <PdfBlock>[];
      for (final image in images) {
        blocks.add(
          PdfBlock(
            png: await encodePng(image),
            aspectRatio: image.width / image.height,
          ),
        );
        image.dispose();
      }

      const service = PdfExportService();
      await service.share(
        await service.build(blocks),
        service.buildFilename(summary.chapter.name, DateTime.now()),
      );
    } on Object catch (error, stack) {
      debugPrint('Ather: chapter report export failed -- $error');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        showAtherToastOn(
          overlay,
          direction,
          l.chapterReportExportError,
          tone: ToastTone.failed,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  List<ExamEntry> _examsOf(ChapterSummary summary) {
    final snapshot = ref.read(snapshotValueProvider);
    return <ExamEntry>[
      for (final lesson in summary.lessons)
        ...snapshot.examsFor(lesson.lesson.id),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final summary = ref.watch(chapterSummaryProvider(widget.chapterId));

    if (summary == null) {
      return AtherScreen(
        header: AtherHeader(title: '', onBack: () => context.pop()),
        children: const <Widget>[],
      );
    }

    final snapshot = ref.watch(snapshotValueProvider);
    final exams = <ExamEntry>[
      for (final lesson in summary.lessons)
        ...snapshot.examsFor(lesson.lesson.id),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final ranked = List<LessonSummary>.of(summary.lessons)
      ..sort((a, b) => a.mastery.compareTo(b.mastery));

    return AtherScreen(
      header: AtherHeader(
        title: l.chapterReportTitle,
        onBack: () => context.pop(),
        actions: <Widget>[
          CircleHeaderButton(
            // `_export` returns early while one is already running, which
            // is what keeps a second tap from starting a second render.
            onTap: () => _export(summary, ranked),
            semanticLabel: l.chapterReportExport,
            child: Icon(
              Icons.ios_share,
              size: 18,
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ),
      children: <Widget>[
        _ReportCard(l: l, summary: summary, exams: exams),
        const SizedBox(height: AppSpacing.xl),
        SectionTitle(l.sectionLessons),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < ranked.length; i++) ...<Widget>[
          _LessonRow(
            l: l,
            summary: ranked[i],
            // Only meaningful when there is something to be weakest *of*.
            weakest: i == 0 && ranked.length > 1,
            onTap: () => context.push(Routes.lesson(ranked[i].lesson.id)),
          ),
          const SizedBox(height: AppSpacing.listGap),
        ],
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.l,
    required this.summary,
    required this.exams,
  });

  /// Passed in rather than read from the context.
  ///
  /// This card is built twice: on screen, and again off-screen on its way into
  /// the PDF. That second tree is a render tree of its own with no
  /// `Localizations` above it, and putting one there would mean resolving its
  /// delegates inside a pipeline that pumps two frames and then stops.
  final L l;

  final ChapterSummary summary;
  final List<ExamEntry> exams;

  /// Compares where the chapter started against where it is now.
  ///
  /// Under one percentage point of movement counts as flat: reporting "up 0.4%"
  /// as improvement is the same flattery the honest-trend fix removed.
  (String, Color) _trend(AppColors colors) {
    if (exams.length < 2) return (l.trendFlat, colors.textSecondary);

    final first = exams.first.percentage;
    final delta = summary.mastery - first;
    if (delta.abs() < 1) return (l.trendFlat, colors.textSecondary);

    final from = percent(first);
    final to = percent(summary.mastery);
    return delta > 0
        ? (l.trendUp(from, to), colors.rightText)
        : (l.trendDown(from, to), colors.wrong);
  }

  @override
  Widget build(BuildContext context) {
    final hasData = summary.hasAnyExam;
    final color = MasteryPalette.resolve(
      colors: context.colors,
      percentage: summary.mastery,
      hasData: hasData,
      needsReview: summary.needsReview,
    );
    final (trendLine, trendColor) = _trend(context.colors);

    return AtherCard(
      padding: AppSpacing.xxxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            summary.chapter.name,
            textAlign: TextAlign.center,
            style: AppTypography.cardTitle,
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              percentLabel(summary.mastery, hasData: hasData),
              style: AppTypography.resultNumber.copyWith(color: color),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          MasteryBar(
            fraction: MasteryPalette.barFraction(
              percentage: summary.mastery,
              hasData: hasData,
            ),
            color: MasteryPalette.fill(context.colors, color),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            '${l.averageExamScore}: '
            '${hasData ? percent(summary.averageExamScore) : '—'}',
            textAlign: TextAlign.center,
            style: context.text.secondaryStrong,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            trendLine,
            textAlign: TextAlign.center,
            style: AppTypography.controlLabel.copyWith(color: trendColor),
          ),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.l,
    required this.summary,
    required this.weakest,
    this.onTap,
  });

  /// See the note on [_ReportCard.l].
  final L l;

  final LessonSummary summary;
  final bool weakest;

  /// Null in the printed copy. A card in a PDF that looks tappable is a card
  /// telling the reader something untrue about itself.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = MasteryPalette.resolve(
      colors: context.colors,
      percentage: summary.mastery,
      hasData: summary.hasExam,
      needsReview: summary.needsReview,
    );

    return AtherCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          if (weakest) ...<Widget>[
            MiniBadge(label: l.weakestLessonBadge, wrong: true),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Text(
              summary.lesson.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cardTitle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            percentLabel(summary.mastery, hasData: summary.hasExam),
            style: AppTypography.rowTitle.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// The report as it goes into the PDF: the same two cards, no scroll view.
///
/// Every inherited widget the cards need is rebuilt here by hand, because this
/// tree is rooted in its own [RenderView] with nothing above it -- no
/// `MaterialApp`, no `Theme`, no `Directionality`. Each is taken from the live
/// screen so the exported copy matches the one the student was looking at,
/// down to which theme they have on.
class _PrintableReport extends StatelessWidget {
  const _PrintableReport({
    required this.l,
    required this.theme,
    required this.direction,
    required this.summary,
    required this.exams,
    required this.ranked,
  });

  final L l;
  final ThemeData theme;
  final TextDirection direction;
  final ChapterSummary summary;
  final List<ExamEntry> exams;
  final List<LessonSummary> ranked;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: direction,
      child: MediaQuery(
        // Deliberately not the student's own text scale. This is a document
        // that will be read on somebody else's screen or on paper, where a
        // reader zooms rather than inheriting a phone accessibility setting --
        // and where a 2x scale would reflow the whole report.
        data: const MediaQueryData(textScaler: TextScaler.noScaling),
        child: Theme(
          data: theme,
          child: DefaultTextStyle(
            style: TextStyle(
              fontFamily: 'ReadexPro',
              color: theme.extension<AppColors>()?.textPrimary ?? Colors.black,
            ),
            child: ColoredBox(
              color: context.colors.pageBackground,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    RepaintBoundary(
                      child: _ReportCard(l: l, summary: summary, exams: exams),
                    ),
                    for (var i = 0; i < ranked.length; i++) ...<Widget>[
                      const SizedBox(height: AppSpacing.listGap),
                      RepaintBoundary(
                        child: _LessonRow(
                          l: l,
                          summary: ranked[i],
                          weakest: i == 0 && ranked.length > 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
