import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/branding/ather_logo.dart' as brand;
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_card.dart';
import '../../core/widgets/ather_scaffold.dart';
import 'settings_screen.dart';

/// What the app is, and which build this is.
///
/// Moved off the Settings page for the reason everything else moved: it was a
/// card carrying a mark, a tagline, the homework rule and the version number,
/// sitting between two one-line rows. None of it is a control, and none of it
/// is read twice.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return AtherScreen(
      header: AtherHeader(title: l.settingsAbout, onBack: () => context.pop()),
      children: <Widget>[
        AtherCard(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // The glyph on the card's white -- the plated icon would put a
              // grey square inside a white card.
              Row(
                children: <Widget>[
                  const brand.AtherGlyph(size: 26),
                  const SizedBox(width: AppSpacing.md),
                  Text(l.appName, style: AppTypography.cardTitle),
                ],
              ),
              const SizedBox(height: AppSpacing.textGap),
              Text(l.appTagline, style: context.text.secondary),
              const SizedBox(height: AppSpacing.xl),
              const CardDivider(),
              const SizedBox(height: AppSpacing.xl),
              // The one product rule that is not visible anywhere in the
              // interface, so it is stated where the app describes itself.
              Text(l.homeworkNote, style: context.text.sublabel),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Center(
          child: Text(
            l.settingsVersionFormat(SettingsScreen.appVersion),
            style: context.text.micro,
          ),
        ),
      ],
    );
  }
}
