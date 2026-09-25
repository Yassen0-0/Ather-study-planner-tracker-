import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/diagnostics/crash_reporting.dart';
import '../../domain/entities/study_backup.dart';
import '../../domain/repositories/backup_repository.dart';

/// What a payload looks like on the way out: compressed bytes, and a digest of
/// what they decompress to.
typedef _Encoded = ({Uint8List bytes, String checksum});

/// What it looks like on the way back: the parsed record, and the digest of the
/// bytes it was actually parsed from.
typedef _Decoded = ({Map<String, Object?> json, String checksum});

/// Top-level, because [Isolate.run] sends its closure to another isolate and a
/// closure capturing `this` would have to send the repository with it.
///
/// The digest is taken over the **uncompressed** JSON, not over the gzip
/// output. gzip is not deterministic across implementations or levels, so a
/// digest of the compressed bytes would be a digest of this build's zlib rather
/// than of the student's record.
_Encoded _encode(Map<String, Object?> json) {
  final raw = utf8.encode(jsonEncode(json));
  return (
    bytes: Uint8List.fromList(gzip.encode(raw)),
    checksum: sha256.convert(raw).toString(),
  );
}

_Decoded _decode(Uint8List bytes) {
  final raw = gzip.decode(bytes);
  return (
    json: jsonDecode(utf8.decode(raw)) as Map<String, Object?>,
    checksum: sha256.convert(raw).toString(),
  );
}

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

    // Absent on every document written before format version 3, and those are
    // in the cloud right now. A missing checksum means "written by a build that
    // did not compute one", not "tampered with" -- refusing it would delete a
    // student's only backup to defend against a threat it predates.
    final expected = snap.data()?['checksum'];

    try {
      // Decompressed off the UI isolate for the same reason as [upload], and
      // with more at stake: a restore runs while a Settings button is showing a
      // spinner, so a frozen frame thread is a frozen spinner.
      final decoded = await _decodeOffThread(blob.bytes);

      // Checked **before** the record is handed back, so a payload that does
      // not match its digest never reaches the drift transaction that replaces
      // the local database. Without this, a blob corrupted in transit or in
      // storage is discovered only when `fromJson` happens to trip over the
      // damaged part -- and damage that lands inside a string field does not
      // trip over anything at all. It restores, silently, wrong.
      if (expected is String && expected != decoded.checksum) {
        throw const BackupException(BackupFailure.unreadable);
      }

      return StudyBackup.fromJson(decoded.json);
    } on BackupException {
      rethrow;
    } on Object catch (e, stack) {
      // Covers a corrupt blob, invalid UTF-8, malformed JSON and a
      // BackupFormatException alike. All of them mean the same thing to the
      // caller: do not touch the local database.
      reportNonFatal(e, stack);
      throw const BackupException(BackupFailure.unreadable);
    }
  }

  @override
  Future<void> upload(StudyBackup backup) async {
    // Serialise and compress off the UI isolate.
    //
    // A two-year record is a few thousand exams; `jsonEncode` plus `gzip.encode`
    // over that is tens of milliseconds of solid CPU, and it ran on the frame
    // thread. Worse, it ran on a 20-second debounce — so it landed *while the
    // student was using the app*, not at some quiet moment. The lifecycle flush
    // is the only call where jank would not have been noticed.
    //
    // `toJson()` stays here: it is plain map building, and sending the entity
    // graph across an isolate boundary would cost more than it saves.
    final encoded = await _encodeOffThread(backup.toJson());
    final bytes = encoded.bytes;

    if (bytes.lengthInBytes > _maxBlobBytes) {
      // Refuse rather than truncate. A backup missing its most recent two years
      // is worse than no backup, because the student believes they have one.
      throw const BackupException(BackupFailure.tooLarge);
    }

    await _guard(
      () async => _doc()
          .set(<String, Object?>{
            'payload': Blob(bytes),
            // A plain field beside the payload rather than a key inside it: it
            // has to be readable without decompressing the thing it describes,
            // and a digest stored inside the bytes it covers cannot cover
            // itself.
            'checksum': encoded.checksum,
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

  @override
  Future<void> deleteCloudData() async {
    // `_doc()` throws `notSignedIn` when the account is already gone — which
    // is the state account deletion leaves behind. That is success here, not
    // a failure to report: the goal is "nothing of this student's remains",
    // and an account that no longer exists owns nothing.
    try {
      await _guard(() async => _doc().delete().timeout(_timeout));
    } on BackupException catch (e) {
      if (e.failure != BackupFailure.notSignedIn) rethrow;
    }
  }

  /// **Static on purpose, and not inlined at the call sites.**
  ///
  /// `Isolate.run` sends its closure, and a closure written inside an instance
  /// method captures that method's whole context -- including `this`, because
  /// the surrounding code calls `_doc()` and `_guard()`. Sending `this` means
  /// sending the `FirebaseFirestore` handle, which is not sendable, and the
  /// upload fails with "object is unsendable" before it has compressed
  /// anything.
  ///
  /// In production both handles are null, so nothing was there to be unsendable
  /// and this never fired. It fires the moment a real Firestore is injected --
  /// which is exactly what the first test to exercise this class did. A static
  /// method has no `this` to capture, so the context carries only the payload.
  static Future<_Encoded> _encodeOffThread(Map<String, Object?> json) =>
      Isolate.run(() => _encode(json));

  static Future<_Decoded> _decodeOffThread(Uint8List bytes) =>
      Isolate.run(() => _decode(bytes));

  /// Translates every transport failure into a [BackupFailure] at the boundary,
  /// so no Firebase type and no English error string escapes this file.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on BackupException {
      rethrow;
    } on FirebaseException catch (e, stack) {
      reportNonFatal(e, stack);
      throw BackupException(switch (e.code) {
        'permission-denied' => BackupFailure.permissionDenied,
        'unauthenticated' => BackupFailure.notSignedIn,
        'unavailable' || 'deadline-exceeded' => BackupFailure.offline,
        _ => BackupFailure.unknown,
      });
    } on SocketException catch (e, stack) {
      reportNonFatal(e, stack);
      throw const BackupException(BackupFailure.offline);
    } on Object catch (e, stack) {
      // TimeoutException lands here too, and is the offline case in practice.
      reportNonFatal(e, stack);
      throw const BackupException(BackupFailure.offline);
    }
  }
}
