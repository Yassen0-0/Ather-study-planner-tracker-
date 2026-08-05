import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../data/notifications/review_notification_service.dart';
import 'app_providers.dart';

final notificationServiceProvider = Provider<ReviewNotificationService>((ref) {
  return ReviewNotificationService(FlutterLocalNotificationsPlugin());
});

/// Keeps the scheduled reminders in step with the data and repairs drift on
/// resume.
///
/// Mounted once, near the root of the tree.
class ReviewScheduler extends ConsumerStatefulWidget {
  const ReviewScheduler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ReviewScheduler> createState() => _ReviewSchedulerState();
}

class _ReviewSchedulerState extends ConsumerState<ReviewScheduler>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Resume is the reconciliation point: the device may have been off, the
    // clock may have moved, or exams may have been recorded on another day.
    // Re-deriving the whole schedule here is cheap and cannot leave a stale
    // reminder behind.
    if (state == AppLifecycleState.resumed) _sync();
  }

  Future<void> _sync() async {
    if (!mounted) return;

    final service = ref.read(notificationServiceProvider);
    final l = L.of(context);

    try {
      await service.initialise(onLessonTapped: (_) {});
      await service.reschedule(
        snapshot: ref.read(snapshotValueProvider),
        now: ref.read(clockProvider).now(),
        enabled: ref.read(notificationsEnabledProvider),
        title: l.reviewNotificationTitle,
        buildBody: (lesson, chapter) =>
            l.reviewNotificationBody(lesson, chapter),
      );
    } catch (_) {
      // Notifications are an enhancement, never a gate. If the platform
      // refuses -- unsupported desktop build, revoked permission, missing
      // channel -- the in-app red flags still carry the whole mechanic.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-schedule whenever the data or the preference changes.
    ref.listen(snapshotProvider, (_, _) => _sync());
    ref.listen(notificationsEnabledProvider, (_, _) => _sync());
    return widget.child;
  }
}
