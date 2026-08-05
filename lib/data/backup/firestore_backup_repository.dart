import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/study_backup.dart';
import '../../domain/repositories/backup_repository.dart';

/// The only file in the app that imports `cloud_firestore`.
///
/// One document per student at `users/{uid}/backup/snapshot`, holding the whole
/// record as a gzipped JSON blob plus a few plain fields.
///
/// **Why one blob rather than a collection per entity:** a student's record is
/// small (a few hundred lessons, a few thousand exams) and is only ever read or
/// written whole. Modelling it as collections would multiply the document reads
/// on every restore by the number of rows, cost more on the free tier, and add a
/// partial-write failure mode -- for a query flexibility no screen wants,
/// because every screen reads local SQLite.
class FirestoreBackupRepository implements BackupRepository {
  /// Positional rather than named so the handles can be initializing formals on
  /// private fields -- Dart forbids a named parameter starting with an
  /// underscore. Both are for injection; production passes neither.
  const FirestoreBackupRepository([this._firestore, this._auth]);

  /// Resolved lazily, never in the constructor.
  ///
  /// `main()` wraps `Firebase.initializeApp` in a try/catch on purpose
  /// (PROJECT.md §3.17): initialisation must never stand between a student and
  /// study data sitting on their own phone. Touching `FirebaseFirestore.instance`
  /// while constructing this would throw `[core/no-app]` the moment Settings
  /// built, turning a tolerated init failure into a crashed screen.
  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;

  /// Firestore's hard ceiling is 1 MiB per document. The budget is deliberately
  /// below it: the blob is not the only field, and a backup that fails at the
  /// boundary fails on the student's most valuable record -- the biggest one.
  static const int _maxBlobBytes = 900 * 1024;

  /// A read that never returns is worse than one that fails: the caller shows
  /// "not saved yet" and moves on, which is the honest state anyway.
  static const Duration _timeout = Duration(seconds: 20);

  DocumentReference<Map<String, dynamic>> _doc() {
    final uid = (_auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (uid == null) throw const BackupException(BackupFailure.notSignedIn);
    return (_firestore ?? FirebaseFirestore.instance)
        .collection('users')
        .doc(uid)
        .collection('backup')
        .doc('snapshot');
  }

  @override
  Future<BackupMetadata?> readMetadata() async {
    // Inside the guard, so a missing Firebase app becomes a BackupFailure
    // rather than an exception escaping into a widget build.
    final snap = await _guard(() async => _doc().get().timeout(_timeout));
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;

    final updatedAt = data['updatedAt'];
    if (updatedAt is! Timestamp) return null;

    return BackupMetadata(
      updatedAt: updatedAt.toDate(),
      chapterCount: (data['chapterCount'] as num?)?.toInt() ?? 0,
      examCount: (data['examCount'] as num?)?.toInt() ?? 0,
      formatVersion: (data['formatVersion'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<StudyBackup?> download() async {
    // Inside the guard, so a missing Firebase app becomes a BackupFailure
    // rather than an exception escaping into a widget build.
    final snap = await _guard(() async => _doc().get().timeout(_timeout));
    if (!snap.exists) return null;
    final blob = snap.data()?['payload'];
    if (blob is! Blob) throw const BackupException(BackupFailure.unreadable);

    try {
      final bytes = gzip.decode(blob.bytes);
      final json =
          jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      return StudyBackup.fromJson(json);
    } on BackupException {
      rethrow;
    } on Object {
      // Covers a corrupt blob, invalid UTF-8, malformed JSON and a
      // BackupFormatException alike. All of them mean the same thing to the
      // caller: do not touch the local database.
      throw const BackupException(BackupFailure.unreadable);
    }
  }

  @override
  Future<void> upload(StudyBackup backup) async {
    final bytes = Uint8List.fromList(
      gzip.encode(utf8.encode(jsonEncode(backup.toJson()))),
    );
    if (bytes.lengthInBytes > _maxBlobBytes) {
      // Refuse rather than truncate. A backup missing its most recent two years
      // is worse than no backup, because the student believes they have one.
      throw const BackupException(BackupFailure.tooLarge);
    }

    await _guard(
      () async => _doc()
          .set(<String, Object?>{
            'payload': Blob(bytes),
            // Plain, so readMetadata can answer "is the cloud newer?" without
            // downloading and decompressing the payload.
            'formatVersion': StudyBackup.formatVersion,
            'chapterCount': backup.chapterCount,
            'examCount': backup.examCount,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(_timeout),
    );
  }

  /// Translates every transport failure into a [BackupFailure] at the boundary,
  /// so no Firebase type and no English error string escapes this file.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on BackupException {
      rethrow;
    } on FirebaseException catch (e) {
      throw BackupException(switch (e.code) {
        'permission-denied' => BackupFailure.permissionDenied,
        'unauthenticated' => BackupFailure.notSignedIn,
        'unavailable' || 'deadline-exceeded' => BackupFailure.offline,
        _ => BackupFailure.unknown,
      });
    } on SocketException {
      throw const BackupException(BackupFailure.offline);
    } on Object {
      // TimeoutException lands here too, and is the offline case in practice.
      throw const BackupException(BackupFailure.offline);
    }
  }
}
