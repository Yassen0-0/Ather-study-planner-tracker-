import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/study_backup.dart';
import '../../domain/services/data_export_service.dart';
import 'app_providers.dart';
import 'task_providers.dart';

final dataExportServiceProvider = Provider<DataExportService>(
  (ref) => const DataExportService(),
);

enum ExportStatus { idle, exporting, done, failed }

final class ExportState {
  const ExportState({this.status = ExportStatus.idle, this.failure});

  final ExportStatus status;

  /// Set only alongside [ExportStatus.failed], so the screen can say *why*:
  /// "the file could not be written" and "the share sheet would not open" are
  /// different news and point at different fixes.
  final ExportFailure? failure;

  bool get busy => status == ExportStatus.exporting;
}

/// Drives the one action on the export screen.
///
/// **On demand only.** Unlike the cloud backup, nothing here runs on a timer, a
/// lifecycle hook or a data change. The student taps, it runs, the state says
/// what happened.
class DataExportNotifier extends Notifier<ExportState> {
  @override
  ExportState build() => const ExportState();

  Future<void> share() async {
    if (state.busy) return;
    state = const ExportState(status: ExportStatus.exporting);

    try {
      final backup = await _buildBackup();
      await ref.read(dataExportServiceProvider).share(backup);
      state = const ExportState(status: ExportStatus.done);
    } on ExportException catch (e) {
      state = ExportState(status: ExportStatus.failed, failure: e.failure);
    } on Object {
      state = const ExportState(
        status: ExportStatus.failed,
        failure: ExportFailure.unknown,
      );
    }
  }

  /// Reads through `.future`, never `snapshotValueProvider` / `tasksValueProvider`.
  ///
  /// Those two fall back to empty while their stream is still loading --
  /// deliberately, so a transient frame cannot crash a screen -- and reading
  /// them here would ask "what has this student recorded?" at the one moment
  /// the honest answer is "not known yet", then export the empty answer as
  /// though it were the record. Awaiting costs nothing on this path: no frame
  /// is waiting on it, and the student has just asked for an export.
  Future<StudyBackup> _buildBackup() async {
    final snapshot = await ref.read(snapshotProvider.future);
    final tasks = await ref.read(tasksProvider.future);
    return StudyBackup.fromSnapshot(snapshot, tasks);
  }
}

final dataExportProvider = NotifierProvider<DataExportNotifier, ExportState>(
  DataExportNotifier.new,
);
