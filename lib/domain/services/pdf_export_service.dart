import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../entities/chapter.dart';
import '../entities/lesson.dart';
import '../entities/mastery.dart';
import '../entities/study_snapshot.dart';
import '../entities/subject.dart';
import 'mastery_calculator.dart';

/// Why a PDF export did not complete.
///
/// Structured enum, matching [ExportFailure] in [DataExportService]. The data
/// layer has no access to localisation, so an English platform error could
/// never reach an Arabic student.
enum PdfExportFailure {
  /// Could not access the Downloads directory or write to it.
  fileSystemError,

  /// The share sheet could not be opened.
  shareError,

  unknown,
}

class PdfExportException implements Exception {
  const PdfExportException(this.failure);

  final PdfExportFailure failure;

  @override
  String toString() => 'PdfExportException: ${failure.name}';
}

/// Generates a PDF summary of a student's mastery across all subjects.
///
/// **Pure, offline PDF generation.** This never touches the network: it reads
/// from a [StudySnapshot] already in memory and writes to local storage or
/// hands a file to the system share sheet. A student with no connectivity can
/// export.
///
/// **Why PDF rather than JSON for the summary:** PDF is human-readable and
/// printable. A student can hand it to a parent or tutor, or keep it as a
/// progress snapshot. JSON is for machines and backup; PDF is for people.
///
/// The output is a single-page or multi-page report showing:
/// - Overall mastery percentage
/// - Per-subject mastery with chapter and lesson breakdowns
/// - Exam counts for each lesson
/// - Mastery band classification (weak/medium/good/excellent)
class PdfExportService {
  const PdfExportService();

