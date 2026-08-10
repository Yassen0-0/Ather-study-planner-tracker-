import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../data/notifications/review_notification_service.dart';
import 'app_providers.dart';

final notificationServiceProvider = Provider<ReviewNotificationService>((ref) {
  return ReviewNotificationService(FlutterLocalNotificationsPlugin());
});

/// Whether the OS will actually deliver a notification.
///
/// Deliberately separate from [notificationsEnabledProvider], which is the
/// student's own preference. The two can disagree — the switch on, Android
/// refusing to show anything — and that combination was previously invisible in
/// every direction: the switch said reminders were on, the schedule silently did
/// nothing, and nothing anywhere said why.
final osNotificationsAllowedProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref.watch(notificationServiceProvider).refreshPermission();
  } catch (_) {
    // An unsupported platform reports by throwing. That is a "no".
    return false;
  }
});

/// True when a reminder is actually owed to somebody: at least one lesson has a
/// review clock running.
///
/// The Settings card only warns about a blocked permission when this is true.
/// On a fresh install the permission has legitimately never been asked for and
/// there is nothing to remind about yet, so a warning there would be noise about
/// a problem the student does not have.
final hasScheduledReviewsProvider = Provider<bool>((ref) {
  return ref
      .watch(snapshotValueProvider)
      .lessons
      .any((lesson) => lesson.lastReviewedAt != null);
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
  /// Rescheduling is `cancelAll()` plus one platform round trip **per lesson**.
  /// Ticking a single checklist box re-emits the snapshot, so without this every
  /// tap on the lesson screen paid for a full rebuild of a few hundred alarms.
  /// The schedule only has to be right by the time the app is next away, and it
  /// is rebuilt on resume anyway, so a few seconds of lag costs nothing.
  static const Duration _debounce = Duration(seconds: 5);

  Timer? _pending;

  /// Two overlapping passes would interleave a `cancelAll()` with the other's
  /// `zonedSchedule` calls and silently drop reminders the first one had already
  /// written. A rebuild that arrives mid-pass is not lost: [_dirty] replays it.
  bool _running = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _pending?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Resume is the reconciliation point: the device may have been off, the
    // clock may have moved, exams may have been recorded on another day, or the
    // student may have just revoked the notification permission in Settings.
    // Immediate rather than debounced -- this is the one pass that has to be
    // correct before the app is next backgrounded.
    if (state == AppLifecycleState.resumed) _sync();
  }

  /// Coalesces a burst of writes into one reschedule.
  void _scheduleSync() {
    _pending?.cancel();
    _pending = Timer(_debounce, _sync);
  }

  Future<void> _sync() async {
    if (!mounted) return;
    if (_running) {
      _dirty = true;
      return;
    }
    _running = true;
    _pending?.cancel();

    final service = ref.read(notificationServiceProvider);
    final l = L.of(context);

    try {
      await service.initialise(onLessonTapped: _openLesson);
      // Read back from the OS every pass rather than trusting a flag: this is
      // what lets a student who granted the permission months ago keep getting
      // reminders, and what notices one revoked in system settings.
      await service.refreshPermission();
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
    } finally {
      _running = false;
      if (_dirty) {
        _dirty = false;
        if (mounted) _scheduleSync();
      }
    }
  }

  /// Tapping a reminder lands on the lesson it is about.
  ///
  /// The payload was already being written and parsed; it was then handed to an
  /// empty callback, so the reminder opened the dashboard and left the student
  /// to find the lesson themselves — for a notification whose entire subject is
  /// one specific lesson.
  void _openLesson(int lessonId) {
    // Posted rather than called: the tap can arrive while the engine is still
    // starting up, before the router has a navigator to push onto.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = rootNavigatorKey.currentContext;
      if (context == null) return;
      context.push(Routes.lesson(lessonId));
    });
  }

  @override
  Widget build(BuildContext context) {
    // Re-schedule whenever the data or the preference changes. Debounced: a
    // snapshot re-emits on every single write.
    ref.listen(snapshotProvider, (_, _) => _scheduleSync());
    // Not debounced -- flipping the switch is a deliberate act and the student
    // is looking at the result.
    ref.listen(notificationsEnabledProvider, (_, _) => _sync());
    return widget.child;
  }
}
