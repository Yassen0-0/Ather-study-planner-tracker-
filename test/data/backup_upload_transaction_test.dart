import 'package:ather/data/backup/firestore_backup_repository.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_backup.dart';
import 'package:ather/domain/entities/subject.dart';
import 'package:ather/domain/repositories/backup_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

/// Round 3: an upload goes through a transaction, which Firestore never
/// queues offline, instead of a `set()` it would queue and send later --
/// possibly after the app had decided not to upload.
///
/// The fake does not model offline queueing, so these pin the part that can
/// be pinned: the write only happens inside a transaction, and a transaction
/// that fails leaves the cloud exactly as it was.
void main() {
  const uid = 'student-a';

  StudyBackup backup(String chapterName) => StudyBackup(
    subjects: const <Subject>[
      Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
    ],
    chapters: <Chapter>[
      Chapter(
        id: 1,
        subjectId: 1,
        name: chapterName,
        createdAt: DateTime.utc(2026, 8, 1),
      ),
    ],
    lessons: const <Lesson>[],
    exams: const <ExamEntry>[],
    homework: const <HomeworkEntry>[],
    tasks: const <DailyTask>[],
  );

  FirestoreBackupRepository repositoryOn(FakeFirebaseFirestore firestore) =>
      FirestoreBackupRepository(
        firestore,
        MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid)),
      );

  test('the upload is written inside a transaction', () async {
    final firestore = _CountingFirestore();
    await repositoryOn(firestore).upload(backup('باب'));

    expect(firestore.transactions, 1);
    final metadata = await repositoryOn(firestore).readMetadata();
    expect(metadata!.chapterCount, 1);
  });

  test('a transaction that cannot commit leaves the cloud untouched', () async {
    final firestore = _CountingFirestore();
    final repository = repositoryOn(firestore);
    await repository.upload(backup('الأول'));

    // Offline: the commit is refused -- and, unlike a queued set(), nothing
    // is left behind to arrive later.
    firestore.failWith = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );
    await expectLater(
      repository.upload(backup('الثاني')),
      throwsA(
        isA<BackupException>().having(
          (e) => e.failure,
          'failure',
          BackupFailure.offline,
        ),
      ),
    );

    firestore.failWith = null;
    final restored = await repository.download();
    expect(restored!.chapters.single.name, 'الأول');
  });
}

/// Counts transactions, and can refuse one the way an offline commit does.
class _CountingFirestore extends FakeFirebaseFirestore {
  int transactions = 0;
  Object? failWith;

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    transactions++;
    final failure = failWith;
    if (failure != null) return Future<T>.error(failure);
    return super.runTransaction(
      transactionHandler,
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
  }
}
