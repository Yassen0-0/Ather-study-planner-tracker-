import '../entities/study_backup.dart';

/// Why a backup did not happen.
///
/// A structured enum, never a message string -- the same rule as [AuthFailure]
/// and `Insight`. The data layer has no access to localisation, so an English
/// Firestore error could never reach an Arabic student.
enum BackupFailure {
  /// No network, or the request timed out. The overwhelmingly common one, and
  /// the one that is **not an error**: the app is offline-first, so "not saved
  /// yet" is a state to display, not a failure to report.
  offline,

  /// Signed out. Nothing to key a backup document off.
  notSignedIn,

  /// The security rules rejected the read or write. In practice this means the
  /// rules were never published -- worth surfacing distinctly, because it looks
  /// exactly like "sync silently does nothing" otherwise.
  permissionDenied,

  /// The compressed payload exceeds what a single document can hold.
  tooLarge,

  /// The stored copy cannot be parsed, or was written by a newer app.
  unreadable,

  /// Not uploaded, on purpose: the cloud already holds a record with more
  /// chapters or exams than this device, and this device has never synced
  /// with it (D1). Typically a new phone whose automatic restore did not get
  /// through before the student started typing -- uploading would replace
  /// years of history with a morning's. The student decides, from the backup
  /// screen: restore the cloud copy, or knowingly save this phone over it.
  cloudHasMore,

  unknown,
}

class BackupException implements Exception {
  const BackupException(this.failure);

  final BackupFailure failure;

  @override
  String toString() => 'BackupException: ${failure.name}';
}

/// What the cloud holds about a backup without downloading it.
///
/// Read separately from the payload so "is the cloud copy newer than mine?" does
/// not cost a full download and a decompress on every launch.
final class BackupMetadata {
  const BackupMetadata({
    required this.updatedAt,
    required this.chapterCount,
    required this.examCount,
    required this.formatVersion,
  });

  final DateTime updatedAt;
  final int chapterCount;
  final int examCount;
  final int formatVersion;
}

/// The student's study record, mirrored off the device.
///
/// **This is a backup, not a second source of truth.** Local SQLite answers
/// every read and takes every write; nothing in the UI ever waits on this. See
/// PROJECT.md §3.17, which this feature rewrote.
abstract interface class BackupRepository {
  /// Cheap enough to call on launch: metadata only, no payload.
  ///
  /// Null means the student has never backed up.
  Future<BackupMetadata?> readMetadata();

  Future<StudyBackup?> download();

  Future<void> upload(StudyBackup backup);

  /// Removes the cloud mirror entirely — the counterpart of account deletion,
  /// not of sign-out. Must be idempotent: called after the auth account may
  /// already be gone, so "no such document" is success.
  Future<void> deleteCloudData();
}
