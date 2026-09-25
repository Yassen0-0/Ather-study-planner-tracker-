import 'package:ather/domain/entities/study_backup.dart';
import 'package:ather/domain/repositories/backup_repository.dart';

/// A [BackupRepository] that never touches a network.
///
/// Every widget test boots the real app, and the real app has a backup layer
/// wired into its lifecycle. Without this the tests would either need Firebase
/// running or would be asserting against `[core/no-app]`.
///
/// The default is [FakeBackupRepository.failing], because the interesting
/// property is not that sync works -- it is that **the app is completely usable
/// when sync does not**.
class FakeBackupRepository implements BackupRepository {
  FakeBackupRepository({this.stored, this.metadata, this.failure});

  /// Nothing in the cloud, and every call fails. What a student in airplane
  /// mode has, which is the state this app is designed around.
  FakeBackupRepository.failing([
    BackupFailure this.failure = BackupFailure.offline,
  ]) : stored = null,
       metadata = null;

  /// A cloud copy waiting to be pulled down.
  FakeBackupRepository.holding(StudyBackup this.stored, {DateTime? updatedAt})
    : failure = null,
      metadata = BackupMetadata(
        updatedAt: updatedAt ?? DateTime(2026, 8, 5),
        chapterCount: stored.chapterCount,
        examCount: stored.examCount,
        formatVersion: StudyBackup.formatVersion,
      );

  StudyBackup? stored;
  BackupMetadata? metadata;
  BackupFailure? failure;

  int uploadCount = 0;
  int downloadCount = 0;
  int deleteCount = 0;

  /// Set when [delete] runs, so a test can assert the cloud copy went **before**
  /// the account did rather than merely that both were called.
  bool? cloudDeletedBeforeAccountDeleted;

  /// Consulted by [delete] to record the ordering above.
  int Function()? accountDeleteCount;

  /// How often the cloud was *looked at* -- D1's first-upload check reads
  /// metadata, and a device that already knows the cloud must stop asking.
  int metadataReadCount = 0;

  @override
  Future<BackupMetadata?> readMetadata() async {
    metadataReadCount++;
    if (failure != null) throw BackupException(failure!);
    return metadata;
  }

  @override
  Future<StudyBackup?> download() async {
    downloadCount++;
    if (failure != null) throw BackupException(failure!);
    return stored;
  }

  @override
  Future<void> upload(StudyBackup backup) async {
    uploadCount++;
    if (failure != null) throw BackupException(failure!);
    stored = backup;
  }

  int deleteCloudCount = 0;

  @override
  Future<void> deleteCloudData() async {
    deleteCloudCount++;
    cloudDeletedBeforeAccountDeleted = (accountDeleteCount?.call() ?? 0) == 0;
    if (failure != null) throw BackupException(failure!);
    stored = null;
    metadata = null;
  }
}
