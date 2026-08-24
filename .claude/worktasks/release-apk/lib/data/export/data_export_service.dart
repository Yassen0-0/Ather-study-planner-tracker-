import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/study_backup.dart';

/// Why an export did not complete.
///
/// A structured enum, never a message string -- the same rule as
/// [BackupFailure]. This layer has no localisation, so an English
/// platform error could never reach an Arabic student.
enum ExportFailure {
  /// The file could not be written to the app's temporary directory. Almost
  /// always means the device is out of storage.
  fileSystemError,

  /// The system share sheet could not be opened at all. Platform-specific, and
  /// rare. Distinct from the student dismissing the sheet, which is not a
  /// failure.
  shareError,

  unknown,
}

class ExportException implements Exception {
  const ExportException(this.failure);

  final ExportFailure failure;

  @override
  String toString() => 'ExportException: ${failure.name}';
}

/// Hands the student their own record as a JSON file, through the share sheet.
///
/// **Fully offline.** Nothing here touches the network: it serialises what is
/// already in memory, writes it to the app's temporary directory, and hands the
/// path to the system share sheet. A student with no connectivity can export.
///
/// **Why JSON:** portability and trust. A student who can open their export in
/// a text editor and read their own exam scores knows the record is theirs, not
/// trapped. It is also the same serialisation the cloud backup uses, so it
/// inherits [StudyBackup]'s round-trip tests rather than growing a second
/// format that can drift away from them.
///
/// **Why the share sheet and not a "save to Downloads" button.** The obvious
/// second button is a tempting one, and it is wrong on this platform.
/// `path_provider`'s `getDownloadsDirectory()` resolves on Android to
/// `Android/data/com.ather.app/files/Download` -- app-private storage that the
/// student cannot reach from a file manager and that Android deletes with the
/// app. A button reading "saved to Downloads" would be a false statement about
/// where the file went, attached to a copy that disappears at exactly the
/// moment an export is supposed to survive. The share sheet lets the student
/// put the file somewhere that is actually theirs: Drive, WhatsApp, Files, a
/// mail draft.
class DataExportService {
  const DataExportService();

  /// Serialises [backup] and opens the system share sheet with it attached.
  ///
  /// [now] stamps the exported filename. Time is handed in by the caller's
  /// [Clock](see PROJECT.md §3.8) rather than read off the wall -- this used to
  /// be the one `DateTime.now()` outside that rule, which made the name an
  /// export would land under unpinnable in a test.
  ///
  /// Returns normally when the sheet opened, whether or not the student went on
  /// to send the file -- backing out of a share sheet is a decision, not an
  /// error, and reporting it as one teaches students to distrust the message.
  Future<void> share(StudyBackup backup, {required DateTime now}) async {
    final json = encode(backup);
    final filename = buildFilename(now);

    final File file;
    try {
      final directory = await getTemporaryDirectory();
      file = File('${directory.path}/$filename');
      await file.writeAsString(json);
    } on Object {
      throw const ExportException(ExportFailure.fileSystemError);
    }

    try {
      final result = await Share.shareXFiles(<XFile>[XFile(file.path)]);
      if (result.status == ShareResultStatus.unavailable) {
        throw const ExportException(ExportFailure.shareError);
      }
    } on ExportException {
      rethrow;
    } on Object {
      throw const ExportException(ExportFailure.shareError);
    }
  }

  /// Serialises the backup to indented JSON.
  ///
  /// **Why indented:** this file is for a student to read, not for a machine to
  /// parse cheaply. A multi-year record minified onto one line is unreadable in
  /// a text editor, and the size difference does not matter for a file measured
  /// in tens of kilobytes that is written once and shared by hand.
  ///
  /// The payload carries `formatVersion` -- [StudyBackup.toJson] writes it --
  /// so an export can be told apart from a future shape rather than half-read.
  String encode(StudyBackup backup) =>
      const JsonEncoder.withIndent('  ').convert(backup.toJson());

  /// `ather_export_YYYY-MM-DD_HH-MM-SS.json`, in local time.
  ///
  /// The timestamp keeps repeated exports from overwriting each other and sorts
  /// chronologically in a file browser. Colons become dashes: they are legal on
  /// Android but not on the Windows and Drive targets a shared file often lands
  /// on, and a filename rejected at the far end is a share that silently fails.
  String buildFilename(DateTime at) {
    final stamp = at
        .toIso8601String()
        .substring(0, 19)
        .replaceAll('T', '_')
        .replaceAll(':', '-');
    return 'ather_export_$stamp.json';
  }
}
