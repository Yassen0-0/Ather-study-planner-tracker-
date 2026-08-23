import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'ather_icons.dart';
import 'reduced_motion.dart';

/// The glyphs that move, and nothing else.
///
/// Three rules hold across everything in this file, from the icon motion
/// handoff (v1, 9 Aug 2026):
///
/// * One curve: [AppMotion.standard], which is `Cubic(0.23, 1, 0.32, 1)`. Never
///   an ease-in on anything that answers a tap — the first frame after a touch
///   must move.
/// * Nothing here changes an authored path. Every transition is a tween over a
///   paint property (stroke width, fill opacity, colour) or a transform about
///   the glyph's own centre.
/// * Reduced motion lands on the end state on the first frame. The controller's
///   value is *set*, not animated to — a shortened duration is still motion.
///
/// Interruption: every controller below is reversible mid-flight. A second tap
/// reverses from wherever the first one got to, so `forward()`/`reverse()` and
/// never `forward(from: 0)` in a tap handler.

/// A bottom-bar tab glyph on the weight axis (handoff §2).
///
/// One tween drives the weight and the tint together, so a tab can never sit at
/// its final colour with its starting weight. [AtherIcon.selection] does the
/// per-glyph work: `home` fades a fill in, the other three thicken.
class TabGlyph extends StatelessWidget {
  const TabGlyph({
    super.key,
    required this.glyph,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    this.size = 25,
    this.builder,
  });

  final AtherGlyph glyph;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final double size;

  /// Given the tween's current tint, builds the rest of the tab. The label is
  /// handed the same colour the glyph is drawn in, from the same frame.
  final Widget Function(BuildContext context, Color tint, Widget glyph)? builder;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: selected ? 1 : 0),
      duration: prefersReducedMotion(context) ? Duration.zero : AppMotion.nav,
      curve: AppMotion.standard,
      builder: (context, t, _) {
        final tint = Color.lerp(unselectedColor, selectedColor, t)!;
        final glyphWidget = AtherIcon(
          glyph,
          size: size,
          color: tint,
          selection: t,
        );
        return builder?.call(context, tint, glyphWidget) ?? glyphWidget;
      },
    );
  }
}

/// The settings cog, which turns 45° every time it is opened (handoff §3).
///
/// The cog is eight teeth walked in polar coordinates, so its period is exactly
/// 45° and a 45° turn maps the glyph onto itself — the landing is exact, not
/// nearly exact, and no frame of the turn shows a cog that is off its axis.
///
/// **Accumulates, never resets.** Each open adds `pi / 4` to the *current*
/// target. Taking the value modulo a full turn between opens would make a fast
/// double-open spin backwards, which is why [_turns] only ever counts up.
class SpinningCog extends StatefulWidget {
  const SpinningCog({super.key, this.size = 19, this.color});

  final double size;
  final Color? color;

  @override
  State<SpinningCog> createState() => SpinningCogState();
}

class SpinningCogState extends State<SpinningCog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.micro,
  );

  /// Completed turns, in eighths. Monotonic for the life of the widget.
  int _turns = 0;

  /// The cog's current angle in radians, counted from the first build and never
  /// wrapped — ten turns is 2.5π, not 0.5π. Read by the drift test, which is
  /// the only thing that can tell an accumulating turn from a resetting one.
  double get angle {
    if (_turns == 0) return 0;
    return (_turns - 1 + AppMotion.standard.transform(_c.value)) * math.pi / 4;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Turn one more eighth. Called by the button that owns this cog, on tap.
  void turn() {
    _turns += 1;
    if (prefersReducedMotion(context)) {
      setState(() => _c.value = 1);
      return;
    }
    // From 0 rather than reversed: this transition accumulates, so an
    // interrupting tap adds a turn on top of the one in flight instead of
    // undoing it. It is the one exception to the reversibility rule above.
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      // The eighths already landed, plus however far through the current one
      // the controller is — see [angle]. Both come off the same monotonic base,
      // so an interrupting turn can never rewind.
      builder: (context, child) =>
          Transform.rotate(angle: angle, child: child),
      // Built once and reused across every frame of the turn: the glyph itself
      // does not change, only the transform above it.
      child: AtherIcon(
        AtherGlyph.settings,
        size: widget.size,
        color: widget.color,
      ),
    );
  }
}

