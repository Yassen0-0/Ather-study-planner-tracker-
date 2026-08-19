import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ather/core/clock/clock.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:ather/presentation/providers/backup_providers.dart';
import 'package:ather/presentation/providers/task_providers.dart';

import '../support/fake_auth.dart';
import '../support/fake_backup.dart';

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
    scheduledExams: const [],
  );

  /// A container wired the way the app wires it, with both streams under the
  /// test's control so "still loading" is a state it can hold open.
  Future<ProviderContainer> boot({
    required FakeBackupRepository backup,
    required Stream<StudySnapshot> snapshots,
    required Stream<List<DailyTask>> tasks,
    String owner = 'test-uid',
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kLastAccountUidKey: owner,
    });
    final preferences = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
        backupRepositoryProvider.overrideWithValue(backup),
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

  test('a genuinely empty device uploads nothing', () async {
    final backup = FakeBackupRepository();
    final container = await boot(
      backup: backup,
      snapshots: Stream<StudySnapshot>.value(const StudySnapshot.empty()),
      tasks: Stream<List<DailyTask>>.value(const <DailyTask>[]),
    );

    await container.read(backupSyncProvider.notifier).flush();

    expect(backup.uploadCount, 0);
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
}
