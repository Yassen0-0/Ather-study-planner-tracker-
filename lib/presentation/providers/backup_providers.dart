import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup/firestore_backup_repository.dart';
import '../../domain/entities/study_backup.dart';
import '../../domain/repositories/backup_repository.dart';
import 'app_providers.dart';
import 'auth_providers.dart';
import 'task_providers.dart';

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => FirestoreBackupRepository(),
);

/// What the Settings card shows. Never blocks anything.
enum SyncStatus {
  /// Nothing has been sent yet this session, and nothing is known to be wrong.
  idle,

  saving,

  saved,

  /// The last attempt failed. Carried with a [BackupFailure] so the card can say
  /// *why* -- "offline" and "the rules were never published" are very different
  /// news, and the second one is invisible otherwise.
  failed,
}

final class SyncState {
  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSavedAt,
    this.failure,
  });

  final SyncStatus status;
  final DateTime? lastSavedAt;
  final BackupFailure? failure;

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSavedAt,
    BackupFailure? failure,
    bool clearFailure = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// Pushes the local database to the cloud, debounced.
///
/// **Nothing here is on any read path.** Every screen reads local SQLite; this
/// watches for changes and mirrors them afterwards. A student in airplane mode
/// records an exam, sees their mastery move, and this quietly fails -- which is
/// a state, not an error (PROJECT.md §3.17).
class BackupSyncNotifier extends Notifier<SyncState> {
  Timer? _debounce;

  /// Long enough that a burst of edits -- adding four lessons in a row -- is one
  /// upload rather than four, short enough that closing the app right after
  /// recording an exam still saves it. The lifecycle flush covers the rest.
  static const Duration _debounceDelay = Duration(seconds: 20);

  @override
  SyncState build() {
    ref.onDispose(() => _debounce?.cancel());

    // Any write anywhere re-emits these, which is exactly the trigger we want:
    // the sync follows the data rather than being called from each screen.
    ref.listen(snapshotProvider, (_, _) => _schedule());
    ref.listen(tasksProvider, (_, _) => _schedule());

    return const SyncState();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => unawaited(flush()));
  }

  /// Uploads now. Called by the debounce, by the app going to the background,
  /// and by the manual button in Settings.
  Future<void> flush() async {
    _debounce?.cancel();
    if (ref.read(accountProvider).value == null) return;

    final snapshot = ref.read(snapshotValueProvider);
    final tasks = ref.read(tasksValueProvider);
    if (snapshot.isEmpty && tasks.isEmpty) return;

    state = state.copyWith(status: SyncStatus.saving, clearFailure: true);
    try {
      await ref
          .read(backupRepositoryProvider)
          .upload(StudyBackup.fromSnapshot(snapshot, tasks));
      state = state.copyWith(
        status: SyncStatus.saved,
        lastSavedAt: ref.read(clockProvider).now(),
        clearFailure: true,
      );
    } on BackupException catch (e) {
      state = state.copyWith(status: SyncStatus.failed, failure: e.failure);
    } on Object {
      state = state.copyWith(
        status: SyncStatus.failed,
        failure: BackupFailure.unknown,
      );
    }
  }

  /// Pulls the cloud copy over the local database. Destructive by definition, so
  /// every caller confirms first -- except the empty-database case, where there
  /// is nothing to lose.
  Future<void> restore(StudyBackup backup) async {
    await ref.read(studyRepositoryProvider).restore(backup);
    await ref.read(taskRepositoryProvider).restoreTasks(backup.tasks);
  }
}

final backupSyncProvider = NotifierProvider<BackupSyncNotifier, SyncState>(
  BackupSyncNotifier.new,
);

/// The cloud copy's metadata, if any. Metadata only -- no payload, no
/// decompression, so this is cheap enough to read when Settings opens.
final backupMetadataProvider = FutureProvider<BackupMetadata?>((ref) async {
  if (ref.watch(accountProvider).value == null) return null;
  try {
    return await ref.watch(backupRepositoryProvider).readMetadata();
  } on BackupException {
    // The card falls back to "unknown" rather than the screen failing to build.
    return null;
  }
});