/// The back chevron, reflected about the glyph's own centre (handoff §5).
///
/// The authored path points right, which is the correct *resting* state for
/// back in Arabic; under LTR it is mirrored. The reflection is driven off
/// [Directionality], not off a hard-coded start value — a wrongly-seeded
/// controller looks right until the first change and wrong afterwards.
///
/// The stroke tweens 2.4 → 2.2 alongside the reflection, because the two
/// authored glyphs carry different weights and a bare reflection lands on a
/// chevron heavier than the one drawn elsewhere on the same screen.
class AnimatedBackChevron extends StatelessWidget {
  const AnimatedBackChevron({super.key, this.size = 19, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // 0 = pointing right (Arabic's "back"), 1 = mirrored (English's).
    final mirrored = Directionality.of(context) == TextDirection.ltr ? 1.0 : 0.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: mirrored),
      duration: prefersReducedMotion(context) ? Duration.zero : AppMotion.micro,
      curve: AppMotion.standard,
      builder: (context, t, _) => Transform(
        alignment: Alignment.center,
        // A reflection about the glyph's own vertical centreline: scaleX runs
        // 1 → −1, and passes through 0 exactly halfway, where the polyline is
        // edge-on. That is the whole transition.
        transform: Matrix4.diagonal3Values(1 - 2 * t, 1, 1),
        child: AtherIcon(
          AtherGlyph.back,
          size: size,
          color: color,
          strokeWidth: 2.4 + (2.2 - 2.4) * t,
        ),
      ),
    );
  }
}

/// A ring that floods to a solid disc and then takes a tick (handoff §7).
///
/// The week strip's day circle at 34, and the checklist's box at 24 — one shape
/// at two sizes, so one widget.
///
/// **Why it floods rather than filling instantly.** The circle used to snap to
/// solid on one frame, on the reasoning that a partly-filled circle reads as a
/// day half-proved. That is true of a fill that *rises*, which is a level and
/// which this app already uses to mean partial progress. It is not true of a
/// fill that closes inward from the rim: nothing about it looks like a
/// measurement, and it gives the eye something to follow between the tap and
/// the tick. The rejected variant is the rising one.
///
/// Two things in sequence, 120 ms then 220 ms, so 340 ms in total — over the
/// tick token on purpose. Compressing it to fit the token is what would make it
/// look hurried.
class CompletionDisc extends StatefulWidget {
  const CompletionDisc({
    super.key,
    required this.done,
    required this.size,
    required this.fill,
    required this.ring,
    required this.ringWidth,
    required this.tickSize,
    required this.tickColor,
    this.tickStroke = 3,
    this.celebrateRing,
  });

  final bool done;
  final double size;

  /// The disc, once it is solid.
  final Color fill;

  /// The empty state's outline. It fades out as the flood closes over it.
  final Color ring;
  final double ringWidth;

  final double tickSize;
  final Color tickColor;
  final double tickStroke;

  /// An optional celebratory ring flooded once around a disc born complete.
  ///
  /// Null -- the default -- paints nothing extra, so every existing caller
  /// keeps byte-identical output. When set, a stroke starts on the rim and
  /// expands outward while fading, over [AppMotion.flood], on the disc's first
  /// frame only. It reads as energy leaving the disc rather than as a second
  /// object, which is why it expands *and* dies in one gesture instead of
  /// holding. Built for the mastered-chapter celebration (SP-04ب): the one
  /// place a disc arrives already complete *and* newly on screen, where the
  /// pop above it needs an opening echo. Reduced motion skips it entirely --
  /// the end state of a halo is no halo.
  final Color? celebrateRing;

  @override
  State<CompletionDisc> createState() => _CompletionDiscState();
}

