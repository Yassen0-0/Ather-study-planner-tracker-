import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/branding/ather_logo.dart';
import '../../core/l10n/formatting.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_card.dart';
import '../../core/widgets/ather_controls.dart';
import '../../core/widgets/ather_scaffold.dart';
import '../../core/widgets/ather_toast.dart';
import '../../core/widgets/buttons.dart';
import '../../domain/repositories/backup_repository.dart';
import '../common/prompts.dart';
import '../providers/app_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/backup_providers.dart';

/// A short list of cards and nothing else.
///
/// There is no subject management (the four are fixed) and no "mark as
/// reviewed" hiding in an advanced section — the only way to reset a review
/// clock is to sit an exam.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// The order the three options appear in, and the only place that order is
  /// written down. The segmented control renders it and reads a tap back
  /// through the same list, so an index can never drift from a mode.
  static const List<ThemeMode> _themeModes = <ThemeMode>[
    ThemeMode.light,
    ThemeMode.dark,
    ThemeMode.system,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final notifications = ref.watch(notificationsEnabledProvider);
    final account = ref.watch(accountValueProvider);
    final lockEnabled = ref.watch(appLockEnabledProvider);
    // The lock switch is only offered where the device can actually satisfy it;
    // a toggle that locks the app behind a sensor that will never answer would
    // shut the student out of their own work.
    final biometricsAvailable =
        ref.watch(biometricsAvailableProvider).value ?? false;

    return AtherScreen(
      header: AtherHeader(title: l.settingsTitle, onBack: () => context.pop()),
      children: <Widget>[
        AtherCard(
          padding: AppSpacing.cardPaddingLarge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l.settingsLanguage, style: AppTypography.cardTitle),
              const SizedBox(height: AppSpacing.lg),
              SegmentedControl(
                labels: <String>[
                  l.settingsLanguageArabic,
                  l.settingsLanguageEnglish,
                ],
                selectedIndex: locale.languageCode == 'en' ? 1 : 0,
                onSelect: (index) => ref
                    .read(localeProvider.notifier)
                    .set(Locale(index == 1 ? 'en' : 'ar')),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Built from the same card and the same segmented control as the
        // language row above it, deliberately: a second way of presenting a
        // three-way choice would be a new pattern to learn for no gain.
        AtherCard(
          padding: AppSpacing.cardPaddingLarge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l.settingsTheme, style: AppTypography.cardTitle),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                l.settingsThemeBody,
                style: AppTypography.style(
                  size: 13,
                  weight: AppTypography.medium,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SegmentedControl(
                labels: <String>[
                  l.settingsThemeLight,
                  l.settingsThemeDark,
                  l.settingsThemeSystem,
                ],
                selectedIndex: _themeModes.indexOf(themeMode),
                onSelect: (index) => ref
                    .read(themeModeProvider.notifier)
                    .set(_themeModes[index]),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AtherCard(
          padding: AppSpacing.cardPaddingLarge,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l.settingsNotifications,
                      style: AppTypography.cardTitle,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      l.settingsNotificationsBody,
                      style: AppTypography.style(
                        size: 13,
                        weight: AppTypography.medium,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              AtherSwitch(
                value: notifications,
                onChanged: (value) =>
                    ref.read(notificationsEnabledProvider.notifier).set(value),
              ),
            ],
          ),
        ),
        if (biometricsAvailable) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          AtherCard(
            padding: AppSpacing.cardPaddingLarge,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l.lockSetting, style: AppTypography.cardTitle),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        l.lockSettingBody,
                        style: AppTypography.style(
                          size: 13,
                          weight: AppTypography.medium,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                AtherSwitch(
                  value: lockEnabled,
                  onChanged: (value) =>
                      ref.read(appLockEnabledProvider.notifier).set(value),
                ),
              ],
            ),
          ),
        ],
        if (account != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          const _BackupCard(),
          const SizedBox(height: AppSpacing.md),
          AtherCard(
            padding: AppSpacing.cardPaddingLarge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(l.authAccount, style: AppTypography.cardTitle),
                const SizedBox(height: 6),
                Text(account.email, style: context.text.secondary),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: l.authSignOut,
                  tone: PrimaryButtonTone.wrong,
                  onTap: () async {
                    final confirmed = await confirmDestructive(
                      context,
                      title: l.authSignOut,
                      message: l.authSignOutConfirm,
                    );
                    if (!confirmed) return;
                    await ref.read(authRepositoryProvider).signOut();
                  },
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AtherCard(
          padding: AppSpacing.cardPaddingLarge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // The About card is where the app names itself, so it is where
              // the mark belongs. Glyph on the card's white -- the plated icon
              // would put a grey square inside a white card.
              Row(
                children: <Widget>[
                  const AtherGlyph(size: 26),
                  const SizedBox(width: AppSpacing.sm),
                  Text(l.settingsAbout, style: AppTypography.cardTitle),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${l.appName} — ${l.appTagline}',
                style: context.text.secondary.copyWith(height: 1.6),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l.homeworkNote, style: context.text.micro),
            ],
          ),
        ),
      ],
    );
  }
}

