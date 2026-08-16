import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_card.dart';
import '../../core/widgets/ather_scaffold.dart';

/// The privacy policy, written from the code rather than from a template.
///
/// Every claim here is checkable in this repository: what is stored locally
/// (drift tables), what leaves the device (one Firestore document per
/// student), what Firebase holds (an email), and what deletion does (the
/// Settings path at the bottom of the page). The day any of those changes,
/// this screen must change with it — a policy that drifts from the code is
/// worse than none.
///
/// Not legal advice; a plain-language draft the developer must review before
/// release.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return AtherScreen(
      header: AtherHeader(
        title: l.privacyTitle,
        onBack: () => context.pop(),
      ),
      children: <Widget>[
        AtherCard(
          padding: AppSpacing.cardPadding,
          child: Text(
            l.privacyIntro,
            style: context.text.secondary.copyWith(height: 1.6),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Section(title: l.privacyLocalTitle, body: l.privacyLocalBody),
        const SizedBox(height: AppSpacing.md),
        _Section(title: l.privacyAccountTitle, body: l.privacyAccountBody),
        const SizedBox(height: AppSpacing.md),
        _Section(title: l.privacyCloudTitle, body: l.privacyCloudBody),
        const SizedBox(height: AppSpacing.md),
        _Section(title: l.privacyDeleteTitle, body: l.privacyDeleteBody),
        const SizedBox(height: AppSpacing.md),
        _Section(title: l.privacyNoCollectTitle, body: l.privacyNoCollectBody),
      ],
    );
  }
}

/// One titled card per topic — the same card, title and body style the rest
/// of Settings uses, so the policy reads like part of the app rather than a
/// document pasted over it.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AtherCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.textGap),
          Text(body, style: context.text.secondary.copyWith(height: 1.6)),
        ],
      ),
    );
  }
}
