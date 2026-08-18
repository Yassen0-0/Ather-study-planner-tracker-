import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_card.dart';
import '../../core/widgets/ather_scaffold.dart';
import '../../core/widgets/ather_toast.dart';
import '../../core/widgets/buttons.dart';
import '../../domain/services/data_export_service.dart';
import '../../domain/services/pdf_export_service.dart';
import '../providers/app_providers.dart';
import '../providers/export_providers.dart';

/// Data export screen offering JSON and PDF export options.
///
/// **Two export types, two use cases:**
/// - **JSON export:** Complete data backup for portability and archival. The
///   student gets every subject, chapter, lesson, exam, and mastery score in a
///   structured format they can read in a text editor or reimport elsewhere.
/// - **PDF summary:** Human-readable mastery overview for printing or sharing
///   with parents/tutors. Shows overall mastery, per-subject breakdown, and
///   chapter/lesson hierarchy.
///
/// Both work fully offline and never touch the network. The student can save
/// to Downloads or share via the Android share sheet.
///
/// **Why a dedicated screen rather than a settings row:** Export is a
/// deliberate action with multiple options and potential failure states. A
/// single row cannot show "JSON or PDF?", "Save or Share?", status messages,
/// and error handling. This screen gives each option room to breathe.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  /// PDF export state, managed locally since there is no PdfExportNotifier yet.
  /// Follows the same pattern as [_restoring] in BackupScreen: a boolean flag
  /// that disables the button while the operation runs.
  bool _exportingPdf = false;

  /// Turns an export failure into a sentence. Follows the same pattern as
  /// [_failureLabel] in BackupScreen: the data layer returns structured enums,
  /// the presentation layer translates them to strings.
  String _exportFailureLabel(ExportFailure failure) {
    switch (failure) {
      case ExportFailure.fileSystemError:
        return 'Could not write to Downloads folder';
      case ExportFailure.shareError:
        return 'Share sheet could not be opened';
      case ExportFailure.unknown:
        return 'Export failed. Please try again.';
    }
  }

  String _pdfExportFailureLabel(PdfExportFailure failure) {
    switch (failure) {
      case PdfExportFailure.fileSystemError:
        return 'Could not write to Downloads folder';
      case PdfExportFailure.shareError:
        return 'Share sheet could not be opened';
      case PdfExportFailure.unknown:
        return 'PDF export failed. Please try again.';
    }
  }

  /// Exports JSON data to the Downloads folder.
  Future<void> _saveJsonToDownloads() async {
    final messenger = Overlay.of(context, rootOverlay: true);
    final direction = Directionality.of(context);

    await ref.read(dataExportProvider.notifier).saveToDownloads();
    if (!mounted) return;

    final state = ref.read(dataExportProvider);
    if (state.status == ExportStatus.success) {
      showAtherToastOn(messenger, direction, 'Saved to Downloads');
    } else if (state.status == ExportStatus.failed && state.failure != null) {
      showAtherToastOn(
        messenger,
        direction,
        _exportFailureLabel(state.failure!),
        tone: ToastTone.failed,
      );
    }
  }

  /// Opens the share sheet with JSON data.
  Future<void> _shareJson() async {
    final messenger = Overlay.of(context, rootOverlay: true);
    final direction = Directionality.of(context);

    await ref.read(dataExportProvider.notifier).shareAsJson();
    if (!mounted) return;

    final state = ref.read(dataExportProvider);
    if (state.status == ExportStatus.failed && state.failure != null) {
      showAtherToastOn(
        messenger,
        direction,
        _exportFailureLabel(state.failure!),
        tone: ToastTone.failed,
      );
    }
    // Success case: no toast. The share sheet opening is feedback enough, and
    // a toast saying "Shared" when the student dismissed the sheet would be
    // wrong -- dismissal is not sharing.
  }

  /// Exports PDF summary to the Downloads folder.
  Future<void> _savePdfToDownloads() async {
    if (_exportingPdf) return;

    final messenger = Overlay.of(context, rootOverlay: true);
    final direction = Directionality.of(context);

    setState(() => _exportingPdf = true);
    try {
      final snapshot = await ref.read(snapshotProvider.future);
      const service = PdfExportService();
      await service.saveToDownloads(snapshot);

      if (mounted) {
        showAtherToastOn(messenger, direction, 'PDF saved to Downloads');
      }
    } on PdfExportException catch (e) {
      if (mounted) {
        showAtherToastOn(
          messenger,
          direction,
          _pdfExportFailureLabel(e.failure),
          tone: ToastTone.failed,
        );
      }
    } on Object catch (error, stack) {
      debugPrint('Ather: PDF export failed -- $error\n$stack');
      if (mounted) {
        showAtherToastOn(
          messenger,
          direction,
          'Something went wrong',
          tone: ToastTone.failed,
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  /// Opens the share sheet with PDF summary.
  Future<void> _sharePdf() async {
    if (_exportingPdf) return;

    final messenger = Overlay.of(context, rootOverlay: true);
    final direction = Directionality.of(context);

    setState(() => _exportingPdf = true);
    try {
      final snapshot = await ref.read(snapshotProvider.future);
      const service = PdfExportService();
      await service.shareAsPdf(snapshot);
      // Success case: no toast. The share sheet opening is feedback enough.
    } on PdfExportException catch (e) {
      if (mounted) {
        showAtherToastOn(
          messenger,
          direction,
          _pdfExportFailureLabel(e.failure),
          tone: ToastTone.failed,
        );
      }
    } on Object catch (error, stack) {
      debugPrint('Ather: PDF export failed -- $error\n$stack');
      if (mounted) {
        showAtherToastOn(
          messenger,
          direction,
          'Something went wrong',
          tone: ToastTone.failed,
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exportState = ref.watch(dataExportProvider);

    return AtherScreen(
      header: AtherHeader(
        title: 'Export Data',
        onBack: () => context.pop(),
      ),
      children: <Widget>[
        // JSON Export Section
        Text(
          'Complete Data Export',
          style: AppTypography.sectionTitle.copyWith(color: context.colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Export all your study data as JSON: subjects, chapters, lessons, exams, and mastery scores. You can reimport this file or keep it as a personal backup.',
          style: AppTypography.body.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        AtherCard(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PrimaryButton(
                label: 'Save to Downloads',
                tone: PrimaryButtonTone.secondary,
                busy: exportState.status == ExportStatus.exporting,
                onTap: _saveJsonToDownloads,
              ),
              const SizedBox(height: AppSpacing.xs),
              PrimaryButton(
                label: 'Share',
                tone: PrimaryButtonTone.secondary,
                busy: exportState.status == ExportStatus.exporting,
                onTap: _shareJson,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),

        // PDF Summary Section
        Text(
          'Mastery Summary (PDF)',
          style: AppTypography.sectionTitle.copyWith(color: context.colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Generate a PDF report of your mastery across all subjects. Perfect for printing or sharing with parents and tutors.',
          style: AppTypography.body.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        AtherCard(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PrimaryButton(
                label: 'Save PDF to Downloads',
                tone: PrimaryButtonTone.secondary,
                busy: _exportingPdf,
                onTap: _savePdfToDownloads,
              ),
              const SizedBox(height: AppSpacing.xs),
              PrimaryButton(
                label: 'Share PDF',
                tone: PrimaryButtonTone.secondary,
                busy: _exportingPdf,
                onTap: _sharePdf,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
