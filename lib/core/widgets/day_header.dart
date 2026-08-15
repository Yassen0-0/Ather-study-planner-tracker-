import 'package:flutter/widgets.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The header shared by the two day-shaped screens: a large title, actions on
/// the trailing edge, and the week strip beneath.
///
/// Extracted from the dashboard when the tasks screen grew the same shape. Two
/// hand-kept copies of a header is how they start to drift by a couple of pixels
/// and stop looking like one app.
class DayHeader extends StatelessWidget {
  const DayHeader({
    super.key,
    required this.title,
    this.strip,
    this.actions = const <Widget>[],
  });

  final String title;

  /// The week strip for this screen, or null for a screen that does not pick a
  /// day.
  ///
  /// Passed in rather than built here because the tasks screen fills its
  /// circles from its own data, and it is the only screen that does: the
  /// dashboard carried a copy that could not be tapped, selected nothing, and
  /// reported a fact — "an exam happened on this day" — that the cards directly
  /// beneath it already state in full. A row of seven circles that answers
  /// nothing is a row the eye has to skip past to reach the screen.
  final Widget? strip;

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The same horizontal margin as `AtherHeader` and as the page itself.
      // These two headers are the same shape on two screens and used to
      // disagree by 4, which on a 320 phone is the difference between
      // "النهارده" fitting and eliding.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMargin,
        AppSpacing.xxs,
        AppSpacing.pageMargin,
        AppSpacing.xl,
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.today,
                ),
              ),
              for (final action in actions) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                action,
              ],
            ],
          ),
          // Both the gap and the strip go together. Keeping the gap for a
          // screen with no strip would leave the title floating above 20 of
          // nothing.
          if (strip != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xxl),
            strip!,
          ],
        ],
      ),
    );
  }
}
