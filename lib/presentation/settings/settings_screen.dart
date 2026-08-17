import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/formatting.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_icons.dart';
import '../../core/widgets/ather_scaffold.dart';
import '../../core/widgets/ather_sheet.dart';
import '../../core/widgets/ather_toast.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/settings_list.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../app/router.dart';
import '../common/prompts.dart';
import '../common/write_guard.dart';
import '../providers/app_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/backup_providers.dart';
import '../providers/notification_providers.dart';
import '../providers/task_providers.dart';

/// Grouped rows, in the shape every app a student already uses has settled on.
///
/// It was nine free-standing cards in a column — two segmented controls, two
/// switch rows, a card with two full-width buttons inside it, a link row, an
/// about block, and a bare red slab under a heading reading "منطقة الخطر".
/// Nothing grouped and no two entries were the same height, so the page read
/// as a pile of unrelated things rather than a list of settings.
///
/// Three rules hold it together now:
///
/// * **A row is one line.** Anything with more to say gets a screen of its own
///   (the backup, the about page) or a sheet ([_pickOne]). The row shows the
///   current answer, which is more useful at a glance than a control showing
///   all three options at once.
/// * **No filled buttons in the list.** They were the loudest thing on the
///   page, and two of them were large and red for actions almost nobody takes.
///   Destructive now means a red *label*, in the last block.
/// * **The destructive block is last, and it is not announced.** "منطقة الخطر"
///   as a heading is a developer's framing; the position past every setting and
///   the red are what protect a student, along with the confirmation dialogs,
///   which are unchanged.
///
/// Subject management lives here now, one row into the preferences group. There
/// is still no "mark as reviewed" hiding in an advanced section — the only way
/// to reset a review clock is to sit an exam.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Must match `version:` in pubspec.yaml. Checked by
  /// `tool/check_invariants.sh`, which looks for it on this class — which is
  /// why it stays declared here even though the About screen is what displays
  /// it now.
  static const String appVersion = '1.6.0+11';

  /// The order the three theme options appear in, and the only place that
  /// order is written down.
  static const List<ThemeMode> _themeModes = <ThemeMode>[
    ThemeMode.light,
    ThemeMode.dark,
    ThemeMode.system,
  ];

  static String _themeLabel(L l, ThemeMode mode) => switch (mode) {
    ThemeMode.light => l.settingsThemeLight,
    ThemeMode.dark => l.settingsThemeDark,
    ThemeMode.system => l.settingsThemeSystem,
  };

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

    final sync = ref.watch(backupSyncProvider);
    final cloud = ref.watch(backupMetadataProvider).value;
    final lastSaved = sync.lastSavedAt ?? cloud?.updatedAt;

    return AtherScreen(
      header: AtherHeader(title: l.settingsTitle, onBack: () => context.pop()),
      children: <Widget>[
        if (account != null) ...<Widget>[
          _AccountHeader(account: account),
          const SizedBox(height: AppSpacing.xxl),
          SettingsGroup(
            title: l.authAccount,
            children: <Widget>[
              SettingsRow(
                label: l.backupTitle,
                // The one part of the backup a student checks in passing. The
                // rest of it is a tap away.
                value: lastSaved == null ? l.backupNever : dateLabel(lastSaved),
                onTap: () => context.push(Routes.backup),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
        SettingsGroup(
          title: l.settingsPreferences,
          children: <Widget>[
            SettingsRow(
              label: l.subjectsTitle,
              value: l.subjectCountLabel(
                ref.watch(snapshotValueProvider).activeSubjects.length,
              ),
              onTap: () => context.push(Routes.subjects),
            ),
            SettingsRow(
              label: l.settingsLanguage,
              value: locale.languageCode == 'en'
                  ? l.settingsLanguageEnglish
                  : l.settingsLanguageArabic,
              onTap: () => _pickLanguage(context, ref, locale),
            ),
            SettingsRow(
              label: l.settingsTheme,
              value: _themeLabel(l, themeMode),
              onTap: () => _pickTheme(context, ref, themeMode),
            ),
            const _NotificationsRow(),
            if (biometricsAvailable)
              SettingsRow.toggle(
                label: l.lockSetting,
                toggle: lockEnabled,
                onToggle: (value) =>
                    ref.read(appLockEnabledProvider.notifier).set(value),
              ),
          ],
        ),
        const _NotificationsWarning(),
        const SizedBox(height: AppSpacing.xxl),
        SettingsGroup(
          title: l.settingsAbout,
          children: <Widget>[
            // The policy, one tap away from every other setting. Google Play
            // expects to find it; a student expecting honesty finds it too.
            SettingsRow(
              label: l.settingsPrivacy,
              onTap: () => context.push(Routes.privacy),
            ),
            SettingsRow(
              label: l.settingsAbout,
              onTap: () => context.push(Routes.about),
            ),
          ],
        ),
        // Past every setting, where a deliberate scroll is the difference
        // between "I want this" and "I was looking for notifications".
        if (account != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xxxl),
          const _AccountActions(),
        ],
        const SizedBox(height: AppSpacing.xxl),
        SettingsFootnote(l.settingsVersionFormat(appVersion)),
      ],
    );
  }

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    Locale current,
  ) async {
    final l = L.of(context);
    final picked = await _pickOne<String>(
      context,
      title: l.settingsLanguage,
      options: <(String, String)>[
        ('ar', l.settingsLanguageArabic),
        ('en', l.settingsLanguageEnglish),
      ],
      selected: current.languageCode == 'en' ? 'en' : 'ar',
    );
    if (picked == null) return;
    await ref.read(localeProvider.notifier).set(Locale(picked));
  }

  Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) async {
    final l = L.of(context);
    final picked = await _pickOne<ThemeMode>(
      context,
      title: l.settingsTheme,
      options: <(ThemeMode, String)>[
        for (final mode in _themeModes) (mode, _themeLabel(l, mode)),
      ],
      selected: current,
    );
    if (picked == null) return;
    await ref.read(themeModeProvider.notifier).set(picked);
  }
}

