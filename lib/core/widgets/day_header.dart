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
    required this.strip,
    this.actions = const <Widget>[],
  });

  final String title;

  /// The [WeekStrip] for this screen. Passed in rather than built here: the two
  /// screens fill its circles from different data and only one of them is a
  /// picker.
  final Widget strip;

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
          const SizedBox(height: AppSpacing.xxl),
          strip,
        ],
      ),
    );
  }
}
