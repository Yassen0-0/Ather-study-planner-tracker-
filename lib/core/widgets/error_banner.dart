import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'list_entrance.dart';

/// The one place red gets a background: an error the student has to read before
/// they can continue.
///
/// Why one widget: the wizard, the homework sheet and the login screen each had
/// a private copy of this container. Three copies is three chances for one of
/// them to start shaking -- and it must not. A shake tells a student they did
/// something stupid; this app's position is that it failed to explain the rule.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, this.height});

  final String message;

  /// Line height. The login screen's copy is longer and breaks across lines.
  final double? height;

  @override
  Widget build(BuildContext context) {
    // Keyed on the message so a *different* error replays the entrance instead
    // of swapping the sentence under the student's eyes.
    return RiseIn(
      key: ValueKey<String>(message),
      rise: AppMotion.microRise,
      duration: AppMotion.micro,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: context.colors.wrongTint,
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: Text(
          message,
          style: AppTypography.style(
            size: 13.5,
            weight: AppTypography.semiBold,
            height: height,
            color: context.colors.wrong,
          ),
        ),
      ),
    );
  }
}
