import 'dart:io';

import 'package:ather/data/backup/firestore_backup_repository.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_backup.dart';
import 'package:ather/domain/entities/subject.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

/// S1: `firestore.rules` against the document the app actually writes.
///
/// **What this is not:** an execution of the rules. The in-process simulator
/// that fake_cloud_firestore ships (`fake_firebase_security_rules` 0.5.4)
/// cannot parse this file at all -- it rejects `rules_version`, knows no
/// `create` method, and has no `is`, `keys()`, `hasOnly()`, `hasAll()` or
/// `size()`. Evaluating the real conditions needs the Firestore emulator, and
/// `tool/check_deployed_rules.sh` asks the same questions of the live project
/// after a deploy.
///
/// **What this is:** the contract between the two halves, checked on every
/// test run. The real rules file is read from disk; the real
/// `FirestoreBackupRepository.upload` writes a document into a fake Firestore;
/// and the tests fail the moment the fields `upload()` writes and the fields the
/// rules admit -- by name and by type -- stop being the same list. That drift is
/// the failure that would matter: every student's backup silently rejected by
/// a rule that no longer matches the client.
void main() {
  const uid = 'student-a';
  final rules = File('firestore.rules').readAsStringSync();

  /// The body of `match <path> { ... }`, braces balanced.
  String block(String matchHeader) {
    final start = rules.indexOf(matchHeader);
    expect(start, isNot(-1), reason: 'no `$matchHeader` in firestore.rules');
    // The header ends on its opening brace; paths contain braces of their
    // own (`{uid}`), so counting starts there, not at the first `{`.
    var depth = 0;
    for (var i = start + matchHeader.length - 1; i < rules.length; i++) {
      if (rules[i] == '{') depth++;
      if (rules[i] == '}') depth--;
      if (depth == 0) return rules.substring(start, i + 1);
    }
    fail('unbalanced braces after `$matchHeader`');
  }

  /// Rules comments are `//` lines; strip them so a field named in prose does
  /// not count as a field named in a condition.
  String code(String text) => text
      .split('\n')
      .map((line) {
        final comment = line.indexOf('//');
        return comment == -1 ? line : line.substring(0, comment);
      })
      .join('\n');

  Set<String> listIn(String source, String function) {
    final match = RegExp('$function\\(\\[([^\\]]*)\\]\\)').firstMatch(source);
    expect(match, isNotNull, reason: 'no $function([...]) in the backup rule');
    return RegExp(r"'([A-Za-z]+)'")
        .allMatches(match!.group(1)!)
        .map((m) => m.group(1)!)
        .toSet();
  }

  late String snapshotRule;
  late Map<String, dynamic> written;

  setUpAll(() async {
    snapshotRule = code(block('match /users/{uid}/backup/snapshot {'));

    // The document exactly as the app writes it.
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreBackupRepository(
      firestore,
      MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid)),
    );
    await repository.upload(_backup());
    final snap = await firestore
        .collection('users')
        .doc(uid)
        .collection('backup')
        .doc('snapshot')
        .get();
    written = snap.data()!;
  });

  test('the backup rule matches one exact document, not a wildcard', () {
    final all = code(rules);
    expect(all, contains('match /users/{uid}/backup/snapshot {'));
    // The old `backup/{document=**}` let a client create unbounded documents
    // under its own backup/. Nothing under backup/ may be a variable now.
    expect(all, isNot(contains('backup/{')));
  });

  test('everything else stays denied', () {
    final deny = code(block('match /{document=**} {'));
    expect(deny, contains('allow read, write: if false;'));
    // And it is the only other rule: no path besides the snapshot is opened.
    expect(RegExp(r'\ballow\b').allMatches(code(rules)).length, 4,
        reason: 'read, create/update and delete on the snapshot, plus the '
            'global deny');
  });

  test('every access is owner-only', () {
    final allows = RegExp(r'allow [^:]+:[^;]*;', dotAll: true)
        .allMatches(snapshotRule)
        // Conditions wrap across lines; compare them as one line.
        .map((m) => m.group(0)!.replaceAll(RegExp(r'\s+'), ' '))
        .toList();
    expect(allows, hasLength(3));
    for (final allow in allows) {
      expect(
        allow,
        contains('request.auth != null && request.auth.uid == uid'),
        reason: allow,
      );
    }
  });

  test('delete stays allowed, and never reads request.resource', () {
    // On a delete there is no request.resource: a condition touching it
    // errors and denies, and account deletion then cannot erase the backup.
    final delete = RegExp(r'allow delete:[^;]*;').firstMatch(snapshotRule);
    expect(delete, isNotNull);
    expect(delete!.group(0), isNot(contains('request.resource')));
  });

  test('hasOnly admits exactly the fields upload() writes', () {
    expect(listIn(snapshotRule, 'hasOnly'), written.keys.toSet());
  });

  test('hasAll requires every written field older builds also wrote', () {
    final required = listIn(snapshotRule, 'hasAll');
    expect(written.keys.toSet().containsAll(required), isTrue);
    // `checksum` arrived with format 3; builds from before it are still
    // installed, so requiring it would reject their every upload.
    expect(required, written.keys.toSet().difference(<String>{'checksum'}));
  });

  test('every written field is type-checked as the type upload() writes', () {
    String rulesType(Object? value) => switch (value) {
      Blob() => 'bytes',
      String() => 'string',
      int() => 'int',
      Timestamp() => 'timestamp',
      _ => fail('upload() wrote ${value.runtimeType}; teach this test and '
          'firestore.rules its type'),
    };
    for (final entry in written.entries) {
      expect(
        snapshotRule,
        contains(
          'request.resource.data.${entry.key} is ${rulesType(entry.value)}',
        ),
        reason: '${entry.key} is written as ${entry.value.runtimeType}',
      );
    }
  });

  test('the payload ceiling reads bytes, and sits above the client limit', () {
    final ceiling = RegExp(
      r'request\.resource\.data\.payload\.size\(\) <= (\d+)',
    ).firstMatch(snapshotRule);
    expect(ceiling, isNotNull);
    // 900 KiB is `_maxBlobBytes`; the server must not refuse what the client
    // was willing to send.
    expect(int.parse(ceiling!.group(1)!), greaterThanOrEqualTo(900 * 1024));
  });
}

StudyBackup _backup() {
  final t0 = DateTime.fromMillisecondsSinceEpoch(1754300000000);
  return StudyBackup(
    subjects: const <Subject>[
      Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
    ],
    chapters: <Chapter>[
      Chapter(id: 7, subjectId: 1, name: 'باب', createdAt: t0),
    ],
    lessons: const <Lesson>[],
    exams: const <ExamEntry>[],
    homework: const <HomeworkEntry>[],
    tasks: const <DailyTask>[],
  );
}
