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
import '../../core/widgets/error_banner.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/backup_repository.dart';
import '../common/prompts.dart';
import '../common/write_guard.dart';
import '../providers/app_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/backup_providers.dart';
import '../providers/notification_providers.dart';
import '../providers/task_providers.dart';

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
        const _NotificationsCard(),
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
                  semanticLabel: l.lockSetting,
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
                    if (!confirmed || !context.mounted) return;
                    // Push whatever has not been mirrored yet *before* the
                    // session goes: after sign-out there is no uid to upload
                    // under, and the debounce may still be holding the last
                    // twenty seconds of work.
                    await ref.read(backupSyncProvider.notifier).flush();
                    if (!context.mounted) return;
                    await runWrite(
                      context,
                      () => ref.read(authRepositoryProvider).signOut(),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _DeleteAccountCard(),
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

/// Deleting the account, and the order that keeps it from being a lie.
///
/// **Play requires this**, for any app a student can create an account in. But
/// the requirement is not "call `user.delete()`" — it is that the student's data
/// actually goes, and the obvious implementation fails that in a way nobody sees:
/// Firebase deletes the Auth user and leaves `users/{uid}/backup/snapshot`
/// exactly where it was. The security rules key that document on
/// `request.auth.uid == uid`, so once the account is gone **no caller can ever
/// satisfy them again**. The record becomes unreachable and permanent, and the
/// app has just told the student it deleted everything.
///
/// Measured, not assumed: on 2026-08-15 a live account was deleted and its
/// document was still there afterwards, and needed a separate explicit delete.
///
/// So the order is **cloud, then account, then device**, and the first failure
/// stops the sequence:
///
/// 1. **Cloud copy.** If this fails, nothing else runs. The student keeps their
///    account and their data, and is told to try again with a connection —
///    which is recoverable. Deleting the account first would not be.
/// 2. **The account.** If this fails, the cloud copy is already gone, but that
///    is the harmless half: the backup is a mirror, not a source of truth
///    (PROJECT.md §3.26), the local database is untouched, and the next
///    successful backup rebuilds it.
/// 3. **The device.** Last, because it is the copy the student is holding, and
///    the only step that cannot be undone by a retry.
class _DeleteAccountCard extends ConsumerStatefulWidget {
  const _DeleteAccountCard();

  @override
  ConsumerState<_DeleteAccountCard> createState() => _DeleteAccountCardState();
}

class _DeleteAccountCardState extends ConsumerState<_DeleteAccountCard> {
  bool _busy = false;

  Future<void> _delete() async {
    if (_busy) return;

    final l = L.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l.authDeleteConfirmTitle,
      message: l.authDeleteConfirmMessage,
      confirmLabel: l.authDeleteConfirmButton,
    );
    if (!confirmed || !mounted) return;

    // Everything the messages need is resolved *before* the first await. The
    // account going away pops this screen out from under us, so by the time the
    // last toast is shown there may be no element left to read `L` from.
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final direction = Directionality.of(context);
    final needsConnection = l.authDeleteNeedsConnection;
    final recentLogin = l.authErrorRecentLogin;
    final generic = l.commonSomethingWentWrong;
    final done = l.authDeleteDone;

    void say(String message, {bool failed = true}) {
      if (overlay == null) return;
      showAtherToastOn(
        overlay,
        direction,
        message,
        tone: failed ? ToastTone.failed : ToastTone.done,
      );
    }

    setState(() => _busy = true);

    // 1. The cloud copy, first and blocking.
    try {
      await ref.read(backupRepositoryProvider).delete();
    } on BackupException catch (error) {
      if (mounted) setState(() => _busy = false);
      // Offline is the likely one and it has its own copy, because "something
      // went wrong" would send the student back to a button that will keep
      // failing for a reason they could have fixed.
      say(
        error.failure == BackupFailure.offline ||
                error.failure == BackupFailure.notSignedIn
            ? needsConnection
            : generic,
      );
      return;
    }

    // 2. The account.
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
    } on AuthException catch (error) {
      if (mounted) setState(() => _busy = false);
      say(
        error.failure == AuthFailure.requiresRecentLogin
            ? recentLogin
            : generic,
      );
      return;
    }

    // 3. The device. Not guarded by `mounted`: the auth stream has already
    // emitted null and the router is tearing this screen down, but the wipe
    // must finish regardless -- a student whose account is gone while their
    // exam history sits on the phone is the failure this whole card exists to
    // prevent.
    await ref.read(studyRepositoryProvider).clear();
    await ref.read(taskRepositoryProvider).clearTasks();
    // Cleared so the next student to sign in on this phone is not measured
    // against a uid that no longer exists.
    await ref.read(sharedPreferencesProvider).remove(kLastAccountUidKey);

    say(done, failed: false);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return AtherCard(
      padding: AppSpacing.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l.authDeleteAccount, style: AppTypography.cardTitle),
          const SizedBox(height: 6),
          // Names the three things that go. A bare "delete account" reads as
          // though it removes a login, and the student would not learn what it
          // costs until it had already happened.
          Text(
            l.authDeleteAccountBody,
            style: context.text.secondary.copyWith(height: 1.6),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: l.authDeleteAccount,
            tone: PrimaryButtonTone.wrong,
            onTap: _busy ? null : _delete,
          ),
        ],
      ),
    );
  }
}

