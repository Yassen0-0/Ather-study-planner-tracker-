import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_icons.dart';
import '../../core/widgets/icon_motion.dart';
import '../../core/widgets/pop_in.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/reduced_motion.dart';
import '../providers/summary_providers.dart';

/// The four-slot tab bar.
///
/// Four destinations, evenly distributed across the full width of the bar. There
/// is **no "+"**: the visual refresh removed the raised centre button and its
/// popup menu entirely.
///
/// The "+" was defended as the shortest path from "I sat a paper" to "it is
/// recorded". What it actually did was ask the student which lesson they meant,
/// after the fact, from a context that had none — and it was dead whenever no
/// lesson existed yet, which is the state a new student is in. Logging an exam
/// is now reachable only from somewhere that already knows the lesson: the
/// "Exam" pill on the dashboard's up-next card, and the CTA on a lesson screen.
/// One fewer control, and no route that can start with the question "which one?".
///
/// Hand-built rather than a `NavigationBar` because Material insists on an
/// indicator pill, a ripple and a tint on scroll — all three of which this
/// design removes.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final overdue = ref.watch(dashboardProvider).overdueCount;

    return Scaffold(
      backgroundColor: context.colors.pageBackground,
      // The scroll view has to actually pass under the bar, or the blur below
      // has nothing to blur. AtherScreen adds the bar's height back as bottom
      // padding, so the last card travels behind the glass instead of stopping
      // short of it.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _floatingBar(
        context,
        // Expanded, not spaceAround: with the centre slot gone the four tabs
        // take an equal quarter of the bar each, so the touch target runs edge
        // to edge and no tab is nearer the middle than another.
        tabs: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: _Tab(
                glyph: AtherGlyph.home,
                label: l.navHome,
                selected: navigationShell.currentIndex == 0,
                onTap: () => _goBranch(0),
              ),
            ),
            Expanded(
              child: _Tab(
                glyph: AtherGlyph.review,
                label: l.navReview,
                selected: navigationShell.currentIndex == 1,
                badge: overdue,
                onTap: () => _goBranch(1),
              ),
            ),
            Expanded(
              child: _Tab(
                glyph: AtherGlyph.chart,
                label: l.navProgress,
                selected: navigationShell.currentIndex == 2,
                onTap: () => _goBranch(2),
              ),
            ),
            Expanded(
              child: _Tab(
                glyph: AtherGlyph.tasks,
                label: l.navTasks,
                selected: navigationShell.currentIndex == 3,
                onTap: () => _goBranch(3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the already-selected tab returns to that branch's root, the
      // behaviour a bottom bar is expected to have.
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

/// The bar floats: a glass pill inset from all four edges.
///
/// **The glass is still the app's one sanctioned exception** (PROJECT.md §3.10
/// bans blur, §3.19 bounds the exception to this surface). Nothing about those
/// bounds moved when the "+" left: exactly one [BackdropFilter], a mandatory
/// clip, a sigma that is never animated, and a platform gate rather than a
/// reduce-motion gate.
///
/// Losing the "+" also lost the only thing that ever overhung the pill, so the
/// bar is now exactly its own height plus its lift — no [Stack], and nothing
/// drawn outside the clip.
Widget _floatingBar(BuildContext context, {required Widget tabs}) {
  final safeBottom = MediaQuery.paddingOf(context).bottom;

  return SizedBox(
    // The whole thing, inset included, so Scaffold hands this height down as
    // the body's bottom padding and AtherScreen can add it back as list travel.
    height: AppSizes.barHeight + AppSizes.barLift * 2 + safeBottom,
    child: Padding(
      // The same page margin every card uses, so the pill lines up with the
      // content it is floating over rather than nearly lining up with it.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageMargin,
        AppSizes.barLift,
        AppSpacing.pageMargin,
        AppSizes.barLift + safeBottom,
      ),
      child: _glassPill(
        context,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
          child: tabs,
        ),
      ),
    ),
  );
}

Widget _glassPill(BuildContext context, Widget content) {
  final radius = BorderRadius.circular(AppRadius.pill);
  final border = Border.all(color: context.colors.dividerStrong, width: 1);

  // Deliberately NOT gated on MediaQuery.disableAnimations. Glass is a visual
  // effect, not a motion: a student who turns on reduce-motion because
  // scrolling makes them ill has no reason to lose the frosted bar. That flag
  // owns fades, scales, slides and pops -- nothing else. The only reason to
  // fall back is a platform that cannot raster a blur cheaply.
  final platform = Theme.of(context).platform;
  final canBlur =
      platform == TargetPlatform.android || platform == TargetPlatform.iOS;

  if (!canBlur) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.card,
        border: border,
        borderRadius: radius,
      ),
      child: content,
    );
  }

  return ClipRRect(
    // Mandatory: unbounded, a BackdropFilter blurs the entire layer tree,
    // including the content it is supposed to sit above. Rounded now, because
    // the thing being bounded is a pill.
    borderRadius: radius,
    child: BackdropFilter(
      // Never animated. Animating a blur radius drops frames; if the bar ever
      // needs to react to scroll, animate the tint alpha instead. Nothing in
      // this app animates on scroll position at all -- see PROJECT.md §3.21.
      filter: ImageFilter.blur(
        sigmaX: AppMotion.glassSigma,
        sigmaY: AppMotion.glassSigma,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // 0.72 is a floor, not a starting point: below it the inactive label
          // stops being legible over a white card. Everything that passes under
          // this bar is lighter than the tint, except the toast -- which is why
          // the toast is pinned clear of it. See AppSizes.toastBottom.
          color: context.colors.card.withValues(alpha: AppMotion.glassTint),
          border: border,
          borderRadius: radius,
        ),
        child: content,
      ),
    ),
  );
}

