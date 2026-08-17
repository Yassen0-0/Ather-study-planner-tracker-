import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_scaffold.dart';
import '../../core/widgets/ather_sheet.dart';
import '../../core/widgets/settings_list.dart';
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
class ProfileScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final name = ref.watch(profileNameProvider);
    final year = ref.watch(profileYearProvider);
    final account = ref.watch(accountValueProvider);

    return AtherScreen(
      header: AtherHeader(title: l.profileTitle, onBack: () => context.pop()),
      children: <Widget>[
        Center(child: _Avatar(name: name, email: account?.email)),
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
              value: yearLabel(l, year),
              onTap: () => _pickYear(context, ref, year),
            ),
            if (account != null)
              SettingsRow(
                label: l.authEmail,
                value: account.email,
                trailing: SettingsRowTrailing.none,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
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
            for (final year in _years)
              SettingsRow(
                label: yearLabel(l, year),
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