class _CompletionDiscState extends State<CompletionDisc>
    with SingleTickerProviderStateMixin {
  /// The flood, then the tick — from the tokens, not restated.
  static final Duration _total = AppMotion.flood + AppMotion.tick;
  static final double _split =
      AppMotion.flood.inMicroseconds / _total.inMicroseconds;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _total,
    // A day that is already complete when the strip is built does not replay:
    // scrolling a week into view is not seven completions.
    value: widget.done ? 1 : 0,
  );

  @override
  void didUpdateWidget(CompletionDisc old) {
    super.didUpdateWidget(old);
    if (widget.done == old.done) return;
    if (prefersReducedMotion(context)) {
      _c.value = widget.done ? 1 : 0;
      return;
    }
    widget.done ? _c.forward() : _c.reverse();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.value;
          final flood = AppMotion.standard.transform(
            (v / _split).clamp(0.0, 1.0),
          );
          final tick = AppMotion.standard.transform(
            ((v - _split) / (1 - _split)).clamp(0.0, 1.0),
          );

          // The celebration's one-shot echo, tweened by its own mount-time
          // builder: an unchanged tween never replays, so this is exactly once
          // per disc, and Duration.zero under reduced motion lands on the
          // finished (invisible) end state on the first frame.
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration:
                widget.celebrateRing == null || prefersReducedMotion(context)
                ? Duration.zero
                : AppMotion.flood,
            curve: AppMotion.standard,
            builder: (context, halo, _) => CustomPaint(
              painter: _FloodPainter(
                flood: flood,
                fill: widget.fill,
                ring: widget.ring,
                ringWidth: widget.ringWidth,
                halo: widget.celebrateRing == null ? null : halo,
                haloColor: widget.celebrateRing,
              ),
              // The tick is a real glyph scaled about its centre, not a second
              // path: it is the same check the rest of the app draws.
              child: tick == 0
                  ? null
                  : Center(
                      child: Opacity(
                        opacity: tick,
                        child: Transform.scale(
                          scale: 0.6 + 0.4 * tick,
                          child: AtherIcon(
                            AtherGlyph.check,
                            size: widget.tickSize,
                            color: widget.tickColor,
                            strokeWidth: widget.tickStroke,
                          ),
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _FloodPainter extends CustomPainter {
  const _FloodPainter({
    required this.flood,
    required this.fill,
    required this.ring,
    required this.ringWidth,
    this.halo,
    this.haloColor,
  });

  final double flood;
  final Color fill;
  final Color ring;
  final double ringWidth;

  /// Progress of the optional celebratory ring; null means none is requested
  /// and nothing below may draw it. At 1 it has fully faded -- also "none".
  final double? halo;
  final Color? haloColor;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final outer = size.width / 2;

    // The empty state's outline, fading out under the flood closing over it.
    if (flood < 1) {
      canvas.drawCircle(
        centre,
        outer - ringWidth / 2,
        Paint()
          ..color = ring.withValues(alpha: 1 - flood)
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth,
      );
    }

    if (flood == 0) return;

    // Radius in, stroke out: the ring closes from the rim to the centre and
    // ends as a filled disc, without a second shape and without a seam. At
    // flood = 1 the stroke spans exactly [0, outer].
    canvas.drawCircle(
      centre,
      outer * (1 - flood / 2),
      Paint()
        ..color = fill
        ..style = PaintingStyle.stroke
        ..strokeWidth = outer * flood,
    );

    // The celebratory echo, drawn last and strictly outside the disc so it can
    // never read as part of the fill: 18% growth is enough to detach from the
    // rim, no more -- past that it stops being an echo of *this* disc.
    final h = halo;
    if (h != null && h < 1) {
      canvas.drawCircle(
        centre,
        outer * (1 + 0.18 * h),
        Paint()
          ..color = haloColor!.withValues(alpha: haloColor!.a * (1 - h))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 - 2 * h,
      );
    }
  }

  @override
  bool shouldRepaint(_FloodPainter old) =>
      old.flood != flood ||
      old.fill != fill ||
      old.ring != ring ||
      old.ringWidth != ringWidth ||
      old.halo != halo ||
      old.haloColor != haloColor;
}

/// The overdue mark completing: a dashed ring floods to a disc and its dashes
/// land as a tick (handoff §6).
///
/// One controller, 220 ms, driving four things at once. The flood is a radius
/// that shrinks while its stroke grows: at t = 1 the stroke is twice the
/// radius, which *is* a filled circle. Cheaper than an arc tween, and it can
/// never seam.
///
/// The tick lands at [CheckDisc] proportions rather than full size — a disc
/// draws its tick at 52% of itself, and this circle is 18 units across in the
/// 24-unit grid, so the target is the authored check path scaled by
/// `0.52 * 18 / 24 = 0.39`. Morphing to the check at full size overshoots the
/// disc and lands on a glyph that exists nowhere else in the app.
///
/// Colour switches on the first frame rather than tweening: that is the rule
/// everywhere else in the app (PROJECT.md M-02), and the tween's midpoint here
/// is a muddy olive.
class OverdueCheck extends StatefulWidget {
  const OverdueCheck({super.key, required this.done, this.size = 15});

  /// True once the lesson is no longer overdue. Flipping it plays the flood.
  final bool done;
  final double size;

  @override
  State<OverdueCheck> createState() => _OverdueCheckState();
}

class _OverdueCheckState extends State<OverdueCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.tick,
    // Seeded at the end state when the row is built already-complete, so a list
    // scrolling into view does not replay every tick it contains.
    value: widget.done ? 1 : 0,
  );

  @override
  void didUpdateWidget(OverdueCheck old) {
    super.didUpdateWidget(old);
    if (widget.done == old.done) return;
    if (prefersReducedMotion(context)) {
      _c.value = widget.done ? 1 : 0;
      return;
    }
    // Reversible mid-flight: a second change before the first lands reverses
    // from the current value rather than restarting.
    widget.done ? _c.forward() : _c.reverse();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => _Flood(t: _c.value, size: widget.size),
    );
  }
}

/// The flood at one point in time. Both [OverdueCheck] and [OverdueMark] paint
/// through this, so the two can never drift apart on geometry or colour.
class _Flood extends StatelessWidget {
  const _Flood({required this.t, required this.size});

  /// The controller's raw value; the easing is applied here, once.
  final double t;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OverdueCheckPainter(
          t: AppMotion.standard.transform(t),
          // Instant, on the frame the state changes -- not a tween.
          color: t > 0 ? colors.right : colors.wrong,
          tick: colors.onState,
        ),
      ),
    );
  }
}

