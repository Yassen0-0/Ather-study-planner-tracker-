import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_card.dart';
import '../../core/widgets/ather_scaffold.dart';
import '../../core/widgets/ather_toast.dart';
import '../../core/widgets/buttons.dart';
import '../../domain/services/data_export_service.dart';
import '../providers/export_providers.dart';

/// The student's own record, on its way out of the app.
///
/// One screen, one action. There is no format picker and no "save here vs
/// share" choice: the export is JSON because that is the shape the backup
/// already speaks, and it leaves through the share sheet because that is the
/// only place on Android the student genuinely chooses where their file lands.
/// See [DataExportService] for why a second "save to Downloads" button would be
/// a lie about where the file went.
///
/// The chapter report PDF is deliberately **not** here. It belongs on the
/// chapter report screen, next to the report it is a copy of.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  /// Turns a failure into a sentence, here rather than in the domain layer --
  /// which has no localisation, which is why [ExportFailure] is an enum.
  String _failureLabel(L l, ExportFailure failure) => switch (failure) {
    ExportFailure.fileSystemError => l.exportErrorFile,
    ExportFailure.shareError => l.exportErrorShare,
    ExportFailure.unknown => l.commonSomethingWentWrong,
  };

  Future<void> _export() async {
    final l = L.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    final direction = Directionality.of(context);

    await ref.read(dataExportProvider.notifier).share();
    if (!mounted) return;

    final state = ref.read(dataExportProvider);
    if (state.status == ExportStatus.failed && state.failure != null) {
      showAtherToastOn(
        overlay,
        direction,
        _failureLabel(l, state.failure!),
        tone: ToastTone.failed,
      );
    }
    // Success gets no toast. The share sheet appearing is the feedback, and a
    // message reading "shared" after the student backed out of the sheet would
    // be reporting something that did not happen.
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final export = ref.watch(dataExportProvider);

    return AtherScreen(
      header: AtherHeader(title: l.exportTitle, onBack: () => context.pop()),
      children: <Widget>[
        AtherCard(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(l.exportBody, style: context.text.secondaryStrong),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: l.exportAction,
                tone: PrimaryButtonTone.secondary,
                busy: export.busy,
                onTap: _export,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l.exportWhereNote,
                style: AppTypography.controlLabel.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
