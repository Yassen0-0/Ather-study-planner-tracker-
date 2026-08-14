import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/account.dart';
import '../../domain/repositories/backup_repository.dart';
import 'app_providers.dart';
import 'auth_providers.dart';
import 'backup_providers.dart';
import 'task_providers.dart';

/// Two jobs, both invisible: flush the backup when the app goes away, and pull
/// the cloud copy onto a device that has nothing.
///
/// A widget rather than a provider because both need the app lifecycle, and
/// because it must never be on the path of a build -- it renders its child
/// unchanged, always, whatever the network is doing.
class BackupSyncGate extends ConsumerStatefulWidget {
  const BackupSyncGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BackupSyncGate> createState() => _BackupSyncGateState();
}

class _BackupSyncGateState extends ConsumerState<BackupSyncGate>
    with WidgetsBindingObserver {
  /// Guards against a second automatic restore in one session -- a stream that
  /// re-emits must not be able to replay a restore over data the student has
  /// since typed.
  bool _restoreChecked = false;

  /// Wipes the device when the account that just signed in is **not** the one
  /// whose data is sitting on it.
  ///
  /// Nothing did this before, and the consequences ran in both directions: the
  /// second student opened the app to the first student's curriculum, and the
  /// backup sync then uploaded that curriculum into the second student's cloud
  /// document -- corrupting a backup that had done nothing wrong.
  ///
  /// The check is the *uid*, not "is anyone signed in", and it is deliberately
  /// not tied to sign-out. Signing out leaves everything in place, so the same
  /// student signing back in -- offline, with work that never reached the cloud
  /// -- finds it exactly as they left it. Data only becomes the wrong data when
  /// somebody else's account arrives.
  ///
  /// Clearing here also feeds the restore below the answer it wants: the device
  /// is now genuinely empty, so the ordinary auto-restore pulls the new
  /// student's own cloud copy with no second code path.
  Future<void> _clearIfDifferentAccount(String uid) async {
    final preferences = ref.read(sharedPreferencesProvider);
    final previous = preferences.getString(kLastAccountUidKey);

    if (previous != null && previous != uid) {
      await ref.read(studyRepositoryProvider).clear();
      await ref.read(taskRepositoryProvider).clearTasks();
    }
    // Written after the wipe, never before: a crash mid-wipe must leave the
    // device still claiming the *old* uid, so the next launch tries again.
    await preferences.setString(kLastAccountUidKey, uid);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause, not resume: this is the last moment before the app may be killed,
    // and it is exactly when a student closes the app after recording an exam.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(backupSyncProvider.notifier).flush();
    }
  }

  /// Restores **only** onto an empty database.
  ///
  /// A device with nothing on it has nothing to lose, so no question is worth
  /// asking. Every other case -- local data present, cloud copy newer -- is a
  /// choice that belongs to the student, and it lives behind the explicit button
  /// in Settings with a confirmation. Silently overwriting a student's work with
  /// a cloud copy is the one failure this feature must not have.
  ///
  /// **Emptiness is read from the database, never from `snapshotValueProvider`.**
  /// That provider falls back to `StudySnapshot.empty()` while its stream is
  /// still loading -- deliberately, so a transient frame cannot crash a screen.
  /// Reading it here asked "is this device empty?" at the one moment the honest
  /// answer is "not known yet", and got back "yes". A student who signed in on a
  /// phone that already had their curriculum on it had it replaced by the cloud
  /// copy. `readSnapshot()` exists for exactly this: logic outside the widget
  /// tree that needs a real answer rather than a safe default.
  ///
  /// Daily tasks are deliberately not consulted. The auth gate stands in front
  /// of the entire app, so a student on a fresh install signs in *before* they
  /// can write anything at all, tasks included -- and reading them here built
  /// the tasks stream from inside this callback, which left `student_flow_test`
  /// unable to settle.
  Future<void> _restoreIfEmpty(String uid) async {
    if (_restoreChecked) return;
    _restoreChecked = true;

    // Before anything reads or uploads: if this is a different student, the
    // data on the device is not theirs.
    await _clearIfDifferentAccount(uid);

    // `snapshotProvider.future`, not `snapshotValueProvider`: awaiting the
    // stream's first real emission gives a true answer, and it goes through the
    // same provider every screen reads -- so a test that stubs the snapshot
    // stubs this too, rather than this quietly opening a second database.
    if (!(await ref.read(snapshotProvider.future)).isEmpty) return;

    try {
      final backup = await ref.read(backupRepositoryProvider).download();
      if (backup == null || backup.isEmpty) return;
      if (!mounted) return;
      // Re-read rather than re-use: the download took a network round trip, and
      // the student may have started building a chapter during it.
      if (!(await ref.read(snapshotProvider.future)).isEmpty) return;
      await ref.read(backupSyncProvider.notifier).restore(backup);
    } on BackupException {
      // Offline, or the rules were never published. Either way the app is
      // perfectly usable and the student can restore by hand from Settings.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Account?>>(accountProvider, (previous, next) {
      final was = previous?.value;
      final now = next.value;
      // The condition is "a *different* account is now signed in", not "somebody
      // signed in where nobody was". Those are the same thing only if every
      // account change passes through null on the way, and the wipe below is
      // the one thing standing between two students on one phone. Keying it on
      // the uid means it cannot be skipped by a transition that never emits
      // null -- and it still does nothing when the stream merely re-emits the
      // same account, which happens on every token refresh.
      if (now != null && now.id != was?.id) {
        _restoreChecked = false;
        _restoreIfEmpty(now.id);
      }
      // Signing out clears the guard so the next student on this device gets
      // their own restore check rather than inheriting this one's.
      if (now == null) _restoreChecked = false;
    });

    return widget.child;
  }
}
