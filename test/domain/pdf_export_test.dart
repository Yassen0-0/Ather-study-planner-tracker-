import 'dart:io';
import 'dart:ui' as ui;

import 'package:ather/core/theme/app_theme.dart';
import 'package:ather/domain/services/pdf_export_service.dart';
import 'package:ather/presentation/share/widget_raster.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
// The two shaping paths inside the `pdf` package, reached through `src/`
// deliberately: the first group exists to pin down what that package actually
// does to Arabic, and its public API hides it.
// ignore: implementation_imports
import 'package:pdf/src/pdf/font/arabic.dart' as pdf_arabic;
// ignore: implementation_imports
import 'package:pdf/src/pdf/font/bidi_utils.dart' as pdf_bidi;

/// Why the chapter report PDF is drawn by Flutter rather than by the `pdf`
/// package, and proof that the drawing survives being taken off-screen.
///
/// The first group is the finding the whole design rests on. The plan for this
/// task said to embed `ReadexPro.ttf` as a `pw.Font`, set the page direction to
/// RTL, and check the result visually. Checked: it does not work, and it fails
/// **silently** -- no exception, just missing glyphs. These tests fail if
/// anyone concludes otherwise, and they will start failing the day a font that
/// does carry the presentation forms is added, which is the moment to go back
/// to real PDF text.
void main() {
  const sample = 'الفصل الأول: التفاضل والتكامل';

  late ui.FlutterView view;

  setUp(() {
    view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
  });

  /// A stand-in for the printable report: a column of blocks carrying Arabic,
  /// deliberately taller than any phone screen.
  Widget sheet({required int rows}) => Directionality(
    textDirection: TextDirection.rtl,
    child: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.noScaling),
      child: Theme(
        data: AppTheme.light,
        child: DefaultTextStyle(
          style: const TextStyle(
            fontFamily: 'ReadexPro',
            fontSize: 18,
            color: Color(0xFF101010),
          ),
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < rows; i++)
                  RepaintBoundary(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('$sample ${i + 1}'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  /// Rasterising has to run through [WidgetTester.runAsync].
  ///
  /// `toImage` hands the layer to the engine and waits for the raster to come
  /// back. Inside a widget test the clock and the microtask queue are both
  /// driven by the test framework, so that reply never arrives and the test
  /// hangs rather than failing -- which is how this was found. `runAsync`
  /// steps out into the real event loop for the duration.
  Future<List<ui.Image>> capture(
    WidgetTester tester, {
    required int rows,
  }) async {
    final images = await tester.runAsync(
      () => rasterizeBlocks(
        widget: sheet(rows: rows),
        width: 520,
        pixelRatio: 2,
        view: view,
      ),
    );
    return images!;
  }

  group('the pdf package cannot shape Arabic in this app font', () {
    late Map<int, int> cmap;

    setUpAll(() {
      final bytes = File('assets/fonts/ReadexPro.ttf').readAsBytesSync();
      cmap = TtfParser(bytes.buffer.asByteData()).charToGlyphIndexMap;
    });

    List<int> missingFrom(String text) =>
        text.runes.where((r) => r != 0x20 && !cmap.containsKey(r)).toList();

    test('Readex Pro covers the Arabic letters themselves', () {
      // So the failure below is specifically about *joined* forms, and not
      // about the font lacking Arabic.
      expect(missingFrom(sample), isEmpty);
    });

    test('but not the joined forms the pdf package looks up', () {
      // Both of the package's right-to-left paths rewrite the string into
      // Unicode presentation forms (U+FE70..U+FEFF) and then look those
      // codepoints up in the embedded font. Readex Pro joins through `GSUB`
      // and carries none of the initial, medial or final forms, so a third of
      // a chapter title comes out blank.
      for (final shaped in <String>[
        pdf_bidi.logicalToVisual(sample),
        pdf_arabic.convert(sample),
      ]) {
        expect(
          missingFrom(shaped),
          isNotEmpty,
          reason:
              'If this passes, a font carrying the Arabic presentation forms '
              'has been added, and the report can go back to being real, '
              'selectable PDF text instead of pictures. Rewrite '
              'PdfExportService when that happens.',
        );
      }
    });
  });

  group('rasterizing the report off-screen', () {
    testWidgets('captures every block, including ones no screen would fit', (
      tester,
    ) async {
      // Forty blocks at ~70 logical pixels each is far taller than the 600
      // logical pixels a test view has. Under the obvious approach -- a
      // RepaintBoundary around the on-screen list -- everything past the
      // viewport would simply not be in the picture.
      const rows = 40;

      final images = await capture(tester, rows: rows);

      expect(images, hasLength(rows));
      final capturedHeight = images.fold<int>(0, (sum, i) => sum + i.height) / 2;
      expect(
        capturedHeight,
        greaterThan(
          tester.view.physicalSize.height / tester.view.devicePixelRatio,
        ),
        reason: 'the captured report should be taller than one screen',
      );
      for (final image in images) {
        expect(image.width, 520 * 2);
        image.dispose();
      }
    });

    testWidgets('the captured pixels are a drawing, not a blank card', (
      tester,
    ) async {
      final images = await capture(tester, rows: 1);

      final data = await tester.runAsync(() => images.single.toByteData());
      final distinct = data!.buffer.asUint32List().toSet();

      // **What this can and cannot prove.** `flutter test` runs against a stub
      // font -- every glyph is a filled rectangle, whatever the string says --
      // so no test in this file can show that Arabic came out *shaped*. What
      // it can show is that the off-screen pipeline painted at all: a block
      // that laid out but never got a paint pass, which is the failure mode
      // this pipeline actually has, comes back one flat colour.
      //
      // The shaping itself is verified by the app: this is the same Flutter
      // text stack that already draws these chapter names on the chapter
      // screen, in the same font. The alternative -- the `pdf` package's own
      // path -- is the one proven broken above.
      expect(
        distinct.length,
        greaterThan(1),
        reason: 'the block came back a flat fill -- nothing was painted on it',
      );
      images.single.dispose();
    });
  });

  group('assembling the document', () {
    const service = PdfExportService();

    testWidgets('a real report becomes a real PDF', (tester) async {
      // End to end, through the same path the app uses: Arabic laid out by
      // Flutter, captured off-screen, encoded, assembled. A PDF built from a
      // synthetic image would not prove the two halves fit together.
      final images = await capture(tester, rows: 3);

      final (bytes, empty) = (await tester.runAsync(() async {
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
        // The same document with nothing in it, as the baseline: it isolates
        // the bytes the blocks contributed from the bytes the format costs.
        return (await service.build(blocks), await service.build(<PdfBlock>[]));
      }))!;

      // Every PDF opens with the version header; anything else means the
      // document did not serialise.
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

      // The blocks are in the file. Measured against an empty document rather
      // than against a fixed byte count: the pdf package compresses its object
      // streams, so the image dictionaries are not searchable as text, and
      // under the stub font the blocks themselves compress to almost nothing
      // -- a fixed threshold would be measuring the test environment.
      expect(empty, isNotEmpty);
      expect(bytes.length, greaterThan(empty.length));
    });

    test('an Arabic chapter name survives becoming a filename', () {
      final name = service.buildFilename(
        'الفصل الأول: التفاضل / التكامل',
        DateTime(2026, 8, 18, 9, 5),
      );

      expect(name, startsWith('ather_report_'));
      expect(name, endsWith('_2026-08-18.pdf'));
      // The letters are kept: a file called `ather_report__.pdf` tells the
      // student nothing about which chapter they are holding.
      expect(name, contains('الفصل'));
      // The separators that break a filename at the far end of a share are not.
      expect(name, isNot(contains(':')));
      expect(name, isNot(contains('/')));
    });

    test('a chapter named only in punctuation still produces a filename', () {
      expect(
        service.buildFilename('///', DateTime(2026, 8, 18)),
        'ather_report_2026-08-18.pdf',
      );
    });
  });
}
