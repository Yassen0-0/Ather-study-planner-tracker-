import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart' show rootNavigatorKey;
import '../../core/l10n/generated/app_localizations.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/backup_repository.dart';
import '../common/prompts.dart';
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

  /// This session's automatic restore could not reach the cloud (a
  /// [BackupException] -- offline, a timeout, the rules).
  ///
  /// It used to be final for the session: `_restoreChecked` stayed true and
  /// nothing asked again until the next cold start. By then the student had
  /// often typed something, the device was no longer empty, and no automatic
  /// restore would ever run for it again (D1). So a failed attempt is retried
  /// the next time the app comes back to the foreground -- still only onto an
  /// empty device, re-read at that moment, so a retry can never land on work.
  bool _restoreFailed = false;

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
  /// somebody else's account arrives -- or when **no** account was ever
  /// recorded, the state of every phone upgraded from before logins existed;
  /// those decide from the data on the device, exactly as a different uid
  /// would.
  ///
  /// **The wipe is confirmed, never silent.** It is the one destructive act in
  /// the app with no undo, and it sits behind a mis-tap: "create account" and
  /// "sign in" share one form on one screen, so a tired thumb can arrive at a
  /// brand-new uid by accident -- and everything on the phone would be gone
  /// before a single warning was read. So when the device holds real data for
  /// another account, a sheet asks first. An empty device still wipes without
  /// asking: there is nothing to mourn, and the ordinary auto-restore below
  /// depends on starting from empty. Refusing leaves every byte where it was,
  /// keeps the stored uid pointing at the *old* account so the next launch asks
  /// again rather than inheriting a consent nobody gave, and skips this
  /// session's auto-restore -- a device we may not touch is not a device we may
  /// fill either.
  ///
  /// Clearing here also feeds the restore below the answer it wants: the device
  /// is now genuinely empty, so the ordinary auto-restore pulls the new
  /// student's own cloud copy with no second code path.
  Future<bool> _clearIfDifferentAccount(String uid) async {
    final preferences = ref.read(sharedPreferencesProvider);
    final previous = preferences.getString(kLastAccountUidKey);

    // The same student coming back: nothing on this device belongs to anybody
    // else, so there is nothing to ask about.
    if (previous == uid) {
      await preferences.setString(kLastAccountUidKey, uid);
      return true;
    }

    // **A missing key is not an empty device.** Phones that predate accounts
    // hold a whole curriculum under no uid at all -- the key is written only
    // here -- and on those the first account this gate ever sees is already
    // the second student. So `previous == null` falls through to the very
    // same decision as a known-different uid, made from the data actually on
    // the device rather than from the absence of a marker (C1): empty means
    // nobody's record is at risk, non-empty means somebody must consent.
    //
    // Emptiness is read from the database through `snapshotProvider.future`,
    // the same honest answer _restoreIfEmpty insists on below -- never from
    // the loading fallback. Daily tasks are deliberately not consulted; the
    // reason is written on _restoreIfEmpty.
    //
    // A read that *fails* answers neither way, and since WS6 (c771d13) a
    // failing stream rejects rather than collapsing to empty -- so this await
    // is guarded like its siblings below: guessing "empty" wipes without
    // asking and guessing "non-empty" sheets a wipe built on a guess. The
    // honest answer is unknown, unknown holds, and holding here skips the
    // whole hand-over -- no wipe decision, no restore, and the old uid stays
    // recorded so the next launch asks again. Same fail-safe direction as the
    // confirmation sheet above, whose no-surface fallback this mirrors.
    final bool empty;
    try {
      empty = (await ref.read(snapshotProvider.future)).isEmpty;
    } on Object catch (error, stack) {
      debugPrint(
        'Ather: account-switch check held -- device read failed: '
        '$error\n$stack',
      );
      return false;
    }
    if (!empty) {
      final confirmed = await _confirmWipe();
      if (!confirmed) {
        return false;
      }
    }

    // Gone mid-hand-over (the app closed): stop without touching `ref`. The
    // old uid is still recorded, so the next launch asks again -- the same
    // recovery a crash mid-wipe gets, described below.
    if (!mounted) return false;
    await ref.read(studyRepositoryProvider).clear();
    if (!mounted) return false;
    await ref.read(taskRepositoryProvider).clearTasks();
    // The database was only half of what the previous student left: drafts
    // keyed by lesson id would resurface under the new student once ids
    // restart at 1 (D-01), and the name and lock configuration are theirs too
    // (SEC-04). Runs before the uid rewrite below, so a crash mid-wipe leaves
    // no uid recorded rather than the wrong one.
    await wipeAccountPreferences(preferences);
    if (!mounted) return false;
    // The restore below asks whether the device is empty, and the stream it
    // asks may not have re-emitted since these deletes landed -- a stale
    // non-empty answer would skip the auto-restore for the very student who
    // just consented to it. Dropping the cached read forces a fresh one, so
    // the question is answered from the database as the wipe left it, not as
    // the last frame rendered it.
    ref.invalidate(snapshotProvider);
    // Written after the wipe, never before: a crash mid-wipe must leave the
    // device still claiming the *old* uid, so the next launch tries again.
    await preferences.setString(kLastAccountUidKey, uid);
    return true;
  }

  /// The sheet that stands between a different account and the data already on
  /// the phone.
  ///
  /// Shown against the **root navigator's** context rather than any screen's:
  /// the gate lives above the router precisely because the decision belongs to
  /// the app as a whole, and whatever route happens to be on top when the
  /// account stream emits must not decide whether the question can be asked --
  /// or where the sheet lands.
  ///
  /// Posted to the next frame rather than shown inline, for the same reason
  /// notification taps are: the emission can arrive while the engine is still
  /// laying out its first frames, before there is a navigator to present on.
  ///
  /// If no surface exists even then, the answer is **no wipe**. Asking again
  /// costs one launch; wiping unasked costs a student's whole record. That is
  /// also why the sheet's cancel is the default on any failure -- the copy on
  /// the red button describes exactly what is about to go, so "yes" has to be
  /// a reading, never an accident.
  Future<bool> _confirmWipe() {
    final completer = Completer<bool>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final context = rootNavigatorKey.currentContext;
        if (context == null || !context.mounted) {
          completer.complete(false);
          return;
        }
        final l = L.of(context);
        completer.complete(
          await confirmDestructive(
            context,
            title: l.accountSwitchWipeTitle,
            message: l.accountSwitchWipeMessage,
            confirmLabel: l.accountSwitchWipeConfirm,
          ),
        );
      } on Object catch (error, stack) {
        debugPrint(
          'Ather: account-switch confirmation could not be shown -- '
          '$error\n$stack',
        );
        if (!completer.isCompleted) completer.complete(false);
      }
    });
    return completer.future;
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
    // Back in front after a restore that could not get through: the network
    // may well be back too (see [_restoreFailed]).
    if (state == AppLifecycleState.resumed && _restoreFailed) {
      final account = ref.read(accountProvider).value;
      if (account != null) {
        _restoreFailed = false;
        _restoreChecked = false;
        unawaited(_restoreIfEmpty(account.id));
      }
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
    // data on the device is not theirs -- and if they declined to hand it
    // over, neither the wipe nor this session's restore may touch anything.
    if (!await _clearIfDifferentAccount(uid)) return;
    // Every await below can outlive this widget (the app closing mid-restore),
    // and `ref` throws once it has; each one is followed by this check before
    // `ref` is touched again.
    if (!mounted) return;

    // `snapshotProvider.future`, not `snapshotValueProvider`: awaiting the
    // stream's first real emission gives a true answer, and it goes through the
    // same provider every screen reads -- so a test that stubs the snapshot
    // stubs this too, rather than this quietly opening a second database.
    //
    // Guarded, because since WS6 (c771d13) a failing read rejects instead of
    // collapsing to empty, and this future runs fire-and-forget off a
    // lifecycle callback -- an unguarded rejection escapes as an unhandled
    // zone error and files a fatal crash report for what is a recoverable
    // read hiccup (C6). It must not be guessed about either: "empty" would
    // restore onto unknown data, "non-empty" would skip it silently. Unknown
    // holds -- skip this session's restore, with the news on the sync card
    // exactly as a failed download reports (N14). The next successful launch
    // retries; nothing was written in the meantime.
    final bool empty;
    try {
      empty = (await ref.read(snapshotProvider.future)).isEmpty;
    } on Object catch (error, stack) {
      debugPrint(
        'Ather: automatic restore held -- device read failed: $error\n$stack',
      );
      if (!mounted) return;
      ref.read(backupSyncProvider.notifier).reportFailure(
            BackupFailure.unknown,
          );
      return;
    }
    if (!empty || !mounted) return;

    try {
      final backup = await ref.read(backupRepositoryProvider).download();
      if (backup == null || backup.isEmpty) return;
      if (!mounted) return;
      // Re-read rather than re-use: the download took a network round trip, and
      // the student may have started building a chapter during it.
      //
      // Inside the try but not covered by its catch: that catches only
      // `BackupException` -- cloud failures -- while a rejecting read is a
      // *local* one. Guarded on its own, for the same reason as the first
      // read above, and holding is doubly right here: the download already
      // succeeded, so restoring over an answer we could not get would risk
      // exactly the work this re-read exists to protect. The cloud copy stays
      // where it is and the student can restore by hand from Settings.
      final bool stillEmpty;
      try {
        stillEmpty = (await ref.read(snapshotProvider.future)).isEmpty;
      } on Object catch (error, stack) {
        debugPrint(
          'Ather: automatic restore held -- re-read failed: $error\n$stack',
        );
        if (!mounted) return;
        ref.read(backupSyncProvider.notifier).reportFailure(
              BackupFailure.unknown,
            );
        return;
      }
      if (!stillEmpty || !mounted) return;
      await ref.read(backupSyncProvider.notifier).restore(backup);
    } on BackupException catch (e) {
      // Offline, or the rules were never published. Either way the app is
      // perfectly usable and the student can restore by hand from Settings --
      // but the sync card carries the news instead of swallowing it (N14),
      // exactly as a failed upload already does.
      debugPrint('Ather: automatic restore failed -- ${e.failure}');
      if (!mounted) return;
      _restoreFailed = true;
      ref.read(backupSyncProvider.notifier).reportFailure(e.failure);
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
        _restoreFailed = false;
        _restoreIfEmpty(now.id);
      }
      // Signing out clears the guard so the next student on this device gets
      // their own restore check rather than inheriting this one's.
      if (now == null) {
        _restoreChecked = false;
        _restoreFailed = false;
      }
    });

    return widget.child;
  }
}