/// The overdue mark as a row actually uses it: it floods to a tick, then leaves.
///
/// A row cannot simply drop the glyph the moment the lesson stops being overdue
/// — that is the frame the flood is supposed to start on, and an unmounted
/// widget has nothing to animate. So this stays mounted through the completion
/// and takes itself out afterwards.
///
/// It leaves rather than holding the green tick, because the mark answers "does
/// this need review". Once the answer is no, a permanent tick beside a healthy
/// subject is a second, quieter claim the row never meant to make — and the
/// subtitle underneath has already changed back to the ordinary chapter count.
///
/// One controller drives both halves: the flood over [AppMotion.tick], then the
/// fade and collapse over [AppMotion.microOut]. A single timeline is what keeps
/// the exit from starting before the tick has landed.
class OverdueMark extends StatefulWidget {
  const OverdueMark({super.key, required this.needsReview, this.size = 15});

  final bool needsReview;
  final double size;

  /// The gap between the row's title and the mark. It lives here so that it
  /// collapses with the glyph instead of leaving a hole in the row.
  static const double gap = 6;

  @override
  State<OverdueMark> createState() => _OverdueMarkState();
}

class _OverdueMarkState extends State<OverdueMark>
    with SingleTickerProviderStateMixin {
  /// The flood, then the exit — derived from the tokens rather than restated,
  /// so retuning either one moves this timeline with it.
  static final Duration _total = AppMotion.tick + AppMotion.microOut;

  /// Where the flood ends and the exit begins, as a fraction of [_total].
  static final double _split =
      AppMotion.tick.inMicroseconds / _total.inMicroseconds;

  /// Built on the first frame that needs it, not on the first frame. A healthy
  /// subject is the common case by a wide margin, and it should cost nothing:
  /// no controller, no ticker, no laid-out box, no gap.
  ///
  /// Deliberately not `late final`: a lazy field would be *initialised* by the
  /// `dispose` that was trying to tear it down, which looks up a ticker on a
  /// deactivated element and throws.
  AnimationController? _controller;

  AnimationController get _c =>
      _controller ??= AnimationController(vsync: this, duration: _total);

  /// Whether this row has ever been overdue.
  late bool _everOverdue = widget.needsReview;

  @override
  void didUpdateWidget(OverdueMark old) {
    super.didUpdateWidget(old);
    if (widget.needsReview == old.needsReview) return;

    if (widget.needsReview) {
      // Overdue again: the mark comes straight back, un-flooded. Decay
      // returning is not an event to celebrate with a reverse animation.
      _c.value = 0;
      setState(() => _everOverdue = true);
      return;
    }
    if (prefersReducedMotion(context)) {
      _c.value = 1;
      return;
    }
    _c.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_everOverdue) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        // The flood runs out the first stretch of the timeline; the exit takes
        // the rest. Before the split the exit is a no-op, and after it the
        // flood is finished — neither ever runs while the other is moving.
        final flood = (v / _split).clamp(0.0, 1.0);
        final leaving = ((v - _split) / (1 - _split)).clamp(0.0, 1.0);
        final remaining = 1 - AppMotion.standard.transform(leaving);

        if (remaining == 0) return const SizedBox.shrink();

        return Align(
          alignment: AlignmentDirectional.centerStart,
          // Collapses the glyph *and* its leading gap together, so the title
          // slides back over exactly the space the mark was holding.
          widthFactor: remaining,
          child: Opacity(
            opacity: remaining,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: OverdueMark.gap,
              ),
              child: _Flood(t: flood, size: widget.size),
            ),
          ),
        );
      },
    );
  }
}

