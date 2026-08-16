import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/branding/ather_logo.dart' as brand;
import '../../core/l10n/formatting.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_card.dart';
import '../../core/widgets/ather_controls.dart';
import '../../core/widgets/ather_icons.dart';
import '../../core/widgets/ather_scaffold.dart';
import '../../core/widgets/ather_sheet.dart';
import '../../core/widgets/ather_toast.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_banner.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/backup_repository.dart';
import '../../app/router.dart';
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
///
/// [appVersion] is the one place the version is written by hand; the
/// release-invariants script is the thing that notices when it drifts from
/// pubspec.yaml. (A package_info dependency for one string on one screen
/// would be a dependency bought with nothing.)
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Must match `version:` in pubspec.yaml. Checked by
  /// `tool/check_invariants.sh`.
  static const String appVersion = '1.6.0+11';

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
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l.settingsLanguage, style: AppTypography.cardTitle),
              const SizedBox(height: AppSpacing.xl),
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
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l.settingsTheme, style: AppTypography.cardTitle),
              const SizedBox(height: AppSpacing.xl),
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
            padding: AppSpacing.cardPadding,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l.lockSetting, style: AppTypography.cardTitle),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
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
          _AccountCard(account: account),
        ],
        const SizedBox(height: AppSpacing.md),
        // The policy, one tap away from every other setting. Google Play
        // expects to find it; a student expecting honesty finds it too.
        AtherCard(
          padding: AppSpacing.cardPadding,
          onTap: () => context.push(Routes.privacy),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(l.settingsPrivacy, style: AppTypography.rowTitle),
              ),
              const SizedBox(width: AppSpacing.md),
              const AtherIcon(AtherGlyph.chevron, size: 20),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AtherCard(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // The About card is where the app names itself, so it is where
              // the mark belongs. Glyph on the card's white -- the plated icon
              // would put a grey square inside a white card.
              Row(
                children: <Widget>[
                  const brand.AtherGlyph(size: 26),
                  const SizedBox(width: AppSpacing.md),
                  Text(l.settingsAbout, style: AppTypography.cardTitle),
                ],
              ),
              const SizedBox(height: AppSpacing.textGap),
              Text(
                '${l.appName} — ${l.appTagline}',
                style: context.text.secondary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${l.homeworkNote} · ${l.settingsVersionFormat(appVersion)}',
                style: context.text.micro,
              ),
            ],
          ),
        ),
        // The delete-account control is last on purpose: past every setting,
        // where a deliberate scroll is the difference between "I want this"
        // and "I was looking for notifications". See _DeleteAccountSection.
        if (account != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xxxl),
          const _DeleteAccountSection(),
        ],
      ],
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
      padding: AppSpacing.cardPadding,
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
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
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
      // Red, because it replaces the local record -- but the student is
      // agreeing to a restore, not a delete, and the button says so.
      confirmLabel: l.backupRestore,
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
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l.backupTitle, style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.md),
          Text(
            status,
            style: AppTypography.statusLine.copyWith(color: statusColor),
          ),
          const SizedBox(height: AppSpacing.xl),
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
            const SizedBox(height: AppSpacing.md),
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

/// The account card: who is signed in, and the everyday way out. The
/// destructive way out — deleting the account — is not here; it sits at the
/// very bottom of the Settings page, where a scroll is a second thought and
/// no one erases two years of exams by landing on the wrong button.
class _AccountCard extends ConsumerStatefulWidget {
  const _AccountCard({required this.account});

  final Account account;

  @override
  ConsumerState<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends ConsumerState<_AccountCard> {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final account = widget.account;

    return AtherCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l.authAccount, style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.textGap),
          Text(account.email, style: context.text.secondary),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: l.authSignOut,
            tone: PrimaryButtonTone.secondary,
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final l = L.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l.authSignOut,
      message: l.authSignOutConfirm,
      confirmLabel: l.authSignOut,
    );
    if (!confirmed || !context.mounted) return;

    // Push whatever has not been mirrored yet *before* the session goes:
    // after sign-out there is no uid to upload under, and the debounce may
    // still be holding the last twenty seconds of work.
    await ref.read(backupSyncProvider.notifier).flush();
    if (!context.mounted) return;
    await runWrite(context, () => ref.read(authRepositoryProvider).signOut());
  }
}

/// Account deletion, in its own visible section at the bottom of Settings.
///
/// Google Play requires the delete path to be findable, and a destructive
/// action buried mid-list fails both tests at once: students who need it
/// cannot find it, and students who do not can hit it by accident. The bottom
/// of the page — past every setting, where a deliberate scroll is required —
/// is the honest position for both.
///
/// The deletion order is deliberate: confirm in words what disappears, flush
/// anything that has not reached the cloud yet (deleting the cloud copy first
/// would orphan the flush), wipe the device, delete the cloud mirror, and only
/// then delete the account itself. An account deleted before its data leaves
/// a student whose cloud copy outlives their ability to ever reach it again.
class _DeleteAccountSection extends ConsumerStatefulWidget {
  const _DeleteAccountSection();

  @override
  ConsumerState<_DeleteAccountSection> createState() =>
      _DeleteAccountSectionState();
}