/// The tab switch: opacity, and nothing else.
///
/// Fifty times a day means the least motion in the app -- 150ms, no slide. Why
/// not [AnimatedSwitcher]: every branch has to stay in the tree or each tab
/// loses its navigation stack and scroll position, which is the entire reason
/// the shell exists. go_router's `navigatorContainerBuilder` hands us all
/// branches at once, so the switch is nothing but opacity.
class BranchCrossFade extends StatelessWidget {
  const BranchCrossFade({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final reduced = prefersReducedMotion(context);

    return Stack(
      // Tight constraints for every branch, matching the IndexedStack this
      // replaced. Under the default loose fit a branch would shrink-wrap its
      // content instead of filling the screen.
      fit: StackFit.expand,
      children: <Widget>[
        for (var i = 0; i < children.length; i++)
          AnimatedOpacity(
            opacity: i == currentIndex ? 1 : 0,
            duration: reduced ? Duration.zero : AppMotion.nav,
            curve: AppMotion.standard,
            // A faded-out branch must not take taps, be read out, or keep
            // ticking. It stays mounted; it does not stay alive.
            child: IgnorePointer(
              ignoring: i != currentIndex,
              child: ExcludeSemantics(
                excluding: i != currentIndex,
                child: TickerMode(
                  enabled: i == currentIndex,
                  child: children[i],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final AtherGlyph glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    // Selected is the brand accent now, not the foreground colour. On a bar
    // where every other pixel is grey, hue carries "you are here" further than
    // value does -- and it is the same blue the progress bars fill with, so the
    // student learns one colour rather than two.
    return Pressable(
      onTap: onTap,
      // One tween drives the glyph's weight, the glyph's colour and the label
      // together, so a tab can never sit at its final colour with its starting
      // weight.
      child: TabGlyph(
        glyph: glyph,
        selected: selected,
        selectedColor: context.colors.accent,
        unselectedColor: context.colors.textTertiary,
        builder: (context, tinted, glyphWidget) => SizedBox(
          // Width comes from the Expanded above -- the bar divides itself into
          // four equal columns rather than centring four fixed-width ones.
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // The badge hangs off the icon, not off the tab: a tab is a
              // quarter of the bar wide now, and anchoring to its edge would
              // float the count somewhere out in the gap beside the glyph.
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  glyphWidget,
                  PositionedDirectional(
                    top: -5,
                    end: -8,
                    child: _OverdueBadge(count: badge),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.tabLabel.copyWith(color: tinted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The overdue count. Always a number, never a bare dot: three decayed lessons
/// and thirty are not the same news.
///
/// It arrives with a pop keyed on the count -- keying it is what makes 3 -> 4
/// replay instead of silently swapping a digit -- and leaves with a plain fade.
/// The absence of overdue work is not an event worth animating away from.
class _OverdueBadge extends StatefulWidget {
  const _OverdueBadge({required this.count});

  final int count;

  @override
  State<_OverdueBadge> createState() => _OverdueBadgeState();
}

class _OverdueBadgeState extends State<_OverdueBadge> {
  /// The badge has to keep rendering its old number while it fades out, or the
  /// student watches "3" become "0" on the way to nothing.
  late int _shown = widget.count;

  @override
  void didUpdateWidget(_OverdueBadge old) {
    super.didUpdateWidget(old);
    if (widget.count > 0) _shown = widget.count;
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.count > 0;
    final reduced = prefersReducedMotion(context);

    // Four of the five tabs never carry a badge. Costing them a fade layer and
    // a laid-out container apiece, forever, to buy the review tab a 150ms exit
    // is not a trade worth making.
    if (!visible && _shown == 0) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: reduced ? Duration.zero : AppMotion.microOut,
      curve: AppMotion.standard,
      child: IgnorePointer(
        ignoring: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: visible
              ? PopIn(
                  key: ValueKey<int>(_shown),
                  child: _badge(context, _shown),
                )
              : _badge(context, _shown),
        ),
      ),
    );
  }
}

Widget _badge(BuildContext context, int count) {
  return Container(
    constraints: const BoxConstraints(minWidth: 16),
    height: 16,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: context.colors.wrong,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '$count',
      style: AppTypography.style(
        size: 10,
        weight: AppTypography.bold,
        color: context.colors.onState,
      ),
    ),
  );
}