  /// Generates a PDF summary and saves it to the Downloads folder.
  ///
  /// Returns the absolute path to the saved file, which the caller can display
  /// or use to open the file.
  ///
  /// The filename includes a timestamp so repeated exports do not overwrite
  /// each other: `ather_mastery_summary_2026-08-18_14-30-45.pdf`.
  Future<String> saveToDownloads(StudySnapshot snapshot) async {
    final pdf = _generatePdf(snapshot);
    final filename = _generateFilename();

    try {
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw const PdfExportException(PdfExportFailure.fileSystemError);
      }

      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(await pdf.save());

      return file.path;
    } on PdfExportException {
      rethrow;
    } on Object {
      // Covers FileSystemException, SecurityException and any platform-specific
      // error. All of them mean the same thing to the caller: the file did not
      // land where it was meant to.
      throw const PdfExportException(PdfExportFailure.fileSystemError);
    }
  }

  /// Opens the Android share sheet with the mastery summary as a PDF file.
  ///
  /// The student can then send it via WhatsApp, email, Drive, or any other app
  /// that accepts file shares. The file is written to a temporary cache
  /// directory first, then cleaned up by the system when no longer needed.
  Future<void> shareAsPdf(StudySnapshot snapshot) async {
    final pdf = _generatePdf(snapshot);
    final filename = _generateFilename();

    try {
      // Write to a temporary directory first -- share_plus needs a real file,
      // not bytes, and handing it a Downloads file would leave the share
      // target writing to the same path we use for explicit saves.
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(await pdf.save());

      final result = await Share.shareXFiles(
        <XFile>[XFile(file.path)],
        text: 'Ather mastery summary',
      );

      // ShareResult.dismissed means the student backed out, which is not an
      // error. Only ShareResultStatus.unavailable is a failure -- the platform
      // could not open the sheet at all.
      if (result.status == ShareResultStatus.unavailable) {
        throw const PdfExportException(PdfExportFailure.shareError);
      }
    } on PdfExportException {
      rethrow;
    } on Object {
      // Covers file write failures and any share_plus exceptions. Translates
      // both into a single actionable message for the UI.
      throw const PdfExportException(PdfExportFailure.shareError);
    }
  }

  /// Generates the PDF document from a snapshot.
  ///
  /// **Pure function.** All data comes from the snapshot parameter; there are
  /// no file reads, no database queries, and no network calls. This is what
  /// makes the generator unit-testable without mocking anything.
  pw.Document _generatePdf(StudySnapshot snapshot) {
    final pdf = pw.Document();

    // Compute all mastery values once, up front. This matches the pattern in
    // [MasteryCalculator.lessonMasteries]: compute everything once and thread
    // the map through, rather than recomputing on every access.
    final lessonMasteries = MasteryCalculator.lessonMasteries(snapshot);
    final overallMastery = MasteryCalculator.overallMastery(snapshot);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => <pw.Widget>[
          // Header
          pw.Header(
            level: 0,
            child: pw.Text(
              'Ather - Mastery Summary',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 10),

          // Overall mastery
          pw.Text(
            'Overall Mastery: ${overallMastery.toStringAsFixed(1)}%',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Band: ${_bandLabel(MasteryBand.fromPercentage(overallMastery))}',
            style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 20),

          // Per-subject breakdown
          ...snapshot.activeSubjects.map((subject) {
            final subjectMastery = MasteryCalculator.subjectMasteryOf(
              snapshot,
              subject.id,
            );
            return _buildSubjectSection(
              subject,
              subjectMastery,
              snapshot,
              lessonMasteries,
            );
          }),

          // Footer note if there are archived or deleted subjects
          if (snapshot.subjects.any((s) => !s.isActive))
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 20),
              child: pw.Text(
                'Note: Archived and deleted subjects are excluded from this summary.',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ),

          // Export timestamp
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Exported: ${_formatDateTime(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
        ],
      ),
    );

    return pdf;
  }

  /// Builds the section for one subject: its mastery, and all chapters and
  /// lessons beneath it.
  pw.Widget _buildSubjectSection(
    Subject subject,
    double subjectMastery,
    StudySnapshot snapshot,
    Map<int, double> lessonMasteries,
  ) {
    final chapters = snapshot.chaptersIn(subject.id);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        // Subject header
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              pw.Text(
                _subjectName(subject),
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                '${subjectMastery.toStringAsFixed(1)}% • ${_bandLabel(MasteryBand.fromPercentage(subjectMastery))}',
                style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),

        // Chapters
        ...chapters.map((chapter) {
          final chapterMastery = MasteryCalculator.chapterMasteryOf(
            snapshot,
            chapter.id,
          );
          return _buildChapterSection(
            chapter,
            chapterMastery,
            snapshot,
            lessonMasteries,
          );
        }),
        pw.SizedBox(height: 16),
      ],
    );
  }

  /// Builds the section for one chapter: its mastery, and all lessons beneath it.
  pw.Widget _buildChapterSection(
    Chapter chapter,
    double chapterMastery,
    StudySnapshot snapshot,
    Map<int, double> lessonMasteries,
  ) {
    final lessons = snapshot.lessonsIn(chapter.id);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 16, bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          // Chapter header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              pw.Text(
                chapter.name,
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                '${chapterMastery.toStringAsFixed(1)}%',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.SizedBox(height: 4),

          // Lessons
          ...lessons.map((lesson) {
            final lessonMastery = lessonMasteries[lesson.id] ?? 0;
            final examCount = snapshot.examsFor(lesson.id).length;
            return _buildLessonRow(lesson, lessonMastery, examCount);
          }),
        ],
      ),
    );
  }

  /// Builds one row for a lesson: name, mastery percentage, and exam count.
  pw.Widget _buildLessonRow(
    Lesson lesson,
    double mastery,
    int examCount,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 16, top: 2, bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Text(
              lesson.name,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
          pw.Text(
            '${mastery.toStringAsFixed(1)}% • $examCount exam${examCount != 1 ? 's' : ''}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  /// Returns the display name for a subject.
  ///
  /// For seeded subjects, the code's name is used (which will be in English in
  /// the PDF, since the ARB files are not available here). For custom subjects,
  /// the student's own name is used.
  String _subjectName(Subject subject) {
    if (subject.code != null) {
      // Seeded subject: use the code's name (English)
      return subject.code!.name[0].toUpperCase() + subject.code!.name.substring(1);
    }
    // Custom subject: use the stored name
    return subject.name ?? 'Unknown Subject';
  }

  /// Returns the English label for a mastery band.
  String _bandLabel(MasteryBand band) {
    switch (band) {
      case MasteryBand.weak:
        return 'Weak';
      case MasteryBand.medium:
        return 'Medium';
      case MasteryBand.good:
        return 'Good';
      case MasteryBand.excellent:
        return 'Excellent';
    }
  }

  /// Formats a DateTime for display in the PDF footer.
  String _formatDateTime(DateTime dt) {
    final year = dt.year;
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  /// Generates a timestamped filename for the PDF export.
  ///
  /// Format: `ather_mastery_summary_YYYY-MM-DD_HH-MM-SS.pdf`
  ///
  /// The timestamp ensures repeated exports do not overwrite each other, and
  /// sorts chronologically in a file browser. Colons are replaced with dashes
  /// because Windows file systems reject them in filenames.
  String _generateFilename() {
    final now = DateTime.now();
    final timestamp = now.toIso8601String()
        .substring(0, 19) // "2026-08-18T14:30:45"
        .replaceAll('T', '_')
        .replaceAll(':', '-');
    return 'ather_mastery_summary_$timestamp.pdf';
  }
}
