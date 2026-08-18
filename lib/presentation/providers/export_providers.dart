import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/study_backup.dart';
import '../../domain/services/data_export_service.dart';
import 'app_providers.dart';
import 'task_providers.dart';

final dataExportServiceProvider = Provider<DataExportService>(
  (ref) => const DataExportService(),
);

/// What the Export screen shows. Never blocks anything.
enum ExportStatus {
  /// Nothing has been exported yet this session, and nothing is known to be
  /// wrong.
  idle,

  /// An export operation is in progress -- saving to Downloads or opening the
  /// share sheet.
  exporting,

  /// The last export succeeded. Carried with a file path for Downloads exports
  /// so the card can show "Saved to /storage/..." or open the file.
  success,

  /// The last attempt failed. Carried with an [ExportFailure] so the screen can
  /// say *why* -- "could not write to Downloads" and "share sheet unavailable"
  /// are very different news.
  failed,
}

final class ExportState {
  const ExportState({
    this.status = ExportStatus.idle,
    this.savedPath,
    this.failure,
  });

  final ExportStatus status;
  final String? savedPath;
  final ExportFailure? failure;

  ExportState copyWith({
    ExportStatus? status,
    String? savedPath,
    ExportFailure? failure,
    bool clearSavedPath = false,
    bool clearFailure = false,
  }) {
    return ExportState(
      status: status ?? this.status,
      savedPath: clearSavedPath ? null : (savedPath ?? this.savedPath),
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// Manages data export operations.
///
/// **On-demand only.** Unlike backup sync, this never runs automatically -- the
/// student has to tap a button. No debouncing, no background saves, no
/// lifecycle hooks. When a screen calls [saveToDownloads] or [shareAsJson],
/// the operation runs immediately and the state reflects what happened.
class DataExportNotifier extends Notifier<ExportState> {
  @override
  ExportState build() => const ExportState();

  /// Exports the student's complete record as JSON to the Downloads folder.
  ///
  /// Returns the absolute path to the saved file on success. The state moves to
  /// [ExportStatus.success] with the path so the UI can display it or offer to
  /// open the file.
  Future<String?> saveToDownloads() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      clearSavedPath: true,
      clearFailure: true,
    );

    try {
      final backup = await _buildBackup();
      final path = await ref
          .read(dataExportServiceProvider)
          .saveToDownloads(backup);

      state = state.copyWith(
        status: ExportStatus.success,
        savedPath: path,
        clearFailure: true,
      );

      return path;
    } on ExportException catch (e) {
      state = state.copyWith(
        status: ExportStatus.failed,
        failure: e.failure,
        clearSavedPath: true,
      );
      return null;
    } on Object {
      state = state.copyWith(
        status: ExportStatus.failed,
        failure: ExportFailure.unknown,
        clearSavedPath: true,
      );
      return null;
    }
  }

  /// Opens the Android share sheet with the student's data as a JSON file.
  ///
  /// The student can then send it via WhatsApp, email, Drive, or any other app
  /// that accepts file shares. The state moves to [ExportStatus.success] if the
  /// share sheet opened, even if the student dismissed it -- dismissal is not a
  /// failure.
  Future<void> shareAsJson() async {
    state = state.copyWith(
      status: ExportStatus.exporting,
      clearSavedPath: true,
      clearFailure: true,
    );

    try {
      final backup = await _buildBackup();
      await ref.read(dataExportServiceProvider).shareAsJson(backup);

      state = state.copyWith(
        status: ExportStatus.success,
        clearSavedPath: true,
        clearFailure: true,
      );
    } on ExportException catch (e) {
      state = state.copyWith(
        status: ExportStatus.failed,
        failure: e.failure,
        clearSavedPath: true,
      );
    } on Object {
      state = state.copyWith(
        status: ExportStatus.failed,
        failure: ExportFailure.unknown,
        clearSavedPath: true,
      );
    }
  }

  /// Builds a [StudyBackup] from the current database state.
  ///
  /// `.future`, never `snapshotValueProvider` / `tasksValueProvider`. Those two
  /// fall back to empty while their stream is still loading -- deliberately, so
  /// a transient frame cannot crash a screen -- and reading them here asked
  /// "what does this student have?" at the one moment the honest answer is "not
  /// known yet".
  ///
  /// Awaiting is free here: nothing renders off this path, and the student has
  /// explicitly asked for an export so a brief wait is expected.
  Future<StudyBackup> _buildBackup() async {
    final snapshot = await ref.read(snapshotProvider.future);
    final tasks = await ref.read(tasksProvider.future);
    return StudyBackup.fromSnapshot(snapshot, tasks);
  }
}

final dataExportProvider = NotifierProvider<DataExportNotifier, ExportState>(
  DataExportNotifier.new,
);
