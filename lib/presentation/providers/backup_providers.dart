import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup/firestore_backup_repository.dart';
import '../../data/repositories/drift_study_repository.dart';
import '../../domain/entities/daily_task.dart';
import '../../domain/entities/study_backup.dart';
import '../../domain/entities/study_snapshot.dart';
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
    final account = ref.read(accountProvider).value;
    if (account == null) return;

    // The device has to agree that this data belongs to this account before any
    // of it leaves the phone. `BackupSyncGate` writes the uid only *after* it
    // has wiped a previous student's curriculum, so a mismatch here means the
    // wipe has not happened yet -- and uploading in that window is exactly how
    // one student's chapters end up in another student's cloud document.
    final owner = ref
        .read(sharedPreferencesProvider)
        .getString(kLastAccountUidKey);
    if (owner != account.id) return;

    // `.future`, never `snapshotValueProvider` / `tasksValueProvider`. Those two
    // fall back to empty while their stream is still loading -- deliberately, so
    // a transient frame cannot crash a screen -- and reading them here asked
    // "what does this student have?" at the one moment the honest answer is "not
    // known yet".
    //
    // The old guard was `snapshot.isEmpty && tasks.isEmpty`, an `&&`, so it only
    // caught the case where *both* halves were still loading. These are two
    // independent drift streams: when one had emitted and the other had not,
    // this uploaded the half it could see over the half it could not. A student
    // who backgrounded the app in that window had their cloud tasks replaced
    // with an empty list -- and the cloud copy is the only copy that survives a
    // lost phone.
    //
    // This is the same trap, in the same feature, that `BackupSyncGate` already
    // documents at length for the restore direction. Awaiting is free here:
    // nothing renders off this path.
    //
    // Guarded, because since WS6 (c771d13) a failing stream rejects instead of
    // collapsing to empty -- and this whole method runs fire-and-forget (the
    // debounce wraps it in `unawaited`, the lifecycle call awaits nothing), so
    // a rejection here escaped as an unhandled zone error and reached
    // Crashlytics marked fatal for what is a recoverable read hiccup (C6).
    // The catch below only handles cloud failures, so these two local reads
    // are guarded ahead of it. Degradation is hold, not proceed: a read that
    // failed leaves the record unknown, and uploading an unknown record is
    // how one student's data ends up over another's cloud copy -- the same
    // direction the N4 guard below already prefers. Nothing was written by
    // this cycle; the next write re-schedules one.
    final StudySnapshot snapshot;
    final List<DailyTask> tasks;
    try {
      snapshot = await ref.read(snapshotProvider.future);
      tasks = await ref.read(tasksProvider.future);
    } on Object catch (error, stack) {
      debugPrint('Ather: holding upload -- local read failed: $error\n$stack');
      state = state.copyWith(
        status: SyncStatus.failed,
        failure: BackupFailure.unknown,
      );
      return;
    }

    // **There is deliberately no empty-state guard here** -- with one N4
    // exception below.
    //
    // There used to be -- `if (snapshot.isEmpty && tasks.isEmpty) return;` --
    // and it was written to defend against the loading-state bug described
    // above. The switch to `.future` fixed that bug properly: by this line both
    // streams have emitted, so "empty" means the student's record really is
    // empty rather than not yet known.
    //
    // Left in place, it meant a student who deleted everything never uploaded
    // that fact. The cloud kept the copy from before the delete, and
    // `BackupSyncGate._restoreIfEmpty` handed it back on the next device the
    // student signed into -- so deleting their data locally looked like it had
    // worked and then quietly undid itself. Emptiness is a state worth
    // recording, and it is the one state the old guard refused to record.
    //
    // But only once the emptiness is *informed*. If no cloud copy has ever
    // reached this device, "empty" can equally mean a failed offline
    // auto-restore -- and uploading that would overwrite the newer cloud doc
    // with nothing. Until a restore has succeeded here (marker in
    // [kLastCloudDownloadKey]), an empty record stays local. A brand-new
    // account loses nothing by this: there was nothing in its cloud document
    // to protect, and the first real upload creates it as before.
    if (snapshot.isEmpty &&
        tasks.isEmpty &&
        ref
            .read(sharedPreferencesProvider)
            .getInt(kLastCloudDownloadKey)
            == null) {
      debugPrint(
        'Ather: holding empty upload -- no cloud copy has reached this '
        'device yet',
      );
      return;
    }

    // The account can change while those two awaits are in flight, and an upload
    // is addressed by uid. Re-check rather than trust the value read above.
    if (ref.read(accountProvider).value?.id != owner) return;

    state = state.copyWith(status: SyncStatus.saving, clearFailure: true);
    try {
      // Capture history rides with every upload: a cloud copy without it
      // would let the first restore erase exactly what the events table
      // exists to keep.
      final events = await ref.read(studyRepositoryProvider).readEvents();
      await ref
          .read(backupRepositoryProvider)
          .upload(
            StudyBackup.fromSnapshot(snapshot, tasks, events: events),
          );
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

  /// Records a failure that happened outside the upload path -- the
  /// automatic restore in `BackupSyncGate` (N14). The card shows the same
  /// "failed" state a failed flush produces, so a restore that could not get
  /// through is news the student can see rather than silence.
  void reportFailure(BackupFailure failure) {
    state = state.copyWith(status: SyncStatus.failed, failure: failure);
  }

  /// Pulls the cloud copy over the local database. Destructive by definition, so
  /// every caller confirms first -- except the empty-database case, where there
  /// is nothing to lose.
  ///
  /// One call, one transaction: study world and daily tasks land together or
  /// not at all (D-02). Two unjoined transactions across two repositories let
  /// process death strand a half-state that the next flush made
  /// cloud-permanent.
  Future<void> restore(StudyBackup backup) async {
    await DriftStudyRepository(
      ref.read(databaseProvider),
    ).restoreEverything(backup);

    // Only a *completed* bring-down marks the device: from here an empty local
    // record is an informed state that flush may upload, not a failed
    // auto-restore it must protect (N4).
    await ref
        .read(sharedPreferencesProvider)
        .setInt(
          kLastCloudDownloadKey,
          ref.read(clockProvider).now().millisecondsSinceEpoch,
        );
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
