import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Why a PDF export did not complete. Structured, for the same reason
/// [ExportFailure] is: this layer has no localisation.
enum PdfExportFailure { fileSystemError, shareError, unknown }

class PdfExportException implements Exception {
  const PdfExportException(this.failure);

  final PdfExportFailure failure;

  @override
  String toString() => 'PdfExportException: ${failure.name}';
}

/// One block of a report, already drawn.
///
/// [png] is a picture of a single card or row, and [aspectRatio] is its
/// width-over-height so the page can size it without decoding it first.
final class PdfBlock {
  const PdfBlock({required this.png, required this.aspectRatio});

  final Uint8List png;
  final double aspectRatio;
}

/// Assembles a report PDF out of blocks that Flutter has already drawn, and
/// hands the file to the share sheet.
///
/// **Why the pages are pictures.** The `pdf` package cannot shape Arabic in
/// this app's font -- it maps right-to-left runs onto Unicode presentation
/// forms and looks those up in the embedded font's `cmap`, and Readex Pro joins
/// through `GSUB` and carries none of them. Ten of the twenty-eight characters
/// in a chapter title like `الفصل الأول: التفاضل والتكامل` come out blank. That
/// is proven in `test/domain/pdf_export_test.dart`, not assumed. Flutter shapes
/// the same string correctly, so the report is drawn by Flutter and arrives
/// here as images. See `presentation/share/widget_raster.dart`.
///
/// **Why blocks rather than one tall picture.** A single image the height of
/// the whole report has to be cut somewhere to fit on pages, and the cut lands
/// wherever it lands -- through the middle of a lesson row as often as not.
/// Handing [pw.MultiPage] one image per card lets it break between them, which
/// is the only place a break belongs.
class PdfExportService {
  const PdfExportService();

  /// A4 with a margin wide enough to survive a home printer's dead zone.
  static const PdfPageFormat pageFormat = PdfPageFormat.a4;
  static const double pageMargin = 32;

  Future<Uint8List> build(List<PdfBlock> blocks) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormat.copyWith(
          marginLeft: pageMargin,
          marginRight: pageMargin,
          marginTop: pageMargin,
          marginBottom: pageMargin,
        ),
        build: (context) => <pw.Widget>[
          for (final block in blocks) ...<pw.Widget>[
            pw.Image(pw.MemoryImage(block.png), fit: pw.BoxFit.contain),
            pw.SizedBox(height: 8),
          ],
        ],
      ),
    );
    return document.save();
  }

  /// Writes [bytes] to the temporary directory and opens the share sheet.
  ///
  /// No "save to Downloads" here either, and for the same reason as
  /// [DataExportService]: on Android that directory is app-private and is
  /// deleted with the app.
  Future<void> share(Uint8List bytes, String filename) async {
    final File file;
    try {
      final directory = await getTemporaryDirectory();
      file = File('${directory.path}/$filename');
      await file.writeAsBytes(bytes);
    } on Object {
      throw const PdfExportException(PdfExportFailure.fileSystemError);
    }

    try {
      final result = await Share.shareXFiles(<XFile>[XFile(file.path)]);
      if (result.status == ShareResultStatus.unavailable) {
        throw const PdfExportException(PdfExportFailure.shareError);
      }
    } on PdfExportException {
      rethrow;
    } on Object {
      throw const PdfExportException(PdfExportFailure.shareError);
    }
  }

  /// `ather_report_<chapter>_YYYY-MM-DD.pdf`.
  ///
  /// The chapter name goes through [_safeSegment] before it reaches a filename:
  /// chapter names are typed by the student, they are usually Arabic, and they
  /// can contain slashes and colons that break a filename on the far end of a
  /// share.
  String buildFilename(String chapterName, DateTime at) {
    final day = at.toIso8601String().substring(0, 10);
    final name = _safeSegment(chapterName);
    return name.isEmpty
        ? 'ather_report_$day.pdf'
        : 'ather_report_${name}_$day.pdf';
  }

  /// Keeps letters and digits in any script -- Arabic included -- and turns
  /// everything else into a single underscore.
  static String _safeSegment(String input) {
    final buffer = StringBuffer();
    var pendingSeparator = false;
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(char)) {
        if (pendingSeparator && buffer.isNotEmpty) buffer.write('_');
        pendingSeparator = false;
        buffer.write(char);
      } else {
        pendingSeparator = true;
      }
    }
    // Long enough to identify the chapter, short enough to leave room for the
    // date on file systems that cap a name at 255 bytes -- Arabic runs two to
    // three bytes a letter in UTF-8.
    final out = buffer.toString();
    return out.length <= 40 ? out : out.substring(0, 40);
  }
}
