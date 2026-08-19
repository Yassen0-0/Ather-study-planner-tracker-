import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

/// The integrity field on the cloud backup.
///
/// A backup is the only copy that survives a lost phone, and it used to be
/// stored with nothing that could tell a good blob from a damaged one. A
/// corrupt payload was discovered only if `fromJson` happened to trip over the
/// damaged part -- and damage landing inside a string field trips over nothing
/// at all. It restores, silently, wrong.
///
/// The third group is the one that matters most: students have format version 2
/// documents in the cloud **right now**, written before any of this existed.
/// Refusing them would be data loss dressed up as a safety check.
void main() {
  const uid = 'test-uid';

  final DateTime t0 = DateTime.fromMillisecondsSinceEpoch(1754300000000);

  StudyBackup populated() => StudyBackup(
    subjects: const <Subject>[
      Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
    ],
    chapters: <Chapter>[
      Chapter(
        id: 7,
        subjectId: 1,
        name: 'الباب الأول — الخلية',
        createdAt: t0,
      ),
    ],
    lessons: <Lesson>[
      Lesson(
        id: 20,
        chapterId: 7,
        name: 'تركيب الخلية',
        createdAt: t0,
        checklist: const LessonChecklist(
          watchedLesson: true,
          readNotes: false,
          didHomework: true,
          didExam: true,
          reviewedNotes: false,
        ),
      ),
    ],
    exams: <ExamEntry>[
      ExamEntry(
        id: 55,
        lessonId: 20,
        isReviewExam: false,
        totalPossiblePoints: 10,
        correctPoints: 8,
        percentage: 80,
        createdAt: t0,
        groups: const <ExamQuestionGroup>[
          ExamQuestionGroup(
            id: 90,
            examId: 55,
            pointsPerQuestion: 1,
            questionCount: 10,
            correctCount: 8,
          ),
        ],
      ),
    ],
    homework: const <HomeworkEntry>[],
    tasks: <DailyTask>[
      DailyTask(
        id: 2,
        day: DateTime(2025, 8, 4),
        title: 'أذاكر',
        done: true,
        sortOrder: 0,
        createdAt: t0,
      ),
    ],
  );

  late FakeFirebaseFirestore firestore;
  late FirestoreBackupRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestoreBackupRepository(
      firestore,
      MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid)),
    );
  });

  DocumentReference<Map<String, dynamic>> doc() => firestore
      .collection('users')
      .doc(uid)
      .collection('backup')
      .doc('snapshot');

  /// Writes a document by hand, the way a build at [version] would have --
  /// which for version 2 means **no `checksum` field at all**, not an empty one.
  Future<void> writeRaw(StudyBackup backup, {required int version}) async {
    final bytes = Uint8List.fromList(
      gzip.encode(utf8.encode(jsonEncode(backup.toJson()))),
    );
    await doc().set(<String, Object?>{
      'payload': Blob(bytes),
      'formatVersion': version,
      'chapterCount': backup.chapterCount,
      'examCount': backup.examCount,
      'updatedAt': Timestamp.fromDate(t0),
    });
  }

  group('a payload written by this build', () {
    test('carries a checksum beside it, not inside it', () async {
      await repository.upload(populated());

      final data = (await doc().get()).data()!;
      expect(data['checksum'], isA<String>());
      // SHA-256, hex: sixty-four characters. Asserted because a digest stored
      // as bytes, or truncated, would still be "a String" and would still
      // compare equal to itself -- and would still be useless.
      expect((data['checksum']! as String).length, 64);
      expect(data['formatVersion'], 3);
    });

    test('round-trips through download intact', () async {
      await repository.upload(populated());

      final out = await repository.download();

      expect(out, isNotNull);
      expect(out!.chapters.single.name, 'الباب الأول — الخلية');
      expect(out.exams.single.percentage, 80);
      expect(out.tasks.single.title, 'أذاكر');
    });

    test('the same record twice produces the same digest', () async {
      // The digest is taken over the uncompressed JSON rather than over the
      // gzip output for exactly this reason: gzip is not required to be
      // byte-identical between runs, and a digest that drifts is a digest that
      // rejects good backups.
      await repository.upload(populated());
      final first = (await doc().get()).data()!['checksum'];

      await repository.upload(populated());
      final second = (await doc().get()).data()!['checksum'];

      expect(second, first);
    });
  });

  group('a payload that does not match its checksum', () {
    test('is refused as unreadable', () async {
      await repository.upload(populated());
      // What a corrupt blob looks like from here: the document still parses,
      // the payload still decompresses, and the record it decodes to is not
      // the one that was written.
      await doc().update(<String, Object?>{'checksum': 'a' * 64});

      expect(
        () => repository.download(),
        throwsA(
          isA<BackupException>().having(
            (e) => e.failure,
            'failure',
            BackupFailure.unreadable,
          ),
        ),
      );
    });

    test('is refused before it is handed back, not after', () async {
      // The point of checking here rather than in the caller: `download`
      // returning a mismatched record at all would put it one step from the
      // drift transaction that deletes the student's database before writing
      // the replacement. Nothing that fails its digest may reach that step.
      await repository.upload(populated());
      await doc().update(<String, Object?>{'checksum': 'b' * 64});

      StudyBackup? leaked;
      try {
        leaked = await repository.download();
      } on BackupException {
        // expected
      }
      expect(leaked, isNull);
    });

    test('a payload edited under a stale checksum is caught', () async {
      // The realistic shape of the failure: the bytes change and the digest
      // does not follow. Written here as a payload swapped for a different
      // record, which is what a partial write or a crossed document produces.
      await repository.upload(populated());
      const other = StudyBackup(
        subjects: <Subject>[],
        chapters: <Chapter>[],
        lessons: <Lesson>[],
        exams: <ExamEntry>[],
        homework: <HomeworkEntry>[],
        tasks: <DailyTask>[],
      );
      await doc().update(<String, Object?>{
        'payload': Blob(
          Uint8List.fromList(
            gzip.encode(utf8.encode(jsonEncode(other.toJson()))),
          ),
        ),
      });

      expect(
        () => repository.download(),
        throwsA(
          isA<BackupException>().having(
            (e) => e.failure,
            'failure',
            BackupFailure.unreadable,
          ),
        ),
      );
    });
  });

  group('a format version 2 document, written before any of this existed', () {
    test('still restores, checksum or no checksum', () async {
      // **This is the test that matters.** Students have version 2 blobs in the
      // cloud right now. A missing checksum means "written by a build that did
      // not compute one", not "tampered with", and refusing it would delete a
      // student's only backup to defend against a threat that postdates it.
      await writeRaw(populated(), version: 2);

      final out = await repository.download();

      expect(out, isNotNull);
      expect(out!.chapters.single.name, 'الباب الأول — الخلية');
      expect(out.exams.single.percentage, 80);
      expect(out.tasks.single.title, 'أذاكر');
    });

    test('its metadata still reads', () async {
      await writeRaw(populated(), version: 2);

      final metadata = await repository.readMetadata();

      expect(metadata, isNotNull);
      expect(metadata!.formatVersion, 2);
      expect(metadata.chapterCount, 1);
      expect(metadata.examCount, 1);
    });

    test('the next upload replaces it with a checksummed version 3', () async {
      await writeRaw(populated(), version: 2);
      await repository.upload(populated());

      final data = (await doc().get()).data()!;
      expect(data['formatVersion'], 3);
      expect(data['checksum'], isA<String>());
    });
  });

  group('an empty record', () {
    test('uploads and comes back empty rather than failing', () async {
      // The other half of this batch: a student who deletes everything has to
      // be able to say so to the cloud, and the empty payload has to survive
      // the same integrity check as a full one.
      const empty = StudyBackup(
        subjects: <Subject>[],
        chapters: <Chapter>[],
        lessons: <Lesson>[],
        exams: <ExamEntry>[],
        homework: <HomeworkEntry>[],
        tasks: <DailyTask>[],
      );

      await repository.upload(empty);
      final out = await repository.download();

      expect(out, isNotNull);
      expect(out!.isEmpty, isTrue);
    });
  });
}
