import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../layout/breakpoints.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'buttons.dart';
import 'icon_motion.dart';
import 'list_entrance.dart';

/// The back chevron.
///
/// Drawn pointing right, which is "backwards" in Arabic, and mirrored under
/// LTR. The header places it on the leading edge, so it lands on the right in
/// Arabic and the left in English without either screen knowing about it.
///
/// The reflection is a tween rather than a swap, so switching language in
/// Settings turns the arrow over instead of blinking it. See
/// [AnimatedBackChevron] for why the stroke moves with it.
class BackChevron extends StatelessWidget {
  const BackChevron({super.key, this.size = 19});

  final double size;

  @override
  Widget build(BuildContext context) => AnimatedBackChevron(size: size);
}

/// Header for an inner screen: circular back button, title, optional context
/// line beneath it, optional trailing actions.
///
/// Root screens (home, review, progress) never show a back button — there is
/// nothing above them to go back to, and an arrow that pops to nowhere is a
/// standing invitation to lose the student.
class AtherHeader extends StatelessWidget {
  const AtherHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The page margin, not a value of its own. The title has to start on the
      // same vertical as the cards below it, and this header and `DayHeader`
      // have to start on the same vertical as each other -- they are the same
      // screen shape wearing two hats, and they used to sit 14 and 18 from the
      // edge respectively, which put every inner screen's title 2 inside its
      // own content and every day screen's title 2 outside it.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMargin,
        AppSpacing.opticalInset,
        AppSpacing.pageMargin,
        AppSpacing.xl,
      ),
      child: Row(
        children: <Widget>[
          if (onBack != null) ...<Widget>[
            CircleHeaderButton(
              onTap: onBack!,
              semanticLabel: L.of(context).commonBack,
              child: const BackChevron(),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.screenTitle,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.sublabel,
                  ),
              ],
            ),
          ),
          for (final action in actions) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            action,
          ],
        ],
      ),
    );
  }
}

/// Page chrome shared by every screen: the grey page, a header, a scrolling
/// body inset by the 16px page margin, and an optional pinned bottom action.
///
/// Content is capped and centred on wide windows. The design is a phone
/// design, and the honest desktop answer is the same layout with room around
/// it — not an invented second layout the handoff never specified.
class AtherScreen extends StatelessWidget {
  const AtherScreen({
    super.key,
    required this.header,
    required this.children,
    this.bottom,
  });

  final Widget header;
  final List<Widget> children;
  final Widget? bottom;

  static const double maxContentWidth = 520;

  @override
  Widget build(BuildContext context) {
    // The tab bar is glass, and AppShell sets `extendBody: true` so the list
    // scrolls *under* it -- otherwise there is nothing behind the bar to blur.
    // Scaffold hands that bar's height down as bottom padding, and it is added
    // back here so the last card can travel behind the glass instead of
    // stopping short of it. On screens with no tab bar this is 0 plus whatever
    // the system inset is, which the list wanted anyway.
    final underBar = MediaQuery.paddingOf(context).bottom;

    final body = ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageMargin,
        AppSpacing.opticalInset,
        AppSpacing.pageMargin,
        AppSpacing.xxxl + underBar,
      ),
      children: children,
    );

    return Scaffold(
      backgroundColor: context.colors.pageBackground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        // One entrance per row per visit to this screen. Without it, a row
        // scrolled out and back is a fresh mount and animates again -- see
        // ListEntranceScope.
        child: ListEntranceScope(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.windowSize.isCompact
                    ? double.infinity
                    : maxContentWidth,
              ),
              child: Column(
                children: <Widget>[
                  header,
                  Expanded(
                    child: ScrollConfiguration(
                      // The design hides scrollbars; the cards themselves show
                      // that a list continues.
                      behavior: const _NoScrollbar(),
                      child: body,
                    ),
                  ),
                  // The list may pass under the glass bar; a button may not.
                  // Same inset, applied as real space rather than scroll travel.
                  if (bottom != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: underBar),
                      child: bottom,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoScrollbar extends ScrollBehavior {
  const _NoScrollbar();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
