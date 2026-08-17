import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/formatting.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_card.dart';
import '../../core/widgets/ather_scaffold.dart';
import '../../core/widgets/ather_toast.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/settings_list.dart';
import '../../domain/repositories/backup_repository.dart';
import '../common/prompts.dart';
import '../providers/backup_providers.dart';

/// The cloud backup, on a screen of its own.
///
/// It used to be a card on the Settings page carrying a heading, a sentence of
/// explanation, a status line and two full-width buttons — one of them a large
/// red slab. That is four levels of detail on a page whose other entries are
/// one line each, and the red slab in the middle of a settings list was the
/// loudest thing on the screen for an action almost nobody takes.
///
/// What a student checks at a glance — when it last saved — stays on the row
/// in Settings. Everything else is here, where there is room for it.
///
/// Deliberately still has **no on/off switch**. A backup a student can turn off
/// is a backup they will find missing on the day their phone dies.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
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

    return AtherScreen(
      header: AtherHeader(title: l.backupTitle, onBack: () => context.pop()),
      children: <Widget>[
        AtherCard(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
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
            ],
          ),
        ),
        // Only offered once something is actually up there. A restore button
        // that can only say "nothing to restore" is a button that teaches the
        // student the feature does not work.
        if (cloud != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xxl),
          SettingsGroup(
            children: <Widget>[
              SettingsRow(
                label: l.backupRestore,
                destructive: true,
                trailing: SettingsRowTrailing.none,
                busy: _restoring,
                onTap: _restore,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