/// The app's one "pick one of these" modal.
///
/// A sheet rather than a screen: choosing a language is a question with a short
/// answer, and a whole page for two rows is a page a student has to leave. Rows
/// rather than a segmented control, because the row in Settings is already
/// showing the answer — this only has to offer the alternatives, and here there
/// is room to spell them out.
Future<T?> _pickOne<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  required T selected,
}) {
  return showAtherSheet<T>(
    context: context,
    builder: (sheetContext) => AtherSheetBody(
      title: title,
      child: SettingsGroup(
        children: <Widget>[
          for (final (value, label) in options)
            SettingsRow(
              label: label,
              value: value == selected ? '✓' : null,
              trailing: SettingsRowTrailing.none,
              onTap: () => Navigator.of(sheetContext).pop(value),
            ),
        ],
      ),
    ),
  );
}

/// Who is signed in, at the top of the page, and the way into the profile.
///
/// The name is the heading once there is one; until then the email is, because
/// a block about the person looking at it must never be blank. Both lines are
/// shown when both exist — the name is what a student recognises, the email is
/// what identifies the account, and on this screen they want the second as
/// often as the first.
class _AccountHeader extends ConsumerWidget {
  const _AccountHeader({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final name = ref.watch(profileNameProvider);
    final email = account.email;
    final source = name.isNotEmpty ? name : email;
    final initial = source.isEmpty ? '؟' : source.substring(0, 1).toUpperCase();

    return Pressable(
      onTap: () => context.push(Routes.profile),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: AppTypography.rowNumber.copyWith(color: colors.accent),
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  source,
                  style: AppTypography.cardLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (name.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    email,
                    style: context.text.sublabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          AtherIcon(
            AtherGlyph.chevron,
            size: 18,
            color: colors.textTertiary,
          ),
        ],
      ),
    );
  }
}

