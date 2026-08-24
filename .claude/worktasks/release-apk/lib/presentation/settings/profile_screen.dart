import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_scaffold.dart';
import '../../core/widgets/ather_sheet.dart';
import '../../core/widgets/ather_toast.dart';
import '../../core/widgets/settings_list.dart';
import '../../domain/repositories/auth_repository.dart';
import '../common/prompts.dart';
import '../providers/app_providers.dart';
import '../providers/auth_providers.dart';

/// The student's own name and year.
///
/// Everything here is kept **on this device**. See [ProfileNameNotifier] for
/// the reasoning: the account knows a student's email and nothing else, which
/// is a position worth more than saving them one line of typing on a new phone.
///
/// There is no photo picker. A photo means an image plugin, a gallery
/// permission prompt, a file to store and a file to delete on account deletion
/// — a large amount of surface for a picture nobody but its owner ever sees.
/// The first letter of the name does the same job everywhere it appears.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  /// The three years of Thanaweya Amma, plus "not said".
  static const List<int> _years = <int>[1, 2, 3];

  static String yearLabel(L l, int year) => switch (year) {
    1 => l.profileYearFirst,
    2 => l.profileYearSecond,
    3 => l.profileYearThird,
    _ => l.profileYearUnset,
  };

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Verification happens outside the app: the student opens their inbox and
    // taps a link. Nothing in the running app would notice, so this screen --
    // the one place that shows the state -- asks the server when it opens.
    // Otherwise a student who has just verified comes back to a screen still
    // telling them to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authRepositoryProvider).reloadAccount();
    });
  }

  /// Sends the link again, and says which of the three things happened.
  ///
  /// Firebase rate-limits resends, and that answer is "wait a moment", not
  /// "your account is broken" -- so it gets its own sentence rather than the
  /// generic failure toast. A student who taps twice must not be told
  /// something went wrong when nothing did.
  Future<void> _resend() async {
    if (_sending) return;
    final l = L.of(context);
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final direction = Directionality.of(context);
    final sent = l.authVerificationSent;
    final tooSoon = l.authVerificationTooSoon;
    final generic = l.authErrorGeneric;

    setState(() => _sending = true);
    try {
      await ref.read(authRepositoryProvider).sendEmailVerification();
      if (overlay != null) showAtherToastOn(overlay, direction, sent);
    } on AuthException catch (e) {
      if (overlay == null) return;
      showAtherToastOn(
        overlay,
        direction,
        e.failure == AuthFailure.tooManyRequests ? tooSoon : generic,
        tone: ToastTone.failed,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final name = ref.watch(profileNameProvider);
    final year = ref.watch(profileYearProvider);
    final account = ref.watch(accountValueProvider);
    final needsVerification = ref.watch(needsEmailVerificationProvider);

    return AtherScreen(
      header: AtherHeader(title: l.profileTitle, onBack: () => context.pop()),
      children: <Widget>[
        Center(
          child: _Avatar(name: name, email: account?.email),
        ),
        const SizedBox(height: AppSpacing.xxl),
        SettingsGroup(
          children: <Widget>[
            SettingsRow(
              label: l.profileName,
              value: name.isEmpty ? l.profileNameUnset : name,
              onTap: () => _editName(context, ref, name),
            ),
            SettingsRow(
              label: l.profileYear,
              value: ProfileScreen.yearLabel(l, year),
              onTap: () => _pickYear(context, ref, year),
            ),
            if (account != null)
              SettingsRow(
                label: l.authEmail,
                value: account.email,
                trailing: SettingsRowTrailing.none,
              ),
            // Only while it is unverified, and never for a Google account,
            // which arrives verified. A row that said "confirmed" forever
            // would be one more thing to read on a screen about the student,
            // not about the app's paperwork.
            if (needsVerification)
              SettingsRow(
                label: l.authResendVerification,
                value: l.authEmailUnverified,
                busy: _sending,
                onTap: _resend,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Says plainly that nothing is being withheld. A prompt with no stated
        // consequence reads as a threat, and this one has none to make: the
        // app works exactly the same unverified.
        if (needsVerification) ...<Widget>[
          SettingsFootnote(l.authVerificationNote),
          const SizedBox(height: AppSpacing.md),
        ],
        SettingsFootnote(l.profileLocalNote),
      ],
    );
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l = L.of(context);
    final name = await showNamePrompt(
      context,
      title: l.profileName,
      hint: l.profileNameHint,
      initialValue: current.isEmpty ? null : current,
    );
    if (name == null) return;
    await ref.read(profileNameProvider.notifier).set(name);
  }

  Future<void> _pickYear(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final l = L.of(context);
    final picked = await showAtherSheet<int>(
      context: context,
      builder: (sheetContext) => AtherSheetBody(
        title: l.profileYear,
        child: SettingsGroup(
          children: <Widget>[
            for (final year in ProfileScreen._years)
              SettingsRow(
                label: ProfileScreen.yearLabel(l, year),
                value: year == current ? '✓' : null,
                trailing: SettingsRowTrailing.none,
                onTap: () => Navigator.of(sheetContext).pop(year),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ref.read(profileYearProvider.notifier).set(picked);
  }
}

/// The letter, large. Takes it from the name once there is one, and from the
/// email until then, so the circle is never empty on a screen whose whole job
/// is to be about the person looking at it.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.email});

  final String name;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final source = name.trim().isNotEmpty ? name.trim() : (email ?? '');
    final initial = source.isEmpty ? '؟' : source.substring(0, 1).toUpperCase();

    return Container(
      width: 88,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.accentSoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: AppTypography.style(
          size: 40,
          weight: AppTypography.bold,
          height: 1,
          color: colors.accent,
        ),
      ),
    );
  }
}
