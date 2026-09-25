import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/app_passcode.dart';
import '../../core/l10n/formatting.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_controls.dart';
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
  static const String appVersion = '1.10.0+18';

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
    final lockMethod = ref.watch(lockMethodProvider);
    final hasPasscode = ref.watch(appPasscodeProvider) != null;
    // Which fingerprint options exist on this device. The lock itself is
    // offered everywhere now (T4): a password needs no sensor, so the master
    // switch no longer disappears on phones without one. Kept watched here
    // rather than read cold in the handlers: a FutureProvider answers its
    // first `.value` only once something has started it.
    ref.watch(biometricsAvailableProvider);

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
            // Directly under Subjects, so the bin sits beside the thing that
            // fills it. Shown only when there is something in it: a row
            // reading "0" is a row that teaches the student to ignore it.
            if (ref.watch(snapshotValueProvider).deletedSubjects.isNotEmpty)
              SettingsRow(
                label: l.binTitle,
                value: l.subjectCountLabel(
                  ref.watch(snapshotValueProvider).deletedSubjects.length,
                ),
                onTap: () => context.push(Routes.recycleBin),
              ),
            SettingsRow(
              label: l.exportTitle,
              onTap: () => context.push(Routes.export),
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
            // Vibration stays available under reduce-motion on purpose: it is
            // not visual motion. Documented in the motion spec, ملحق PH-04.
            SettingsRow.toggle(
              label: l.hapticsSetting,
              toggle: ref.watch(hapticsEnabledProvider),
              onToggle: (value) =>
                  ref.read(hapticsEnabledProvider.notifier).set(value),
            ),
            // Master switch. Enabling on a phone with no sensor walks the
            // student through choosing a password first -- see [_toggleLock];
            // a lock nothing can open is never promised.
            SettingsRow.toggle(
              label: l.lockSetting,
              toggle: lockEnabled,
              onToggle: (value) => _toggleLock(context, ref, value),
            ),
            if (lockEnabled)
              SettingsRow(
                label: l.lockMethodsTitle,
                value: _lockMethodLabel(l, lockMethod),
                onTap: () => _pickLockMethod(context, ref),
              ),
            // Present only while the password is one of the ways in: a row
            // about a password the method never asks for is noise.
            if (lockEnabled && lockMethod.usesPassword)
              SettingsRow(
                label: l.setPasswordTitle,
                value: hasPasscode ? '✓' : null,
                onTap: () => _editPasscode(context, ref),
              ),
          ],
        ),
        const _NotificationsWarning(),
        const SizedBox(height: AppSpacing.xxl),
        SettingsGroup(
          // Named for the app, not for the row inside it. The heading and the
          // "عن التطبيق" row below it both read `settingsAbout` at first, which
          // is a group announcing one of its own children -- and two widgets
          // carrying identical text on one screen, which is its own bug.
          title: l.settingsAboutSection,
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

  static String _lockMethodLabel(L l, LockMethod method) => switch (method) {
    LockMethod.biometric => l.lockMethodBiometric,
    LockMethod.password => l.lockMethodPassword,
    LockMethod.both => l.lockMethodBoth,
  };

  /// The lock turns on only if something can actually answer it.
  ///
  /// With a sensor present, today's behaviour: on it goes, and the method in
  /// force is whatever the student last chose. Without one, the password has
  /// to carry the lock alone -- so either a password already exists (and a
  /// biometric-only choice is quietly re-pointed at it) or the student is
  /// walked through choosing one first. Cancelling that sheet leaves the
  /// switch off rather than promising a lock nothing can open.
  Future<void> _toggleLock(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final lock = ref.read(appLockEnabledProvider.notifier);
    if (!enable) {
      await lock.set(false);
      // A lock the owner just switched off leaves no guesses to count: a
      // backoff surviving it would greet the next "on" with a refusal the
      // student never earned.
      await ref.read(lockAttemptStoreProvider).reset();
      return;
    }
    final biometrics = ref.read(biometricsAvailableProvider).value ?? false;
    if (biometrics) {
      await lock.set(true);
      return;
    }
    final hasPasscode = ref.read(appPasscodeProvider) != null;
    if (!hasPasscode) {
      final saved = await _editPasscode(context, ref);
      if (!saved) return;
      await ref.read(lockMethodProvider.notifier).set(LockMethod.password);
    } else if (!ref.read(lockMethodProvider).usesPassword) {
      await ref.read(lockMethodProvider.notifier).set(LockMethod.password);
    }
    await lock.set(true);
  }

  /// Offers whichever methods this device could actually satisfy, then makes
  /// sure a password exists before one is promised. Backing out of the
  /// password sheet changes nothing.
  Future<void> _pickLockMethod(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final biometrics = ref.read(biometricsAvailableProvider).value ?? false;
    final picked = await _pickOne<LockMethod>(
      context,
      title: l.lockMethodsTitle,
      options: <(LockMethod, String)>[
        if (biometrics) (LockMethod.biometric, l.lockMethodBiometric),
        (LockMethod.password, l.lockMethodPassword),
        if (biometrics) (LockMethod.both, l.lockMethodBoth),
      ],
      selected: ref.read(lockMethodProvider),
    );
    if (picked == null || picked == ref.read(lockMethodProvider)) return;
    if (!context.mounted) return;
    if (picked.usesPassword && ref.read(appPasscodeProvider) == null) {
      final saved = await _editPasscode(context, ref);
      if (!saved) return;
    }
    await ref.read(lockMethodProvider.notifier).set(picked);
  }

  /// The set/change-password sheet. Answers through the popped value because
  /// the callers above have decisions of their own to gate on it.
  Future<bool> _editPasscode(BuildContext context, WidgetRef ref) async =>
      await showAtherSheet<bool>(
        context: context,
        builder: (_) => const _PasscodeSheet(),
      ) ??
      false;

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

/// Asks for -- and stores only the digest of -- the app password.
///
/// First time through it wants the new word twice; when a password already
/// stands, the current one comes first, so someone handed the phone cannot
/// quietly replace what guards it. Every failure says exactly which rule
/// broke, and nothing about the password itself is written anywhere.
class _PasscodeSheet extends ConsumerStatefulWidget {
  const _PasscodeSheet();

  @override
  ConsumerState<_PasscodeSheet> createState() => _PasscodeSheetState();
}

class _PasscodeSheetState extends ConsumerState<_PasscodeSheet> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _new = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  /// True when a password already exists and this pass changes it.
  late final bool _changing;

  String? Function(L)? _message;

  @override
  void initState() {
    super.initState();
    _changing = ref.read(appPasscodeProvider) != null;
  }

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final stored = ref.read(appPasscodeProvider);
    // The standing password is checked before the new one is even read
    // closely: a wrong current answer ends it here.
    if (_changing &&
        (stored == null || !AppPasscode.verify(_current.text, stored.hash))) {
      setState(() => _message = (l) => l.wrongPassword);
      return;
    }
    if (_new.text.length < AppPasscode.minLength) {
      setState(() => _message = (l) => l.passwordTooShort);
      return;
    }
    if (_new.text != _confirm.text) {
      setState(() => _message = (l) => l.passwordMismatch);
      return;
    }
    ref
        .read(appPasscodeProvider.notifier)
        .set(
          StoredAppPasscode(
            hash: AppPasscode.hash(_new.text),
            digitsOnly: AppPasscode.looksNumeric(_new.text),
          ),
        );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return AtherSheetBody(
      title: l.setPasswordTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_changing)
            AtherTextField(
              controller: _current,
              label: l.currentPasswordLabel,
              obscure: true,
            ),
          AtherTextField(
            controller: _new,
            label: l.newPasswordLabel,
            obscure: true,
            autofocus: !_changing,
            textInputAction: TextInputAction.next,
          ),
          AtherTextField(
            controller: _confirm,
            label: l.confirmNewPasswordLabel,
            obscure: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          if (_message != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            ErrorBanner(message: _message!(l)!),
          ],
          const SizedBox(height: AppSpacing.xxl),
          PrimaryButton(label: l.commonSave, onTap: _submit),
        ],
      ),
    );
  }
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
          AtherIcon(AtherGlyph.chevron, size: 18, color: colors.textTertiary),
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
/// The deletion order is deliberate: confirm in words what disappears, prove
/// ownership again if the sign-in is stale (before anything is erased, D4),
/// flush anything that has not reached the cloud yet (deleting the cloud copy
/// first would orphan the flush), wipe the device, delete the cloud mirror,
/// and only then delete the account itself. An account deleted before
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
      // Signing out deletes nothing -- the sentence above the button says so
      // -- so it is not a destructive commitment and earns no heavy haptic.
      heavyOnConfirm: false,
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
      // Ownership is proved BEFORE anything is erased. The order used to be
      // wipe first, ask later: a stale sign-in reached `requires-recent-login`
      // only at the account step, by which point the device and the cloud copy
      // were already gone -- and a Google account, asked for a password it
      // never had, could not finish. The student was left with no data and an
      // account that still existed. Backing out here touches nothing.
      if (!await _ensureRecentLogin()) return;
      await _runDeletion(flushFirst: true);
    } on AuthException catch (e) {
      // Stop the ring before anything else: a ring left running under the
      // re-auth sheet both freezes tests and reads as an action still in
      // flight while the student is being asked to type a password.
      if (mounted) setState(() => _deleting = false);
      if (!mounted) return;
      if (e.failure == AuthFailure.requiresRecentLogin) {
        // The backstop: Firebase judged the sign-in stale after all (the
        // check and the delete are minutes apart on a slow flush). Ask again
        // rather than reporting failure: the student asked to delete their
        // account and "try again later" is not an answer to that request.
        await _retryAfterReauth();
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

  /// Makes sure Firebase will accept the deletion, asking the account for
  /// fresh proof in the only form it can give -- the Google sheet for a Google
  /// account, the password sheet otherwise (see [ReauthMethod]).
  ///
  /// Returns false when the student backed out; nothing has been touched and
  /// nothing is reported. A wrong password or no network throws
  /// [AuthException] and is reported by the caller.
  Future<bool> _ensureRecentLogin({bool force = false}) async {
    final auth = ref.read(authRepositoryProvider);
    if (!force && await auth.hasRecentLogin()) return true;

    final method = auth.reauthMethod;
    // Signed out underneath us: deleteAccount treats that as already done.
    if (method == null) return true;

    if (method == ReauthMethod.google) {
      try {
        await auth.reauthenticateWithGoogle();
        return true;
      } on AuthException catch (e) {
        if (e.failure == AuthFailure.cancelled) return false;
        rethrow;
      }
    }

    // The sheet goes up with the ring stopped (see _confirmDelete) and the
    // ring comes back while the password is checked.
    if (!mounted) return false;
    setState(() => _deleting = false);
    final password = await _askPassword();
    if (password == null || !mounted) return false;
    setState(() => _deleting = true);
    await auth.reauthenticateWithPassword(password);
    return true;
  }

  /// Flush → wipe device → delete cloud mirror → delete account → clear
  /// preferences. Each step only runs if the one before it succeeded, so a
  /// failure anywhere leaves a state that can be retried rather than
  /// half-deleted. The cloud copy goes while the session is still alive,
  /// because the Firestore rules only let its owner delete it.
  ///
  /// One sequence for both entries into deletion -- the plain delete and the
  /// re-auth retry differ only in whether there is anything left to flush
  /// (arch F-02). Preferences are wiped strictly **after** the account
  /// deletion succeeded (SEC-04): a failed attempt must not have taken the
  /// student's name and lock with it.
  Future<void> _runDeletion({required bool flushFirst}) async {
    if (flushFirst) await ref.read(backupSyncProvider.notifier).flush();
    await ref.read(studyRepositoryProvider).clear();
    await ref.read(taskRepositoryProvider).clearTasks();
    await ref.read(backupRepositoryProvider).deleteCloudData();
    await ref.read(authRepositoryProvider).deleteAccount();
    await wipeAccountPreferences(ref.read(sharedPreferencesProvider));
  }

  /// The retry after `requires-recent-login` reached the account step. No
  /// flush: the first attempt already pushed what it could.
  Future<void> _retryAfterReauth() async {
    final l = L.of(context);
    setState(() => _deleting = true);
    try {
      if (!await _ensureRecentLogin(force: true)) return;
      await _runDeletion(flushFirst: false);
    } on Object {
      if (mounted) _reportFailure(l);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  /// The password sheet. Returns the typed password, or null when the student
  /// closed the sheet instead.
  Future<String?> _askPassword() {
    return showAtherSheet<String>(
      context: context,
      builder: (sheetContext) => _ReauthSheet(
        onSubmit: (password) => Navigator.of(sheetContext).pop(password),
      ),
    );
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