/// The review-reminder switch, and the one line that tells the truth when the
/// switch and the operating system disagree.
///
/// Flipping it on is the clearest possible moment to ask for the OS permission:
/// the student has just said, in words, that they want reminders. Nothing used
/// to ask at all, which is why no reminder had ever been scheduled.
class _NotificationsCard extends ConsumerWidget {
  const _NotificationsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final enabled = ref.watch(notificationsEnabledProvider);
    final allowed = ref.watch(osNotificationsAllowedProvider).value ?? true;

    // Only warn when a reminder is genuinely owed. On a fresh install nothing
    // has a review clock yet, so "notifications are blocked" would be a warning
    // about a problem the student does not have.
    final blocked =
        enabled && !allowed && ref.watch(hasScheduledReviewsProvider);

    return AtherCard(
      padding: AppSpacing.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
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
                value: enabled,
                semanticLabel: l.settingsNotifications,
                onChanged: (value) => _set(ref, value),
              ),
            ],
          ),
          if (blocked) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            ErrorBanner(height: 1.5, message: l.settingsNotificationsBlocked),
          ],
        ],
      ),
    );
  }

  Future<void> _set(WidgetRef ref, bool value) async {
    await ref.read(notificationsEnabledProvider.notifier).set(value);
    if (!value) return;

    // Android only ever prompts once per install; after a refusal this returns
    // false without showing anything, which is precisely when the line above
    // has to appear instead.
    try {
      await ref.read(notificationServiceProvider).requestPermission();
    } catch (_) {
      // A platform that cannot be asked is a platform that answers "no".
    }
    ref.invalidate(osNotificationsAllowedProvider);
  }
}

/// The cloud backup card.
///
/// Deliberately quiet. Sync is not a feature a student should have to think
/// about -- the card exists so they know it is happening and can force it, not
/// so they have to manage it. There is no toggle: a backup the student can
/// switch off is a backup they will find missing on the day their phone dies.
class _BackupCard extends ConsumerStatefulWidget {
  const _BackupCard();

  @override
  ConsumerState<_BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends ConsumerState<_BackupCard> {
  /// A restore is a download plus a full database replacement, and it is the
  /// most destructive thing in the app. It used to run with no feedback at all:
  /// the button stayed live, took further taps, and the student had no way to
  /// tell a slow network from a dead control.
  bool _restoring = false;

  /// Turns a failure into a sentence, here rather than in the data layer --
  /// which has no localisation, which is why [BackupFailure] is an enum.
  String _failureLabel(L l, BackupFailure failure) => switch (failure) {
    BackupFailure.offline => l.backupErrorOffline,
    BackupFailure.permissionDenied => l.backupErrorPermission,
    BackupFailure.tooLarge => l.backupErrorTooLarge,
    BackupFailure.unreadable => l.backupErrorUnreadable,
    BackupFailure.notSignedIn || BackupFailure.unknown => l.backupErrorUnknown,
  };

  Future<void> _restore() async {
    if (_restoring) return;

    final l = L.of(context);
    final messenger = Overlay.of(context, rootOverlay: true);
    final direction = Directionality.of(context);

    final confirmed = await confirmDestructive(
      context,
      title: l.backupRestore,
      message: l.backupRestoreConfirm,
    );
    if (!confirmed || !mounted) return;

    setState(() => _restoring = true);
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
    } on Object catch (error, stack) {
      // Only BackupException was caught before, so a failure from the *local*
      // write half -- the drift transaction that replaces the database -- went
      // unhandled and told the student nothing. The transaction rolls back, so
      // their data is intact; they just have to be told it did not happen.
      debugPrint('Ather: restore failed -- $error\n$stack');
      showAtherToastOn(
        messenger,
        direction,
        l.commonSomethingWentWrong,
        tone: ToastTone.failed,
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            busy: sync.status == SyncStatus.saving,
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
              busy: _restoring,
              onTap: _restore,
            ),
          ],
        ],
      ),
    );
  }
}