class _OverdueCheckPainter extends CustomPainter {
  const _OverdueCheckPainter({
    required this.t,
    required this.color,
    required this.tick,
  });

  /// The eased progress, 0 = overdue, 1 = complete.
  final double t;
  final Color color;

  /// The tick's colour once it is sitting on a solid disc.
  final Color tick;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void paint(Canvas canvas, Size size) {
    // Authored in the same 24-grid as every other glyph, scaled once here.
    canvas
      ..save()
      ..scale(size.width / 24);

    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Radius down, stroke up: the ring floods inward to a solid disc without a
    // second shape ever entering the picture.
    ring.strokeWidth = _lerp(1.9, 9, t);
    canvas.drawCircle(const Offset(12, 12), _lerp(9, 4.5, t), ring);

    // The two dashes of the overdue bar travel to the two segments of the
    // authored check path, scaled to CheckDisc proportions about the centre.
    const scale = 0.52 * 18 / 24;
    Offset target(Offset p) =>
        const Offset(12, 12) + (p - const Offset(12, 12)) * scale;

    final dashes = <(Offset, Offset)>[
      (const Offset(12, 7.5), const Offset(12, 9.3)),
      (const Offset(12, 11.9), const Offset(12, 12.5)),
    ];
    final checkPoints = <(Offset, Offset)>[
      (target(const Offset(5, 12.5)), target(const Offset(9.5, 17))),
      (target(const Offset(9.5, 17)), target(const Offset(19, 7))),
    ];

    final bar = Paint()
      // The dashes start as the mark's own colour and end white on the disc.
      ..color = Color.lerp(color, tick, t)!
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = _lerp(1.9, 3 * scale, t);

    for (var i = 0; i < dashes.length; i++) {
      canvas.drawLine(
        Offset.lerp(dashes[i].$1, checkPoints[i].$1, t)!,
        Offset.lerp(dashes[i].$2, checkPoints[i].$2, t)!,
        bar,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_OverdueCheckPainter old) =>
      old.t != t || old.color != color || old.tick != tick;
}