/// The review-reminder switch. Flipping it on is the clearest possible moment
/// to ask for the OS permission: the student has just said, in words, that they
/// want reminders. Nothing used to ask at all, which is why no reminder had
/// ever been scheduled.
class _NotificationsRow extends ConsumerWidget {
  const _NotificationsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);

    return SettingsRow.toggle(
      label: l.settingsNotifications,
      toggle: ref.watch(notificationsEnabledProvider),
      onToggle: (value) => _set(ref, value),
    );
  }

  Future<void> _set(WidgetRef ref, bool value) async {
    await ref.read(notificationsEnabledProvider.notifier).set(value);
    if (!value) return;

    // Android only ever prompts once per install; after a refusal this returns
    // false without showing anything, which is precisely when the warning below
    // has to appear instead.
    try {
      await ref.read(notificationServiceProvider).requestPermission();
    } catch (_) {
      // A platform that cannot be asked is a platform that answers "no".
    }
    ref.invalidate(osNotificationsAllowedProvider);
  }
}

/// The one line that tells the truth when the switch and the operating system
/// disagree. It sits under the group rather than inside it because a row is one
/// line by construction, and this is the exception that proves why: it is not a
/// setting, it is a report about one.
class _NotificationsWarning extends ConsumerWidget {
  const _NotificationsWarning();

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
    if (!blocked) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: ErrorBanner(height: 1.5, message: l.settingsNotificationsBlocked),
    );
  }
}

/// The two ways out of an account, in the block that closes the page.
///
/// Signing out is not destructive — the copy in its own dialog has always said
/// the data survives — so it is a plain row. Deleting the account is, so it is
/// red. Neither is a filled slab any more.
///
/// The deletion order is deliberate and unchanged: confirm in words what
/// disappears, flush anything that has not reached the cloud yet (deleting the
/// cloud copy first would orphan the flush), wipe the device, delete the cloud
/// mirror, and only then delete the account itself. An account deleted before
/// its data leaves a student whose cloud copy outlives their ability to ever
/// reach it again.
class _AccountActions extends ConsumerStatefulWidget {
  const _AccountActions();

  @override
  ConsumerState<_AccountActions> createState() => _AccountActionsState();
}

class _AccountActionsState extends ConsumerState<_AccountActions> {
  bool _deleting = false;
  bool _signingOut = false;
  String? _reauthPassword;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return SettingsGroup(
      children: <Widget>[
        SettingsRow(
          label: l.authSignOut,
          trailing: SettingsRowTrailing.none,
          busy: _signingOut,
          onTap: _signOut,
        ),
        SettingsRow(
          label: l.authDeleteAccount,
          destructive: true,
          trailing: SettingsRowTrailing.none,
          busy: _deleting,
          onTap: _confirmDelete,
        ),
      ],
    );
  }

  Future<void> _signOut() async {
    final l = L.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l.authSignOut,
      message: l.authSignOutConfirm,
      // Without this the red button reads "حذف". Signing out deletes nothing
      // -- the sentence directly above it says so -- and a button that
      // contradicts its own dialog teaches a student that Ather's warnings
      // cannot be read literally.
      confirmLabel: l.authSignOut,
    );
    if (!confirmed || !mounted) return;

    setState(() => _signingOut = true);
    try {
      // Push whatever has not been mirrored yet *before* the session goes:
      // after sign-out there is no uid to upload under, and the debounce may
      // still be holding the last twenty seconds of work.
      await ref.read(backupSyncProvider.notifier).flush();
      if (!mounted) return;
      await runWrite(context, () => ref.read(authRepositoryProvider).signOut());
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
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
      // Stop the ring before anything else: a ring left running under the
      // re-auth sheet both freezes tests and reads as an action still in
      // flight while the student is being asked to type a password.
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
