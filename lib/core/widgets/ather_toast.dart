import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'ather_icons.dart';
import 'reduced_motion.dart';

/// The black confirmation toast.
///
/// The old build saved an exam and returned to the lesson silently, which left
/// students unsure whether anything had happened. This is the acknowledgement:
/// black card, green tick, one sentence, 2.2 seconds.
///
/// Implemented as an overlay entry rather than a `SnackBar` because the design
/// pins it 104px above the bottom — clear of the tab bar and the FAB — and
/// Material's snack bar insists on sitting flush to the bottom of the scaffold.
/// What a toast is acknowledging.
///
/// The green tick used to be unconditional, which meant the only way to report
/// a failed write was a success mark beside the word "failed".
enum ToastTone {
  /// Something was recorded. Green tick.
  done,

  /// Something did not work. The overdue mark, in red -- the app's one existing
  /// "this is wrong" glyph, rather than a new one invented for errors.
  failed,
}

void showAtherToast(
  BuildContext context,
  String message, {
  ToastTone tone = ToastTone.done,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  showAtherToastOn(overlay, Directionality.of(context), message, tone: tone);
}

/// The same toast, addressed by overlay rather than context.
///
/// Callers that show a toast *after* an `await` capture the overlay before it,
/// so nothing reaches for a `BuildContext` that may have been unmounted while
/// the write was in flight.
void showAtherToastOn(
  OverlayState overlay,
  TextDirection direction,
  String message, {
  ToastTone tone = ToastTone.done,
}) {
  // One toast at a time. Two overlapping saves used to insert two entries at
  // the same pinned offset and stack them, one black card exactly on top of
  // another, with the lower one unreadable and both timers running.
  _current?.replace();

  late final OverlayEntry entry;

  // A ValueNotifier rather than a setState on a captured State: the entry is
  // removed by a timer, and the card has to be told to leave first.
  final leaving = ValueNotifier<bool>(false);

  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 20,
      right: 20,
      // Load-bearing, not a taste decision, and derived from the bar's own
      // geometry rather than typed twice -- see AppSizes.toastBottom. The tab
      // bar is glass and this card is the one black surface in the app: passing
      // under the 0.72 white tint it would drop the inactive tab label to
      // 1.5:1, so it has to clear the bar entirely.
      // The system inset is added at build time rather than baked into the
      // constant: a gesture bar is 34px on one phone and 0 on another, and the
      // bar this has to clear sits on top of whichever it is.
      bottom: AppSizes.toastBottom + MediaQuery.paddingOf(context).bottom,
      child: Directionality(
        textDirection: direction,
        child: _ToastCard(message: message, tone: tone, leaving: leaving),
      ),
    ),
  );

  overlay.insert(entry);

  final live = _LiveToast(entry: entry, leaving: leaving);
  _current = live;

  live.dwell = Timer(AppMotion.toast, live.replace);
}

/// The toast currently on screen, if any.
///
/// Module-level because a toast outlives whatever showed it: the entry is owned
/// by the overlay and torn down by a timer, so there is no widget to hang this
/// off. Exactly one can exist, which is the point.
_LiveToast? _current;

class _LiveToast {
  _LiveToast({required this.entry, required this.leaving});

  final OverlayEntry entry;
  final ValueNotifier<bool> leaving;

  Timer? dwell;
  Timer? exit;
  bool _gone = false;

  /// Starts this toast leaving, and stops it from being torn down twice.
  void replace() {
    if (_gone) return;
    _gone = true;
    dwell?.cancel();
    if (identical(_current, this)) _current = null;

    leaving.value = true;
    exit = Timer(AppMotion.microOut, () {
      if (entry.mounted) entry.remove();
      leaving.dispose();
    });
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({
    required this.message,
    required this.tone,
    required this.leaving,
  });

  final String message;
  final ToastTone tone;
  final ValueListenable<bool> leaving;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    // Fades in on the frame after insertion; an overlay entry that appears at
    // full opacity in the same frame reads as a glitch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduced = prefersReducedMotion(context);

    return ValueListenableBuilder<bool>(
      valueListenable: widget.leaving,
      builder: (context, leaving, child) => AnimatedOpacity(
        opacity: leaving ? 0 : _opacity,
        duration: reduced
            ? Duration.zero
            // No downward slide on exit: the eye has already left it.
            : (leaving ? AppMotion.microOut : AppMotion.micro),
        curve: AppMotion.standard,
        child: TweenAnimationBuilder<double>(
          // An exact 12px, so AnimatedSlide's size-relative offset cannot make
          // a one-line and a two-line toast rise different distances.
          tween: Tween<double>(
            begin: AppMotion.toastRise,
            end: reduced || _opacity == 1 ? 0 : AppMotion.toastRise,
          ),
          duration: reduced ? Duration.zero : AppMotion.micro,
          curve: AppMotion.standard,
          builder: (context, dy, _) =>
              Transform.translate(offset: Offset(0, dy), child: child),
        ),
      ),
      child: _card(),
    );
  }

  Widget _card() {
    final failed = widget.tone == ToastTone.failed;

    return Semantics(
      // Announced when it appears rather than only when something happens to
      // land on it. The toast is the only confirmation that an exam was
      // recorded, and it was previously invisible to a screen reader entirely.
      liveRegion: true,
      label: widget.message,
      child: ExcludeSemantics(child: _plate(failed)),
    );
  }

  Widget _plate(bool failed) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: context.colors.actionPrimary,
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: Row(
          children: <Widget>[
            // The plate is `actionPrimary`, which **inverts**: black in light,
            // white in dark. A bare green tick was fine on the black one (9.5:1)
            // and nearly invisible on the white one (2.2:1). A filled disc with
            // a white tick carries its own contrast onto either plate, and it is
            // the app's existing success mark rather than a new one -- the same
            // shape the celebration and the empty review queue use.
            //
            // The failure mark stays an outline: red on white is 3.6:1 and red
            // on black 5.9:1, both clear of the 3:1 an icon needs, and a filled
            // red disc would read as a much louder event than "try again".
            if (failed)
              AtherIcon(
                AtherGlyph.overdue,
                size: 18,
                color: context.colors.wrong,
                strokeWidth: 3,
              )
            else
              const CheckDisc(size: 18, checkSize: 11, strokeWidth: 2.8),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(widget.message, style: context.text.toastMessage),
            ),
          ],
        ),
      ),
    );
  }
}
