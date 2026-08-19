import 'package:ather/data/notifications/review_notification_service.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// A [ReviewNotificationService] that records instead of scheduling.
///
/// The real one talks to the platform on every call, so in a widget test each
/// one throws into the `catch (_)` that `ReviewScheduler` keeps around for
/// unsupported platforms -- meaning the scheduler's decisions were invisible to
/// the test suite. Constructing the plugin object is harmless; only its methods
/// touch a channel, and none of them are called here.
final class FakeNotificationService extends ReviewNotificationService {
  FakeNotificationService() : super(FlutterLocalNotificationsPlugin());

  /// The `enabled` argument of every [reschedule], in order. `false` means the
  /// pass cancelled everything and scheduled nothing.
  final List<bool> rescheduleEnabled = <bool>[];

  /// What the last pass decided to register, in the order it would have
  /// registered it.
  ///
  /// The override below never reaches a platform channel, so it runs the real
  /// [ReviewNotificationService.planReminders] and keeps the result instead.
  /// That is the half worth asserting on: the moments, the bodies, the ids and
  /// the cap are all decided there, and `zonedSchedule` only carries them
  /// across.
  List<ScheduledReminder> plannedReminders = const <ScheduledReminder>[];

  int cancelAllCount = 0;

  bool get lastPassScheduled =>
      rescheduleEnabled.isNotEmpty && rescheduleEnabled.last;

  @override
  Future<void> initialise({
    required void Function(int lessonId) onLessonTapped,
  }) async {}

  @override
  Future<bool> refreshPermission() async {
    permissionGranted = true;
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    permissionGranted = true;
    return true;
  }

  @override
  Future<void> reschedule({
    required StudySnapshot snapshot,
    required DateTime now,
    required bool enabled,
    required String Function(String lesson, String chapter) buildBody,
    required String Function(String lesson, String chapter) buildEarlyBody,
    required String title,
  }) async {
    rescheduleEnabled.add(enabled);
    plannedReminders = ReviewNotificationService.planReminders(
      snapshot: snapshot,
      now: now,
      enabled: enabled,
      buildBody: buildBody,
      buildEarlyBody: buildEarlyBody,
    );
    if (!enabled) cancelAllCount++;
  }

  @override
  Future<void> cancelAll() async => cancelAllCount++;
}
