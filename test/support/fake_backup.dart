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

  @override
  Future<BackupMetadata?> readMetadata() async {
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
}
