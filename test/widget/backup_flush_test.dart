import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drift/native.dart';

import 'package:ather/core/clock/clock.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/domain/entities/study_backup.dart';
import 'package:ather/domain/entities/subject.dart';
import 'package:ather/domain/repositories/study_repository.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:ather/presentation/providers/backup_providers.dart';
import 'package:ather/presentation/providers/task_providers.dart';

import '../support/fake_auth.dart';
import '../support/fake_backup.dart';

/// Satisfies the one repository touch the upload path makes beyond its
/// streams: reading the capture history. These tests stub the *streams*, so a
/// real database here would be an accident; `noSuchMethod` keeps the fake to
/// exactly the member in use.
class _EventsOnlyStudyRepository implements StudyRepository {
  @override
  Future<List<StudyEvent>> readEvents() async => const <StudyEvent>[];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

/// The **upload** direction of cloud backup.
///
/// Until these existed, nothing in the suite called [BackupSyncNotifier.flush]
/// at all. Restore was covered from the beginning because it is the obviously
/// destructive one -- it writes over the phone. Upload writes over the *cloud*,
/// which is the only copy that survives a lost phone, and it was the untested
/// half.
///
/// The bug these were written against: `flush` read `snapshotValueProvider` and
/// `tasksValueProvider`, both of which report empty while their stream is still
/// loading. The guard was `snapshot.isEmpty && tasks.isEmpty` -- an `&&` -- so
/// it only bailed when *both* halves were unknown. With one loaded and one not,
/// `flush` uploaded the half it could see over the half it could not.
void main() {
  // These are plain `test`s rather than `testWidgets` -- nothing here renders.
  // SharedPreferences' mock still talks over a platform channel, though, and
  // without a binding `getInstance()` simply never returns.
  TestWidgetsFlutterBinding.ensureInitialized();

  final DateTime now = DateTime(2026, 8, 5);

  Chapter chapter() =>
      Chapter(id: 1, subjectId: 1, name: 'الباب الأول', createdAt: now);

  DailyTask task() => DailyTask(
    id: 1,
    day: DateTime(2026, 8, 5),
    title: 'أذاكر',
    done: false,
    sortOrder: 0,
    createdAt: now,
  );

  StudySnapshot snapshotWithChapter() => StudySnapshot(
    subjects: const [],
    chapters: [chapter()],
    lessons: const [],
    exams: const [],
    homework: const [],
  );

  /// A container wired the way the app wires it, with both streams under the
  /// test's control so "still loading" is a state it can hold open.
  ///
  /// [cloudSeen] seeds the last-successful-download marker (N4): true is the
  /// state of a device that has restored at least once, false the state of a
  /// fresh sign-in whose auto-restore may never have got through.
  Future<ProviderContainer> boot({
    required FakeBackupRepository backup,
    required Stream<StudySnapshot> snapshots,
    required Stream<List<DailyTask>> tasks,
    String owner = 'test-uid',
    bool cloudSeen = true,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kLastAccountUidKey: owner,
      if (cloudSeen) kLastCloudDownloadKey: now.millisecondsSinceEpoch,
    });
    final preferences = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
        backupRepositoryProvider.overrideWithValue(backup),
        studyRepositoryProvider.overrideWithValue(_EventsOnlyStudyRepository()),
        sharedPreferencesProvider.overrideWithValue(preferences),
        clockProvider.overrideWithValue(MutableClock(now)),
        snapshotProvider.overrideWith((ref) => snapshots),
        tasksProvider.overrideWith((ref) => tasks),
      ],
    );
    addTearDown(container.dispose);

    // Riverpod 3 auto-disposes by default, and a bare `read` of a still-loading
    // StreamProvider leaves nothing holding it: the element is torn down before
    // the first event and the future completes with "disposed during loading
    // state". In the app the widget tree is the listener; here these stand in
    // for it.
    addTearDown(
      container
          .listen(accountProvider, (_, _) {}, fireImmediately: true)
          .close,
    );
    addTearDown(
      container
          .listen(snapshotProvider, (_, _) {}, fireImmediately: true)
          .close,
    );
    addTearDown(
      container.listen(tasksProvider, (_, _) {}, fireImmediately: true).close,
    );
    addTearDown(
      container
          .listen(backupSyncProvider, (_, _) {}, fireImmediately: true)
          .close,
    );

    // The account has to be resolved before flush will do anything at all.
    await container.read(accountProvider.future);
    return container;
  }

  test('does not upload the loaded half over the half still loading', () async {
    final backup = FakeBackupRepository();
    final tasks = StreamController<List<DailyTask>>();
    addTearDown(tasks.close);

    final container = await boot(
      backup: backup,
      // The curriculum has arrived...
      snapshots: Stream<StudySnapshot>.value(snapshotWithChapter()),
      // ...and the tasks have not.
      tasks: tasks.stream,
    );

    // Let the snapshot stream land, so this is genuinely the half-loaded state
    // and not simply "nothing has started yet".
    await container.read(snapshotProvider.future);

    final flushed = container.read(backupSyncProvider.notifier).flush();

    // Nothing may have gone out while the tasks were unknown.
    await Future<void>.delayed(Duration.zero);
    expect(
      backup.uploadCount,
      0,
      reason: 'uploaded before the tasks stream had said anything',
    );

    tasks.add(<DailyTask>[task()]);
    await flushed;

    expect(backup.uploadCount, 1);
    expect(
      backup.stored!.tasks,
      hasLength(1),
      reason: "the student's task was replaced by the loading fallback",
    );
    expect(backup.stored!.chapters, hasLength(1));
  });

  test('uploads both halves once both have loaded', () async {
    final backup = FakeBackupRepository();
    final container = await boot(
      backup: backup,
      snapshots: Stream<StudySnapshot>.value(snapshotWithChapter()),
      tasks: Stream<List<DailyTask>>.value(<DailyTask>[task()]),
    );

    await container.read(backupSyncProvider.notifier).flush();

    expect(backup.uploadCount, 1);
    expect(backup.stored!.chapters, hasLength(1));
    expect(backup.stored!.tasks, hasLength(1));
  });

  test('a genuinely empty device uploads its emptiness', () async {
    // **This assertion is the reverse of what it used to be**, and the reversal
    // is the fix. `flush` used to return early on
    // `snapshot.isEmpty && tasks.isEmpty`, so a student who deleted everything
    // never told the cloud. The cloud kept the copy from before the delete, and
    // `BackupSyncGate._restoreIfEmpty` handed it straight back on the next
    // device they signed into -- so the delete appeared to work and then
    // silently undid itself.
    //
    // The guard existed to avoid uploading during the loading state. Reading
    // through `.future` already handles that: by the time `flush` gets here,
    // both streams have emitted, and "empty" is an answer rather than a
    // not-yet.
    final backup = FakeBackupRepository();
    final container = await boot(
      backup: backup,
      snapshots: Stream<StudySnapshot>.value(const StudySnapshot.empty()),
      tasks: Stream<List<DailyTask>>.value(const <DailyTask>[]),
    );

    await container.read(backupSyncProvider.notifier).flush();

    expect(backup.uploadCount, 1);
    expect(backup.stored!.isEmpty, isTrue);
  });

  test('deleting everything replaces the cloud copy rather than leaving it',
      () async {
    // The whole failure, end to end: a full record goes up, the student clears
    // the device, and the second flush has to overwrite what the first one
    // wrote. If the cloud still holds chapters after this, the next device to
    // sign in gets the deleted data back.
    final backup = FakeBackupRepository();
    final snapshots = StreamController<StudySnapshot>();
    final tasks = StreamController<List<DailyTask>>();
    addTearDown(snapshots.close);
    addTearDown(tasks.close);

    final container = await boot(
      backup: backup,
      snapshots: snapshots.stream,
      tasks: tasks.stream,
    );

    snapshots.add(snapshotWithChapter());
    tasks.add(<DailyTask>[task()]);
    await container.read(backupSyncProvider.notifier).flush();
    expect(backup.stored!.chapters, hasLength(1));

    snapshots.add(const StudySnapshot.empty());
    tasks.add(const <DailyTask>[]);
    // Let the two streams actually deliver. `.future` on a provider that has
    // already emitted completes with what it holds *now*, so flushing in the
    // same turn as the `add` would upload the record the student just cleared
    // and prove nothing.
    await Future<void>.delayed(Duration.zero);
    await container.read(backupSyncProvider.notifier).flush();

    expect(backup.uploadCount, 2);
    expect(
      backup.stored!.isEmpty,
      isTrue,
      reason: 'the cloud still holds the record the student deleted',
    );
  });

  test('nothing leaves the phone while the device claims another uid', () async {
    final backup = FakeBackupRepository();
    final container = await boot(
      backup: backup,
      snapshots: Stream<StudySnapshot>.value(snapshotWithChapter()),
      tasks: Stream<List<DailyTask>>.value(<DailyTask>[task()]),
      // The wipe in BackupSyncGate has not run yet, so the data on this device
      // still belongs to somebody else.
      owner: 'a-different-student',
    );

    await container.read(backupSyncProvider.notifier).flush();

    expect(backup.uploadCount, 0);
  });

  test('an empty record never seen the cloud does not overwrite it (N4)',
      () async {
    // The failed-offline-restore hazard: a fresh sign-in whose auto-restore
    // never got through holds an empty local record while a newer cloud doc
    // sits untouched. Uploading that emptiness -- which the debounce or a
    // backgrounding will happily schedule -- would replace the student's real
    // copy with nothing. Until one restore has succeeded on this device,
    // emptiness is not knowledge, and it stays local.
    // Offline, as the failed auto-restore left it.
    final backup = FakeBackupRepository.failing();
    final container = await boot(
      backup: backup,
      snapshots: Stream<StudySnapshot>.value(const StudySnapshot.empty()),
      tasks: Stream<List<DailyTask>>.value(const <DailyTask>[]),
      cloudSeen: false,
    );

    await container.read(backupSyncProvider.notifier).flush();

    expect(backup.uploadCount, isZero);
  });

  test('a populated record uploads without any marker', () async {
    // The N4 guard is about *empty* records only: a student who recorded work
    // offline must sync exactly as before, marker or no marker.
    final backup = FakeBackupRepository();
    final container = await boot(
      backup: backup,
      snapshots: Stream<StudySnapshot>.value(snapshotWithChapter()),
      tasks: Stream<List<DailyTask>>.value(<DailyTask>[task()]),
      cloudSeen: false,
    );

    await container.read(backupSyncProvider.notifier).flush();

    expect(backup.uploadCount, 1);
    expect(backup.stored!.chapters, hasLength(1));
  });

  test('a completed restore lets emptiness flow again', () async {
    // The other half of N4: once a restore has genuinely brought the cloud
    // copy down, "I deleted everything" must reach the cloud as before. The
    // marker is what separates that state from a restore that never happened.
    SharedPreferences.setMockInitialValues(<String, Object>{
      kLastAccountUidKey: 'test-uid',
      // No marker: the device has never taken the cloud copy in.
    });
    final preferences = await SharedPreferences.getInstance();

    // Offline until the restore below succeeds -- the state the failure mode
    // lives in.
    final backup = FakeBackupRepository.failing();
    // A real database: since D-02 the restore runs through one joined
    // transaction owned by DriftStudyRepository.restoreEverything, so stubbing
    // the repositories here would stub nothing.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
        backupRepositoryProvider.overrideWithValue(backup),
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(preferences),
        clockProvider.overrideWithValue(MutableClock(now)),
        snapshotProvider.overrideWith(
          (ref) => Stream<StudySnapshot>.value(const StudySnapshot.empty()),
        ),
        tasksProvider.overrideWith(
          (ref) => Stream<List<DailyTask>>.value(const <DailyTask>[]),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Same reason boot() holds these: a bare `read` leaves the streams with no
    // listener and `.future` never settles.
    addTearDown(
      container
          .listen(accountProvider, (_, _) {}, fireImmediately: true)
          .close,
    );
    addTearDown(
      container
          .listen(snapshotProvider, (_, _) {}, fireImmediately: true)
          .close,
    );
    addTearDown(
      container.listen(tasksProvider, (_, _) {}, fireImmediately: true).close,
    );
    await container.read(accountProvider.future);

    // Before any restore: the empty record is held back.
    await container.read(backupSyncProvider.notifier).flush();
    expect(backup.uploadCount, isZero);

    // A restore completes -- the auto path and the Settings button share it.
    await container.read(backupSyncProvider.notifier).restore(_emptyBackup());
    expect(preferences.getInt(kLastCloudDownloadKey), isNotNull);

    // ...and now the same empty record is an informed delete-everything.
    backup.failure = null;
    await container.read(backupSyncProvider.notifier).flush();

    expect(backup.uploadCount, 1);
    expect(backup.stored!.isEmpty, isTrue);
  });
}

StudyBackup _emptyBackup() => const StudyBackup(
  subjects: <Subject>[],
  chapters: <Chapter>[],
  lessons: <Lesson>[],
  exams: <ExamEntry>[],
  homework: <HomeworkEntry>[],
  tasks: <DailyTask>[],
);