/// The cloud backup card.
///
/// Deliberately quiet. Sync is not a feature a student should have to think
/// about -- the card exists so they know it is happening and can force it, not
/// so they have to manage it. There is no toggle: a backup the student can
/// switch off is a backup they will find missing on the day their phone dies.
class _BackupCard extends ConsumerWidget {
  const _BackupCard();

  /// Turns a failure into a sentence, here rather than in the data layer --
  /// which has no localisation, which is why [BackupFailure] is an enum.
  String _failureLabel(L l, BackupFailure failure) => switch (failure) {
    BackupFailure.offline => l.backupErrorOffline,
    BackupFailure.permissionDenied => l.backupErrorPermission,
    BackupFailure.tooLarge => l.backupErrorTooLarge,
    BackupFailure.unreadable => l.backupErrorUnreadable,
    BackupFailure.notSignedIn || BackupFailure.unknown =>
      l.backupErrorUnknown,
  };

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final messenger = Overlay.of(context, rootOverlay: true);
    final direction = Directionality.of(context);

    final confirmed = await confirmDestructive(
      context,
      title: l.backupRestore,
      message: l.backupRestoreConfirm,
    );
    if (!confirmed) return;

    try {
      final backup = await ref.read(backupRepositoryProvider).download();
      if (backup == null) {
        showAtherToastOn(messenger, direction, l.backupRestoreEmpty);
        return;
      }
      await ref.read(backupSyncProvider.notifier).restore(backup);
      showAtherToastOn(messenger, direction, l.backupRestoreDone);
    } on BackupException catch (e) {
      showAtherToastOn(messenger, direction, _failureLabel(l, e.failure));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final sync = ref.watch(backupSyncProvider);
    final cloud = ref.watch(backupMetadataProvider).value;

    // Precedence: a live failure outranks a timestamp, because "saved 3 days
    // ago" beside a silent failure reads as everything being fine.
    final String status;
    final Color statusColor;
    if (sync.status == SyncStatus.saving) {
      status = l.backupSaving;
      statusColor = context.colors.textSecondary;
    } else if (sync.failure != null) {
      status = _failureLabel(l, sync.failure!);
      // Offline is not an error -- it is the normal state of an offline-first
      // app, and colouring it red would teach students to ignore red.
      statusColor = sync.failure == BackupFailure.offline
          ? context.colors.textSecondary
          : context.colors.wrong;
    } else {
      final at = sync.lastSavedAt ?? cloud?.updatedAt;
      status = at == null ? l.backupNever : l.backupSavedAt(dateLabel(at));
      statusColor = context.colors.textSecondary;
    }

    return AtherCard(
      padding: AppSpacing.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l.backupTitle, style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            l.backupBody,
            style: AppTypography.style(
              size: 13,
              weight: AppTypography.medium,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            status,
            style: AppTypography.style(
              size: 13,
              weight: AppTypography.semiBold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: l.backupSaveNow,
            tone: PrimaryButtonTone.secondary,
            onTap: () => ref.read(backupSyncProvider.notifier).flush(),
          ),
          // Only offered once something is actually up there. A restore button
          // that can only say "nothing to restore" is a button that teaches the
          // student the feature does not work.
          if (cloud != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: l.backupRestore,
              tone: PrimaryButtonTone.wrong,
              onTap: () => _restore(context, ref),
            ),
          ],
        ],
      ),
    );
  }
}
