import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lays a widget out away from the screen and photographs it, block by block.
///
/// **Why this exists, and why the obvious alternative does not work.**
///
/// Two features need a picture of something the student is not currently
/// looking at: the chapter report PDF and the shareable progress card. The
/// usual trick -- wrap the on-screen widget in a [RepaintBoundary] and call
/// `toImage()` -- captures only what was painted, and what was painted is what
/// fits in the viewport. A chapter with fifteen lessons would export the four
/// that happened to be scrolled into view, and once `AtherScreen` builds its
/// rows lazily it would export fewer still.
///
/// So the widget is built into a render tree of its own: a [RenderView] with a
/// tight width and an unbounded height, laid out and painted once, with no
/// viewport and nothing clipping it. The content is as tall as it wants to be.
///
/// **Why a raster at all, for the PDF.** The `pdf` package cannot shape Arabic
/// in this app's font. It rewrites right-to-left runs into Unicode presentation
/// forms (U+FE70..U+FEFF) and looks those up in the embedded font's `cmap`;
/// Readex Pro joins Arabic through `GSUB` and carries none of them, so ten of
/// the twenty-eight characters in a title like `الفصل الأول: التفاضل والتكامل`
/// come out blank -- silently, with no exception to notice. That is asserted in
/// `test/domain/pdf_export_test.dart` rather than left here as a claim. Flutter
/// shapes the same string correctly, so the report is drawn by Flutter and goes
/// into the PDF as pictures. The trade is real: the text in the PDF cannot be
/// selected or searched. It buys Arabic that can be read, in the app's own
/// typeface, identical to what was on screen.
///
/// A font carrying the presentation-form block -- Amiri, Noto Naskh Arabic --
/// would allow real text instead. That means a second typeface in every APK,
/// and one the design system did not choose, so it is not taken here.
///
/// Returns one image per top-level [RepaintBoundary] in [widget], in tree
/// order. Boundaries nested inside another boundary are left alone: the outer
/// one already contains them.
Future<List<ui.Image>> rasterizeBlocks({
  required Widget widget,
  required double width,
  required double pixelRatio,
  required ui.FlutterView view,
}) async {
  final root = RenderRepaintBoundary();
  final renderView = RenderView(
    view: view,
    configuration: ViewConfiguration(
      // Tight width, free height. This is the whole point: the content decides
      // how tall it is and no viewport crops it.
      logicalConstraints: BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: double.infinity,
      ),
      physicalConstraints: BoxConstraints(
        minWidth: width * pixelRatio,
        maxWidth: width * pixelRatio,
        maxHeight: double.infinity,
      ),
      devicePixelRatio: pixelRatio,
    ),
    child: root,
  );

  final pipelineOwner = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();

  // A [BuildOwner] of its own, so a half-built report can never be flushed as
  // part of the app's own frame. The cost is that `GlobalKey.currentContext`
  // does not work here -- it resolves against `WidgetsBinding.instance
  // .buildOwner` and nothing else -- which is why the blocks are found by
  // walking the render tree instead of by key.
  final buildOwner = BuildOwner(focusManager: FocusManager());
  final element = RenderObjectToWidgetAdapter<RenderBox>(
    container: root,
    child: widget,
  ).attachToRenderTree(buildOwner);

  try {
    // Two passes. The first builds and lays out; the second lets anything that
    // measured itself during that layout -- text that wrapped, a row that
    // learned its own height -- settle before the paint that is photographed.
    for (var pass = 0; pass < 2; pass++) {
      buildOwner
        ..buildScope(element)
        ..finalizeTree();
      pipelineOwner
        ..flushLayout()
        ..flushCompositingBits()
        ..flushPaint();
    }

    final blocks = <RenderRepaintBoundary>[];
    _collectBlocks(root, blocks);

    final images = <ui.Image>[];
    for (final block in blocks) {
      images.add(await block.toImage(pixelRatio: pixelRatio));
    }
    return images;
  } finally {
    // Left attached, this tree keeps its render objects and its own
    // [RenderView] alive for as long as the [BuildOwner] is reachable -- an
    // export run three times would leak three reports. Rebuilding the adapter
    // with no child unmounts the subtree through the same public path that
    // mounted it.
    RenderObjectToWidgetAdapter<RenderBox>(
      container: root,
    ).attachToRenderTree(buildOwner, element);
    buildOwner
      ..buildScope(element)
      ..finalizeTree();
    pipelineOwner.rootNode = null;
  }
}

/// Depth-first, stopping at the first boundary on each branch.
///
/// Stopping matters: several of the app's own widgets put a [RepaintBoundary]
/// inside themselves for their own painting reasons, and descending into one
/// would return a picture of a card *and* a picture of its progress bar.
void _collectBlocks(RenderObject node, List<RenderRepaintBoundary> out) {
  node.visitChildren((child) {
    if (child is RenderRepaintBoundary) {
      out.add(child);
    } else {
      _collectBlocks(child, out);
    }
  });
}

/// PNG bytes for an image produced by [rasterizeBlocks].
Future<Uint8List> encodePng(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) {
    throw StateError('the block could not be encoded as a PNG');
  }
  return data.buffer.asUint8List();
}