class _DeleteAccountSectionState extends ConsumerState<_DeleteAccountSection> {
  bool _deleting = false;
  String? _reauthPassword;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PrimaryButton(
          label: l.authDeleteAccount,
          tone: PrimaryButtonTone.wrong,
          busy: _deleting,
          onTap: _confirmDelete,
        ),
      ],
    );
  }

  Future<void> _confirmDelete() async {
    final l = L.of(context);

    // The one honest extra line worth adding: if the last cloud sync failed
    // or never happened while there is data on the device, deletion destroys
    // work that exists nowhere else. `flush()` runs first and will retry it,
    // but an offline phone cannot be fixed by a retry.
    final sync = ref.read(backupSyncProvider);
    final unsaved =
        (sync.failure != null || sync.lastSavedAt == null) &&
        // Nothing recorded locally means nothing can be lost.
        !(ref.read(snapshotValueProvider).isEmpty);

    final confirmed = await confirmDestructive(
      context,
      title: l.authDeleteAccount,
      message: unsaved
          ? '${l.authDeleteAccountConfirm}\n\n${l.authDeleteAccountOfflineWarning}'
          : l.authDeleteAccountConfirm,
      confirmLabel: l.authDeleteAccount,
    );
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);
    try {
      await _deleteEverything();
    } on AuthException catch (e) {
      // Stop the ring before anything else: it is the only spinner in the
      // app, and a ring left running under the re-auth sheet both freezes
      // tests and reads as an action still in flight while the student is
      // being asked to type a password.
      if (mounted) setState(() => _deleting = false);
      if (!mounted) return;
      if (e.failure == AuthFailure.requiresRecentLogin) {
        // Firebase wants fresh proof of ownership. Ask for it rather than
        // reporting failure: the student asked to delete their account and
        // "try again later" is not an answer to that request.
        final retry = await _askReauth();
        if (retry && mounted && _reauthPassword != null) {
          await _retryWithPassword();
        }
        return;
      }
      _reportFailure(l);
    } on Object {
      if (!mounted) return;
      _reportFailure(l);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  /// Flush → wipe device → delete cloud mirror → delete account. Each step
  /// only runs if the one before it succeeded, so a failure anywhere leaves
  /// a state that can be retried rather than half-deleted.
  Future<void> _deleteEverything() async {
    final repository = ref.read(authRepositoryProvider);
    await ref.read(backupSyncProvider.notifier).flush();
    await ref.read(studyRepositoryProvider).clear();
    await ref.read(taskRepositoryProvider).clearTasks();
    await ref.read(backupRepositoryProvider).deleteCloudData();
    await repository.deleteAccount();
  }

  /// The password retry after `requires-recent-login`. Same order minus the
  /// flush — the first attempt already pushed what it could.
  Future<void> _retryWithPassword() async {
    final l = L.of(context);
    setState(() => _deleting = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      await ref.read(studyRepositoryProvider).clear();
      await ref.read(taskRepositoryProvider).clearTasks();
      await ref.read(backupRepositoryProvider).deleteCloudData();
      await repository.deleteAccountWithPassword(_reauthPassword!);
    } on Object {
      if (mounted) _reportFailure(l);
    } finally {
      _reauthPassword = null;
      if (mounted) setState(() => _deleting = false);
    }
  }

  /// The sheet Firebase's `requires-recent-login` demands. Returns whether
  /// the student gave a password; [_retryWithPassword] uses it.
  Future<bool> _askReauth() {
    return showAtherSheet<bool>(
      context: context,
      builder: (sheetContext) => _ReauthSheet(
        onSubmit: (password) {
          _reauthPassword = password;
          Navigator.of(sheetContext).pop(true);
        },
      ),
    ).then((value) => value ?? false);
  }

  void _reportFailure(L l) {
    final messenger = Overlay.of(context, rootOverlay: true);
    showAtherToastOn(
      messenger,
      Directionality.of(context),
      l.authDeleteAccountFailed,
      tone: ToastTone.failed,
    );
  }
}

/// A password field in the app's one modal shape, for the one action that
/// must re-prove ownership before it erases everything.
class _ReauthSheet extends StatefulWidget {
  const _ReauthSheet({required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<_ReauthSheet> createState() => _ReauthSheetState();
}

class _ReauthSheetState extends State<_ReauthSheet> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hasText = _controller.text.isNotEmpty;

    return AtherSheetBody(
      title: l.authDeleteAccountReauthTitle,
      body: l.authDeleteAccountReauthBody,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: context.colors.muted,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: 2,
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => setState(() {}),
              style: AppTypography.body,
              cursorColor: context.colors.textPrimary,
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                counterText: '',
                hintText: l.authPassword,
                hintStyle: AppTypography.body.copyWith(
                  color: context.colors.textNoData,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xl,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          PrimaryButton(
            label: l.authDeleteAccountReauthAction,
            tone: hasText
                ? PrimaryButtonTone.wrong
                : PrimaryButtonTone.unearned,
            onTap: _submit,
          ),
        ],
      ),
    );
  }

  void _submit() {
    final value = _controller.text;
    if (value.isEmpty) return;
    widget.onSubmit(value);
  }
}
