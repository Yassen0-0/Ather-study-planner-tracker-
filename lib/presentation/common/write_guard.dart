import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/widgets/ather_toast.dart';

/// Runs a write and tells the student if it did not happen.
///
/// **Why this exists.** Almost every write in the app was fire-and-forget:
/// ticking a checklist step, saving a homework score, mastering a chapter,
/// adding a chapter or a lesson or a task, reordering a day. A failure on any of
/// them produced no exception anyone caught, no message, and no change on
/// screen — the tap simply did nothing, and the student's only reading of that
/// is that the app is broken. In an offline-first app the database is the one
/// thing that is *supposed* to be reliable, which is exactly why its rare
/// failures need saying out loud rather than assuming away.
///
/// The context is resolved **before** the await, so nothing reaches into a tree
/// that may have been torn down while the write was in flight — the same rule
/// the exam wizard and the backup card already follow by hand.
///
/// Returns whether the write succeeded, so a caller that has follow-up work
/// (pop the screen, show its own toast) can skip it.
Future<bool> runWrite(
  BuildContext context,
  Future<void> Function() action, {

  /// Shown on success. Most writes are their own confirmation — the row appears,
  /// the tick fills — so this is usually null and the toast stays reserved for
  /// recording evidence.
  String? successMessage,
}) async {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final direction = Directionality.of(context);
  final failureMessage = L.of(context).commonSomethingWentWrong;

  try {
    await action();
  } on Object catch (error, stack) {
    debugPrint('Ather: write failed -- $error\n$stack');
    if (overlay != null) {
      showAtherToastOn(
        overlay,
        direction,
        failureMessage,
        tone: ToastTone.failed,
      );
    }
    return false;
  }

  if (successMessage != null && overlay != null) {
    showAtherToastOn(overlay, direction, successMessage);
  }
  return true;
}
