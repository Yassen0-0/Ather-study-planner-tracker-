import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_icons.dart';
import '../../core/widgets/ather_toast.dart';
import '../../core/widgets/pop_in.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/reduced_motion.dart';
import '../providers/navigation_providers.dart';
import '../providers/summary_providers.dart';

/// The five-slot tab bar.
///
/// Four destinations plus a raised black "+" in the middle. The "+" is not a
/// fifth tab: it is the shortest path from "I just sat a paper" to "it is
/// recorded", which is the only action the whole product exists to capture, so
/// it gets the most reachable pixel on the screen.
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
    final target = ref.watch(quickExamTargetProvider);

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
        tabs: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _Tab(
              glyph: AtherGlyph.home,
              label: l.navHome,
              selected: navigationShell.currentIndex == 0,
              onTap: () => _goBranch(0),
            ),
            _Tab(
              glyph: AtherGlyph.review,
              label: l.navReview,
              selected: navigationShell.currentIndex == 1,
              badge: overdue,
              onTap: () => _goBranch(1),
            ),
            // The "+" is drawn above the pill rather than inside it, so this
            // only reserves its slot. Putting the real button in the Row would
            // put it inside the ClipRRect, where it would be both clipped and
            // blurred -- and the primary action does not go translucent.
            const SizedBox(width: AppSizes.fab),
            _Tab(
              glyph: AtherGlyph.chart,
              label: l.navProgress,
              selected: navigationShell.currentIndex == 2,
              onTap: () => _goBranch(2),
            ),
            _Tab(
              glyph: AtherGlyph.tasks,
              label: l.navTasks,
              selected: navigationShell.currentIndex == 3,
              onTap: () => _goBranch(3),
            ),
          ],
        ),
        fab: _QuickExamButton(
          onTap: () {
            if (target == null) {
              showAtherToast(context, l.addContentBeforeExam);
              return;
            }
            context.push(Routes.exam(target.lesson.id, fromLesson: false));
          },
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

/// The bar floats: a glass pill inset from all four edges, with the black "+"
/// raised over its top edge.
///
/// **The glass is still the app's one sanctioned exception** (PROJECT.md §3.10
/// bans blur, §3.19 bounds the exception to this surface). Nothing about those
/// bounds moved when the shape did: exactly one [BackdropFilter], a mandatory
/// clip, a sigma that is never animated, an opaque FAB, and a platform gate
/// rather than a reduce-motion gate.
///
/// What did change: a full-bleed bar was separated from the page by one hairline
/// along its top. A floating one has content on all four sides and no shadow to
/// lift it -- this app has none anywhere -- so the hairline goes all the way
/// round. That border is the only thing holding the pill off the page.
Widget _floatingBar(
  BuildContext context, {
  required Widget tabs,
  required Widget fab,
}) {
  final safeBottom = MediaQuery.paddingOf(context).bottom;

  return SizedBox(
    // The whole thing, inset included, so Scaffold hands this height down as
    // the body's bottom padding and AtherScreen can add it back as list travel.
    height:
        AppSizes.fabOverhang +
        AppSizes.barHeight +
        AppSizes.barLift +
        safeBottom,
    child: Stack(
      alignment: Alignment.bottomCenter,
      children: <Widget>[
        Positioned(
          // The same page margin every card uses, so the pill lines up with the
          // content it is floating over rather than nearly lining up with it.
          left: AppSpacing.pageMargin,
          right: AppSpacing.pageMargin,
          bottom: AppSizes.barLift + safeBottom,
          height: AppSizes.barHeight,
          child: _glassPill(
            context,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
              child: tabs,
            ),
          ),
        ),
        Positioned(
          bottom: AppSizes.barLift + safeBottom + AppSizes.fabLift,
          child: fab,
        ),
      ],
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
    final color = selected
        ? context.colors.textPrimary
        : context.colors.textTertiary;

    return Pressable(
      onTap: onTap,
      // One tween drives the icon and the label together, so they can never
      // disagree about how selected this tab is.
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(begin: color, end: color),
        duration: prefersReducedMotion(context) ? Duration.zero : AppMotion.nav,
        curve: AppMotion.standard,
        builder: (context, tinted, _) => SizedBox(
          width: 62,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AtherIcon(glyph, size: 25, color: tinted!),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.tabLabel.copyWith(color: tinted),
                  ),
                ],
              ),
              PositionedDirectional(
                top: -3,
                end: 8,
                child: _OverdueBadge(count: badge),
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

class _QuickExamButton extends StatelessWidget {
  const _QuickExamButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        // Positioned by the bar itself now: it is lifted clear of the pill so
        // it reads as an action sitting on top of the navigation rather than
        // one of the destinations.
        width: AppSizes.fab,
        height: AppSizes.fab,
        decoration: BoxDecoration(
          color: context.colors.actionPrimary,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: AtherIcon(
          AtherGlyph.plus,
          size: 26,
          color: context.colors.onPrimary,
        ),
      ),
    );
  }
}
