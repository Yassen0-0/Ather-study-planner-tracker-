import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../entities/study_backup.dart';

/// Why an export did not complete.
///
/// Structured enum, never a message string -- the same rule as [BackupFailure].
/// The data layer has no access to localisation, so an English platform error
/// could never reach an Arabic student.
enum ExportFailure {
  /// Could not access the Downloads directory or write to it. Typically a
  /// permissions issue, though on modern Android that is uncommon for the
  /// Downloads folder specifically.
  fileSystemError,

  /// The share sheet could not be opened. Platform-specific, and rare.
  shareError,

  unknown,
}

class ExportException implements Exception {
  const ExportException(this.failure);

  final ExportFailure failure;

  @override
  String toString() => 'ExportException: ${failure.name}';
}

/// Exports study data as JSON to Downloads or via the share sheet.
///
/// **Fully offline.** This never touches the network: it serialises what is
/// already in memory and writes it to local storage or hands it to the system
/// share sheet. A student with no connectivity can export.
///
/// **Why JSON rather than a proprietary format:** portability and trust. A
/// student who can open their export in a text editor and read their own exam
/// scores knows the data is theirs, not trapped. JSON is also what the backup
/// uses, so this shares the serialisation code -- and its round-trip tests.
class DataExportService {
  const DataExportService();

  /// Saves the student's complete record as JSON to the Downloads folder.
  ///
  /// Returns the absolute path to the saved file, which the caller can display
  /// or use to open the file.
  ///
  /// The filename includes a timestamp so repeated exports do not overwrite
  /// each other: `ather_export_2026-08-18_14-30-45.json`.
  Future<String> saveToDownloads(StudyBackup backup) async {
    final json = _encodeBackup(backup);
    final filename = _generateFilename();

    try {
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw const ExportException(ExportFailure.fileSystemError);
      }

      final file = File('${directory.path}/$filename');
      await file.writeAsString(json);

      return file.path;
    } on ExportException {
      rethrow;
    } on Object {
      // Covers FileSystemException, SecurityException and any platform-specific
      // error. All of them mean the same thing to the caller: the file did not
      // land where it was meant to.
      throw const ExportException(ExportFailure.fileSystemError);
    }
  }

  /// Opens the Android share sheet with the student's data as a JSON file.
  ///
  /// The student can then send it via WhatsApp, email, Drive, or any other app
  /// that accepts file shares. The file is written to a temporary cache
  /// directory first, then cleaned up by the system when no longer needed.
  Future<void> shareAsJson(StudyBackup backup) async {
    final json = _encodeBackup(backup);
    final filename = _generateFilename();

    try {
      // Write to a temporary directory first -- share_plus needs a real file,
      // not a string, and handing it a Downloads file would leave the share
      // target writing to the same path we use for explicit saves.
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsString(json);

      final result = await Share.shareXFiles(
        <XFile>[XFile(file.path)],
        text: 'Ather study data export',
      );

      // ShareResult.dismissed means the student backed out, which is not an
      // error. Only ShareResultStatus.unavailable is a failure -- the platform
      // could not open the sheet at all.
      if (result.status == ShareResultStatus.unavailable) {
        throw const ExportException(ExportFailure.shareError);
      }
    } on ExportException {
      rethrow;
    } on Object {
      // Covers file write failures and any share_plus exceptions. Translates
      // both into a single actionable message for the UI.
      throw const ExportException(ExportFailure.shareError);
    }
  }

  /// Serialises the backup to pretty-printed JSON.
  ///
  /// **Why pretty-printed:** this is for a student to read, not a machine. A
  /// multi-year record minified to one line is unreadable in a text editor,
  /// and the size difference is negligible -- a gzipped backup is under 100 KB
  /// even for a full curriculum.
  String _encodeBackup(StudyBackup backup) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(backup.toJson());
  }

  /// Generates a timestamped filename for the export.
  ///
  /// Format: `ather_export_YYYY-MM-DD_HH-MM-SS.json`
  ///
  /// The timestamp ensures repeated exports do not overwrite each other, and
  /// sorts chronologically in a file browser. Colons are replaced with dashes
  /// because Windows file systems reject them in filenames.
  String _generateFilename() {
    final now = DateTime.now();
    final timestamp = now.toIso8601String()
        .substring(0, 19) // "2026-08-18T14:30:45"
        .replaceAll('T', '_')
        .replaceAll(':', '-');
    return 'ather_export_$timestamp.json';
  }
}
