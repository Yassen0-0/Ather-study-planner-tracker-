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
void showAtherToast(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  showAtherToastOn(overlay, Directionality.of(context), message);
}

/// The same toast, addressed by overlay rather than context.
///
/// Callers that show a toast *after* an `await` capture the overlay before it,
/// so nothing reaches for a `BuildContext` that may have been unmounted while
/// the write was in flight.
void showAtherToastOn(
  OverlayState overlay,
  TextDirection direction,
  String message,
) {
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
        child: _ToastCard(message: message, leaving: leaving),
      ),
    ),
  );

  overlay.insert(entry);
  Future<void>.delayed(AppMotion.toast, () {
    leaving.value = true;
    Future<void>.delayed(AppMotion.microOut, () {
      if (entry.mounted) entry.remove();
      leaving.dispose();
    });
  });
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({required this.message, required this.leaving});

  final String message;
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
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: context.colors.actionPrimary,
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: Row(
          children: <Widget>[
            AtherIcon(
              AtherGlyph.check,
              size: 18,
              color: context.colors.right,
              strokeWidth: 3,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                widget.message,
                style: AppTypography.style(
                  size: 14.5,
                  weight: AppTypography.semiBold,
                  color: context.colors.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
